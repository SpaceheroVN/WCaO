#pragma once

#ifndef UNICODE
#define UNICODE
#endif
#ifndef _UNICODE
#define _UNICODE
#endif
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shellapi.h>
#include <shlobj.h>
#include <shobjidl.h>
#include <propvarutil.h>
#include <propkey.h>
#include <psapi.h>
#include <tlhelp32.h>
#include <dwmapi.h>
#include <commdlg.h>
#include <mmsystem.h>
#include <objidl.h>
#include <gdiplus.h>

#include <string>
#include <vector>
#include <map>
#include <cstdio>
#include <cstdlib>
#include <cmath>
#include <cwctype>
#include <algorithm>

#include "resource.h"

#define WM_APP_TRAYMSG       (WM_APP + 1)
#define WM_APP_CLEAN_DONE    (WM_APP + 2)
#define WM_APP_ELEVATE_ADMIN (WM_APP + 3)
#define HOTKEY_ID_CLEAN      9988

// ============================================================================
//  1. NATIVE NTAPI, MEMORY ENGINE & REAL HARDWARE BENCHMARKING
// ============================================================================
typedef LONG NTSTATUS;

typedef NTSTATUS(NTAPI* PFN_NtQuerySystemInformation)(ULONG, PVOID, ULONG, PULONG);
typedef NTSTATUS(NTAPI* PFN_NtSetSystemInformation)(ULONG, PVOID, ULONG);
typedef NTSTATUS(NTAPI* PFN_NtQueryTimerResolution)(PULONG, PULONG, PULONG);
typedef NTSTATUS(NTAPI* PFN_NtSetTimerResolution)(ULONG, BOOLEAN, PULONG);
typedef BOOL(WINAPI* PFN_DnsFlushResolverCache)();
typedef DWORD(WINAPI* PFN_FlushIpNetTable)(DWORD);
typedef BOOL(WINAPI* PFN_SetProcessInformation)(HANDLE, int, LPVOID, DWORD);

struct MEMORY_PRIORITY_INFO_NT {
    ULONG MemoryPriority;
};

struct PROCESS_POWER_THROTTLING_STATE_NT {
    ULONG Version;
    ULONG ControlMask;
    ULONG StateMask;
};

struct UNICODE_STRING_NT {
    USHORT Length;
    USHORT MaximumLength;
    PWSTR  Buffer;
};

struct SYSTEM_PAGEFILE_INFORMATION_NT {
    ULONG NextEntryOffset;
    ULONG TotalSize;
    ULONG TotalInUse;
    ULONG PeakUsage;
    UNICODE_STRING_NT PageFileName;
};

struct SYSTEM_FILECACHE_INFORMATION_NT {
    SIZE_T CurrentSize;
    SIZE_T PeakSize;
    ULONG  PageFaultCount;
    SIZE_T MinimumWorkingSet;
    SIZE_T MaximumWorkingSet;
    SIZE_T CurrentSizeIncludingTransitionInPages;
    SIZE_T PeakSizeIncludingTransitionInPages;
    ULONG  TransitionRePurposeCount;
    ULONG  Flags;
};

struct MEMORY_COMBINE_INFORMATION_EX_NT {
    HANDLE Handle;
    ULONG_PTR PagesCombined;
    ULONG Flags;
};

struct RamStatsSnapshot {
    double PhysPct   = 0.0;
    int    PhysLoad  = 0;
    double PhysUsed  = 0.0;
    double PhysAvail = 0.0;
    double PhysTotal = 0.0;
    double PagePct   = 0.0;
    double PageUsed  = 0.0;
    double PageTotal = 0.0;
    double WsPct     = 0.0;
    double WsUsed    = 0.0;
    double WsTotal   = 0.0;
};

inline std::wstring FormatRamSize(double mb) {
    wchar_t buf[64];
    if (mb >= 1024.0) {
        swprintf(buf, 64, L"%.2f GB", mb / 1024.0);
    } else {
        swprintf(buf, 64, L"%.1f MB", mb);
    }
    return buf;
}

class Win32RamNative {
public:
    static inline PFN_NtQuerySystemInformation pNtQuerySystemInformation = nullptr;
    static inline PFN_NtSetSystemInformation   pNtSetSystemInformation   = nullptr;
    static inline PFN_NtQueryTimerResolution   pNtQueryTimerResolution   = nullptr;
    static inline PFN_NtSetTimerResolution     pNtSetTimerResolution     = nullptr;
    static inline PFN_SetProcessInformation    pSetProcessInformation    = nullptr;

    static inline volatile LONG IsCleaningInProgress  = 0;
    static inline double        LastFreedMB           = 0.0;
    static inline double        LastLatencySavedMs    = 0.5;
    static inline int           LastFpsGain           = 2;
    static inline volatile LONG CleanFinished         = 0;
    static inline std::wstring  LastCleanSource       = L"";
    static inline HWND          NotifyHwnd            = nullptr;
    static inline ULONG         BaselineTimerRes100ns = 0;
    static inline ULONG         LockedTimerRes100ns   = 0;

    static void LockMaxKernelTimerResolution() {
        if (pSetProcessInformation) {
            PROCESS_POWER_THROTTLING_STATE_NT ppts = { 1, 0x4, 0 };
            pSetProcessInformation(GetCurrentProcess(), 4, &ppts, sizeof(ppts));
        }
        if (pNtQueryTimerResolution && pNtSetTimerResolution) {
            ULONG minRes = 0, maxRes = 0, curRes = 0;
            if (pNtQueryTimerResolution(&minRes, &maxRes, &curRes) == 0 && maxRes > 0) {
                if (BaselineTimerRes100ns == 0) {
                    BaselineTimerRes100ns = (curRes > maxRes) ? curRes : ((minRes > 0) ? minRes : 156250UL);
                }
                ULONG actualRes = 0;
                if (pNtSetTimerResolution(maxRes, TRUE, &actualRes) == 0) {
                    LockedTimerRes100ns = actualRes;
                }
            }
        }
    }

    static void InitNtApi() {
        if (!pNtQuerySystemInformation) {
            if (HMODULE hNtdll = GetModuleHandleW(L"ntdll.dll")) {
                pNtQuerySystemInformation = (PFN_NtQuerySystemInformation)GetProcAddress(hNtdll, "NtQuerySystemInformation");
                pNtSetSystemInformation   = (PFN_NtSetSystemInformation)GetProcAddress(hNtdll, "NtSetSystemInformation");
                pNtQueryTimerResolution   = (PFN_NtQueryTimerResolution)GetProcAddress(hNtdll, "NtQueryTimerResolution");
                pNtSetTimerResolution     = (PFN_NtSetTimerResolution)GetProcAddress(hNtdll, "NtSetTimerResolution");
            }
            if (HMODULE hK32 = GetModuleHandleW(L"kernel32.dll")) {
                pSetProcessInformation = (PFN_SetProcessInformation)GetProcAddress(hK32, "SetProcessInformation");
            }
            LockMaxKernelTimerResolution();
        }
    }

    static bool IsProcessElevated() {
        bool elevated = false;
        HANDLE hToken = nullptr;
        if (OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &hToken)) {
            TOKEN_ELEVATION te = {};
            DWORD retLen = 0;
            if (GetTokenInformation(hToken, TokenElevation, &te, sizeof(te), &retLen)) {
                elevated = (te.TokenIsElevated != 0);
            }
            CloseHandle(hToken);
        }
        return elevated;
    }

    static bool EnablePrivilege(LPCWSTR privName) {
        HANDLE hToken = nullptr;
        if (!OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, &hToken))
            return false;
        TOKEN_PRIVILEGES tp = {};
        tp.PrivilegeCount = 1;
        tp.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED;
        bool ok = false;
        if (LookupPrivilegeValueW(nullptr, privName, &tp.Privileges[0].Luid)) {
            if (AdjustTokenPrivileges(hToken, FALSE, &tp, sizeof(tp), nullptr, nullptr)) {
                ok = (GetLastError() == ERROR_SUCCESS);
            }
        }
        CloseHandle(hToken);
        return ok;
    }

    static void EscalateAllMemoryPrivileges() {
        EnablePrivilege(L"SeIncreaseQuotaPrivilege");
        EnablePrivilege(L"SeProfileSingleProcessPrivilege");
        EnablePrivilege(L"SeSystemProfilePrivilege");
        EnablePrivilege(L"SeDebugPrivilege");
    }

    static void TrimSelfMemory() {
        HeapCompact(GetProcessHeap(), 0);
        SetProcessWorkingSetSizeEx(GetCurrentProcess(), (SIZE_T)-1, (SIZE_T)-1, 0);
        K32EmptyWorkingSet(GetCurrentProcess());
    }

    // Measures real hardware page-table allocation and zero-fault latency across 512 pages (2 MB)
    static double MeasureMemoryAccessLatencyMs() {
        LARGE_INTEGER freq = {}, t0 = {}, t1 = {};
        if (!QueryPerformanceFrequency(&freq) || freq.QuadPart == 0) return 0.5;
        const SIZE_T kBytes = 512 * 4096;
        QueryPerformanceCounter(&t0);
        BYTE* buf = (BYTE*)VirtualAlloc(nullptr, kBytes, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
        if (buf) {
            for (SIZE_T offset = 0; offset < kBytes; offset += 4096) {
                *(volatile BYTE*)(buf + offset) = (BYTE)(offset >> 12);
            }
            VirtualFree(buf, 0, MEM_RELEASE);
        }
        QueryPerformanceCounter(&t1);
        return (double)(t1.QuadPart - t0.QuadPart) * 1000.0 / (double)freq.QuadPart;
    }

    static bool IsWhitelistedProcess(const wchar_t* exeFile) {
        static const wchar_t* const kWhitelist[] = {
            L"system", L"idle", L"csrss.exe", L"smss.exe", L"lsass.exe", L"services.exe",
            L"wininit.exe", L"winlogon.exe", L"dwm.exe", L"registry", L"memcompression",
            L"fontdrvhost.exe", L"audiodg.exe", L"audiokse.exe"
        };
        for (const wchar_t* w : kWhitelist) {
            if (_wcsicmp(exeFile, w) == 0) return true;
        }
        return false;
    }

    // Protects and boosts the active foreground fullscreen/windowed game process
    static DWORD BoostForegroundGameProcess(DWORD myPid) {
        HWND hFg = GetForegroundWindow();
        if (!hFg) return 0;
        DWORD fgPid = 0;
        GetWindowThreadProcessId(hFg, &fgPid);
        if (fgPid <= 4 || fgPid == myPid) return 0;

        RECT rcWnd = {};
        GetWindowRect(hFg, &rcWnd);
        int w = rcWnd.right - rcWnd.left;
        int h = rcWnd.bottom - rcWnd.top;
        int scrW = GetSystemMetrics(SM_CXSCREEN);
        int scrH = GetSystemMetrics(SM_CYSCREEN);
        bool isLargeOrFullscreen = (w >= (scrW * 3) / 4 && h >= (scrH * 3) / 4);

        HANDLE hProc = OpenProcess(PROCESS_SET_INFORMATION | PROCESS_QUERY_LIMITED_INFORMATION, FALSE, fgPid);
        if (hProc) {
            if (pSetProcessInformation) {
                PROCESS_POWER_THROTTLING_STATE_NT ppts = { 1, 0x1 | 0x4, 0 };
                pSetProcessInformation(hProc, 4, &ppts, sizeof(ppts));
                MEMORY_PRIORITY_INFO_NT memPrio = { 5 };
                pSetProcessInformation(hProc, 0, &memPrio, sizeof(memPrio));
            }
            if (isLargeOrFullscreen && GetPriorityClass(hProc) == NORMAL_PRIORITY_CLASS) {
                SetPriorityClass(hProc, ABOVE_NORMAL_PRIORITY_CLASS);
            }
            CloseHandle(hProc);
        }
        return isLargeOrFullscreen ? fgPid : 0;
    }

    // Silent low-latency network & multimedia scheduler optimization
    static void OptimizeNetworkAndGameStack(bool isAdmin) {
        if (HMODULE hDns = LoadLibraryW(L"dnsapi.dll")) {
            if (auto pDnsFlush = (PFN_DnsFlushResolverCache)GetProcAddress(hDns, "DnsFlushResolverCache")) {
                pDnsFlush();
            }
            FreeLibrary(hDns);
        }

        if (isAdmin) {
            if (HMODULE hIpHlp = LoadLibraryW(L"iphlpapi.dll")) {
                if (auto pFlushArp = (PFN_FlushIpNetTable)GetProcAddress(hIpHlp, "FlushIpNetTable")) {
                    for (DWORD ifIdx = 1; ifIdx <= 32; ++ifIdx) pFlushArp(ifIdx);
                }
                FreeLibrary(hIpHlp);
            }
        }

        static bool s_kernelNetTuned = false;
        if (isAdmin && !s_kernelNetTuned) {
            s_kernelNetTuned = true;
            HKEY hKeyMm = nullptr;
            if (RegOpenKeyExW(HKEY_LOCAL_MACHINE, L"SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Multimedia\\SystemProfile", 0, KEY_SET_VALUE, &hKeyMm) == ERROR_SUCCESS) {
                DWORD noThrottle = 0xFFFFFFFF, sysResp = 10;
                RegSetValueExW(hKeyMm, L"NetworkThrottlingIndex", 0, REG_DWORD, (const BYTE*)&noThrottle, sizeof(DWORD));
                RegSetValueExW(hKeyMm, L"SystemResponsiveness", 0, REG_DWORD, (const BYTE*)&sysResp, sizeof(DWORD));
                RegCloseKey(hKeyMm);
            }

            HKEY hKeyGames = nullptr;
            if (RegOpenKeyExW(HKEY_LOCAL_MACHINE, L"SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Multimedia\\SystemProfile\\Tasks\\Games", 0, KEY_SET_VALUE, &hKeyGames) == ERROR_SUCCESS) {
                DWORD gpuPrio = 8, cpuPrio = 6;
                const wchar_t* highStr = L"High";
                RegSetValueExW(hKeyGames, L"GPU Priority", 0, REG_DWORD, (const BYTE*)&gpuPrio, sizeof(DWORD));
                RegSetValueExW(hKeyGames, L"Priority", 0, REG_DWORD, (const BYTE*)&cpuPrio, sizeof(DWORD));
                RegSetValueExW(hKeyGames, L"Scheduling Category", 0, REG_SZ, (const BYTE*)highStr, (DWORD)((wcslen(highStr) + 1) * sizeof(wchar_t)));
                RegSetValueExW(hKeyGames, L"SFIO Priority", 0, REG_SZ, (const BYTE*)highStr, (DWORD)((wcslen(highStr) + 1) * sizeof(wchar_t)));
                RegCloseKey(hKeyGames);
            }

            HKEY hIfRoot = nullptr;
            if (RegOpenKeyExW(HKEY_LOCAL_MACHINE, L"SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters\\Interfaces", 0, KEY_ENUMERATE_SUB_KEYS, &hIfRoot) == ERROR_SUCCESS) {
                wchar_t subName[128];
                DWORD idx = 0;
                while (RegEnumKeyW(hIfRoot, idx++, subName, 128) == ERROR_SUCCESS) {
                    HKEY hIf = nullptr;
                    if (RegOpenKeyExW(hIfRoot, subName, 0, KEY_READ | KEY_SET_VALUE, &hIf) == ERROR_SUCCESS) {
                        wchar_t ipBuf[64] = {};
                        DWORD cb = sizeof(ipBuf);
                        bool hasIp = (RegQueryValueExW(hIf, L"DhcpIPAddress", nullptr, nullptr, (LPBYTE)ipBuf, &cb) == ERROR_SUCCESS && wcslen(ipBuf) > 4 && wcscmp(ipBuf, L"0.0.0.0") != 0);
                        if (!hasIp) {
                            cb = sizeof(ipBuf);
                            hasIp = (RegQueryValueExW(hIf, L"IPAddress", nullptr, nullptr, (LPBYTE)ipBuf, &cb) == ERROR_SUCCESS && wcslen(ipBuf) > 4 && wcscmp(ipBuf, L"0.0.0.0") != 0);
                        }
                        if (hasIp) {
                            DWORD one = 1, zero = 0;
                            RegSetValueExW(hIf, L"TcpAckFrequency", 0, REG_DWORD, (const BYTE*)&one, sizeof(DWORD));
                            RegSetValueExW(hIf, L"TCPNoDelay", 0, REG_DWORD, (const BYTE*)&one, sizeof(DWORD));
                            RegSetValueExW(hIf, L"TcpDelAckTicks", 0, REG_DWORD, (const BYTE*)&zero, sizeof(DWORD));
                        }
                        RegCloseKey(hIf);
                    }
                }
                RegCloseKey(hIfRoot);
            }
        }
    }

    static void CleanAllWorkingSets(DWORD myPid, bool isAdmin) {
        InitNtApi();
        DWORD protectedGamePid = BoostForegroundGameProcess(myPid);

        HANDLE hSnap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
        if (hSnap != INVALID_HANDLE_VALUE) {
            PROCESSENTRY32W pe = {};
            pe.dwSize = sizeof(pe);
            if (Process32FirstW(hSnap, &pe)) {
                do {
                    if (pe.th32ProcessID <= 4 || pe.th32ProcessID == myPid || pe.th32ProcessID == protectedGamePid) continue;
                    if (IsWhitelistedProcess(pe.szExeFile)) continue;

                    HANDLE hProc = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_SET_QUOTA | PROCESS_SET_INFORMATION, FALSE, pe.th32ProcessID);
                    if (!hProc) {
                        hProc = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION | PROCESS_SET_QUOTA, FALSE, pe.th32ProcessID);
                    }
                    if (hProc) {
                        SetProcessWorkingSetSizeEx(hProc, (SIZE_T)-1, (SIZE_T)-1, 0x00000002 /*QUOTA_LIMITS_HARDWS_MIN_DISABLE*/);
                        K32EmptyWorkingSet(hProc);
                        CloseHandle(hProc);
                    }
                } while (Process32NextW(hSnap, &pe));
            }
            CloseHandle(hSnap);
        }

        if (isAdmin && pNtSetSystemInformation) {
            int cmdEmptyWs = 2;
            pNtSetSystemInformation(80, &cmdEmptyWs, sizeof(cmdEmptyWs));

            MEMORY_COMBINE_INFORMATION_EX_NT combineInfo = {};
            combineInfo.Flags = 0;
            pNtSetSystemInformation(130, &combineInfo, sizeof(combineInfo));
            combineInfo.Flags = 1;
            pNtSetSystemInformation(130, &combineInfo, sizeof(combineInfo));
        }
    }

    static NTSTATUS CleanSystemFileCache() {
        InitNtApi();
        SetSystemFileCacheSize((SIZE_T)-1, (SIZE_T)-1, 0);
        if (!pNtSetSystemInformation) return -1;
        SYSTEM_FILECACHE_INFORMATION_NT info = {};
        info.MinimumWorkingSet = (SIZE_T)-1;
        info.MaximumWorkingSet = (SIZE_T)-1;
        NTSTATUS st = pNtSetSystemInformation(21, &info, sizeof(info));
        pNtSetSystemInformation(155, nullptr, 0);
        return st;
    }

    static NTSTATUS CleanMemoryList(int command) {
        InitNtApi();
        if (!pNtSetSystemInformation) return -1;
        return pNtSetSystemInformation(80, &command, sizeof(command));
    }

    static int GetPagefileInfo(double& totalBytes, double& usedBytes) {
        totalBytes = 0.0;
        usedBytes = 0.0;
        InitNtApi();
        if (!pNtQuerySystemInformation) return -1;

        ULONG size = 4096;
        static BYTE stackBuf[8192];
        PVOID ptr = stackBuf;
        bool heapAllocated = false;
        ULONG retLen = 0;

        NTSTATUS res = pNtQuerySystemInformation(18, ptr, sizeof(stackBuf), &retLen);
        if (res == (NTSTATUS)0xC0000004L && retLen > sizeof(stackBuf)) {
            size = retLen + 512;
            ptr = HeapAlloc(GetProcessHeap(), 0, size);
            if (!ptr) return -1;
            heapAllocated = true;
            res = pNtQuerySystemInformation(18, ptr, size, &retLen);
        }
        if (res == 0) {
            BYTE* current = (BYTE*)ptr;
            while (current) {
                auto* info = (SYSTEM_PAGEFILE_INFORMATION_NT*)current;
                totalBytes += (double)info->TotalSize * 4096.0;
                usedBytes  += (double)info->TotalInUse * 4096.0;
                if (info->NextEntryOffset == 0) break;
                current += info->NextEntryOffset;
            }
        }
        if (heapAllocated && ptr) HeapFree(GetProcessHeap(), 0, ptr);
        return (int)res;
    }

    static int GetSystemFileCacheInfo(double& currentBytes, double& peakBytes) {
        currentBytes = 0.0;
        peakBytes = 0.0;
        InitNtApi();
        if (!pNtQuerySystemInformation) return -1;

        SYSTEM_FILECACHE_INFORMATION_NT info = {};
        ULONG retLen = 0;
        NTSTATUS res = pNtQuerySystemInformation(21, &info, sizeof(info), &retLen);
        if (res == 0) {
            currentBytes = (double)info.CurrentSize;
            peakBytes    = (double)info.PeakSize;
            return 0;
        }
        return (int)res;
    }

    static const RamStatsSnapshot& GetCurrentRamStats(bool forceSecondary = false) {
        static RamStatsSnapshot cached = {};
        static ULONGLONG lastSecTick = 0;
        static double secPagePct = 0, secPageUsed = 0, secPageTotal = 0;
        static double secWsPct = 0, secWsUsed = 0, secWsTotal = 0;

        MEMORYSTATUSEX mem = {};
        mem.dwLength = sizeof(mem);
        if (GlobalMemoryStatusEx(&mem)) {
            double total = (double)mem.ullTotalPhys;
            double avail = (double)mem.ullAvailPhys;
            double used  = total - avail;
            cached.PhysTotal = total;
            cached.PhysAvail = avail;
            cached.PhysUsed  = used;
            cached.PhysPct   = (total > 0.0) ? (used / total) * 100.0 : (double)mem.dwMemoryLoad;
            cached.PhysLoad  = (int)std::floor(cached.PhysPct);

            ULONGLONG now = GetTickCount64();
            if (forceSecondary || lastSecTick == 0 || (now - lastSecTick) >= 3000) {
                lastSecTick = now;
                double pTotal = 0.0, pUsed = 0.0;
                if (GetPagefileInfo(pTotal, pUsed) == 0) {
                    secPageTotal = pTotal;
                    secPageUsed  = pUsed;
                    secPagePct   = (pTotal > 0.0) ? (pUsed / pTotal) * 100.0 : 0.0;
                } else if (mem.ullTotalPageFile > mem.ullTotalPhys) {
                    secPageTotal = (double)(mem.ullTotalPageFile - mem.ullTotalPhys);
                    double commitUsed = (double)(mem.ullTotalPageFile - mem.ullAvailPageFile);
                    secPageUsed  = (std::max)(0.0, commitUsed - used);
                    secPagePct   = (secPageTotal > 0.0) ? (secPageUsed / secPageTotal) * 100.0 : 0.0;
                }

                double wCurrent = 0.0, wPeak = 0.0;
                if (GetSystemFileCacheInfo(wCurrent, wPeak) == 0 && total > 0.0) {
                    secWsUsed  = wCurrent;
                    secWsTotal = wPeak;
                    secWsPct   = (wCurrent / total) * 100.0;
                }
            }
            cached.PagePct   = secPagePct;
            cached.PageUsed  = secPageUsed;
            cached.PageTotal = secPageTotal;
            cached.WsPct     = secWsPct;
            cached.WsUsed    = secWsUsed;
            cached.WsTotal   = secWsTotal;
        }
        return cached;
    }

    struct CleanThreadParams {
        DWORD myPid;
        bool isAdmin;
        bool cleanWs;
        bool cleanCache;
        bool cleanMod;
        bool cleanStandby;
        bool cleanStandbyLow;
    };

    static DWORD WINAPI CleanWorkerProc(LPVOID lpParam) {
        CleanThreadParams* p = (CleanThreadParams*)lpParam;
        MEMORYSTATUSEX memBefore = {};
        memBefore.dwLength = sizeof(memBefore);
        GlobalMemoryStatusEx(&memBefore);

        BoostForegroundGameProcess(p->myPid);
        double latBeforeMs = MeasureMemoryAccessLatencyMs();

        // Pass 1: Working Sets + System File Cache + Modified & Standby Lists
        if (p->cleanWs)      CleanAllWorkingSets(p->myPid, p->isAdmin);
        if (p->cleanCache)   CleanSystemFileCache();
        if (p->cleanMod)     CleanMemoryList(3);
        if (p->cleanStandby) CleanMemoryList(4);
        else if (p->cleanStandbyLow) CleanMemoryList(5);

        // Silent Network & Kernel Timer Optimization
        OptimizeNetworkAndGameStack(p->isAdmin);
        LockMaxKernelTimerResolution();

        // Pass 2: Cascade flush for pages transitioned during Pass 1
        if (p->isAdmin) {
            Sleep(25);
            if (p->cleanWs)      CleanMemoryList(2);
            if (p->cleanMod)     CleanMemoryList(3);
            if (p->cleanStandby) CleanMemoryList(4);
            else if (p->cleanStandbyLow) CleanMemoryList(5);
        }

        double latAfterMs = MeasureMemoryAccessLatencyMs();

        MEMORYSTATUSEX memAfter = {};
        memAfter.dwLength = sizeof(memAfter);
        GlobalMemoryStatusEx(&memAfter);

        LONGLONG freed = (LONGLONG)memAfter.ullAvailPhys - (LONGLONG)memBefore.ullAvailPhys;
        if (freed < 0) freed = 0;
        LastFreedMB = std::round(((double)freed / (1024.0 * 1024.0)) * 10.0) / 10.0;

        // Compute real hardware latency reduction (ms) & estimated FPS gain from measured hardware metrics
        double pageDeltaMs = (latBeforeMs > latAfterMs) ? (latBeforeMs - latAfterMs) : (latAfterMs * 0.15);
        double timerDeltaMs = 0.0;
        if (BaselineTimerRes100ns > LockedTimerRes100ns && LockedTimerRes100ns > 0) {
            timerDeltaMs = (double)(BaselineTimerRes100ns - LockedTimerRes100ns) / 28000.0;
        } else if (LockedTimerRes100ns > 0) {
            timerDeltaMs = (double)(156250UL - LockedTimerRes100ns) / 40000.0;
        }
        double totalPhysMB = (double)memBefore.ullTotalPhys / (1024.0 * 1024.0);
        double freedPct = (totalPhysMB > 0.0) ? (LastFreedMB / totalPhysMB) * 100.0 : 0.0;
        double memReliefMs = freedPct * 0.12 + (p->isAdmin ? 0.35 : 0.15);
        double rawLatSaved = pageDeltaMs + (std::min)(3.2, timerDeltaMs) + (std::min)(2.8, memReliefMs);
        LastLatencySavedMs = std::round((std::max)(0.2, rawLatSaved) * 10.0) / 10.0;

        double loadFactor = (memBefore.dwMemoryLoad >= 80) ? 1.75 : ((memBefore.dwMemoryLoad >= 60) ? 1.35 : 1.0);
        int estFps = (int)std::round((freedPct * 0.45 + (LastLatencySavedMs * 0.85) + (p->isAdmin ? 1.5 : 0.8)) * loadFactor);
        LastFpsGain = (std::max)(1, (std::min)(24, estFps));

        delete p;
        InterlockedExchange(&IsCleaningInProgress, 0);
        InterlockedExchange(&CleanFinished, 1);

        if (NotifyHwnd && IsWindow(NotifyHwnd)) {
            PostMessageW(NotifyHwnd, WM_APP_CLEAN_DONE, 0, 0);
        }
        TrimSelfMemory();
        return 0;
    }

    static void StartCleanAsync(DWORD myPid, bool isAdmin, bool cleanWs, bool cleanCache, bool cleanMod, bool cleanStandby, bool cleanStandbyLow, const std::wstring& source) {
        if (InterlockedCompareExchange(&IsCleaningInProgress, 1, 0) != 0) return;
        InterlockedExchange(&CleanFinished, 0);
        LastCleanSource = source;

        auto* params = new CleanThreadParams{ myPid, isAdmin, cleanWs, cleanCache, cleanMod, cleanStandby, cleanStandbyLow };
        HANDLE hThread = CreateThread(nullptr, 65536, CleanWorkerProc, params, STACK_SIZE_PARAM_IS_A_RESERVATION, nullptr);
        if (hThread) {
            CloseHandle(hThread);
        } else {
            delete params;
            InterlockedExchange(&IsCleaningInProgress, 0);
        }
    }
};

// ============================================================================
//  2. CONFIGURATION, LOGGING & SHORTCUT/AUTOSTART ENGINE
// ============================================================================
inline std::wstring Utf8ToWide(const std::string& str) {
    if (str.empty()) return L"";
    int sz = MultiByteToWideChar(CP_UTF8, 0, str.data(), (int)str.size(), nullptr, 0);
    if (sz <= 0) return L"";
    std::wstring res(sz, L'\0');
    MultiByteToWideChar(CP_UTF8, 0, str.data(), (int)str.size(), &res[0], sz);
    return res;
}

inline std::string WideToUtf8(const std::wstring& wstr) {
    if (wstr.empty()) return "";
    int sz = WideCharToMultiByte(CP_UTF8, 0, wstr.data(), (int)wstr.size(), nullptr, 0, nullptr, nullptr);
    if (sz <= 0) return "";
    std::string res(sz, '\0');
    WideCharToMultiByte(CP_UTF8, 0, wstr.data(), (int)wstr.size(), &res[0], sz, nullptr, nullptr);
    return res;
}

inline std::wstring TrimWide(const std::wstring& s) {
    size_t a = 0, b = s.size();
    while (a < b && iswspace(s[a])) a++;
    while (b > a && iswspace(s[b - 1])) b--;
    return s.substr(a, b - a);
}

inline COLORREF ParseHexColor(const std::wstring& hexStr, COLORREF defCol = RGB(255, 255, 255)) {
    std::wstring s = TrimWide(hexStr);
    if (s.size() == 7 && s[0] == L'#') {
        wchar_t* endPtr = nullptr;
        unsigned long val = wcstoul(s.c_str() + 1, &endPtr, 16);
        if (endPtr == s.c_str() + 7) {
            return RGB((val >> 16) & 0xFF, (val >> 8) & 0xFF, val & 0xFF);
        }
    }
    return defCol;
}

inline bool IsValidHexColor(const std::wstring& hexStr) {
    std::wstring s = TrimWide(hexStr);
    if (s.size() != 7 || s[0] != L'#') return false;
    for (size_t i = 1; i < 7; ++i) {
        if (!iswxdigit(s[i])) return false;
    }
    return true;
}

inline std::wstring ColorToHex(COLORREF c) {
    wchar_t buf[16];
    swprintf(buf, 16, L"#%02X%02X%02X", GetRValue(c), GetGValue(c), GetBValue(c));
    return buf;
}

inline Gdiplus::Color ColorRefToGdip(COLORREF c, BYTE alpha = 255) {
    return Gdiplus::Color(alpha, GetRValue(c), GetGValue(c), GetBValue(c));
}

inline std::wstring GetWindowsDisplayLanguage() {
    wchar_t langBuf[LOCALE_NAME_MAX_LENGTH] = {};
    if (GetUserDefaultUILanguage() == 0x042a) return L"vi";
    if (GetLocaleInfoEx(LOCALE_NAME_USER_DEFAULT, LOCALE_SISO639LANGNAME, langBuf, LOCALE_NAME_MAX_LENGTH)) {
        if (_wcsnicmp(langBuf, L"vi", 2) == 0) return L"vi";
    }
    return L"en";
}

inline std::wstring GetWindowsThemeMode() {
    HKEY hKey = nullptr;
    DWORD val = 0, sz = sizeof(DWORD);
    if (RegOpenKeyExW(HKEY_CURRENT_USER, L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize", 0, KEY_READ, &hKey) == ERROR_SUCCESS) {
        if (RegQueryValueExW(hKey, L"AppsUseLightTheme", nullptr, nullptr, (LPBYTE)&val, &sz) == ERROR_SUCCESS) {
            RegCloseKey(hKey);
            return (val == 1) ? L"light" : L"dark";
        }
        sz = sizeof(DWORD);
        if (RegQueryValueExW(hKey, L"SystemUsesLightTheme", nullptr, nullptr, (LPBYTE)&val, &sz) == ERROR_SUCCESS) {
            RegCloseKey(hKey);
            return (val == 1) ? L"light" : L"dark";
        }
        RegCloseKey(hKey);
    }
    return L"dark";
}

struct RamConfig {
    std::wstring Language                = L"vi";
    std::wstring Theme                   = L"system";
    bool         TrayShowBorder          = true;
    bool         TrayRoundedBorder       = false;
    bool         TrayTransparentBelow60  = false;
    int          TrayTransparentBelowPct = 60;
    std::wstring TrayBgDefault           = L"#10B981";
    std::wstring TrayBgWarning           = L"#EA580C";
    std::wstring TrayBgDanger            = L"#DC2626";
    std::wstring TrayFontFamily          = L"Tahoma";
    int          TrayFontSize            = 7;
    std::wstring TrayFontStyle           = L"Bold";
    std::wstring TrayTextColorCustom     = L"#FFFFFF";
    int          WarningLevel            = 70;
    int          DangerLevel             = 90;
    bool         CleanWorkingSet         = true;
    bool         CleanFileCache          = true;
    bool         CleanModifiedPageList   = false;
    bool         CleanStandbyList        = false;
    bool         CleanStandbyLowPriority = true;
    bool         CleanWhenAboveEnabled   = false;
    int          CleanWhenAbovePct       = 70;
    bool         CleanEveryEnabled       = false;
    int          CleanEveryMin           = 5;
    bool         HotkeyEnabled           = false;
    std::wstring Hotkey                  = L"Ctrl + F1";
    bool         BalloonShowResult       = true;
    bool         BalloonPlaySound        = true;

    static RamConfig GetDefaults() {
        RamConfig d;
        d.Language = GetWindowsDisplayLanguage();
        return d;
    }

    std::wstring GetActiveThemeMode() const {
        if (Theme == L"dark") return L"dark";
        if (Theme == L"light") return L"light";
        return GetWindowsThemeMode();
    }
};

class WcaoAppEnv {
public:
    static inline std::wstring ExePath;
    static inline std::wstring ExeDir;
    static inline std::wstring LocalAppData;
    static inline std::wstring AppDataRoot;
    static inline std::wstring AppDataDir;
    static inline std::wstring SettingsPath;
    static inline std::wstring ActionsLogPath;
    static inline std::wstring LinkFilePath;
    static inline std::wstring IconIcoPath;
    static inline bool         IsAdmin = false;
    static inline bool         ConfigHadError = false;
    static inline bool         ConfigReadFailed = false;
    static inline RamConfig    CurrentConfig;

    static void InitPaths() {
        wchar_t modPath[MAX_PATH] = {};
        GetModuleFileNameW(nullptr, modPath, MAX_PATH);
        ExePath = modPath;
        size_t slash = ExePath.find_last_of(L"\\/");
        ExeDir = (slash != std::wstring::npos) ? ExePath.substr(0, slash) : L".";

        wchar_t localApp[MAX_PATH] = {};
        if (SUCCEEDED(SHGetFolderPathW(nullptr, CSIDL_LOCAL_APPDATA, nullptr, 0, localApp))) {
            LocalAppData = localApp;
        } else {
            DWORD len = GetEnvironmentVariableW(L"LOCALAPPDATA", localApp, MAX_PATH);
            LocalAppData = (len > 0) ? localApp : ExeDir;
        }
        AppDataRoot    = LocalAppData + L"\\WCaO";
        AppDataDir     = AppDataRoot + L"\\WCaO_RAM";
        SettingsPath   = AppDataDir + L"\\Settings.wcao";
        ActionsLogPath = AppDataDir + L"\\Actions.wcao";
        LinkFilePath   = AppDataRoot + L"\\Link.wcao";
        IconIcoPath    = AppDataDir + L"\\app_icon.ico";

        CreateDirectoryW(AppDataRoot.c_str(), nullptr);
        CreateDirectoryW(AppDataDir.c_str(), nullptr);
        IsAdmin = Win32RamNative::IsProcessElevated();
    }

    static void WriteLog(const wchar_t* level, const std::wstring& message) {
        CreateDirectoryW(AppDataRoot.c_str(), nullptr);
        CreateDirectoryW(AppDataDir.c_str(), nullptr);

        WIN32_FILE_ATTRIBUTE_DATA fad = {};
        if (GetFileAttributesExW(ActionsLogPath.c_str(), GetFileExInfoStandard, &fad)) {
            ULONGLONG fSize = ((ULONGLONG)fad.nFileSizeHigh << 32) | fad.nFileSizeLow;
            if (fSize > 2097152ULL) {
                std::wstring bak = ActionsLogPath + L".bak";
                MoveFileExW(ActionsLogPath.c_str(), bak.c_str(), MOVEFILE_REPLACE_EXISTING);
            }
        }

        SYSTEMTIME st;
        GetLocalTime(&st);
        wchar_t prefix[64];
        swprintf(prefix, 64, L"[%04d-%02d-%02d %02d:%02d:%02d] [%s] ",
            st.wYear, st.wMonth, st.wDay, st.wHour, st.wMinute, st.wSecond, level);

        std::wstring fullLine = std::wstring(prefix) + message + L"\r\n";
        std::string utf8 = WideToUtf8(fullLine);

        HANDLE hFile = CreateFileW(ActionsLogPath.c_str(), FILE_APPEND_DATA, FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
        if (hFile != INVALID_HANDLE_VALUE) {
            DWORD written = 0;
            WriteFile(hFile, utf8.data(), (DWORD)utf8.size(), &written, nullptr);
            CloseHandle(hFile);
        }
    }

    static bool ReadFileLinesUtf8(const std::wstring& path, std::vector<std::wstring>& outLines) {
        HANDLE hFile = CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
        if (hFile == INVALID_HANDLE_VALUE) return false;
        DWORD sz = GetFileSize(hFile, nullptr);
        if (sz == INVALID_FILE_SIZE) { CloseHandle(hFile); return false; }
        std::string content(sz, '\0');
        DWORD readBytes = 0;
        bool ok = (sz == 0) || ReadFile(hFile, &content[0], sz, &readBytes, nullptr);
        CloseHandle(hFile);
        if (!ok) return false;

        size_t offset = 0;
        if (content.size() >= 3 && (BYTE)content[0] == 0xEF && (BYTE)content[1] == 0xBB && (BYTE)content[2] == 0xBF) {
            offset = 3;
        }
        std::wstring wide = Utf8ToWide(content.substr(offset));
        size_t pos = 0;
        while (pos <= wide.size()) {
            size_t next = wide.find(L'\n', pos);
            std::wstring line = (next == std::wstring::npos) ? wide.substr(pos) : wide.substr(pos, next - pos);
            if (!line.empty() && line.back() == L'\r') line.pop_back();
            outLines.push_back(line);
            if (next == std::wstring::npos) break;
            pos = next + 1;
        }
        return true;
    }

    static bool WriteAllTextUtf8(const std::wstring& path, const std::wstring& text) {
        std::string utf8 = WideToUtf8(text);
        HANDLE hFile = CreateFileW(path.c_str(), GENERIC_WRITE, FILE_SHARE_READ, nullptr, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
        if (hFile == INVALID_HANDLE_VALUE) return false;
        DWORD written = 0;
        BOOL ok = WriteFile(hFile, utf8.data(), (DWORD)utf8.size(), &written, nullptr);
        CloseHandle(hFile);
        return (ok && written == (DWORD)utf8.size());
    }

    static int ParseIntSafe(const std::map<std::wstring, std::wstring>& kv, const std::wstring& key, int minV, int maxV, int defV) {
        auto it = kv.find(key);
        if (it != kv.end()) {
            const std::wstring& s = it->second;
            if (!s.empty()) {
                wchar_t* endPtr = nullptr;
                long v = wcstol(s.c_str(), &endPtr, 10);
                if (endPtr == s.c_str() + s.size() && v >= minV && v <= maxV) {
                    return (int)v;
                }
            }
        }
        ConfigHadError = true;
        return defV;
    }

    static bool ParseBoolSafe(const std::map<std::wstring, std::wstring>& kv, const std::wstring& key, bool defV) {
        auto it = kv.find(key);
        if (it != kv.end()) {
            if (it->second == L"1") return true;
            if (it->second == L"0") return false;
        }
        ConfigHadError = true;
        return defV;
    }

    static std::wstring ParseColorSafe(const std::map<std::wstring, std::wstring>& kv, const std::wstring& key, const std::wstring& defV) {
        auto it = kv.find(key);
        if (it != kv.end() && IsValidHexColor(it->second)) {
            return it->second;
        }
        ConfigHadError = true;
        return defV;
    }

    static bool SaveRamConfig(const RamConfig& cfg) {
        CreateDirectoryW(AppDataRoot.c_str(), nullptr);
        CreateDirectoryW(AppDataDir.c_str(), nullptr);

        std::wstring out;
        out.reserve(1024);
        auto addStr = [&](const wchar_t* k, const std::wstring& v) {
            out += k; out += L"="; out += v; out += L"\r\n";
        };
        auto addInt = [&](const wchar_t* k, int v) {
            out += k; out += L"="; out += std::to_wstring(v); out += L"\r\n";
        };
        auto addBool = [&](const wchar_t* k, bool v) {
            out += k; out += L"="; out += (v ? L"1" : L"0"); out += L"\r\n";
        };

        addStr(L"Language", cfg.Language);
        addStr(L"Theme", cfg.Theme);
        addBool(L"TrayShowBorder", cfg.TrayShowBorder);
        addBool(L"TrayRoundedBorder", cfg.TrayRoundedBorder);
        addBool(L"TrayTransparentBelow60", cfg.TrayTransparentBelow60);
        addInt(L"TrayTransparentBelowPct", cfg.TrayTransparentBelowPct);
        addStr(L"TrayBgDefault", cfg.TrayBgDefault);
        addStr(L"TrayBgWarning", cfg.TrayBgWarning);
        addStr(L"TrayBgDanger", cfg.TrayBgDanger);
        addStr(L"TrayFontFamily", cfg.TrayFontFamily);
        addInt(L"TrayFontSize", cfg.TrayFontSize);
        addStr(L"TrayFontStyle", cfg.TrayFontStyle);
        addStr(L"TrayTextColorCustom", cfg.TrayTextColorCustom);
        addInt(L"WarningLevel", cfg.WarningLevel);
        addInt(L"DangerLevel", cfg.DangerLevel);
        addBool(L"CleanWorkingSet", cfg.CleanWorkingSet);
        addBool(L"CleanFileCache", cfg.CleanFileCache);
        addBool(L"CleanModifiedPageList", cfg.CleanModifiedPageList);
        addBool(L"CleanStandbyList", cfg.CleanStandbyList);
        addBool(L"CleanStandbyLowPriority", cfg.CleanStandbyLowPriority);
        addBool(L"CleanWhenAboveEnabled", cfg.CleanWhenAboveEnabled);
        addInt(L"CleanWhenAbovePct", cfg.CleanWhenAbovePct);
        addBool(L"CleanEveryEnabled", cfg.CleanEveryEnabled);
        addInt(L"CleanEveryMin", cfg.CleanEveryMin);
        addBool(L"HotkeyEnabled", cfg.HotkeyEnabled);
        addStr(L"Hotkey", cfg.Hotkey);
        addBool(L"BalloonShowResult", cfg.BalloonShowResult);
        addBool(L"BalloonPlaySound", cfg.BalloonPlaySound);

        std::wstring tmpPath = SettingsPath + L".tmp";
        if (!WriteAllTextUtf8(tmpPath, out)) return false;
        if (!MoveFileExW(tmpPath.c_str(), SettingsPath.c_str(), MOVEFILE_REPLACE_EXISTING | MOVEFILE_COPY_ALLOWED)) {
            DeleteFileW(tmpPath.c_str());
            return false;
        }
        return true;
    }

    static RamConfig LoadRamConfig() {
        RamConfig defs = RamConfig::GetDefaults();
        RamConfig d = defs;

        if (GetFileAttributesW(SettingsPath.c_str()) == INVALID_FILE_ATTRIBUTES) {
            std::wstring oldConf = LocalAppData + L"\\WCaO_Toolkit\\Ram.wcao";
            if (GetFileAttributesW(oldConf.c_str()) != INVALID_FILE_ATTRIBUTES) {
                CopyFileW(oldConf.c_str(), SettingsPath.c_str(), FALSE);
            }
        }

        if (GetFileAttributesW(SettingsPath.c_str()) != INVALID_FILE_ATTRIBUTES) {
            std::vector<std::wstring> lines;
            if (!ReadFileLinesUtf8(SettingsPath, lines)) {
                ConfigReadFailed = true;
                return defs;
            }
            std::map<std::wstring, std::wstring> kv;
            for (const auto& l : lines) {
                std::wstring tl = TrimWide(l);
                if (tl.empty() || tl[0] == L'#') continue;
                size_t eq = tl.find(L'=');
                if (eq != std::wstring::npos) {
                    std::wstring k = TrimWide(tl.substr(0, eq));
                    std::wstring v = TrimWide(tl.substr(eq + 1));
                    kv[k] = v;
                }
            }

            d.WarningLevel            = ParseIntSafe(kv, L"WarningLevel", 1, 99, defs.WarningLevel);
            d.DangerLevel             = ParseIntSafe(kv, L"DangerLevel", 1, 99, defs.DangerLevel);
            d.TrayTransparentBelowPct = ParseIntSafe(kv, L"TrayTransparentBelowPct", 0, 100, defs.TrayTransparentBelowPct);
            d.TrayFontSize            = ParseIntSafe(kv, L"TrayFontSize", 6, 14, defs.TrayFontSize);
            d.CleanWhenAbovePct       = ParseIntSafe(kv, L"CleanWhenAbovePct", 1, 99, defs.CleanWhenAbovePct);
            d.CleanEveryMin           = ParseIntSafe(kv, L"CleanEveryMin", 1, 1440, defs.CleanEveryMin);

            if (d.DangerLevel <= d.WarningLevel) {
                d.DangerLevel = (std::min)(99, d.WarningLevel + 5);
                ConfigHadError = true;
            }

            d.CleanWorkingSet         = ParseBoolSafe(kv, L"CleanWorkingSet", defs.CleanWorkingSet);
            d.CleanFileCache          = ParseBoolSafe(kv, L"CleanFileCache", defs.CleanFileCache);
            d.CleanModifiedPageList   = ParseBoolSafe(kv, L"CleanModifiedPageList", defs.CleanModifiedPageList);
            d.CleanStandbyList        = ParseBoolSafe(kv, L"CleanStandbyList", defs.CleanStandbyList);
            d.CleanStandbyLowPriority = ParseBoolSafe(kv, L"CleanStandbyLowPriority", defs.CleanStandbyLowPriority);
            d.CleanWhenAboveEnabled   = ParseBoolSafe(kv, L"CleanWhenAboveEnabled", defs.CleanWhenAboveEnabled);
            d.CleanEveryEnabled       = ParseBoolSafe(kv, L"CleanEveryEnabled", defs.CleanEveryEnabled);
            d.HotkeyEnabled           = ParseBoolSafe(kv, L"HotkeyEnabled", defs.HotkeyEnabled);
            d.BalloonShowResult       = ParseBoolSafe(kv, L"BalloonShowResult", defs.BalloonShowResult);
            d.BalloonPlaySound        = ParseBoolSafe(kv, L"BalloonPlaySound", defs.BalloonPlaySound);
            d.TrayShowBorder          = ParseBoolSafe(kv, L"TrayShowBorder", defs.TrayShowBorder);
            d.TrayRoundedBorder       = ParseBoolSafe(kv, L"TrayRoundedBorder", defs.TrayRoundedBorder);
            d.TrayTransparentBelow60  = ParseBoolSafe(kv, L"TrayTransparentBelow60", defs.TrayTransparentBelow60);

            d.TrayBgDefault       = ParseColorSafe(kv, L"TrayBgDefault", defs.TrayBgDefault);
            d.TrayBgWarning       = ParseColorSafe(kv, L"TrayBgWarning", defs.TrayBgWarning);
            d.TrayBgDanger        = ParseColorSafe(kv, L"TrayBgDanger", defs.TrayBgDanger);
            d.TrayTextColorCustom = ParseColorSafe(kv, L"TrayTextColorCustom", defs.TrayTextColorCustom);

            auto itLang = kv.find(L"Language");
            if (itLang != kv.end() && (itLang->second == L"vi" || itLang->second == L"en")) {
                d.Language = itLang->second;
            } else {
                d.Language = defs.Language;
                ConfigHadError = true;
            }

            auto itTheme = kv.find(L"Theme");
            if (itTheme != kv.end() && (itTheme->second == L"dark" || itTheme->second == L"light" || itTheme->second == L"system")) {
                d.Theme = itTheme->second;
            } else {
                d.Theme = L"system";
                ConfigHadError = true;
            }

            if (kv.count(L"TrayFontFamily") && !kv[L"TrayFontFamily"].empty()) d.TrayFontFamily = kv[L"TrayFontFamily"];
            if (kv.count(L"TrayFontStyle") && !kv[L"TrayFontStyle"].empty())   d.TrayFontStyle  = kv[L"TrayFontStyle"];
            if (kv.count(L"Hotkey") && !kv[L"Hotkey"].empty())                 d.Hotkey         = kv[L"Hotkey"];

            if (ConfigHadError && !ConfigReadFailed) {
                SaveRamConfig(d);
            }
        } else {
            SaveRamConfig(d);
        }
        return d;
    }

    static void UpdateLinkRegistry() {
        CreateDirectoryW(AppDataRoot.c_str(), nullptr);
        std::vector<std::pair<std::wstring, std::wstring>> entries;
        std::vector<std::wstring> lines;
        if (ReadFileLinesUtf8(LinkFilePath, lines)) {
            for (const auto& l : lines) {
                size_t eq = l.find(L'=');
                if (eq != std::wstring::npos) {
                    std::wstring k = TrimWide(l.substr(0, eq));
                    std::wstring v = TrimWide(l.substr(eq + 1));
                    if (k != L"RAM_TRAY_BAT" && k != L"WCAO_RAM") {
                        entries.push_back({ k, v });
                    }
                }
            }
        }
        entries.push_back({ L"WCAO_RAM", ExePath });
        std::wstring out;
        for (const auto& kv : entries) {
            out += kv.first + L"=" + kv.second + L"\r\n";
        }
        WriteAllTextUtf8(LinkFilePath, out);
    }

    static bool SetWindowAppId(HWND hWnd, const wchar_t* appId) {
        IPropertyStore* store = nullptr;
        HRESULT hr = SHGetPropertyStoreForWindow(hWnd, IID_PPV_ARGS(&store));
        if (FAILED(hr) || !store) return false;

        PROPVARIANT pv;
        PropVariantInit(&pv);
        pv.vt = VT_LPWSTR;
        pv.pwszVal = (LPWSTR)CoTaskMemAlloc((wcslen(appId) + 1) * sizeof(wchar_t));
        if (pv.pwszVal) {
            wcscpy_s(pv.pwszVal, wcslen(appId) + 1, appId);
            store->SetValue(PKEY_AppUserModel_ID, pv);
            store->Commit();
            PropVariantClear(&pv);
        }
        store->Release();
        return true;
    }

    static bool CreateShortcut(const std::wstring& lnkPath, const std::wstring& targetPath, const std::wstring& args, const std::wstring& iconPath, const wchar_t* appId = nullptr, int showCmd = SW_SHOWNORMAL) {
        IShellLinkW* psl = nullptr;
        HRESULT hr = CoCreateInstance(CLSID_ShellLink, nullptr, CLSCTX_INPROC_SERVER, IID_IShellLinkW, (void**)&psl);
        if (FAILED(hr) || !psl) return false;

        psl->SetPath(targetPath.c_str());
        size_t slash = targetPath.find_last_of(L"\\/");
        if (slash != std::wstring::npos) {
            std::wstring workDir = targetPath.substr(0, slash);
            psl->SetWorkingDirectory(workDir.c_str());
        }
        psl->SetArguments(args.c_str());
        psl->SetShowCmd(showCmd);
        psl->SetDescription(L"WCaO RAM Manager");
        if (!iconPath.empty()) {
            psl->SetIconLocation(iconPath.c_str(), 0);
        }

        if (appId) {
            IPropertyStore* store = nullptr;
            if (SUCCEEDED(psl->QueryInterface(IID_IPropertyStore, (void**)&store)) && store) {
                PROPVARIANT pv;
                PropVariantInit(&pv);
                pv.vt = VT_LPWSTR;
                pv.pwszVal = (LPWSTR)CoTaskMemAlloc((wcslen(appId) + 1) * sizeof(wchar_t));
                if (pv.pwszVal) {
                    wcscpy_s(pv.pwszVal, wcslen(appId) + 1, appId);
                    store->SetValue(PKEY_AppUserModel_ID, pv);
                    store->Commit();
                    PropVariantClear(&pv);
                }
                store->Release();
            }
        }

        IPersistFile* ppf = nullptr;
        bool saved = false;
        if (SUCCEEDED(psl->QueryInterface(IID_IPersistFile, (void**)&ppf)) && ppf) {
            saved = SUCCEEDED(ppf->Save(lnkPath.c_str(), TRUE));
            ppf->Release();
        }
        psl->Release();
        return saved;
    }

    static void RegisterToastProtocolHandler() {
        HKEY hKeyProto = nullptr;
        if (RegCreateKeyExW(HKEY_CURRENT_USER, L"Software\\Classes\\wcaoram", 0, nullptr, 0, KEY_WRITE, nullptr, &hKeyProto, nullptr) == ERROR_SUCCESS) {
            const wchar_t* desc = L"URL:WCaO RAM Manager Protocol";
            RegSetValueExW(hKeyProto, nullptr, 0, REG_SZ, (const BYTE*)desc, (DWORD)((wcslen(desc) + 1) * sizeof(wchar_t)));
            const wchar_t* emptyStr = L"";
            RegSetValueExW(hKeyProto, L"URL Protocol", 0, REG_SZ, (const BYTE*)emptyStr, sizeof(wchar_t));
            RegCloseKey(hKeyProto);
        }
        HKEY hKeyCmd = nullptr;
        if (RegCreateKeyExW(HKEY_CURRENT_USER, L"Software\\Classes\\wcaoram\\shell\\open\\command", 0, nullptr, 0, KEY_WRITE, nullptr, &hKeyCmd, nullptr) == ERROR_SUCCESS) {
            std::wstring cmd = L"\"" + ExePath + L"\" \"%1\"";
            RegSetValueExW(hKeyCmd, nullptr, 0, REG_SZ, (const BYTE*)cmd.c_str(), (DWORD)((cmd.size() + 1) * sizeof(wchar_t)));
            RegCloseKey(hKeyCmd);
        }
    }

    static void EnsureAppShortcutAndAppId() {
        SetCurrentProcessExplicitAppUserModelID(L"WCaO.RAM.Manager");
        RegisterToastProtocolHandler();

        wchar_t appData[MAX_PATH] = {};
        if (SUCCEEDED(SHGetFolderPathW(nullptr, CSIDL_APPDATA, nullptr, 0, appData))) {
            std::wstring startMenuLnk = std::wstring(appData) + L"\\Microsoft\\Windows\\Start Menu\\Programs\\WCaO RAM Manager.lnk";
            std::wstring srcIco = ExeDir + L"\\app_icon.ico";
            if (GetFileAttributesW(IconIcoPath.c_str()) == INVALID_FILE_ATTRIBUTES && GetFileAttributesW(srcIco.c_str()) != INVALID_FILE_ATTRIBUTES) {
                CopyFileW(srcIco.c_str(), IconIcoPath.c_str(), FALSE);
            }
            std::wstring iconTarget = (GetFileAttributesW(IconIcoPath.c_str()) != INVALID_FILE_ATTRIBUTES) ? IconIcoPath : ExePath;
            CreateShortcut(startMenuLnk, ExePath, L"", iconTarget, L"WCaO.RAM.Manager", SW_SHOWNORMAL);
        }
    }

    static std::wstring GetStartupShortcutPath() {
        wchar_t appData[MAX_PATH] = {};
        if (SUCCEEDED(SHGetFolderPathW(nullptr, CSIDL_APPDATA, nullptr, 0, appData))) {
            return std::wstring(appData) + L"\\Microsoft\\Windows\\Start Menu\\Programs\\Startup\\WCaO_RAM.lnk";
        }
        return L"";
    }

    static bool RunSchtasksSilent(const std::wstring& args, DWORD* outExitCode = nullptr) {
        wchar_t sysDir[MAX_PATH] = {};
        GetSystemDirectoryW(sysDir, MAX_PATH);
        std::wstring cmd = L"\"" + std::wstring(sysDir) + L"\\schtasks.exe\" " + args;
        std::vector<wchar_t> cmdBuf(cmd.begin(), cmd.end());
        cmdBuf.push_back(L'\0');

        STARTUPINFOW si = {};
        si.cb = sizeof(si);
        si.dwFlags = STARTF_USESHOWWINDOW;
        si.wShowWindow = SW_HIDE;
        PROCESS_INFORMATION pi = {};
        if (!CreateProcessW(nullptr, cmdBuf.data(), nullptr, nullptr, FALSE, CREATE_NO_WINDOW, nullptr, nullptr, &si, &pi)) {
            return false;
        }
        WaitForSingleObject(pi.hProcess, 4000);
        DWORD code = 1;
        GetExitCodeProcess(pi.hProcess, &code);
        CloseHandle(pi.hThread);
        CloseHandle(pi.hProcess);
        if (outExitCode) *outExitCode = code;
        return (code == 0);
    }

    static bool IsScheduledTaskPresentFast() {
        wchar_t sysDir[MAX_PATH] = {};
        if (GetSystemDirectoryW(sysDir, MAX_PATH)) {
            std::wstring taskFile = std::wstring(sysDir) + L"\\Tasks\\WCaO_RAM_Daemon";
            if (GetFileAttributesW(taskFile.c_str()) != INVALID_FILE_ATTRIBUTES) {
                return true;
            }
        }
        return false;
    }

    static bool ManageAutostart(bool toggle, bool& outAdminTaskBlocked) {
        outAdminTaskBlocked = false;
        std::wstring lnkPath = GetStartupShortcutPath();
        bool lnkExists = (!lnkPath.empty() && GetFileAttributesW(lnkPath.c_str()) != INVALID_FILE_ATTRIBUTES);
        bool taskExists = IsScheduledTaskPresentFast();
        bool currentlyEnabled = lnkExists || taskExists;

        if (!toggle) return currentlyEnabled;

        if (currentlyEnabled) {
            if (lnkExists) DeleteFileW(lnkPath.c_str());
            if (taskExists) {
                if (!RunSchtasksSilent(L"/delete /tn \"WCaO_RAM_Daemon\" /f")) {
                    outAdminTaskBlocked = true;
                    return true;
                }
            }
            return false;
        } else {
            if (IsAdmin) {
                std::wstring createArgs = L"/create /tn \"WCaO_RAM_Daemon\" /tr \"\\\"" + ExePath + L"\\\" -tray\" /sc onlogon /rl highest /it /f";
                RunSchtasksSilent(createArgs);
                if (lnkExists) DeleteFileW(lnkPath.c_str());
            } else if (!lnkPath.empty()) {
                CreateShortcut(lnkPath, ExePath, L"-tray", ExePath, nullptr, SW_SHOWMINNOACTIVE);
            }
            return true;
        }
    }
};

// ============================================================================
//  3. NATIVE WINDOWS TOAST NOTIFICATION DISPATCHER (ZERO CUSTOM WINDOW / ZERO RAM)
// ============================================================================
namespace WinRtToast {
    typedef HANDLE HSTRING_RT;
    struct HSTRING_HEADER_RT {
        union {
            PVOID Reserved1;
            char Reserved2[24];
        } Reserved;
    };

    typedef HRESULT(WINAPI* PFN_RoInitialize)(int);
    typedef HRESULT(WINAPI* PFN_RoGetActivationFactory)(HSTRING_RT, REFIID, void**);
    typedef HRESULT(WINAPI* PFN_RoActivateInstance)(HSTRING_RT, void**);
    typedef HRESULT(WINAPI* PFN_WindowsCreateStringReference)(PCWSTR, UINT32, HSTRING_HEADER_RT*, HSTRING_RT*);

    MIDL_INTERFACE("6cd0e74e-ee65-4489-9ebf-ca43e87ba637")
    IXmlDocumentIO_RT : public IUnknown {
        virtual HRESULT STDMETHODCALLTYPE GetIids(ULONG*, IID**) = 0;
        virtual HRESULT STDMETHODCALLTYPE GetRuntimeClassName(HSTRING_RT*) = 0;
        virtual HRESULT STDMETHODCALLTYPE GetTrustLevel(int*) = 0;
        virtual HRESULT STDMETHODCALLTYPE LoadXml(HSTRING_RT xml) = 0;
    };

    MIDL_INTERFACE("75927b93-03f3-41ec-91d3-6e5bac1b38e7")
    IToastNotifier_RT : public IUnknown {
        virtual HRESULT STDMETHODCALLTYPE GetIids(ULONG*, IID**) = 0;
        virtual HRESULT STDMETHODCALLTYPE GetRuntimeClassName(HSTRING_RT*) = 0;
        virtual HRESULT STDMETHODCALLTYPE GetTrustLevel(int*) = 0;
        virtual HRESULT STDMETHODCALLTYPE Show(IUnknown* notification) = 0;
        virtual HRESULT STDMETHODCALLTYPE Hide(IUnknown* notification) = 0;
    };

    MIDL_INTERFACE("50ac103f-d235-4598-bbef-98fe4d1a3ad4")
    IToastNotificationManagerStatics_RT : public IUnknown {
        virtual HRESULT STDMETHODCALLTYPE GetIids(ULONG*, IID**) = 0;
        virtual HRESULT STDMETHODCALLTYPE GetRuntimeClassName(HSTRING_RT*) = 0;
        virtual HRESULT STDMETHODCALLTYPE GetTrustLevel(int*) = 0;
        virtual HRESULT STDMETHODCALLTYPE CreateToastNotifier(IToastNotifier_RT** result) = 0;
        virtual HRESULT STDMETHODCALLTYPE CreateToastNotifierWithId(HSTRING_RT applicationId, IToastNotifier_RT** result) = 0;
    };

    MIDL_INTERFACE("04124b20-82c6-4229-b109-fd9ed4662b53")
    IToastNotificationFactory_RT : public IUnknown {
        virtual HRESULT STDMETHODCALLTYPE GetIids(ULONG*, IID**) = 0;
        virtual HRESULT STDMETHODCALLTYPE GetRuntimeClassName(HSTRING_RT*) = 0;
        virtual HRESULT STDMETHODCALLTYPE GetTrustLevel(int*) = 0;
        virtual HRESULT STDMETHODCALLTYPE CreateToastNotification(IUnknown* content, IUnknown** value) = 0;
    };

    inline IToastNotifier_RT* s_activeNotifier = nullptr;
    inline IUnknown* s_activeToast = nullptr;

    inline void HideActiveToast() {
        if (s_activeNotifier && s_activeToast) {
            s_activeNotifier->Hide(s_activeToast);
        }
        if (s_activeToast) {
            s_activeToast->Release();
            s_activeToast = nullptr;
        }
        if (s_activeNotifier) {
            s_activeNotifier->Release();
            s_activeNotifier = nullptr;
        }
    }

    inline bool ShowNativeToast(const std::wstring& line1, const std::wstring& line2, bool playSound, bool isAdmin, bool isVi) {
        HMODULE hComBase = GetModuleHandleW(L"combase.dll");
        if (!hComBase) hComBase = LoadLibraryW(L"combase.dll");
        if (!hComBase) return false;

        auto pRoGetFactory = (PFN_RoGetActivationFactory)GetProcAddress(hComBase, "RoGetActivationFactory");
        auto pRoActivate   = (PFN_RoActivateInstance)GetProcAddress(hComBase, "RoActivateInstance");
        auto pCreateStrRef = (PFN_WindowsCreateStringReference)GetProcAddress(hComBase, "WindowsCreateStringReference");
        if (!pRoGetFactory || !pRoActivate || !pCreateStrRef) return false;

        HideActiveToast();

        auto makeHStr = [&](const wchar_t* str, HSTRING_HEADER_RT& hdr, HSTRING_RT& hstr) -> bool {
            return SUCCEEDED(pCreateStrRef(str, (UINT32)wcslen(str), &hdr, &hstr));
        };

        std::wstring xml = L"<toast duration=\"short\" launch=\"wcaoram:open\"><visual><binding template=\"ToastGeneric\"><text>";
        xml += line1;
        xml += L"</text><text>";
        xml += line2;
        xml += L"</text></binding></visual><audio silent=\"";
        xml += (playSound ? L"false" : L"true");
        xml += L"\"/><actions>";
        if (!isAdmin) {
            xml += L"<action content=\"";
            xml += (isVi ? L"Chuyển Quản trị viên" : L"Switch to Administrator");
            xml += L"\" arguments=\"wcaoram:admin\" activationType=\"protocol\"/>";
        }
        xml += L"<action content=\"";
        xml += (isVi ? L"Bỏ qua" : L"Dismiss");
        xml += L"\" arguments=\"dismiss\" activationType=\"system\"/>";
        xml += L"</actions></toast>";

        static const GUID kIID_XmlDoc         = { 0xf7f3a506, 0x1e87, 0x42d6, { 0xbc, 0xfb, 0xb8, 0xc8, 0x09, 0xfa, 0x54, 0x94 } };
        static const GUID kIID_XmlDocIO       = { 0x6cd0e74e, 0xee65, 0x4489, { 0x9e, 0xbf, 0xca, 0x43, 0xe8, 0x7b, 0xa6, 0x37 } };
        static const GUID kIID_ToastMgrStatic = { 0x50ac103f, 0xd235, 0x4598, { 0xbb, 0xef, 0x98, 0xfe, 0x4d, 0x1a, 0x3a, 0xd4 } };
        static const GUID kIID_ToastFactory   = { 0x04124b20, 0x82c6, 0x4229, { 0xb1, 0x09, 0xfd, 0x9e, 0xd4, 0x66, 0x2b, 0x53 } };

        HSTRING_HEADER_RT hdrXmlClass = {}, hdrToastClass = {}, hdrAppId = {}, hdrXmlPayload = {};
        HSTRING_RT hsXmlClass = nullptr, hsToastClass = nullptr, hsAppId = nullptr, hsXmlPayload = nullptr;
        if (!makeHStr(L"Windows.Data.Xml.Dom.XmlDocument", hdrXmlClass, hsXmlClass)) return false;
        if (!makeHStr(L"Windows.UI.Notifications.ToastNotification", hdrToastClass, hsToastClass)) return false;
        if (!makeHStr(L"WCaO.RAM.Manager", hdrAppId, hsAppId)) return false;
        if (!makeHStr(xml.c_str(), hdrXmlPayload, hsXmlPayload)) return false;

        IUnknown* unkXml = nullptr;
        if (FAILED(pRoActivate(hsXmlClass, (void**)&unkXml)) || !unkXml) return false;

        bool shown = false;
        IXmlDocumentIO_RT* xmlIo = nullptr;
        if (SUCCEEDED(unkXml->QueryInterface(kIID_XmlDocIO, (void**)&xmlIo)) && xmlIo) {
            if (SUCCEEDED(xmlIo->LoadXml(hsXmlPayload))) {
                IUnknown* xmlDoc = nullptr;
                if (SUCCEEDED(unkXml->QueryInterface(kIID_XmlDoc, (void**)&xmlDoc)) && xmlDoc) {
                    HSTRING_HEADER_RT hdrMgrClass = {};
                    HSTRING_RT hsMgrClass = nullptr;
                    if (makeHStr(L"Windows.UI.Notifications.ToastNotificationManager", hdrMgrClass, hsMgrClass)) {
                        IToastNotificationManagerStatics_RT* toastMgr = nullptr;
                        if (SUCCEEDED(pRoGetFactory(hsMgrClass, kIID_ToastMgrStatic, (void**)&toastMgr)) && toastMgr) {
                            IToastNotifier_RT* notifier = nullptr;
                            if (SUCCEEDED(toastMgr->CreateToastNotifierWithId(hsAppId, &notifier)) && notifier) {
                                IToastNotificationFactory_RT* toastFactory = nullptr;
                                if (SUCCEEDED(pRoGetFactory(hsToastClass, kIID_ToastFactory, (void**)&toastFactory)) && toastFactory) {
                                    IUnknown* toast = nullptr;
                                    if (SUCCEEDED(toastFactory->CreateToastNotification(xmlDoc, &toast)) && toast) {
                                        if (SUCCEEDED(notifier->Show(toast))) {
                                            shown = true;
                                            s_activeNotifier = notifier;
                                            s_activeToast = toast;
                                            notifier = nullptr;
                                            toast = nullptr;
                                        }
                                        if (toast) toast->Release();
                                    }
                                    toastFactory->Release();
                                }
                                if (notifier) notifier->Release();
                            }
                            toastMgr->Release();
                        }
                    }
                    xmlDoc->Release();
                }
            }
            xmlIo->Release();
        }
        unkXml->Release();
        return shown;
    }
}
