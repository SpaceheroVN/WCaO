<# :
@echo off
chcp 65001 >nul
cls
title Windows Cleanup ^& Optimizer v6.3.2
cd /d "%~dp0"
if "%~1"=="-debug" set WCAO_DEBUG=1
if "%~1"=="/debug" set WCAO_DEBUG=1
if "%~1"=="debug" set WCAO_DEBUG=1
if "%~1"=="/norelaunch" set WCAO_NO_RELAUNCH=1
if "%~1"=="-norelaunch" set WCAO_NO_RELAUNCH=1
if "%~1"=="norelaunch" set WCAO_NO_RELAUNCH=1

:: Direct 1-step launch into Windows Terminal (Hidden relay - 0 flashing windows)
if not defined WT_SESSION if not defined WCAO_NO_RELAUNCH if not defined WCAO_DEBUG if /i not "%TERM_PROGRAM%"=="vscode" (
    where wt.exe >nul 2>&1
    if not errorlevel 1 (
        set "WCAO_NO_RELAUNCH=1"
        powershell -WindowStyle Hidden -NoProfile -Command "Start-Process wt.exe -ArgumentList 'cmd.exe /c \"%~f0\"'"
        exit /b
    )
)


set "WCAO_BAT_PATH=%~f0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$global:WCAO_BAT_PATH=$env:WCAO_BAT_PATH; [Console]::OutputEncoding=[System.Text.Encoding]::UTF8; [Console]::CursorVisible=$false; try { $code = [System.IO.File]::ReadAllText($env:WCAO_BAT_PATH, [System.Text.Encoding]::UTF8); & {[ScriptBlock]::Create($code).Invoke()} } catch { Write-Host `"`n[WCaO ERROR] $_`" -ForegroundColor Red; Write-Host $_.ScriptStackTrace -ForegroundColor Yellow; Write-Host `"`nPress any key to exit...`"; $null = `$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown') }"
exit /b
#>

# ===============================================================================
#  ZONE 1: BOOTSTRAP, WIN32 PLATFORM INTEROP & WINDOW CONTROLLER
# ===============================================================================
# --- [1.1] Console Init & UTF-8 ---
# Immediately Set UTF-8 Output Encoding & Hide Console Cursor
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::InputEncoding  = [System.Text.Encoding]::UTF8
    $OutputEncoding           = [System.Text.Encoding]::UTF8
} catch {}
try { [Console]::CursorVisible = $false } catch {}
[Console]::Write("$([char]27)[?25l$([char]27)[2J$([char]27)[H")
$script:scriptDir = if ($global:WCAO_BAT_PATH) { Split-Path -Parent $global:WCAO_BAT_PATH } elseif ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }

# --- [1.2] Win32 Interop ---
# Enable ANSI Console Colors & Win32 Assemblies
$codeWin32 = @"
using System;
using System.Runtime.InteropServices;

public class ConsoleMouse {
    public const int STD_INPUT_HANDLE = -10;
    public const int STD_OUTPUT_HANDLE = -11;
    public const int ENABLE_MOUSE_INPUT = 0x0010;
    public const int ENABLE_EXTENDED_FLAGS = 0x0080;
    public const int ENABLE_QUICK_EDIT_MODE = 0x0040;
    public const int ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004;

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool SetConsoleOutputCP(uint wCodePageID);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool SetConsoleCP(uint wCodePageID);

    [StructLayout(LayoutKind.Sequential)]
    public struct COORD {
        public short X;
        public short Y;
    }

    [StructLayout(LayoutKind.Explicit)]
    public struct MOUSE_EVENT_RECORD {
        [FieldOffset(0)] public COORD dwMousePosition;
        [FieldOffset(4)] public int dwButtonState;
        [FieldOffset(8)] public int dwControlKeyState;
        [FieldOffset(12)] public int dwEventFlags;
    }

    [StructLayout(LayoutKind.Explicit)]
    public struct KEY_EVENT_RECORD {
        [FieldOffset(0)] public int bKeyDown;
        [FieldOffset(4)] public ushort wRepeatCount;
        [FieldOffset(6)] public ushort wVirtualKeyCode;
        [FieldOffset(8)] public ushort wVirtualScanCode;
        [FieldOffset(10)] public char UnicodeChar;
        [FieldOffset(12)] public int dwControlKeyState;
    }

    [StructLayout(LayoutKind.Explicit)]
    public struct INPUT_RECORD {
        [FieldOffset(0)] public ushort EventType;
        [FieldOffset(4)] public KEY_EVENT_RECORD KeyEvent;
        [FieldOffset(4)] public MOUSE_EVENT_RECORD MouseEvent;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr GetStdHandle(int nStdHandle);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool GetConsoleMode(IntPtr hConsoleInput, out int lpMode);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool SetConsoleMode(IntPtr hConsoleInput, int dwMode);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool ReadConsoleInput(IntPtr hConsoleInput, [Out] INPUT_RECORD[] lpBuffer, uint nLength, out uint lpNumberOfEventsRead);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool GetNumberOfConsoleInputEvents(IntPtr hConsoleInput, out uint lpcNumberOfEvents);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool FlushConsoleInputBuffer(IntPtr hConsoleInput);

    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();

    [DllImport("user32.dll")]
    public static extern IntPtr GetParent(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    public static extern int GetSystemMetrics(int nIndex);
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern uint RegisterWindowMessage(string lpString);
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);

    public const int SM_CXSCREEN = 0;
    public const int SM_CYSCREEN = 1;
    public const uint SWP_NOSIZE = 0x0001;
    public const uint SWP_NOZORDER = 0x0004;

    public static void EnableConsoleVT() {
        SetConsoleOutputCP(65001);
        SetConsoleCP(65001);

        IntPtr hInput = GetStdHandle(STD_INPUT_HANDLE);
        int mode;
        GetConsoleMode(hInput, out mode);
        mode &= ~ENABLE_QUICK_EDIT_MODE;
        mode |= ENABLE_MOUSE_INPUT | ENABLE_EXTENDED_FLAGS;
        SetConsoleMode(hInput, mode);

        IntPtr hOut = GetStdHandle(STD_OUTPUT_HANDLE);
        int outMode;
        GetConsoleMode(hOut, out outMode);
        outMode |= ENABLE_VIRTUAL_TERMINAL_PROCESSING;
        SetConsoleMode(hOut, outMode);
    }

    [DllImport("user32.dll")]
    public static extern IntPtr GetAncestor(IntPtr hwnd, uint flags);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr GetWindow(IntPtr hWnd, uint uCmd);

    public const uint GW_OWNER = 4;

    public static void EnforceMinWindowPixels(int minW = 1100, int minH = 620) {
        try {
            IntPtr hWnd = GetConsoleWindow();
            if (hWnd == IntPtr.Zero) return;
            IntPtr targetWnd = GetAncestor(hWnd, 2); // GA_ROOT
            if (targetWnd == IntPtr.Zero || targetWnd == hWnd) {
                targetWnd = GetWindow(hWnd, GW_OWNER);
            }
            if (targetWnd == IntPtr.Zero) {
                IntPtr parent = GetParent(hWnd);
                targetWnd = (parent != IntPtr.Zero) ? parent : hWnd;
            }
            if (targetWnd == IntPtr.Zero) targetWnd = hWnd;

            RECT rect;
            if (!GetWindowRect(targetWnd, out rect)) return;

            int w = rect.Right - rect.Left;
            int h = rect.Bottom - rect.Top;

            if (w < minW || h < minH) {
                int newW = Math.Max(w, minW);
                int newH = Math.Max(h, minH);
                SetWindowPos(targetWnd, IntPtr.Zero, rect.Left, rect.Top, newW, newH, SWP_NOZORDER);
            }
        } catch {}
    }

    public static void CenterWindow() {
        try {
            IntPtr hWnd = GetConsoleWindow();
            if (hWnd == IntPtr.Zero) return;

            IntPtr parent = GetParent(hWnd);
            IntPtr targetWnd = (parent != IntPtr.Zero) ? parent : hWnd;

            RECT rect;
            if (!GetWindowRect(targetWnd, out rect)) return;

            int winWidth = rect.Right - rect.Left;
            int winHeight = rect.Bottom - rect.Top;

            int screenWidth = GetSystemMetrics(SM_CXSCREEN);
            int screenHeight = GetSystemMetrics(SM_CYSCREEN);

            int posX = Math.Max(0, (screenWidth - winWidth) / 2);
            int posY = Math.Max(0, (screenHeight - winHeight) / 2);

            SetWindowPos(targetWnd, IntPtr.Zero, posX, posY, 0, 0, SWP_NOSIZE | SWP_NOZORDER);
        } catch {}
    }
}
"@
if (-not (([System.Management.Automation.PSTypeName]'ConsoleMouse').Type)) {
    Add-Type -TypeDefinition $codeWin32 -ErrorAction SilentlyContinue
}
try { [ConsoleMouse]::EnableConsoleVT(); [ConsoleMouse]::CenterWindow() } catch {}
if (-not (([System.Management.Automation.PSTypeName]'AsyncProcessStreamer').Type)) {
    $codeStreamer = @"
using System;
using System.Diagnostics;
using System.Collections.Concurrent;

public class AsyncProcessStreamer {
    public ConcurrentQueue<string> OutLines = new ConcurrentQueue<string>();
    public ConcurrentQueue<string> ErrLines = new ConcurrentQueue<string>();

    public void Attach(Process proc) {
        proc.OutputDataReceived += (s, e) => {
            if (e.Data != null) OutLines.Enqueue(e.Data);
        };
        proc.ErrorDataReceived += (s, e) => {
            if (e.Data != null) ErrLines.Enqueue(e.Data);
        };
        proc.BeginOutputReadLine();
        proc.BeginErrorReadLine();
    }
}
"@
    Add-Type -TypeDefinition $codeStreamer -ErrorAction SilentlyContinue
}

# --- [1.3] Cursor Positioning ---
# Safe Cursor Positioning Function
function Set-CursorPos($x, $y) {
    try {
        $maxW = [Console]::BufferWidth - 1
        $maxH = [Console]::BufferHeight - 1
        if ($maxW -lt 0) { $maxW = 0 }
        if ($maxH -lt 0) { $maxH = 0 }

        $clampedX = [math]::Max(0, [math]::Min($maxW, [int]$x))
        $clampedY = [math]::Max(0, [math]::Min($maxH, [int]$y))

        [Console]::SetCursorPosition($clampedX, $clampedY)
    } catch {}
}

# --- [1.4] Window Metrics ---
# Set BufferSize & WindowSize
try { [Console]::Clear() } catch {}
try { [Console]::CursorVisible = $false } catch {}
try {
    $rawUI = $Host.UI.RawUI
    $w = [math]::Max(120, $rawUI.WindowSize.Width)
    $h = [math]::Max(28, $rawUI.WindowSize.Height)
    if ($rawUI.WindowSize.Width -lt 120 -or $rawUI.WindowSize.Height -lt 28) {
        $rawUI.WindowSize = New-Object System.Management.Automation.Host.Size($w, $h)
    }
    # Sync buffer to window to prevent horizontal overflow triggering resize events
    $rawUI.BufferSize = New-Object System.Management.Automation.Host.Size($w, [math]::Max($h, $rawUI.BufferSize.Height))
} catch {}

# ===============================================================================
#  ZONE 2: DESIGN SYSTEM, GLOBAL STATE & MENU CATALOGS
# ===============================================================================
# --- [2.1] Palette & Box Glyphs ---
# ANSI Colors - True Color (24-bit RGB) & Box Characters
$ESC = [char]27
$cReset  = "$ESC[0m"
$cCyan   = "$ESC[38;2;40;210;240m"
$cGreen  = "$ESC[38;2;80;220;120m"
$cLightGreen= "$ESC[38;2;120;240;130m"
$cDarkGreen = "$ESC[38;2;40;165;85m"
$cYellow = "$ESC[38;2;255;200;60m"
$cLightYellow= "$ESC[38;2;255;235;120m"
$cDarkYellow= "$ESC[38;2;215;155;0m"
$cRed    = "$ESC[38;2;245;80;80m"
$cPurp   = "$ESC[38;2;180;120;255m"
$cWhite  = "$ESC[38;2;224;224;230m"
$cGray   = "$ESC[38;2;100;100;115m"
$cDim    = "$ESC[38;2;60;60;75m"
$cLightCyan = "$ESC[38;2;150;235;255m"
$chrLine  = [string][char]0x2500
$chrTL    = [string][char]0x256D
$chrTR    = [string][char]0x256E
$chrBL    = [string][char]0x2570
$chrBR    = [string][char]0x256F
$chrVert  = [string][char]0x2502
$chrThumb = [string][char]0x2588
$chrHThumb= [string][char]0x2584
$chrRD    = [string][char]0x2524
$chrLD    = [string][char]0x251C
# --- [2.2] Global State & Flags ---
$VERSION = "6.3.2"
$TOOLNAME = "Windows Cleanup & Optimizer"

# Single-Instance Mutex Guard (Prevent running duplicate instances)
$script:mutexName = "Global\WCaO_v${VERSION}"
$script:createdNew = $false
for ($i = 0; $i -lt 5; $i++) {
    try {
        $script:appMutex = New-Object System.Threading.Mutex($true, $script:mutexName, [ref]$script:createdNew)
        if ($script:createdNew) { break }
        if ($script:appMutex) {
            try { $script:appMutex.Dispose() } catch {}
            $script:appMutex = $null
        }
    } catch {}
    Start-Sleep -Milliseconds 200
}
if (-not $script:createdNew -and -not $env:WCAO_DEBUG) {
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
        [System.Windows.Forms.MessageBox]::Show("WCaO đang chạy trên hệ thống.`nVui lòng kiểm tra thanh tác vụ hoặc đóng cửa sổ cũ trước khi mở phiên mới.", "WCaO", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
    } catch {
        Write-Host "`n[i] WCaO is already running. Please close the active instance." -ForegroundColor Yellow
        Start-Sleep -Seconds 2
    }
    [System.Environment]::Exit(0)
}
try { $Host.UI.RawUI.WindowTitle = "$TOOLNAME v$VERSION" } catch {}

# --- [2.3] Drive Discovery ---
# Target Drive State & Initialization
$sysDrive = $env:SystemDrive
if (-not $sysDrive) { $sysDrive = "C:" }
$global:availableDrives = @("C:")
$global:selectedDriveIndex = 0
$global:targetDrive = "C:"

# --- Drive State Management Functions ---
function Initialize-DrivesFromList($detectedDrives) {
    if (-not $detectedDrives -or $detectedDrives.Count -eq 0) {
        $detectedDrives = @($sysDrive)
    }
    $list = @()
    if ($detectedDrives.Count -gt 1) {
        $list += "ALL"
    }
    foreach ($d in $detectedDrives) {
        $list += $d
    }
    $global:availableDrives = $list
    $global:selectedDriveIndex = 0
    $global:targetDrive = $global:availableDrives[0]
}

function Refresh-AvailableDrives() {
    try {
        $drives = @([System.IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq 'Fixed' -and $_.IsReady } | ForEach-Object { $_.Name.TrimEnd('\') })
        Initialize-DrivesFromList $drives
    } catch {
        $global:availableDrives = @($sysDrive)
        $global:targetDrive = $sysDrive
    }
}

function Invoke-CycleTargetDrive() {
    if ($global:availableDrives.Count -le 1) {
        Refresh-AvailableDrives
    }
    if ($global:availableDrives.Count -gt 1) {
        $global:selectedDriveIndex = ($global:selectedDriveIndex + 1) % $global:availableDrives.Count
        $global:targetDrive = $global:availableDrives[$global:selectedDriveIndex]
        Write-RightLog "CONFIG" (T "Ổ đĩa mục tiêu: $global:targetDrive" "Target Drive set to: $global:targetDrive") $cLightCyan
        Draw-StatusPane
    } else {
        Write-RightLog "INFO" (T "Hệ thống chỉ có 1 ổ đĩa cố định: $global:targetDrive" "System has only 1 fixed drive: $global:targetDrive") $cDim
    }
}

# --- Working Directory & Log File Initialization ---
$wcaoRootDir = "$env:LocalAppData\WCaO"
$baseDir = "$wcaoRootDir\WCaO_TUI"
if (-not (Test-Path $baseDir)) { New-Item -ItemType Directory -Path $baseDir -Force | Out-Null }
$tmpLog = "$baseDir\Actions.wcao"
# Migration from legacy Actions.log if exists
$oldTmpLog = "$env:LocalAppData\WCaO_Toolkit\Actions.log"
if (-not (Test-Path $tmpLog) -and (Test-Path $oldTmpLog)) {
    try { Copy-Item -Path $oldTmpLog -Destination $tmpLog -Force -ErrorAction SilentlyContinue } catch {}
}
if (Test-Path $tmpLog) { Remove-Item -Path $tmpLog -Force -ErrorAction SilentlyContinue }
try { Set-Content -Path $tmpLog -Value "=== WCaO v$VERSION Actions Log ===" -Encoding UTF8 } catch {}
$script:formattedLogCache = $null
$script:formattedLogVersion = 0
$script:currentLogVersion = 1
$script:lastLogContentW = 0
$script:undoLog = "$baseDir\Rename.undo"
$undoLog = $script:undoLog
# Retention Cleanup (Delete logs older than 7 days)
try {
    Get-ChildItem -Path $baseDir -Filter "Log_*.txt" -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } |
        Remove-Item -Force -ErrorAction SilentlyContinue
} catch {}
$global:expertMode = $false
$global:viewMenuOpen = $false
$global:logMenuOpen = $false
$global:selectedLang = "English"
$global:activeMenu = "MAIN"
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$leftConsoleLines = [System.Collections.Generic.List[string]]::new()
$global:logScrollOffset = 0
$script:isDraggingLogScroll = $false
$script:isRedrawing = $false
$script:termW = 115
$script:termH = 25
$global:activityStatus = "Idle - Ready"
$global:activityColor = $cDim
$global:currentActionName = $null
$global:actionBreadcrumbs = [System.Collections.Generic.List[hashtable]]::new()
$global:navTarget = $null
$script:breadcrumbBounds = @()

# --- [2.4] Menu Catalogs (WCaO_RAM C++ Compatibility Test Suite) ---
$script:menuCatalog = @{
    "MAIN" = @{
        TitleVi     = "MENU TEST - ${cLightCyan}WCaO_RAM C++$cCyan"
        TitleEn     = "TEST MENU - ${cLightCyan}WCaO_RAM C++$cCyan"
        BorderColor = $cCyan
        Items       = @(
            @{ TextVi = "[1] Quản lý RAM";                 TextEn = "[1] RAM Management";               Color = $cLightGreen; Handler = "Invoke-RamTrayManager" }
            @{ TextVi = "[2] Kiểm tra tương thích tự động"; TextEn = "[2] Automated Compatibility Test"; Color = $cLightCyan;  Handler = "Invoke-TestRamCompatibility" }
            @{ TextVi = "[3] Tiện ích hệ thống";           TextEn = "[3] System Utilities";             Color = "$ESC[38;2;80;170;240m"; SubMenu = "SYS_UTIL" }
        )
    }
    "SYS_UTIL" = @{
        TitleVi     = "TIỆN ÍCH HỆ THỐNG"
        TitleEn     = "SYSTEM UTILITIES"
        BorderColor = $cCyan
        BaseRGB     = @(80, 180, 235)
        Items       = @(
            @{ TextVi = "[3] Quản lý RAM";            TextEn = "[3] RAM Management";       Handler = "Invoke-RamTrayManager" }
        )
    }
}
$script:menuParent = @{
    "SYS_UTIL" = "MAIN"
}
$script:menuDisplayName = @{
    "MAIN" = "MAIN MENU"
    "SYS_UTIL" = "System Utilities"
}
$script:lastLogRedrawTick = 0

# --- Runtime Flags & UI Control State ---
$script:isTaskRunning = $false
$script:lastActionEscPressed = $false
$script:skipFinallyRedraw = $false
$script:lastBackBtnRender = $null
$script:inputLockedUntil = 0
$script:currentHoverTarget = "NONE"
$script:currentClickTarget = "NONE"
$script:wasLeftDown = $false
$script:lastMenuHoverLine = -1
$script:lastMenuHoverSub = 0
$global:spinnerChars = @('⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏')
$global:spinnerIdx = 0
$global:currentProgressMsg = $null

# ===============================================================================
#  ZONE 3: CORE UTILITIES & UNIFIED LOGGING SYSTEM
# ===============================================================================
# --- [3.1] Localization (T) ---
function T($viText, $enText) {
    if ($global:selectedLang -eq "Vietnamese") { return $viText } else { return $enText }
}

# --- [3.2] Format Helpers ---
function Format-BytesAuto($b) {
    if ($b -lt 1KB) {
        return "$b B"
    } elseif ($b -lt 1MB) {
        $kb = [math]::Round($b / 1KB, 2)
        return "$kb KB"
    } elseif ($b -lt 1GB) {
        $mb = [math]::Round($b / 1MB, 2)
        return "$mb MB"
    } else {
        $gb = [math]::Round($b / 1GB, 2)
        return "$gb GB"
    }
}

function Get-FadedColor($colName, $lineIdx, $maxViewH) {
    $t = if ($maxViewH -gt 1) { $lineIdx / ($maxViewH - 1) } else { 0 }
    $factor = 1.0 - ($t * 0.55)

    switch ($colName) {
        'Green'  { $r = [int](80  * $factor); $g = [int](250 * $factor); $b = [int](120 * $factor) }
        'Cyan'   { $r = [int](100 * $factor); $g = [int](230 * $factor); $b = [int](255 * $factor) }
        'Yellow' { $r = [int](255 * $factor); $g = [int](230 * $factor); $b = [int](100 * $factor) }
        'Red'    { $r = [int](255 * $factor); $g = [int](90  * $factor); $b = [int](90  * $factor) }
        'Purp'   { $r = [int](220 * $factor); $g = [int](130 * $factor); $b = [int](255 * $factor) }
        default  { $r = [int](240 * $factor); $g = [int](240 * $factor); $b = [int](240 * $factor) }
    }
    return "$ESC[38;2;${r};${g};${b}m"
}

# --- [3.3] RightLog Engine ---
function Add-FormattedLogLineToCache($list, $rawLine, $contentW) {
    if ([string]::IsNullOrWhiteSpace($rawLine)) { return }
    $cleanLine = $rawLine -replace '\x1b\[[0-9;]*m', ''

    $colName = 'Green'
    if ($cleanLine -match '\[-\]' -or $cleanLine -match '\[ERROR\]' -or $cleanLine -match '\[FAILED\]' -or $cleanLine -match '\[BUG\]') {
        $colName = 'Red'
    } elseif ($cleanLine -match '\[!\]' -or $cleanLine -match '\[WARN\]' -or $cleanLine -match '\[WARNING\]' -or $cleanLine -match '\[#\]' -or $cleanLine -match '\[BLOCKED\]') {
        $colName = 'Yellow'
    } elseif ($cleanLine -match '\[\$\]' -or $cleanLine -match '\[NAV\]') {
        $colName = 'Cyan'
    } elseif ($cleanLine -match '\[@\]' -or $cleanLine -match '\[&\]' -or $cleanLine -match '\[&&\]' -or $cleanLine -match '\[UI\]' -or $cleanLine -match '\[BOOT\]' -or $cleanLine -match '\[DEBUG\]') {
        $colName = 'Purp'
    } elseif ($cleanLine -match '\[~\]' -or $cleanLine -match '\[IN\]' -or $cleanLine -match '\[>>\]') {
        $colName = 'Cyan'
    } elseif ($cleanLine -match '\[\+\]' -or $cleanLine -match '\[OUT\]' -or $cleanLine -match '\[SUCCESS\]') {
        $colName = 'Green'
    }

    # Whole-Word Multi-Line Wrapping aligned under column of '[' tag (11 spaces)
    if ($cleanLine.Length -gt $contentW) {
        $words = $cleanLine -split "\s+"
        $currStr = ""

        foreach ($w in $words) {
            if ($currStr.Length -eq 0) {
                $currStr = $w
            } elseif (($currStr.Length + 1 + $w.Length) -le $contentW) {
                $currStr += " " + $w
            } else {
                $list.Add([PSCustomObject]@{ ColorName = $colName; Text = $currStr })
                $indent = " " * 11
                if ((11 + $w.Length) -gt $contentW) {
                    $currStr = $indent + $w.Substring(0, [math]::Max(1, $contentW - 11))
                } else {
                    $currStr = $indent + $w
                }
            }
        }
        if ($currStr.Length -gt 0) {
            $list.Add([PSCustomObject]@{ ColorName = $colName; Text = $currStr })
        }
    } else {
        $list.Add([PSCustomObject]@{ ColorName = $colName; Text = $cleanLine })
    }
}

function Get-FormattedLogLines {
    if (-not (Test-Path $tmpLog)) { return [System.Collections.Generic.List[PSCustomObject]]::new() }

    $cachedW = if ($script:termW -gt 0) { $script:termW } else { 120 }
    $contentW = [math]::Max(10, [math]::Max(10, $cachedW - 45) - 4)

    if ($script:formattedLogCache -and $script:formattedLogVersion -eq $script:currentLogVersion -and $contentW -eq $script:lastLogContentW) {
        return $script:formattedLogCache
    }

    Get-TermSize
    $rightW = [math]::Max(10, $script:termW - 45)
    $contentW = [math]::Max(10, $rightW - 4)

    $lines = [System.IO.File]::ReadAllLines($tmpLog, [System.Text.Encoding]::UTF8)
    $formattedList = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($rawLine in $lines) {
        Add-FormattedLogLineToCache $formattedList $rawLine $contentW
    }
    $script:formattedLogCache = $formattedList
    $script:formattedLogVersion = $script:currentLogVersion
    $script:lastLogContentW = $contentW
    return $formattedList
}

function Write-RightLog($tag, $msg, $color = $cWhite) {
    $normTag = $tag
    if ($normTag -in @("~", "IN", "CMD_RUN", "CLIPBOARD", ">>", "SUMMARY", "CONFIG")) {
        $normTag = "~"
    } elseif ($normTag -in @("+", "OUT", "DECLARED", "SUCCESS")) {
        $normTag = "+"
    } elseif ($normTag -in @("!", "WARN", "WARNING")) {
        $normTag = "!"
    } elseif ($normTag -in @("-", "ERR", "ERROR", "FAILED", "BUG")) {
        $normTag = "-"
    } elseif ($normTag -in @("$", "NAV")) {
        $normTag = "$"
    } elseif ($normTag -in @("#", "BLOCKED")) {
        $normTag = "#"
    } elseif ($normTag -in @("@", "UI")) {
        $normTag = "@"
    } elseif ($normTag -in @("&", "BOOT")) {
        $normTag = "&"
    } elseif ($normTag -in @("&&", "DEBUG")) {
        $normTag = "&&"
    } else {
        $normTag = $tag
    }
    $cleanMsg = $msg -replace '\x1b\[[0-9;]*m', ''
    $time = Get-Date -Format "HH:mm:ss"
    $fullRaw = "[$time] [$normTag] $cleanMsg"
    try { [System.IO.File]::AppendAllText($tmpLog, $fullRaw + [Environment]::NewLine, [System.Text.Encoding]::UTF8) } catch {}
    $script:currentLogVersion++

    $cachedW = if ($script:termW -gt 0) { $script:termW } else { 120 }
    $contentW = [math]::Max(10, [math]::Max(10, $cachedW - 45) - 4)
    if ($script:formattedLogCache -and $contentW -eq $script:lastLogContentW) {
        Add-FormattedLogLineToCache $script:formattedLogCache $fullRaw $contentW
        $script:formattedLogVersion = $script:currentLogVersion
    }

    # Auto-jump to the newest log at the bottom
    $global:logScrollOffset = 0

    # Real-time log pane redraw (PowerShell 5.1 TickCount)
    $nowTick = [Environment]::TickCount
    if ($script:lastLogRedrawTick -eq 0 -or [math]::Abs($nowTick - $script:lastLogRedrawTick) -ge 40 -or $tag -in @("OK", "ERR", "SUMMARY", "WARN", "+", "-", "!", "IN", "~", "OUT", "$", "&", "@")) {
        $script:lastLogRedrawTick = $nowTick
        Draw-RightLogPane
    }
}

function Write-DebugLog($tag, $msg) {
    if ($env:WCAO_DEBUG -eq "1" -or $global:wcaoDebug -or $global:WCAO_DEBUG -eq 1) {
        Write-RightLog $tag $msg $cDim
    }
}

# --- [3.4] Log Scrolling ---
function Scroll-Log($deltaLines) {
    $formattedList = Get-FormattedLogLines
    $totalCount = $formattedList.Count
    Get-TermSize
    $logBoxH = [math]::Max(3, $script:termH - 10)
    $viewHeight = [math]::Max(1, $logBoxH - 2)
    $maxScroll = [math]::Max(0, $totalCount - $viewHeight)

    $targetOffset = $global:logScrollOffset + $deltaLines
    $newOffset = [math]::Max(0, [math]::Min($maxScroll, $targetOffset))
    if ($newOffset -ne $global:logScrollOffset) {
        $global:logScrollOffset = $newOffset
        Draw-RightLogPane
    }
}

function Set-LogScrollByPosY($posY) {
    Get-TermSize
    $formattedList = Get-FormattedLogLines
    $totalCount = $formattedList.Count
    $viewHeight = [math]::Max(1, ($script:termH - 10) - 2)
    if ($totalCount -le $viewHeight) { return }

    $maxScroll = $totalCount - $viewHeight
    $startY = 10
    $endY = $startY + $viewHeight - 1

    $clampedY = [math]::Max($startY, [math]::Min($endY, $posY))
    $ratio = ($endY - $clampedY) / [math]::Max(1, ($endY - $startY))
    $targetOffset = [math]::Round($ratio * $maxScroll)
    if ($targetOffset -ne $global:logScrollOffset) {
        $global:logScrollOffset = $targetOffset
        Draw-RightLogPane
    }
}

function Process-LogScrollEvents($mEvent) {
    $posX = $mEvent.dwMousePosition.X
    $posY = $mEvent.dwMousePosition.Y
    $scrollCol = $script:termW - 2
    $isLeftDown = ($mEvent.dwButtonState -band 1) -ne 0
    $logBoxH = [math]::Max(3, $script:termH - 10)
    $viewHeight = [math]::Max(1, $logBoxH - 2)
    $startY = 10
    $endY = $startY + $viewHeight - 1

    if ($isLeftDown -and ($posX -eq $scrollCol) -and ($posY -ge $startY -and $posY -le $endY)) {
        $script:isDraggingLogScroll = $true
        Set-LogScrollByPosY $posY
        return $true
    }
    if ($isLeftDown -and $script:isDraggingLogScroll) {
        Set-LogScrollByPosY $posY
        return $true
    }
    if (-not $isLeftDown -and $script:isDraggingLogScroll) {
        $script:isDraggingLogScroll = $false
        Draw-RightLogPane
    }
    if ($mEvent.dwEventFlags -eq 4) {
        if ($posX -ge 43) {
            $delta = [int]$mEvent.dwButtonState
            $step = if ($delta -gt 0) { 3 } else { -3 }
            Scroll-Log $step
            return $true
        }
        return $false
    }
    return $false
}

# --- [3.5] Log Export & Registry ---
function Invoke-OpenLogFolder() {
    Write-RightLog "IN" (T "Đang mở thư mục chứa nhật ký..." "Opening log folder...") $cCyan
    try { Start-Process "explorer.exe" "`"$baseDir`"" } catch { Write-RightLog "ERR" (T "Không thể mở thư mục nhật ký." "Cannot open log folder.") $cRed }
}

function Invoke-ExportLogDialog() {
    if (-not (Test-Path $tmpLog)) {
        Write-RightLog "OUT" (T "Không có nhật ký để xuất." "No actions to export.") $cYellow
        return
    }
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
        $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
        $now = Get-Date -Format "yyyyMMdd_HHmmss"
        $saveDialog.FileName = "WCaO_Log_$now.txt"
        $saveDialog.Filter = "Text Files (*.txt)|*.txt|Log Files (*.log)|*.log|All Files (*.*)|*.*"
        $saveDialog.Title = (T "Xuất nhật ký WCaO ra tập tin" "Export WCaO Action Log To...")
        $saveDialog.InitialDirectory = [Environment]::GetFolderPath("Desktop")
        if ($saveDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $destPath = $saveDialog.FileName
            Copy-Item -Path $tmpLog -Destination $destPath -Force -ErrorAction SilentlyContinue
            Write-RightLog "OUT" (T "Đã xuất nhật ký ra: $destPath" "Exported Action Log to: $destPath") $cGreen
        } else {
            Write-RightLog "IN" (T "Đã hủy xuất nhật ký." "Log export cancelled.") $cDim
        }
    } catch {
        Write-RightLog "ERR" (T "Lỗi khi mở hộp thoại lưu: $_" "Error opening save dialog: $_") $cRed
    }
}

function Invoke-OpenFileLog() {
    Write-RightLog "IN" (T "Đang mở tập tin nhật ký: Actions.wcao" "Opening log file: Actions.wcao") $cCyan
    if (-not (Test-Path $tmpLog)) {
        try { Set-Content -Path $tmpLog -Value "=== WCaO v$VERSION Actions Log ===" -Encoding UTF8 } catch {}
    }
    try {
        [System.Diagnostics.Process]::Start("notepad.exe", "`"$tmpLog`"") | Out-Null
    } catch {
        try { Start-Process "$tmpLog" } catch {}
    }
}

function Update-WcaoLinkRegistry($wcaoPath = $null, $ramTrayPath = $null) {
    $linkDir = "$env:LocalAppData\WCaO"
    $linkFile = "$linkDir\Link.wcao"
    $oldLinkFile = "$env:LocalAppData\WCaO_Toolkit\Link.wcao"
    if (-not (Test-Path $linkFile) -and (Test-Path $oldLinkFile)) {
        try {
            if (-not (Test-Path $linkDir)) { [System.IO.Directory]::CreateDirectory($linkDir) | Out-Null }
            Copy-Item -Path $oldLinkFile -Destination $linkFile -Force -ErrorAction SilentlyContinue
        } catch {}
    }
    try {
        if (-not (Test-Path $linkDir)) { [System.IO.Directory]::CreateDirectory($linkDir) | Out-Null }
        $dict = [System.Collections.Specialized.OrderedDictionary]::new()
        if (Test-Path $linkFile) {
            foreach ($line in [System.IO.File]::ReadAllLines($linkFile, [System.Text.Encoding]::UTF8)) {
                if ($line -match '^\s*([^=]+)=(.*)$') {
                    $dict[$matches[1].Trim()] = $matches[2].Trim()
                }
            }
        }
        if ($wcaoPath) { $dict["WCAO_BAT"] = $wcaoPath }
        if ($ramTrayPath) {
            $dict["WCAO_RAM"] = $ramTrayPath
        }
        $lines = [System.Collections.Generic.List[string]]::new()
        foreach ($k in $dict.Keys) { $lines.Add("$k=$($dict[$k])") }
        [System.IO.File]::WriteAllLines($linkFile, $lines, [System.Text.Encoding]::UTF8)
    } catch {}
}

# ===============================================================================
#  ZONE 4: PROCESS MANAGEMENT & CHILD PROCESS CLEANUP GUARD
# ===============================================================================
# --- [4.1] Process Terminator ---
function Terminate-AllChildProcesses() {
    if ($script:currentRunningProc -and -not $script:currentRunningProc.HasExited) {
        try { $script:currentRunningProc.Kill() } catch {}
        $script:currentRunningProc = $null
    }
}

try {
    [AppDomain]::CurrentDomain.add_ProcessExit({ Terminate-AllChildProcesses })
} catch {}

# --- [4.2] Async Command Runner ---
function Run-And-LogCommand($cmdStr, $argStr = "") {
    Write-RightLog "IN" "$cmdStr $argStr" $cYellow
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $cmdStr
    $pinfo.Arguments = $argStr
    $pinfo.UseShellExecute = $false
    $pinfo.RedirectStandardOutput = $true
    $pinfo.RedirectStandardError = $true
    $pinfo.CreateNoWindow = $true

    $script:currentJobProgress = -1
    $lastLogTick = [Environment]::TickCount

    $script:isTaskRunning = $true
    Hide-LeftBackButton
    Draw-FooterBar

    $streamer = if (([System.Management.Automation.PSTypeName]'AsyncProcessStreamer').Type) {
        New-Object AsyncProcessStreamer
    } else { $null }

    try {
        $proc = [System.Diagnostics.Process]::Start($pinfo)
        if ($streamer) {
            $streamer.Attach($proc)
        }
        $errTask = if (-not $streamer) { $proc.StandardError.ReadToEndAsync() } else { $null }
        $script:currentRunningProc = $proc
        $script:stopRequested = $false

        while (-not $proc.HasExited) {
            Process-ConsoleEvents
            if ($script:stopRequested) {
                try { if ($proc -and -not $proc.HasExited) { $proc.Kill() } } catch {}
                Write-LeftConsole (T " [-] Tác vụ đã bị người dùng hủy." " [-] Task cancelled by user.") $cRed
                Write-RightLog "WARN" (T "Tác vụ đã bị người dùng hủy." "Task cancelled by user.") $cYellow
                Set-Activity "!" (T "Đã hủy tác vụ" "Task cancelled") $cYellow
                $script:currentRunningProc = $null
                $script:stopRequested = $false
                $script:lastTaskCancelled = $true
                return -1
            }
            Start-Sleep -Milliseconds 40

            if ($streamer) {
                $outLine = $null
                while ($streamer.OutLines.TryDequeue([ref]$outLine)) {
                    if ($outLine) {
                        $trimmed = $outLine.Trim()
                        if ($trimmed -match '(\d{1,3}\.?\d*)\s*%') {
                            $pVal = [int][double]$matches[1]
                            if ($pVal -ge 0 -and $pVal -le 100) {
                                $script:currentJobProgress = $pVal
                            }
                        } elseif ($trimmed -match 'Stage 1\b|Giai đoạn 1\b') {
                            $script:currentJobProgress = 33
                        } elseif ($trimmed -match 'Stage 2\b|Giai đoạn 2\b') {
                            $script:currentJobProgress = 66
                        } elseif ($trimmed -match 'Stage 3\b|Giai đoạn 3\b') {
                            $script:currentJobProgress = 90
                        }
                        $nowTick = [Environment]::TickCount
                        if ($trimmed.Length -gt 0 -and ($nowTick - $lastLogTick -gt 250)) {
                            Write-RightLog "OUT" $trimmed $cWhite
                            $lastLogTick = $nowTick
                        }
                    }
                }
            } else {
                try {
                    while ($proc.StandardOutput.Peek() -ge 0) {
                        $line = $proc.StandardOutput.ReadLine()
                        if ($line) {
                            $trimmed = $line.Trim()
                            if ($trimmed -match '(\d{1,3}\.?\d*)\s*%') {
                                $pVal = [int][double]$matches[1]
                                if ($pVal -ge 0 -and $pVal -le 100) { $script:currentJobProgress = $pVal }
                            }
                            $nowTick = [Environment]::TickCount
                            if ($trimmed.Length -gt 0 -and ($nowTick - $lastLogTick -gt 250)) {
                                Write-RightLog "OUT" $trimmed $cWhite
                                $lastLogTick = $nowTick
                            }
                        }
                    }
                } catch {}
            }


            if ($global:currentProgressMsg) {
                Write-LeftConsoleProgress $global:currentProgressMsg
            } else {
                $sp = Get-NextSpinnerFrame
                $pStr = ""
                if ($script:currentJobProgress -ge 0) { $pStr = " ($($script:currentJobProgress)%)" }
                Set-Activity $sp (T "Đang thực thi $cmdStr$pStr..." "Executing $cmdStr$pStr...") $cYellow
            }
        }

        $script:currentRunningProc = $null
        try { $proc.WaitForExit() } catch {}
        $code = $proc.ExitCode
        $errOutput = ""
        if ($streamer) {
            $outLine = $null
            while ($streamer.OutLines.TryDequeue([ref]$outLine)) {
                if ($outLine) {
                    $trimmed = $outLine.Trim()
                    if ($trimmed.Length -gt 0) { Write-RightLog "OUT" $trimmed $cWhite }
                }
            }
            $errList = [System.Collections.Generic.List[string]]::new()
            $eLine = $null
            while ($streamer.ErrLines.TryDequeue([ref]$eLine)) {
                if ($eLine) { $errList.Add($eLine) }
            }
            $errOutput = [string]::Join("`n", $errList)
        } else {
            try { if ($errTask) { $errOutput = $errTask.Result } } catch {}
        }
        Write-DebugLog "&&" "Process finished: $cmdStr $argStr (Exit code: $code)"
        if ($code -eq 0) {
            Write-RightLog "OUT" (T "THÀNH CÔNG (Mã lỗi 0)" "SUCCESS (Code 0)") $cGreen
            Set-Activity "OK" (T "Hoàn thành $cmdStr" "Finished $cmdStr") $cGreen
        } else {
            Write-RightLog "WARN" (T "KẾT THÚC (Mã lỗi: $code)" "FINISHED (Code: $code)") $cYellow
            if ($errOutput -and $errOutput.Trim().Length -gt 0) {
                $errLines = $errOutput.Trim().Split("`n") | Where-Object { $_.Trim().Length -gt 0 }
                foreach ($el in ($errLines | Select-Object -First 3)) {
                    Write-RightLog "ERR" $el.Trim() $cRed
                }
            }
            Set-Activity "!" (T "Kết thúc có lỗi: $cmdStr ($code)" "Finished with errors: $cmdStr ($code)") $cYellow
        }
        return $code
    } catch {
        $script:currentRunningProc = $null
        try { if ($proc -and -not $proc.HasExited) { $proc.Kill() } } catch {}
        $errMsg = "$_"
        if ($errMsg -match "Access is denied" -or $errMsg -match "denied") {
            Write-LeftConsole (T " [!!] Cần quyền Quản trị viên cho $cmdStr!" " [!!] Admin required for $cmdStr!") $cRed
            Write-RightLog "ERROR" (T "THẤT BẠI: Truy cập bị từ chối (Cần quyền Quản trị viên cho $cmdStr)" "FAILED: Access Denied (Admin rights required for $cmdStr)") $cRed
        } else {
            Write-LeftConsole (T " [-] Thất bại: $cmdStr" " [-] Failed: $cmdStr") $cRed
            Write-RightLog "ERROR" (T "THẤT BẠI: $_" "FAILED: $_") $cRed
        }
        Set-Activity "!" (T "Thất bại ${cmdStr}: $_" "Failed ${cmdStr}: $_") $cRed
        $script:lastTaskCancelled = $true
        return -1
    } finally {
        $script:isTaskRunning = $false
        $script:stopRequested = $false
        $script:currentJobProgress = -1
        if ($proc) {
            try { $proc.Dispose() } catch {}
        }
        if ($global:activeMenu -ne "MAIN" -or $global:currentActionName) {
            Show-LeftBackButton
        }
        Draw-FooterBar
    }
}

# --- [4.3] Step & Spinner Drivers ---
function Invoke-StepCommand($msgInVi, $msgInEn, $cmd, $cmdArgs, $msgOkVi, $msgOkEn) {
    if ($script:stopRequested) { return $false }
    Write-LeftConsoleProgress (T $msgInVi $msgInEn) $cYellow
    $code = Run-And-LogCommand $cmd $cmdArgs
    if ($code -ne 0) {
        Update-LeftConsoleLine (T " [!] Thất bại khi chạy $cmd (Mã lỗi: $code)" " [!] Failed executing $cmd (Code: $code)") $cRed
        return $false
    }
    Update-LeftConsoleLine (T $msgOkVi $msgOkEn) $cGreen
    return $true
}

# ===============================================================================
#  ZONE 5: TUI RENDER ENGINE & COMPONENT DRAWERS
# ===============================================================================
# --- Terminal & Box Geometry Drawers ---
# --- [5.1] Terminal Metrics ---
$script:lastTermCheckTick = 0
$script:termSizeDirty = $true

function Get-TermSize([switch]$force) {
    $now = [Environment]::TickCount
    if (-not $force -and -not $script:termSizeDirty -and ($now - $script:lastTermCheckTick) -ge 0 -and ($now - $script:lastTermCheckTick) -lt 200) {
        return
    }
    try {
        $rawUI = $Host.UI.RawUI
        $realW = $rawUI.WindowSize.Width
        $realH = $rawUI.WindowSize.Height

        # Smart Auto-Correction: best-effort attempt to resize window back to min bounds
        if ($realW -lt 120 -or $realH -lt 28) {
            if (([System.Management.Automation.PSTypeName]'ConsoleMouse').Type) {
                try { [ConsoleMouse]::EnforceMinWindowPixels(1100, 620) } catch {}
            }
            try {
                $rawUI.WindowSize = New-Object System.Management.Automation.Host.Size([math]::Max(120, $realW), [math]::Max(28, $realH))
            } catch {}
            # Re-read ACTUAL dimensions after resize attempt (may or may not have succeeded)
            $realW = $rawUI.WindowSize.Width
            $realH = $rawUI.WindowSize.Height
        }

        # CRITICAL: Always use the ACTUAL window dimensions, never clamp above real size
        # If EnforceMin failed and window is still 60 cols, we must draw for 60 cols, not 100
        $script:termW = $realW
        $script:termH = $realH

        # Sync buffer width to match window width exactly - prevents line wrapping
        if ($rawUI.BufferSize.Width -ne $script:termW) {
            try { $rawUI.BufferSize = New-Object System.Management.Automation.Host.Size($script:termW, [math]::Max($script:termH, $rawUI.BufferSize.Height)) } catch {}
        }
        $script:termSizeDirty = $false
        $script:lastTermCheckTick = $now
    } catch {
        if (-not $script:termW -or $script:termW -lt 20) { $script:termW = 120 }
        if (-not $script:termH -or $script:termH -lt 10) { $script:termH = 30 }
    }
}

# --- [5.2] Box & Dividers ---
function Draw-Box($x, $y, $w, $h, $title = "", $color = $cGreen) {
    Set-CursorPos $x $y
    $topTitle = ""
    $titleLen = 0
    if ($title) {
        $topTitle = "$chrRD $title$color $chrLD"
        $plainTitle = [System.Text.RegularExpressions.Regex]::Replace($title, "\x1b\[[0-9;]*m", "")
        $titleLen = $plainTitle.Length + 4
    }
    $hasBack = ($x -eq 0 -and $y -eq 3 -and ($global:activeMenu -ne "MAIN" -or $global:currentActionName) -and -not (Test-IsAnyTaskRunning))
    if ($hasBack) {
        $isVi = ($global:selectedLang -eq "Vietnamese")
        $backTxt = if ($isVi) { " Trở về " } else { " Back " }
        $btnInner = "$color$chrRD$cYellow$backTxt$cReset$color$chrLD"
        $btnStartX = if ($isVi) { 30 } else { 32 }
        $btnEndX   = 39
        $leadFill  = [math]::Max(0, $btnStartX - 3 - $titleLen)
        $trailFill = [math]::Max(0, ($w - 1) - 1 - $btnEndX)
        $topLine   = "$chrTL" + ($chrLine * 2) + $topTitle + ($chrLine * $leadFill) + $btnInner + ($chrLine * $trailFill) + "$chrTR"
        $script:lastBackBtnRender = "$color|$isVi|False|False"
    } else {
        $topFillLen = [math]::Max(0, $w - 4 - $titleLen)
        $topLine = "$chrTL" + ($chrLine * 2) + $topTitle + ($chrLine * $topFillLen) + "$chrTR"
    }
    Write-Host "$color$topLine$cReset" -NoNewline

    for ($i = 1; $i -lt ($h - 1); $i++) {
        Set-CursorPos $x ($y + $i)
        Write-Host "$color$chrVert$cReset" -NoNewline
        Set-CursorPos ($x + $w - 1) ($y + $i)
        Write-Host "$color$chrVert$cReset" -NoNewline
    }

    Set-CursorPos $x ($y + $h - 1)
    $botLine = "$chrBL" + ($chrLine * ($w - 2)) + "$chrBR"
    Write-Host "$color$botLine$cReset" -NoNewline
}

function Draw-TopBarText() {
    Get-TermSize
    $hBgHover  = "$ESC[48;2;45;48;54m$ESC[38;2;220;220;230m"
    $hBgActive = "$ESC[48;2;75;85;105m$ESC[38;2;255;255;255m"

    $viewStr = if ($global:viewMenuOpen) { "${hBgActive} View ${cReset}" } else { "${cWhite} View ${cReset}" }
    if ($script:currentClickTarget -eq "TOP_VIEW") { $viewStr = "${hBgActive} View ${cReset}" }
    elseif ($script:currentHoverTarget -eq "TOP_VIEW") {
        $viewStr = if ($global:viewMenuOpen) { "${hBgActive} View ${cReset}" } else { "${hBgHover} View ${cReset}" }
    }

    $gitStr = "${cWhite} Github ${cReset}"
    if ($script:currentClickTarget -eq "TOP_GITHUB") { $gitStr = "${hBgActive} Github ${cReset}" }
    elseif ($script:currentHoverTarget -eq "TOP_GITHUB") { $gitStr = "${hBgHover} Github ${cReset}" }

    $logStr = if ($global:logMenuOpen) { "${hBgActive} Log ${cReset}" } else { "${cWhite} Log ${cReset}" }
    if ($script:currentClickTarget -eq "TOP_LOG") { $logStr = "${hBgActive} Log ${cReset}" }
    elseif ($script:currentHoverTarget -eq "TOP_LOG") {
        $logStr = if ($global:logMenuOpen) { "${hBgActive} Log ${cReset}" } else { "${hBgHover} Log ${cReset}" }
    }

    Set-CursorPos 0 0
    Write-Host " $viewStr ${cDim}|${cReset} $gitStr ${cDim}|${cReset} $logStr" -NoNewline

    $exitX = [math]::Max(30, $script:termW - 7)
    $gapSpace = $exitX - 26

    if ($gapSpace -ge 13) {
        $titleStr = "WCaO v$VERSION"
        $titleX = 26 + [int](($gapSpace - $titleStr.Length) / 2)

        $gap1 = [math]::Max(0, $titleX - 26)
        Write-Host (" " * $gap1) -NoNewline
        Write-Host "${cLightCyan}$titleStr${cReset}" -NoNewline

        $gap2 = [math]::Max(0, $exitX - ($titleX + $titleStr.Length))
        Write-Host (" " * $gap2) -NoNewline
    } elseif ($gapSpace -ge 5) {
        $titleStr = "WCaO"
        $titleX = 26 + [int](($gapSpace - $titleStr.Length) / 2)

        $gap1 = [math]::Max(0, $titleX - 26)
        Write-Host (" " * $gap1) -NoNewline
        Write-Host "${cLightCyan}$titleStr${cReset}" -NoNewline

        $gap2 = [math]::Max(0, $exitX - ($titleX + $titleStr.Length))
        Write-Host (" " * $gap2) -NoNewline
    } else {
        $gap = [math]::Max(0, $exitX - 26)
        Write-Host (" " * $gap) -NoNewline
    }

    $exitStr = "${cWhite} Exit ${cReset}"
    if ($script:currentClickTarget -eq "TOP_EXIT") {
        $exitStr = "$ESC[48;2;240;60;60m$ESC[38;2;255;255;255m Exit $cReset"
    } elseif ($script:currentHoverTarget -eq "TOP_EXIT") {
        $exitStr = "$ESC[48;2;160;40;40m$ESC[38;2;255;255;255m Exit $cReset"
    }
    Write-Host "$exitStr" -NoNewline
}

function Draw-TopDivider() {
    Get-TermSize
    if ($global:viewMenuOpen) {
        $hBgHover  = "$ESC[48;2;45;48;54m$ESC[38;2;220;220;230m"
        $hBgActive = "$ESC[48;2;75;85;105m$ESC[38;2;255;255;255m"

        $engStyle = if ($global:selectedLang -eq "English") { "${hBgActive} English ${cReset}" } else { "${cWhite} English ${cReset}" }
        if ($script:currentClickTarget -eq "LANG_ENG") { $engStyle = "${hBgActive} English ${cReset}" }
        elseif ($script:currentHoverTarget -eq "LANG_ENG") {
            $engStyle = if ($global:selectedLang -eq "English") { "${hBgActive} English ${cReset}" } else { "${hBgHover} English ${cReset}" }
        }

        $tVie = if ($global:selectedLang -eq "Vietnamese") { " Tiếng Việt " } else { " Vietnamese " }
        $vieStyle = if ($global:selectedLang -eq "Vietnamese") { "${hBgActive}$tVie${cReset}" } else { "${cWhite}$tVie${cReset}" }
        if ($script:currentClickTarget -eq "LANG_VIE") { $vieStyle = "${hBgActive}$tVie${cReset}" }
        elseif ($script:currentHoverTarget -eq "LANG_VIE") {
            $vieStyle = if ($global:selectedLang -eq "Vietnamese") { "${hBgActive}$tVie${cReset}" } else { "${hBgHover}$tVie${cReset}" }
        }

        $isVi = ($global:selectedLang -eq "Vietnamese")
        $langLabel = if ($isVi) { "  Ngôn ngữ:  " } else { "  Language:  " }
        Set-CursorPos 0 1
        Write-Host (" " * ($script:termW - 1)) -NoNewline
        Set-CursorPos 0 1
        Write-Host "$langLabel$engStyle   $vieStyle" -NoNewline

        Set-CursorPos 0 2
        Write-Host ("$cCyan" + ($chrLine * ($script:termW - 1)) + "$cReset") -NoNewline
    } elseif ($global:logMenuOpen) {
        $hBgHover  = "$ESC[48;2;45;48;54m$ESC[38;2;220;220;230m"
        $hBgActive = "$ESC[48;2;75;85;105m$ESC[38;2;255;255;255m"
        $isVi = ($global:selectedLang -eq "Vietnamese")

        $tOpen   = if ($isVi) { " Mở Log " } else { " Open Log " }
        $tFolder = if ($isVi) { " Mở Thư mục " } else { " Open Folder " }
        $tExport = if ($isVi) { " Xuất Log ra... " } else { " Export Log To... " }
        $logLabel = if ($isVi) { "  Nhật ký:  " } else { "  Log Menu:  " }

        $openLogStyle = "${cWhite}$tOpen${cReset}"
        if ($script:currentClickTarget -eq "LOG_OPEN") { $openLogStyle = "${hBgActive}$tOpen${cReset}" }
        elseif ($script:currentHoverTarget -eq "LOG_OPEN") { $openLogStyle = "${hBgHover}$tOpen${cReset}" }

        $openFolderStyle = "${cWhite}$tFolder${cReset}"
        if ($script:currentClickTarget -eq "LOG_FOLDER") { $openFolderStyle = "${hBgActive}$tFolder${cReset}" }
        elseif ($script:currentHoverTarget -eq "LOG_FOLDER") { $openFolderStyle = "${hBgHover}$tFolder${cReset}" }

        $exportStyle = "${cWhite}$tExport${cReset}"
        if ($script:currentClickTarget -eq "LOG_EXPORT") { $exportStyle = "${hBgActive}$tExport${cReset}" }
        elseif ($script:currentHoverTarget -eq "LOG_EXPORT") { $exportStyle = "${hBgHover}$tExport${cReset}" }

        Set-CursorPos 0 1
        Write-Host (" " * ($script:termW - 1)) -NoNewline
        Set-CursorPos 0 1
        Write-Host "$logLabel$openLogStyle   $openFolderStyle   $exportStyle" -NoNewline

        Set-CursorPos 0 2
        Write-Host ("$cCyan" + ($chrLine * ($script:termW - 1)) + "$cReset") -NoNewline
    } else {
        Set-CursorPos 0 1
        Write-Host ("$cCyan" + ($chrLine * ($script:termW - 1)) + "$cReset") -NoNewline

        Set-CursorPos 0 2
        Write-Host (" " * ($script:termW - 1)) -NoNewline
    }
}

function Draw-TopMenuBar() {
    Draw-TopBarText
    Draw-TopDivider
}

# --- [5.3] Left Pane View ---
function Clear-LeftPane() {
    Get-TermSize
    $maxY = $script:termH - 3
    for ($y = 4; $y -le $maxY; $y++) {
        Set-CursorPos 1 $y
        Write-Host (" " * 41) -NoNewline
    }
}

function Draw-LeftMenuBox() {
    Get-TermSize
    $leftH = [math]::Max(5, $script:termH - 4)
    if ($global:currentActionName) {
        $borderColor = if ($global:currentActionBorderColor) { $global:currentActionBorderColor } else { $cCyan }
        $isVi = ($global:selectedLang -eq "Vietnamese")
        $maxTitleLen = if ($isVi) { 20 } else { 18 }
        $boxTitle = if ($global:currentActionName.Length -gt $maxTitleLen) { $global:currentActionName.Substring(0, $maxTitleLen - 2) + ".." } else { $global:currentActionName }
        Draw-Box 0 3 43 $leftH $boxTitle $borderColor
        return
    }
    $cat = $script:menuCatalog[$global:activeMenu]
    if (-not $cat) { $cat = $script:menuCatalog["MAIN"] }
    $title = if ($global:selectedLang -eq "Vietnamese") { $cat.TitleVi } else { $cat.TitleEn }
    Draw-Box 0 3 43 $leftH $title $cat.BorderColor
}

function Get-FadedItemColor($colStr, $factor) {
    if ($colStr -match "\x1b\[38;2;(\d+);(\d+);(\d+)m") {
        $r = [int]([int]$Matches[1] * $factor)
        $g = [int]([int]$Matches[2] * $factor)
        $b = [int]([int]$Matches[3] * $factor)
        return "$ESC[38;2;$r;$g;${b}m"
    }
    return $colStr
}

function Draw-LeftMenuItems($animate = $true) {
    Get-TermSize
    $leftH = [math]::Max(5, $script:termH - 4)

    # --- Action View: re-render leftConsoleLines instead of menu catalog ---
    if ($global:currentActionName) {
        if (-not (Test-IsAnyTaskRunning) -and $animate) {
            Show-LeftBackButton
        }
        $maxLines = [math]::Max(1, $leftH - 3)
        for ($l = 0; $l -lt [math]::Min($leftConsoleLines.Count, $maxLines); $l++) {
            Set-CursorPos 2 (5 + $l)
            Write-Host $leftConsoleLines[$l] -NoNewline
        }
        return
    }

    $cat = $script:menuCatalog[$global:activeMenu]
    if (-not $cat) { $cat = $script:menuCatalog["MAIN"] }
    $menuItems = $cat.Items
    $baseRGB = $cat.BaseRGB

    if ($global:activeMenu -ne "MAIN" -and $animate) {
        Show-LeftBackButton
    }

    $isVi = ($global:selectedLang -eq "Vietnamese")
    $lineStep = 2
    $currLine = 5
    $subIdx = 0
    $itemCount = $menuItems.Count
    foreach ($item in $menuItems) {
        if ($currLine -lt ($leftH + 2)) {
            Set-CursorPos 2 $currLine
            $itemTarget = "LEFT_ITEM_$subIdx"
            $txtRaw = if ($isVi) { $item.TextVi } else { $item.TextEn }
            $textPadded = $txtRaw.PadRight(39)

            if ($script:currentClickTarget -eq $itemTarget) {
                $colActive = "$ESC[48;2;75;85;105m$ESC[38;2;255;255;255m"
                Write-Host "$colActive$textPadded$cReset" -NoNewline
            } elseif ($script:currentHoverTarget -eq $itemTarget) {
                $colHover = "$ESC[48;2;45;48;54m$ESC[38;2;220;220;230m"
                Write-Host "$colHover$textPadded$cReset" -NoNewline
            } else {
                $isStarred = $txtRaw.StartsWith("*")
                $isExpertItem = $txtRaw.Contains("[i]") -or $item.RequireExpert
                $needsAdminLock = (-not $isAdmin -and $isStarred)
                $needsExpertLock = (-not $global:expertMode -and $isExpertItem)

                if ($needsAdminLock -or $needsExpertLock) {
                    # Locked item due to missing Admin or missing Expert mode: flat dimmed gray
                    $col = "$ESC[38;2;105;110;120m"
                } elseif ($isAdmin) {
                    # Admin mode & unlocked: apply top-to-bottom vertical gradient fading across ALL items
                    $factor = if ($itemCount -gt 1) { 1.0 - (($subIdx / ($itemCount - 1)) * 0.45) } else { 1.0 }
                    if ($baseRGB) {
                        $r = [int]($baseRGB[0] * $factor)
                        $g = [int]($baseRGB[1] * $factor)
                        $b = [int]($baseRGB[2] * $factor)
                        $col = "$ESC[38;2;$r;$g;${b}m"
                    } elseif ($item.Color) {
                        $col = Get-FadedItemColor $item.Color $factor
                    } else {
                        $r = [int](86 * $factor); $g = [int](198 * $factor); $b = [int](234 * $factor)
                        $col = "$ESC[38;2;$r;$g;${b}m"
                    }
                } else {
                    # Non-admin mode & unlocked item: render standard base color
                    $col = if ($item.Color) { $item.Color } elseif ($baseRGB) { "$ESC[38;2;$($baseRGB[0]);$($baseRGB[1]);$($baseRGB[2])m" } else { $cWhite }
                }
                Write-Host "$col$textPadded$cReset" -NoNewline
            }
            if ($animate) {
                Start-Sleep -Milliseconds 8
            }
            if (($currLine + 1) -lt ($leftH + 2)) {
                Set-CursorPos 2 ($currLine + 1)
                Write-Host (" " * 39) -NoNewline
            }
            $currLine += $lineStep
            $subIdx++
        }
    }
    while ($currLine -lt ($leftH + 2)) {
        Set-CursorPos 2 $currLine
        Write-Host (" " * 39) -NoNewline
        $currLine++
    }
}

function Update-IdleActivity() {
    if (-not ($script:currentRunningProc -and -not $script:currentRunningProc.HasExited)) {
        $cat = $script:menuCatalog[$global:activeMenu]
        $titleRaw = if ($global:selectedLang -eq "Vietnamese") { $cat.TitleVi } else { $cat.TitleEn }
        $cleanTitle = $titleRaw -replace '\x1b\[[0-9;]*m', '' -replace '\s*-\s*WCaO.*', ''
        $idleTag = if ($global:selectedLang -eq "Vietnamese") { "Chờ" } else { "Idle" }
        Set-Activity $idleTag $cleanTitle $cDim
    }
}

function Draw-LeftMenu($animate = $false) {
    if ($animate) { Lock-Input 500 }
    Clear-LeftPane
    $script:lastBackBtnRender = $null
    Update-IdleActivity
    Draw-LeftMenuBox
    if ($global:activeMenu -ne "MAIN" -or $global:currentActionName) {
        Show-LeftBackButton -force
    } else {
        Hide-LeftBackButton
    }
    Draw-LeftMenuItems $animate
    Draw-FooterBar
}

# --- [5.4] Right Pane Status & Log ---
function Draw-StatusPane() {
    Get-TermSize
    $rightW = [math]::Max(10, $script:termW - 45)
    $isVi = ($global:selectedLang -eq "Vietnamese")
    $hBgHover  = "$ESC[48;2;45;48;54m$ESC[38;2;220;220;230m"
    $hBgActive = "$ESC[48;2;75;85;105m$ESC[38;2;255;255;255m"

    $admVal = if ($isAdmin) { $(if ($isVi) { " CÓ " } else { " YES " }) } else { $(if ($isVi) { " KHÔNG " } else { " NO " }) }
    $admStat = if ($isAdmin) { "${cGreen}${admVal}${cReset}" } else { "${cRed}${admVal}${cReset}" }
    if ($script:currentClickTarget -eq "STATUS_ADMIN") { $admStat = "${hBgActive}${admVal}${cReset}" }
    elseif ($script:currentHoverTarget -eq "STATUS_ADMIN") { $admStat = "${hBgHover}${admVal}${cReset}" }

    $expVal = if ($global:expertMode) { $(if ($isVi) { " BẬT " } else { " ON " }) } else { $(if ($isVi) { " TẮT " } else { " OFF " }) }
    $expStat = if ($global:expertMode) { "${cRed}${expVal}${cReset}" } else { "${cYellow}${expVal}${cReset}" }
    if ($script:currentClickTarget -eq "STATUS_EXPERT") { $expStat = "${hBgActive}${expVal}${cReset}" }
    elseif ($script:currentHoverTarget -eq "STATUS_EXPERT") { $expStat = "${hBgHover}${expVal}${cReset}" }

    $drvVal = if ($global:targetDrive) { " $global:targetDrive " } else { " C: " }
    $drvStat = "$cYellow${drvVal}${cReset}"
    if ($script:currentClickTarget -eq "STATUS_DRIVE") { $drvStat = "${hBgActive}${drvVal}${cReset}" }
    elseif ($script:currentHoverTarget -eq "STATUS_DRIVE") { $drvStat = "${hBgHover}${drvVal}${cReset}" }

    $driveLabel = if ($isVi) { "Ổ đĩa" } else { "Drive" }
    $adminLabel = if ($isVi) { "Quản trị" } else { "Admin" }
    $expertLabel = if ($isVi) { "Chuyên gia" } else { "Expert Mode" }

    $plainLen = 2 + $driveLabel.Length + 2 + $drvVal.Length + 5 + 1 + $adminLabel.Length + 2 + $admVal.Length + 5 + 3 + $expertLabel.Length + 2 + $expVal.Length
    $padLen = [math]::Max(0, $rightW - 2 - $plainLen)

    Set-CursorPos 45 4
    if ($rightW -ge ($plainLen + 2)) {
        Write-Host " ${driveLabel}: $drvStat  |  $cYellow*$cReset${adminLabel}: $admStat  |  $cCyan[i]$cReset${expertLabel}: $expStat$(' ' * $padLen)" -NoNewline
    } else {
        $shortText = " ${driveLabel}: $drvStat"
        $sPad = [math]::Max(0, $rightW - 14)
        Write-Host "$shortText$(' ' * $sPad)" -NoNewline
    }

    Draw-ActivityLine
    Draw-Breadcrumb
}

function Draw-RightLogPane() {
    Get-TermSize
        $rightW = [math]::Max(10, $script:termW - 45)
    $logBoxH = [math]::Max(3, $script:termH - 10)
    $viewHeight = [math]::Max(1, $logBoxH - 2)
    $contentW = [math]::Max(1, $rightW - 4)
    $scrollCol = $script:termW - 2
    $startY = 10
    $endY = $startY + $viewHeight - 1

    $formattedList = Get-FormattedLogLines
    $totalCount = $formattedList.Count

    if ($totalCount -le $viewHeight) {
        $startIndex = 0
        $global:logScrollOffset = 0
    } else {
        $maxScroll = $totalCount - $viewHeight
        if ($global:logScrollOffset -gt $maxScroll) { $global:logScrollOffset = $maxScroll }
        if ($global:logScrollOffset -lt 0) { $global:logScrollOffset = 0 }
        $startIndex = $totalCount - $viewHeight - $global:logScrollOffset
    }

    for ($i = 0; $i -lt $viewHeight; $i++) {
        Set-CursorPos 46 ($startY + $i)
        $idx = $startIndex + $i
        if ($idx -ge 0 -and $idx -lt $totalCount) {
            $item = $formattedList[$idx]
            $txt = $item.Text.PadRight($contentW)
            $fadedCol = Get-FadedColor $item.ColorName $i $viewHeight
            Write-Host "$fadedCol$txt$cReset" -NoNewline
        } else {
            Write-Host (" " * $contentW) -NoNewline
        }
    }

    $isScrollHover = ($script:currentHoverTarget -eq "LOG_SCROLL" -or $script:isDraggingLogScroll)
    $trackCol = $cGreen
    $thumbCol = if ($isScrollHover) { "$ESC[48;2;50;180;90m$ESC[38;2;255;255;255m" } else { $cGreen }

    if ($totalCount -gt $viewHeight) {
        $maxScroll = $totalCount - $viewHeight
        $thumbPos = $endY - [math]::Round(($global:logScrollOffset / $maxScroll) * ($viewHeight - 1))
        for ($r = $startY; $r -le $endY; $r++) {
            Set-CursorPos $scrollCol $r
            if ($r -eq $thumbPos) {
                Write-Host "$thumbCol$chrThumb$cReset" -NoNewline
            } else {
                Write-Host "$trackCol$chrVert$cReset" -NoNewline
            }
        }
    } else {
        for ($r = $startY; $r -le $endY; $r++) {
            Set-CursorPos $scrollCol $r
            Write-Host "$trackCol$chrVert$cReset" -NoNewline
        }
    }
}

function Draw-FooterBar() {
    Get-TermSize
    $y = $script:termH - 1
    Set-CursorPos 0 $y
    Write-Host (" " * ($script:termW - 1)) -NoNewline
    Set-CursorPos 1 $y
    $isVi = ($global:selectedLang -eq "Vietnamese")
    $selPrefix = if ($isVi) { "Chọn:" } else { "Select:" }
    $backStr   = if ($isVi) { "Trở về: ESC" } else { "Back: ESC" }
    $scrollStr = if ($isVi) { "Cuộn: Lăn chuột" } else { "Scroll: Mouse Wheel" }

    $isRunning = Test-IsAnyTaskRunning

    $numRange = $null
    if (-not $isRunning -and -not $global:currentActionName -and -not $global:currentActionBorderColor) {
        $numRange = switch ($global:activeMenu) {
            "MAIN"         { "1-6" }
            "SYS_OPT"      { "1-8" }
            "ADV_TOOLS"    { "1-6" }
            "SYS_UTIL"     { "1-6" }
            default        { $null }
        }
    }

    if ($isRunning) {
        Write-Host "${cDim}$scrollStr${cReset}" -NoNewline
    } elseif ($numRange) {
        Write-Host "${cDim}$selPrefix $numRange  |  $backStr  |  $scrollStr${cReset}" -NoNewline
    } else {
        Write-Host "${cDim}$backStr  |  $scrollStr${cReset}" -NoNewline
    }
}

# --- [5.5] Full Layout Master ---
function Draw-FullLayout($animate = $true) {
    if ($script:isRedrawing) { return }
    $script:isRedrawing = $true
    try {
        Get-TermSize
        try { [Console]::Clear() } catch {}
        $script:lastBackBtnRender = $null

        $delay = if ($animate) { 20 } else { 0 }

        # 1. Thanh trên top trước (Top bar text)
        Draw-TopBarText
        Invoke-StaggeredRevealDelay $delay

        # 2. Rồi thanh ngăn cách (Divider line)
        Draw-TopDivider
        Invoke-StaggeredRevealDelay $delay

            $rightW = [math]::Max(10, $script:termW - 45)
        $leftH = [math]::Max(5, $script:termH - 4)
        $logBoxH = [math]::Max(3, $script:termH - 10)
        $isVi = ($global:selectedLang -eq "Vietnamese")

        $statusTitle = if ($isVi) { "TRẠNG THÁI HỆ THỐNG & CHI TIẾT" } else { "SYSTEM STATUS & DETAILS" }
        $logTitle = if ($isVi) { "${cYellow}NHẬT KÝ${cGreen} HOẠT ĐỘNG" } else { "${cYellow}INPUT${cGreen} / OUTPUT LOG" }

        # 3. Rồi bảng status (Frame of Status Box)
        Draw-Box 44 3 $rightW 6 $statusTitle $cYellow
        Invoke-StaggeredRevealDelay $delay

        # 4. Rồi bảng main (Frame of Left/Main Box)
        Draw-LeftMenuBox
        Invoke-StaggeredRevealDelay $delay

        # 5. Rồi bảng log (Frame of Log Box)
        Draw-Box 44 9 $rightW $logBoxH $logTitle $cGreen
        Invoke-StaggeredRevealDelay $delay

        # 6. Rồi nội dung bảng status
        Update-IdleActivity
        Draw-StatusPane
        Invoke-StaggeredRevealDelay $delay

        # 7. Rồi nội dung bảng main
        Draw-LeftMenuItems $animate
        Invoke-StaggeredRevealDelay $delay

        # 8. Rồi nội dung của bảng log
        Draw-RightLogPane
        Draw-FooterBar
        Set-CursorPos 0 0

        if ($animate -and (([System.Management.Automation.PSTypeName]'ConsoleMouse').Type)) {
            try {
                $hIn = [ConsoleMouse]::GetStdHandle([ConsoleMouse]::STD_INPUT_HANDLE)
                [ConsoleMouse]::FlushConsoleInputBuffer($hIn) | Out-Null
            } catch {}
        }
    } finally {
        $script:isRedrawing = $false
    }
}

# -------------------------------------------------------------------------------
#  LEFT CONSOLE OUTPUT & SPINNER ANIMATION ENGINE
# -------------------------------------------------------------------------------
# --- [5.6] Action Console ---
function Redraw-CurrentActionBox() {
    if (-not $global:currentActionBorderColor) { return }
    Get-TermSize
    $leftH = [math]::Max(5, $script:termH - 4)
    $isVi = ($global:selectedLang -eq "Vietnamese")
    $actTitle = if ($global:currentActionTitleVi -and $global:currentActionTitleEn) {
        if ($isVi) { $global:currentActionTitleVi } else { $global:currentActionTitleEn }
    } elseif ($global:currentActionName) {
        $global:currentActionName
    } else {
        ""
    }
    if ($actTitle) {
        $global:currentActionName = $actTitle
        $maxTitleLen = if ($isVi) { 20 } else { 18 }
        $boxTitle = if ($actTitle.Length -gt $maxTitleLen) { $actTitle.Substring(0, $maxTitleLen - 2) + ".." } else { $actTitle }
        Draw-Box 0 3 43 $leftH $boxTitle $global:currentActionBorderColor
        Show-LeftBackButton
        Set-Activity "RUN" (T "Đang chạy: $actTitle" "Running: $actTitle") $cYellow
    }
}

function Start-ActionView($title, $borderColor = $cCyan, $titleEn = $null) {
    $script:stopRequested = $false
    $script:lastTaskCancelled = $false
    $script:isTaskRunning = $false
    $leftConsoleLines.Clear()
    Clear-LeftPane
    Get-TermSize
    $leftH = [math]::Max(5, $script:termH - 4)

    $cleanTitle = $title -replace '^EXECUTION:\s*', ''
    $cleanEn = if ($titleEn) { $titleEn -replace '^EXECUTION:\s*', '' } else { $cleanTitle }
    $global:currentActionTitleVi = $cleanTitle
    $global:currentActionTitleEn = $cleanEn
    $global:currentActionBorderColor = $borderColor
    $global:currentProgressMsg = $null

    $isVi = ($global:selectedLang -eq "Vietnamese")
    $displayTitle = if ($isVi) { $global:currentActionTitleVi } else { $global:currentActionTitleEn }
    $global:currentActionName = $displayTitle
    $maxTitleLen = if ($isVi) { 20 } else { 18 }
    $boxTitle = if ($displayTitle.Length -gt $maxTitleLen) { $displayTitle.Substring(0, $maxTitleLen - 2) + ".." } else { $displayTitle }
    Draw-Box 0 3 43 $leftH $boxTitle $borderColor

    Set-Activity "RUN" (T "Đang chạy: $displayTitle" "Running: $displayTitle") $cYellow
    Draw-StatusPane
    Draw-FooterBar
}

function Add-LeftConsoleLineRaw($formattedLine) {
    Get-TermSize
    # Clamp visible plain text length strictly to 38 characters to protect border column 40
    $plain = [System.Text.RegularExpressions.Regex]::Replace($formattedLine, "\x1b\[[0-9;]*m", "")
    if ($plain.Length -gt 38) {
        $ansiMatch = [System.Text.RegularExpressions.Regex]::Match($formattedLine, "^(\x1b\[[0-9;]*m)+")
        $prefix = if ($ansiMatch.Success) { $ansiMatch.Value } else { "" }
        $formattedLine = "$prefix$($plain.Substring(0, 35))...$cReset"
    }
    $leftConsoleLines.Add($formattedLine)
    $leftH = [math]::Max(5, $script:termH - 4)
    $maxLines = [math]::Max(10, $leftH - 3)
    $didScroll = $false
    if ($leftConsoleLines.Count -gt $maxLines) {
        $leftConsoleLines.RemoveAt(0)
        $didScroll = $true
    }

    if ($didScroll) {
        for ($i = 0; $i -lt $leftConsoleLines.Count; $i++) {
            $targetY = 5 + $i
            Set-CursorPos 2 $targetY
            $p = [System.Text.RegularExpressions.Regex]::Replace($leftConsoleLines[$i], "\x1b\[[0-9;]*m", "")
            $pad = " " * [math]::Max(0, 38 - $p.Length)
            Write-Host "$($leftConsoleLines[$i])$pad" -NoNewline
        }
    } else {
        $newIdx = $leftConsoleLines.Count - 1
        $targetY = 5 + $newIdx
        Set-CursorPos 2 $targetY
        $p = [System.Text.RegularExpressions.Regex]::Replace($formattedLine, "\x1b\[[0-9;]*m", "")
        $pad = " " * [math]::Max(0, 38 - $p.Length)
        Write-Host "$formattedLine$pad" -NoNewline
    }
}

function Write-LeftConsole($msg, $color = $cWhite) {
    Get-TermSize
    $maxW = 38
    if ([string]::IsNullOrEmpty($msg)) {
        Add-LeftConsoleLineRaw "$color$cReset"
        return
    }

    $leadSpace = ""
    if ($msg -match '^(\s+)') {
        $leadSpace = $matches[1]
    }

    $plainMsg = [System.Text.RegularExpressions.Regex]::Replace($msg, "\x1b\[[0-9;]*m", "")
    if ($plainMsg.Length -le $maxW) {
        Add-LeftConsoleLineRaw "$color$msg$cReset"
    } else {
        $cleanMsg = $msg.Trim()
        $rawWords = $cleanMsg -split "\s+"
        $currStr = ""
        $firstLine = $true

        $indent = $leadSpace
        $plainClean = [System.Text.RegularExpressions.Regex]::Replace($cleanMsg, "\x1b\[[0-9;]*m", "")
        if ($plainClean -match '^(\[[^\]]+\]|\(\S+\)|[+\-*!~>]+)') {
            $indent = " " * ([math]::Max(2, $leadSpace.Length + $matches[1].Length + 1))
        }

        # Pre-break any long word without spaces that exceeds available width (e.g. Device IDs)
        $words = @()
        $avail = [math]::Max(5, $maxW - $indent.Length)
        foreach ($rw in $rawWords) {
            $pW = [System.Text.RegularExpressions.Regex]::Replace($rw, "\x1b\[[0-9;]*m", "")
            if ($pW.Length -gt $avail) {
                $rem = $rw
                while ($rem.Length -gt $avail) {
                    $words += $rem.Substring(0, $avail)
                    $rem = $rem.Substring($avail)
                }
                if ($rem.Length -gt 0) { $words += $rem }
            } else {
                $words += $rw
            }
        }

        foreach ($w in $words) {
            if ([string]::IsNullOrEmpty($w)) { continue }
            $plainCurr = [System.Text.RegularExpressions.Regex]::Replace($currStr, "\x1b\[[0-9;]*m", "")
            $plainW = [System.Text.RegularExpressions.Regex]::Replace($w, "\x1b\[[0-9;]*m", "")
            if ($firstLine) {
                if ($currStr.Length -eq 0) {
                    $currStr = $leadSpace + $w
                } elseif (($plainCurr.Length + 1 + $plainW.Length) -le $maxW) {
                    $currStr += " " + $w
                } else {
                    Add-LeftConsoleLineRaw "$color$currStr$cReset"
                    $firstLine = $false
                    $currStr = $indent + $w
                }
            } else {
                if ($currStr.Length -eq 0) {
                    $currStr = $indent + $w
                } elseif (($plainCurr.Length + 1 + $plainW.Length) -le $maxW) {
                    $currStr += " " + $w
                } else {
                    Add-LeftConsoleLineRaw "$color$currStr$cReset"
                    $currStr = $indent + $w
                }
            }
        }
        if ($currStr.Length -gt 0) {
            Add-LeftConsoleLineRaw "$color$currStr$cReset"
        }
    }
}

function Update-LeftConsoleLine($msg, $color = $cWhite) {
    $global:currentProgressMsg = $null
    Get-TermSize
    if ($msg.Length -gt 38) {
        $msg = $msg.Substring(0, 35) + "..."
    }
    if ($leftConsoleLines.Count -gt 0) {
        $lastIdx = $leftConsoleLines.Count - 1
        $leftConsoleLines[$lastIdx] = "$color$msg$cReset"
        $targetY = 5 + $lastIdx
        Set-CursorPos 2 $targetY
        $pad = [math]::Max(0, 39 - $msg.Length)
        Write-Host "$color$msg$cReset$(' ' * $pad)" -NoNewline
    } else {
        Add-LeftConsoleLineRaw "$color$msg$cReset"
    }
}

function Write-LeftConsoleProgress($msg, $color = $cYellow) {
    if ($script:stopRequested) { return }
    $sp = Get-NextSpinnerFrame
    $pStr = ""
    if ($script:currentJobProgress -ge 0) {
        $pStr = " ($($script:currentJobProgress)%)"
    }
    $cleanMsg = $msg
    $maxMsgLen = [math]::Max(5, 33 - $pStr.Length)
    if ($cleanMsg.Length -gt $maxMsgLen) {
        $cleanMsg = $cleanMsg.Substring(0, [math]::Max(2, $maxMsgLen - 3)) + "..."
    }
    $fullClean = "$cleanMsg$pStr"
    if ($global:currentProgressMsg -eq $msg -and $leftConsoleLines.Count -gt 0) {
        $lastIdx = $leftConsoleLines.Count - 1
        $formattedMsg = "$color [$sp] $fullClean$cReset"
        $leftConsoleLines[$lastIdx] = $formattedMsg
        $targetY = 5 + $lastIdx
        Set-CursorPos 2 $targetY
        $pad = " " * [math]::Max(0, 38 - (" [$sp] $fullClean").Length)
        Write-Host "$color [$sp] $fullClean$cReset$pad" -NoNewline
    } else {
        $global:currentProgressMsg = $msg
        Write-LeftConsole " [$sp] $fullClean" $color
    }
    $actName = if ($global:currentActionName) { $global:currentActionName } else { $msg }
    Set-Activity $sp (T "Đang chạy: $actName$pStr" "Running: $actName$pStr") $color
}

# --- [5.7] Spinners & Animations ---
function Get-NextSpinnerFrame() {
    $sp = $global:spinnerChars[$global:spinnerIdx % $global:spinnerChars.Count]
    $global:spinnerIdx++
    return $sp
}

function Invoke-ActionWithSpinner($actionBlock, $msg, $color = $cYellow, $minFrames = 8) {
    $script:stopRequested = $false
    $script:isTaskRunning = $true
    Hide-LeftBackButton
    Draw-FooterBar
    Write-LeftConsoleProgress $msg $color
    $psObj = [powershell]::Create()
    $null = $psObj.AddScript($actionBlock.ToString())
    $asyncResult = $psObj.BeginInvoke()
    $animFrames = 0

    try {
        while (-not $asyncResult.IsCompleted -or $animFrames -lt $minFrames) {
            Process-ConsoleEvents
            if ($script:stopRequested) {
                try { $psObj.Stop() } catch {}
                try { $psObj.Dispose() } catch {}
                $script:stopRequested = $false
                $script:lastTaskCancelled = $true
                Write-LeftConsole (T " [-] Tác vụ đã bị người dùng hủy." " [-] Task cancelled by user.") $cRed
                Write-RightLog "WARN" (T "Tác vụ đã bị người dùng hủy: $msg" "Task cancelled by user: $msg") $cYellow
                Set-Activity "!" (T "Đã hủy tác vụ" "Task cancelled") $cYellow
                return $null
            }
            Start-Sleep -Milliseconds 40
            $animFrames++
            Write-LeftConsoleProgress $msg $color
        }

        $res = $null
        try {
            $res = $psObj.EndInvoke($asyncResult)
        } catch {
            Write-RightLog "ERROR" (T "Lỗi thao tác ($msg): $_" "Action error ($msg): $_") $cRed
        }
        return $res
    } finally {
        $script:isTaskRunning = $false
        $script:stopRequested = $false
        try { $psObj.Dispose() } catch {}
        if ($global:activeMenu -ne "MAIN" -or $global:currentActionName) {
            Show-LeftBackButton
        }
        Draw-FooterBar
    }
}

function Invoke-ScriptWithSpinner($scriptBlock, $msg, $color = $cYellow) {
    $res = Invoke-ActionWithSpinner $scriptBlock $msg $color 1
    return ($res -ne $null)
}

function Invoke-StaggeredRevealDelay($delayMs = 20) {
    if ($delayMs -gt 0) { Start-Sleep -Milliseconds $delayMs }
}

function Wait-LeftReturn() {
    $script:isTaskRunning = $false
    $script:stopRequested = $false
    $script:lastBackBtnRender = $null
    Show-LeftBackButton -force
    Draw-FooterBar

    Start-Sleep -Milliseconds 250
    if (-not (([System.Management.Automation.PSTypeName]'ConsoleMouse').Type)) { return }
    $hInput = [ConsoleMouse]::GetStdHandle([ConsoleMouse]::STD_INPUT_HANDLE)
    try { [ConsoleMouse]::FlushConsoleInputBuffer($hInput) | Out-Null } catch {}

    $records = New-Object ConsoleMouse+INPUT_RECORD[] 64
    $waiting = $true
    while ($waiting) {
        Start-Sleep -Milliseconds 50
        [uint32]$eventsCount = 0
        [ConsoleMouse]::GetNumberOfConsoleInputEvents($hInput, [ref]$eventsCount) | Out-Null
        if ($eventsCount -le 0) { continue }

        [uint32]$toRead = [math]::Min([uint32]$records.Length, $eventsCount)
        [uint32]$read = 0
        [ConsoleMouse]::ReadConsoleInput($hInput, $records, $toRead, [ref]$read) | Out-Null

        for ($i = 0; $i -lt $read; $i++) {
            $rec = $records[$i]
            if ($rec.EventType -eq 4) {
                $script:termSizeDirty = $true
                Get-TermSize -force
                Draw-FullLayout
                Clear-LeftPane
                for ($l = 0; $l -lt $leftConsoleLines.Count; $l++) {
                    Set-CursorPos 2 (5 + $l)
                    Write-Host $leftConsoleLines[$l] -NoNewline
                }
                Show-LeftBackButton
                continue
            }

            if ($rec.EventType -eq 1 -and $rec.KeyEvent.bKeyDown -ne 0) {
                $vk = $rec.KeyEvent.wVirtualKeyCode
                if ($vk -in @(0x1B, 0x08, 0x0D, 0x20)) {
                    $waiting = $false
                    break
                }
            }

            if ($rec.EventType -eq 2) {
                $mEvent = $rec.MouseEvent
                if (Process-LogScrollEvents $mEvent) { continue }

                $posX = $mEvent.dwMousePosition.X
                $posY = $mEvent.dwMousePosition.Y
                $isLeftDown = ($mEvent.dwButtonState -band 1) -ne 0

                $target = Get-HoverTarget $posX $posY
                if ($target -ne $script:currentHoverTarget) {
                    $oldTarget = $script:currentHoverTarget
                    $script:currentHoverTarget = $target
                    if ($target.StartsWith("TOP_") -or $oldTarget.StartsWith("TOP_") -or $target.StartsWith("LANG_") -or $oldTarget.StartsWith("LANG_") -or $target.StartsWith("LOG_") -or $oldTarget.StartsWith("LOG_")) {
                        Draw-TopMenuBar
                    }
                    if ($target.StartsWith("STATUS_") -or $oldTarget.StartsWith("STATUS_") -or $target -eq "ACTIVITY_STOP" -or $oldTarget -eq "ACTIVITY_STOP" -or $target.StartsWith("BREADCRUMB_") -or $oldTarget.StartsWith("BREADCRUMB_")) {
                        Draw-StatusPane
                    }
                    if ($target -eq "LOG_SCROLL" -or $oldTarget -eq "LOG_SCROLL") {
                        Draw-RightLogPane
                    }
                    if ($target -eq "BACK_BTN" -or $oldTarget -eq "BACK_BTN") {
                        if ($global:activeMenu -ne "MAIN" -or $global:currentActionName) {
                            Show-LeftBackButton $target
                        } else {
                            Hide-LeftBackButton
                        }
                    }
                }

                if ($isLeftDown -and -not $script:wasLeftDown) {
                    $script:wasLeftDown = $true
                    if ($target -eq "BACK_BTN") {
                        $waiting = $false
                        break
                    }
                    $res = Handle-GlobalClick $posX $posY
                    if ($res -eq "BREADCRUMB_NAV") {
                        $waiting = $false
                        break
                    }
                } elseif (-not $isLeftDown) {
                    $script:wasLeftDown = $false
                }
            }
        }
    }
    $leftConsoleLines.Clear()
    $global:currentActionName = $null
    $global:currentActionBorderColor = $null
    Update-IdleActivity
    Draw-LeftMenu $false
    Draw-StatusPane
}

# -------------------------------------------------------------------------------
#  REUSABLE INTERACTIVE LIST ENGINE (Navigation & Rendering Component)
# -------------------------------------------------------------------------------
# --- [5.8] Interactive List ---
function Get-HorizSlice([string]$content, [int]$offset, [int]$viewWidth = 38) {
    if (-not $content) { return (" " * $viewWidth) }
    $len = $content.Length
    if ($len -le $viewWidth) {
        return $content.PadRight($viewWidth)
    }
    $maxOffset = [math]::Max(0, $len - $viewWidth)
    $clampedOffset = [math]::Max(0, [math]::Min($maxOffset, $offset))
    
    if ($clampedOffset -eq 0) {
        $sliceLen = $viewWidth - 2
        return $content.Substring(0, $sliceLen) + ".."
    } elseif ($clampedOffset -ge $maxOffset) {
        $sliceLen = $viewWidth - 2
        return ".." + $content.Substring($len - $sliceLen)
    } else {
        $sliceLen = $viewWidth - 4
        return ".." + $content.Substring($clampedOffset + 2, $sliceLen) + ".."
    }
}

function Handle-ListNavigationKey($vk, [ref]$vertOffset, [ref]$horizOffset, $maxVScroll, $maxHScroll, $pageSize) {
    $oldV = $vertOffset.Value
    $oldH = $horizOffset.Value

    switch ($vk) {
        0x26 { $vertOffset.Value = [math]::Max(0, $vertOffset.Value - 1) }                                  # Up
        0x28 { $vertOffset.Value = [math]::Min($maxVScroll, $vertOffset.Value + 1) }                        # Down
        0x21 { $vertOffset.Value = [math]::Max(0, $vertOffset.Value - $pageSize) }                         # PageUp
        0x22 { $vertOffset.Value = [math]::Min($maxVScroll, $vertOffset.Value + $pageSize) }                 # PageDown
        0x24 { $vertOffset.Value = 0; $horizOffset.Value = 0 }                                              # Home
        0x23 { $vertOffset.Value = $maxVScroll; if ($maxHScroll -gt 0) { $horizOffset.Value = $maxHScroll } } # End
        0x25 { if ($maxHScroll -gt 0) { $horizOffset.Value = [math]::Max(0, $horizOffset.Value - 4) } }     # Left
        0x27 { if ($maxHScroll -gt 0) { $horizOffset.Value = [math]::Min($maxHScroll, $horizOffset.Value + 4) } } # Right
        default { return $false }
    }
    return ($vertOffset.Value -ne $oldV -or $horizOffset.Value -ne $oldH)
}

function Handle-ListMouseWheel($delta, $isOverHScroll, [ref]$vertOffset, [ref]$horizOffset, $maxVScroll, $maxHScroll, $vStep = 1, $hStep = 4) {
    $oldV = $vertOffset.Value
    $oldH = $horizOffset.Value

    if ($isOverHScroll -and $maxHScroll -gt 0) {
        if ($delta -gt 0) {
            $horizOffset.Value = [math]::Max(0, $horizOffset.Value - $hStep)
        } else {
            $horizOffset.Value = [math]::Min($maxHScroll, $horizOffset.Value + $hStep)
        }
    } else {
        if ($delta -gt 0) {
            $vertOffset.Value = [math]::Max(0, $vertOffset.Value - $vStep)
        } else {
            $vertOffset.Value = [math]::Min($maxVScroll, $vertOffset.Value + $vStep)
        }
    }
    return ($vertOffset.Value -ne $oldV -or $horizOffset.Value -ne $oldH)
}

function Render-InteractiveList($cfg) {
    $items = $cfg.Items
    $vOffset = $cfg.VertOffset
    $hOffset = $cfg.HorizOffset
    $maxH = $cfg.MaxHorizOffset
    $width = if ($cfg.Width) { $cfg.Width } else { 38 }
    $pageSize = $cfg.Height
    $startY = if ($cfg.StartY) { $cfg.StartY } else { 5 }
    $startX = if ($cfg.StartX) { $cfg.StartX } else { 2 }
    $labelWidth = if ($cfg.LabelWidth) { $cfg.LabelWidth } else { 12 }

    for ($i = 0; $i -lt $pageSize; $i++) {
        $dataIdx = $vOffset + $i
        $rowY = $startY + $i
        Set-CursorPos $startX $rowY

        if ($items -and $dataIdx -lt $items.Count) {
            $item = $items[$dataIdx]
            $isHover = ($cfg.HoverIndex -eq $dataIdx -or $cfg.HoverRowIdx -eq $dataIdx)
            $isFlash = ($cfg.FlashIndex -eq $dataIdx)

            if ($cfg.Mode -eq "KEY_VALUE") {
                $lbl = $item.Label.PadRight($labelWidth)
                $val = [string]$item.Value
                $valCols = $width - $labelWidth - 2
                $valSlice = Get-HorizSlice $val $hOffset $valCols
                $fullRow = "${lbl}: $valSlice"

                if ($isFlash) {
                    Write-Host ("$ESC[48;2;30;85;45m$ESC[38;2;140;255;160m" + $fullRow.PadRight($width) + "$cReset") -NoNewline
                } elseif ($isHover) {
                    Write-Host ("$ESC[48;2;45;50;62m$ESC[38;2;255;255;255m" + $fullRow.PadRight($width) + "$cReset") -NoNewline
                } else {
                    $lblClr = if ($item.LabelColor) { $item.LabelColor } else { $cLightCyan }
                    $valClr = if ($item.ValColor) { $item.ValColor } else { $cWhite }
                    Write-Host "$lblClr${lbl}: $cReset$valClr$valSlice$cReset" -NoNewline
                }
            } elseif ($cfg.Mode -eq "TABLE_ROW" -and $cfg.RowFormatter) {
                & $cfg.RowFormatter $item $hOffset $isHover $isFlash $width
            }
        } else {
            Write-Host (" " * $width) -NoNewline
        }
    }

    # Horizontal Scrollbar Render
    if ($cfg.ContainsKey('RenderHScroll') -and $cfg.RenderHScroll) {
        $hScrollY = $cfg.HScrollY
        Set-CursorPos $startX $hScrollY
        if ($cfg.CustomHScrollBar) {
            Write-Host $cfg.CustomHScrollBar -NoNewline
        } elseif ($maxH -gt 0) {
            $trackW = if ($cfg.TrackWidth) { $cfg.TrackWidth } else { $width - 2 }
            $thumbW = 2
            $travel = $trackW - $thumbW
            $thumbPos = [math]::Round(($hOffset / $maxH) * $travel)
            $thumbPos = [math]::Max(0, [math]::Min($travel, $thumbPos))

            $isHoverThumb = ($cfg.IsHoverThumb -or $cfg.IsDraggingHScroll)
            $trackCol = $cDim
            $thumbCol = if ($isHoverThumb) { "$ESC[38;2;255;255;255m" } else { if ($cfg.ThumbColor) { $cfg.ThumbColor } else { $cLightCyan } }

            $leftTrack = $trackCol + ($chrLine * $thumbPos) + $cReset
            $thumbBlock = $thumbCol + ($chrHThumb * 2) + $cReset
            $rightTrack = $trackCol + ($chrLine * ($travel - $thumbPos)) + $cReset
            $extraWidget = if ($cfg.HScrollRightWidget) { $cfg.HScrollRightWidget } else { "" }

            $hScrollBar = " " + $leftTrack + $thumbBlock + $rightTrack + " " + $extraWidget
            Write-Host $hScrollBar -NoNewline
        } else {
            Write-Host (" " * $width) -NoNewline
        }
    }
}

# ===============================================================================
#  ZONE 6: NAVIGATION, EVENT ROUTING & INPUT CONTROLLERS
# ===============================================================================
# --- Activity Status & Dynamic Back Button ---
# --- [6.1] Activity & Back Button ---
function Set-Activity($tag, $msg, $color) {
    if (-not $color) { $color = $cDim }
    $global:activityStatus = "[$tag] $msg"
    $global:activityColor = $color
    Draw-ActivityLine
}

function Test-IsAnyTaskRunning() {
    try { if ($script:currentRunningProc -and -not $script:currentRunningProc.HasExited) { return $true } } catch {}
    if ($script:isTaskRunning) { return $true }
    return $false
}

function Hide-LeftBackButton() {
    if ($script:lastBackBtnRender -eq "HIDDEN") { return }
    $boxBorderCol = if ($global:currentActionBorderColor) { $global:currentActionBorderColor } else {
        if ($script:menuCatalog -and $script:menuCatalog.ContainsKey($global:activeMenu)) { $script:menuCatalog[$global:activeMenu].BorderColor } else { $cCyan }
    }
    Set-CursorPos 30 3
    Write-Host ($boxBorderCol + ($chrLine * 12) + $cReset) -NoNewline
    $script:lastBackBtnRender = "HIDDEN"
    Set-CursorPos 0 0
}

function Show-LeftBackButton($target = $null, [switch]$force) {
    if (Test-IsAnyTaskRunning) {
        Hide-LeftBackButton
        return
    }
    if ($global:activeMenu -eq "MAIN" -and -not $global:currentActionName) {
        Hide-LeftBackButton
        return
    }
    $boxBorderCol = if ($global:currentActionBorderColor) { $global:currentActionBorderColor } else {
        if ($script:menuCatalog -and $script:menuCatalog.ContainsKey($global:activeMenu)) { $script:menuCatalog[$global:activeMenu].BorderColor } else { $cCyan }
    }
    $isVi = ($global:selectedLang -eq "Vietnamese")
    $backTxt = if ($isVi) { " Trở về " } else { " Back " }

    $isClick = ($target -eq "ACTIVE" -or $script:currentClickTarget -eq "BACK_BTN")
    $isHover = ($target -eq "HOVER" -or $script:currentHoverTarget -eq "BACK_BTN")

    $stateKey = "$boxBorderCol|$isVi|$isClick|$isHover"
    if (-not $force -and $script:lastBackBtnRender -eq $stateKey) {
        return
    }

    $btnStyle = if ($isClick) {
        "$ESC[48;2;75;85;105m$ESC[38;2;255;255;255m"
    } elseif ($isHover) {
        "$ESC[48;2;45;48;54m$ESC[38;2;220;220;230m"
    } else {
        $cYellow
    }

    $btnStartX = if ($isVi) { 30 } else { 32 }
    $btnInner = "$boxBorderCol$chrRD$btnStyle$backTxt$cReset$boxBorderCol$chrLD"

    Set-CursorPos $btnStartX 3
    Write-Host $btnInner -NoNewline
    $script:lastBackBtnRender = $stateKey
    Set-CursorPos 0 0
}
function Draw-ActivityLine() {
    Get-TermSize
    $rightW = [math]::Max(10, $script:termW - 45)
    $isVi = ($global:selectedLang -eq "Vietnamese")
    $actLabel = if ($isVi) { " Hoạt động: " } else { " Activity: " }
    $actText = $global:activityStatus

    $isProcRunning = Test-IsAnyTaskRunning
    $stopTag = if ($isVi) { "[HỦY]" } else { "[CANCEL]" }

    if ($isProcRunning) {
        $maxLen = [math]::Max(10, $rightW - 16 - $stopTag.Length)
        if ($actText.Length -gt $maxLen) { $actText = $actText.Substring(0, $maxLen - 3) + "..." }

        $stopStyle = "${cRed}${stopTag}${cReset}"
        if ($script:currentClickTarget -eq "ACTIVITY_STOP") {
            $stopStyle = "$ESC[48;2;240;60;60m$ESC[38;2;255;255;255m${stopTag}${cReset}"
        } elseif ($script:currentHoverTarget -eq "ACTIVITY_STOP") {
            $stopStyle = "$ESC[48;2;160;40;40m$ESC[38;2;220;220;230m${stopTag}${cReset}"
        }

        $prefixStr = "$actLabel$($global:activityColor)$actText${cReset}  "
        $plainLen = $actLabel.Length + $actText.Length + 2 + $stopTag.Length
        $padLen = [math]::Max(0, $rightW - 2 - $plainLen)

        Set-CursorPos 45 5
        Write-Host "$prefixStr$stopStyle$(' ' * $padLen)" -NoNewline
    } else {
        $maxLen = [math]::Max(10, $rightW - 14)
        if ($actText.Length -gt $maxLen) { $actText = $actText.Substring(0, $maxLen - 3) + "..." }
        $prefixStr = "$actLabel$($global:activityColor)$actText${cReset}"
        $plainLen = $actLabel.Length + $actText.Length
        $padLen = [math]::Max(0, $rightW - 2 - $plainLen)

        Set-CursorPos 45 5
        Write-Host "$prefixStr$(' ' * $padLen)" -NoNewline
    }
}

# --- Breadcrumb Trail Rendering & Click Routing ---
# --- [6.2] Breadcrumb Engine ---
function Get-BreadcrumbPath() {
    $path = [System.Collections.Generic.List[PSCustomObject]]::new()
    $current = $global:activeMenu
    $menuStack = [System.Collections.Generic.List[string]]::new()
    while ($current) {
        $menuStack.Insert(0, $current)
        if ($script:menuParent.ContainsKey($current)) {
            $current = $script:menuParent[$current]
        } else {
            break
        }
    }

    $isVi = ($global:selectedLang -eq "Vietnamese")
    foreach ($mKey in $menuStack) {
        $name = if ($mKey -eq "MAIN") {
            if ($isVi) { "MENU CHÍNH" } else { "MAIN MENU" }
        } elseif ($script:menuCatalog -and $script:menuCatalog.ContainsKey($mKey)) {
            $catTitle = if ($isVi) { $script:menuCatalog[$mKey].TitleVi } else { $script:menuCatalog[$mKey].TitleEn }
            ($catTitle -replace '\x1b\[[0-9;]*m', '').Trim()
        } elseif ($script:menuDisplayName -and $script:menuDisplayName.ContainsKey($mKey)) {
            $script:menuDisplayName[$mKey]
        } else {
            $mKey
        }
        $path.Add([PSCustomObject]@{
            Key       = $mKey
            Target    = "BREADCRUMB_$mKey"
            Type      = "MENU"
            Name      = $name
            Clickable = $true
        })
    }

    if ($global:actionBreadcrumbs -and $global:actionBreadcrumbs.Count -gt 0) {
        for ($ai = 0; $ai -lt $global:actionBreadcrumbs.Count; $ai++) {
            $ab = $global:actionBreadcrumbs[$ai]
            $aName = if ($isVi) { $ab.Vi } else { $ab.En }
            $aKey = if ($ab.Key) { $ab.Key } else { "ACT_$ai" }
            $aTarget = if ($ab.Target) { $ab.Target } else { "BREADCRUMB_$aKey" }
            $path.Add([PSCustomObject]@{
                Key       = $aKey
                Target    = $aTarget
                Type      = "ACTION"
                Name      = $aName
                Clickable = $true
            })
        }
    } elseif ($global:currentActionName) {
        $cleanAct = $global:currentActionName -replace '^EXECUTION:\s*', ''
        $path.Add([PSCustomObject]@{
            Key       = "ACT_0"
            Target    = "ACT_0"
            Type      = "ACTION"
            Name      = $cleanAct
            Clickable = $false
        })
    }

    return ,$path
}

function Draw-Breadcrumb() {
    Get-TermSize
    $rightW = [math]::Max(10, $script:termW - 45)
    $hasAction = ($global:currentActionName -or ($global:actionBreadcrumbs -and $global:actionBreadcrumbs.Count -gt 0))
    $isProcRunning = Test-IsAnyTaskRunning
    if ($global:activeMenu -eq "MAIN" -and -not $hasAction -and -not $isProcRunning) {
        $script:breadcrumbBounds = @()
        Set-CursorPos 45 6
        Write-Host (" " * [math]::Max(0, $rightW - 2)) -NoNewline
        Set-CursorPos 0 0
        return
    }

    $path = Get-BreadcrumbPath
    $maxW = [math]::Max(10, $rightW - 2)

    $rawTotalLen = 0
    foreach ($pItem in $path) { $rawTotalLen += ($pItem.Name.Length + 4) }
    $namesToRender = [System.Collections.Generic.List[string]]::new()
    foreach ($pItem in $path) { $namesToRender.Add($pItem.Name) }

    if ($rawTotalLen -gt $maxW -and $namesToRender.Count -gt 1) {
        $namesToRender[0] = ".."
    }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append(" ")
    $newBounds = @()
    $curCol = 46

    for ($i = 0; $i -lt $namesToRender.Count; $i++) {
        $crumbName = $namesToRender[$i]
        $pTarget = $path[$i].Target
        $isLast = ($i -eq ($namesToRender.Count - 1))
        $isClickable = (-not $isLast) -and $path[$i].Clickable -and (-not $isProcRunning)

        if ($i -gt 0) {
            $sep = " > "
            [void]$sb.Append("${cDim}${sep}${cReset}")
            $curCol += $sep.Length
        }

        $bStart = $curCol
        $bEnd = $curCol + $crumbName.Length - 1

        if ($isClickable) {
            $newBounds += [PSCustomObject]@{
                StartX   = $bStart
                EndX     = $bEnd
                StartCol = $bStart
                EndCol   = $bEnd
                Target   = $pTarget
            }
            if ($script:currentHoverTarget -eq $pTarget) {
                [void]$sb.Append("$ESC[4m${cLightCyan}${crumbName}${cReset}")
            } else {
                [void]$sb.Append("${cCyan}${crumbName}${cReset}")
            }
        } else {
            [void]$sb.Append("${cDim}${crumbName}${cReset}")
        }
        $curCol += $crumbName.Length
    }

    $script:breadcrumbBounds = $newBounds
    Set-CursorPos 45 6
    $plain = [System.Text.RegularExpressions.Regex]::Replace($sb.ToString(), "\x1b\[[0-9;]*m", "")
    $pad = [math]::Max(0, $rightW - 2 - $plain.Length)
    Write-Host "$($sb.ToString())$(' ' * $pad)" -NoNewline
    Set-CursorPos 0 0
}

# --- Mouse Routing & Hit Testing ---
# --- [6.3] Mouse Hit-Testing ---
$script:statusBoundsCache = $null
$script:statusBoundsKey = ""

function Get-StatusControlBounds() {
    $cacheKey = "$($global:selectedLang)_$($global:targetDrive)_$($isAdmin)_$($global:expertMode)"
    if ($script:statusBoundsCache -and $script:statusBoundsKey -eq $cacheKey) {
        return $script:statusBoundsCache
    }

    $isVi = ($global:selectedLang -eq "Vietnamese")
    $driveLabel = if ($isVi) { "Ổ đĩa" } else { "Drive" }
    $adminLabel = if ($isVi) { "Quản trị" } else { "Admin" }
    $expertLabel = if ($isVi) { "Chuyên gia" } else { "Expert Mode" }

    $drivePrefix = " ${driveLabel}: "
    $drvVal = if ($global:targetDrive) { " $global:targetDrive " } else { " C: " }
    $driveX = 45 + $drivePrefix.Length
    $driveLen = $drvVal.Length

    $adminPrefix = "*${adminLabel}: "
    $adminX = $driveX + $driveLen + 5 + $adminPrefix.Length
    $admVal = if ($isAdmin) { $(if ($isVi) { " CÓ " } else { " YES " }) } else { $(if ($isVi) { " KHÔNG " } else { " NO " }) }
    $adminLen = $admVal.Length

    $expertPrefix = "[i]${expertLabel}: "
    $expertX = $adminX + $adminLen + 5 + $expertPrefix.Length
    $expVal = if ($global:expertMode) { $(if ($isVi) { " BẬT " } else { " ON " }) } else { $(if ($isVi) { " TẮT " } else { " OFF " }) }
    $expertLen = $expVal.Length

    $res = @{
        DriveStart  = $driveX
        DriveEnd    = $driveX + $driveLen - 1
        AdminStart  = $adminX
        AdminEnd    = $adminX + $adminLen - 1
        ExpertStart = $expertX
        ExpertEnd   = $expertX + $expertLen - 1
    }
    $script:statusBoundsCache = $res
    $script:statusBoundsKey = $cacheKey
    return $res
}

function Get-HoverTarget($posX, $posY) {
    if ($posY -eq 0) {
        $exitX = [math]::Max(30, $script:termW - 7)
        if ($posX -ge 1 -and $posX -le 6) { return "TOP_VIEW" }
        if ($posX -ge 10 -and $posX -le 17) { return "TOP_GITHUB" }
        if ($posX -ge 21 -and $posX -le 25) { return "TOP_LOG" }
        if ($posX -ge $exitX -and $posX -le ($exitX + 5)) { return "TOP_EXIT" }
    }
    if ($posY -eq 1) {
        if ($global:viewMenuOpen) {
            if ($posX -ge 13 -and $posX -le 21) { return "LANG_ENG" }
            if ($posX -ge 25 -and $posX -le 36) { return "LANG_VIE" }
        } elseif ($global:logMenuOpen) {
            $isVi = ($global:selectedLang -eq "Vietnamese")
            if ($isVi) {
                if ($posX -ge 12 -and $posX -le 19) { return "LOG_OPEN" }
                if ($posX -ge 23 -and $posX -le 34) { return "LOG_FOLDER" }
                if ($posX -ge 38 -and $posX -le 54) { return "LOG_EXPORT" }
            } else {
                if ($posX -ge 13 -and $posX -le 22) { return "LOG_OPEN" }
                if ($posX -ge 26 -and $posX -le 38) { return "LOG_FOLDER" }
                if ($posX -ge 42 -and $posX -le 60) { return "LOG_EXPORT" }
            }
        }
    }
    $isVi = ($global:selectedLang -eq "Vietnamese")
    $backStartX = if ($isVi) { 30 } else { 32 }
    $backEndX   = 39
    if ($posY -eq 3 -and $posX -ge $backStartX -and $posX -le $backEndX -and ($global:activeMenu -ne "MAIN" -or $global:currentActionName)) {
        if (Test-IsAnyTaskRunning) { return "NONE" }
        return "BACK_BTN"
    }
    if ($posY -eq 4 -and $posX -ge 44 -and $posX -lt $script:termW) {
        $bounds = Get-StatusControlBounds
        if ($posX -ge $bounds.DriveStart -and $posX -le $bounds.DriveEnd) { return "STATUS_DRIVE" }
        if ($posX -ge $bounds.AdminStart -and $posX -le $bounds.AdminEnd) { return "STATUS_ADMIN" }
        if ($posX -ge $bounds.ExpertStart -and $posX -le $bounds.ExpertEnd) { return "STATUS_EXPERT" }
    }
    $isProcRunning = Test-IsAnyTaskRunning
    if ($posY -eq 5 -and $posX -ge 44 -and $isProcRunning) {
        $isVi = ($global:selectedLang -eq "Vietnamese")
        $actLabel = if ($isVi) { " Hoạt động: " } else { " Activity: " }
        $stopTag = if ($isVi) { "[HỦY]" } else { "[CANCEL]" }
        $rightW = [math]::Max(10, $script:termW - 45)
        $actText = $global:activityStatus
        $maxLen = [math]::Max(10, $rightW - 16 - $stopTag.Length)
        if ($actText.Length -gt $maxLen) { $actText = $actText.Substring(0, $maxLen - 3) + "..." }

        $stopStartX = 45 + $actLabel.Length + 2 + $actText.Length
        $stopEndX = $stopStartX + $stopTag.Length - 1
        if ($posX -ge $stopStartX -and $posX -le $stopEndX) { return "ACTIVITY_STOP" }
    }
    if ($posY -eq 6) {
        if ($script:breadcrumbBounds) {
            foreach ($b in $script:breadcrumbBounds) {
                if ($posX -ge $b.StartX -and $posX -le $b.EndX) {
                    return $b.Target
                }
            }
        }
    }
    if (-not $global:currentActionName -and $posX -ge 2 -and $posX -le 40 -and $posY -ge 5) {
        $leftH = [math]::Max(5, $script:termH - 4)
        if ($posY -le ($leftH + 2)) {
            $relY = $posY - 5
            if (($relY % 2) -eq 0) {
                $idx = [int]($relY / 2)
                $cat = $script:menuCatalog[$global:activeMenu]
                if (-not $cat) { $cat = $script:menuCatalog["MAIN"] }
                if ($cat -and $idx -ge 0 -and $idx -lt $cat.Items.Count) {
                    return "LEFT_ITEM_$idx"
                }
            }
        }
    }
    $scrollCol = $script:termW - 2
    $logBoxH = [math]::Max(3, $script:termH - 10)
    $viewHeight = [math]::Max(1, $logBoxH - 2)
    $startY = 10
    $endY = $startY + $viewHeight - 1
    $totalCount = (Get-FormattedLogLines).Count
    if ($totalCount -gt $viewHeight) {
        $maxScroll = $totalCount - $viewHeight
        $clampedOff = [math]::Max(0, [math]::Min($maxScroll, $global:logScrollOffset))
        $thumbPos = $endY - [math]::Round(($clampedOff / $maxScroll) * ($viewHeight - 1))
        if ($posX -eq $scrollCol -and $posY -eq $thumbPos) {
            return "LOG_SCROLL"
        }
    }
    return "NONE"
}

function Handle-GlobalClick($posX, $posY) {
    try {
    $target = Get-HoverTarget $posX $posY
    switch ($target) {
        "TOP_VIEW"   {
            $global:viewMenuOpen = -not $global:viewMenuOpen
            if ($global:viewMenuOpen) { $global:logMenuOpen = $false }
            Write-RightLog "@" (T "Bật/tắt Bảng chọn Hiển thị" "Toggled View Menu") $cDim
            Draw-TopMenuBar; return "HANDLED"
        }
        "TOP_GITHUB" { Write-RightLog "IN" (T "Đang mở kho lưu trữ Github..." "Opening Github repository...") $cCyan; try { Start-Process "https://github.com/SpaceheroVN/WCaO" } catch {}; return "HANDLED" }
        "TOP_LOG"    {
            $global:logMenuOpen = -not $global:logMenuOpen
            if ($global:logMenuOpen) { $global:viewMenuOpen = $false }
            Write-RightLog "@" (T "Bật/tắt Bảng chọn Nhật ký" "Toggled Log Menu") $cDim
            Draw-TopMenuBar; return "HANDLED"
        }
        "LOG_OPEN"   { $global:logMenuOpen = $false; Draw-TopMenuBar; Invoke-OpenFileLog; return "HANDLED" }
        "LOG_FOLDER" { $global:logMenuOpen = $false; Draw-TopMenuBar; Invoke-OpenLogFolder; return "HANDLED" }
        "LOG_EXPORT" { $global:logMenuOpen = $false; Draw-TopMenuBar; Invoke-ExportLogDialog; return "HANDLED" }
        "TOP_EXIT"   { Write-RightLog "IN" (T "Đang thoát..." "Exiting...") $cYellow; Terminate-AllChildProcesses; [System.Environment]::Exit(0); return "HANDLED" }
        "LANG_ENG"   {
            $global:selectedLang = "English"
            Write-RightLog "IN" (T "Đã chuyển sang Tiếng Anh" "Language set to English") $cCyan
            if (-not $global:currentActionName -and -not $global:currentActionBorderColor) {
                Draw-FullLayout
            } else {
                Redraw-CurrentActionBox
                Draw-TopMenuBar
                Draw-StatusPane
                Draw-FooterBar
                if ($global:onLanguageChanged) {
                    try { & $global:onLanguageChanged } catch {}
                }
            }
            return "LANG_CHANGED"
        }
        "LANG_VIE"   {
            $global:selectedLang = "Vietnamese"
            Write-RightLog "IN" (T "Đã chuyển sang Tiếng Việt" "Language set to Vietnamese") $cCyan
            if (-not $global:currentActionName -and -not $global:currentActionBorderColor) {
                Draw-FullLayout
            } else {
                Redraw-CurrentActionBox
                Draw-TopMenuBar
                Draw-StatusPane
                Draw-FooterBar
                if ($global:onLanguageChanged) {
                    try { & $global:onLanguageChanged } catch {}
                }
            }
            return "LANG_CHANGED"
        }
        "BACK_BTN"   {
            if (Test-IsAnyTaskRunning) {
                Write-RightLog "#" (T "Quay lại bị chặn: Tác vụ đang chạy" "Back blocked: Task is running") $cYellow
                return "HANDLED"
            }
            Invoke-MenuBack; return "HANDLED"
        }
        "STATUS_DRIVE"  { Invoke-CycleTargetDrive; return "HANDLED" }
        "STATUS_ADMIN"  { Invoke-ElevateAdmin; return "HANDLED" }
        "STATUS_EXPERT" { Invoke-Options; if ($global:onLanguageChanged) { try { & $global:onLanguageChanged } catch {} }; return "HANDLED" }
        "ACTIVITY_STOP" {
            $script:stopRequested = $true
            $script:lastTaskCancelled = $true
            Write-RightLog "WARN" (T "Người dùng yêu cầu HỦY tác vụ." "User requested to CANCEL task.") $cRed
            return "HANDLED"
        }
        "BREADCRUMB_MAIN" {
            if (Test-IsAnyTaskRunning) {
                Write-RightLog "#" (T "Điều hướng bị chặn: Tác vụ đang chạy" "Navigation blocked: Task is running") $cYellow
                return "HANDLED"
            }
            $wasInAction = ($global:currentActionName -or $leftConsoleLines.Count -gt 0)
            $global:navTarget = "MAIN"
            $global:actionBreadcrumbs.Clear()
            $global:currentActionName = $null
            $global:currentActionBorderColor = $null
            $leftConsoleLines.Clear()
            $global:activeMenu = "MAIN"
            Draw-LeftMenu $false
            Draw-StatusPane
            Write-RightLog "$" (T "Chuyển menu: Menu chính" "Switched menu: Main Menu") $cDim
            if ($wasInAction) { $script:skipFinallyRedraw = $true }
            return "BREADCRUMB_NAV"
        }
        "BREADCRUMB_ADV_TOOLS" {
            if (Test-IsAnyTaskRunning) {
                Write-RightLog "#" (T "Điều hướng bị chặn: Tác vụ đang chạy" "Navigation blocked: Task is running") $cYellow
                return "HANDLED"
            }
            $wasInAction = ($global:currentActionName -or $leftConsoleLines.Count -gt 0)
            $global:navTarget = "ADV_TOOLS"
            $global:actionBreadcrumbs.Clear()
            $global:currentActionName = $null
            $global:currentActionBorderColor = $null
            $leftConsoleLines.Clear()
            $global:activeMenu = "ADV_TOOLS"
            Draw-LeftMenu $false
            Draw-StatusPane
            Write-RightLog "$" (T "Chuyển menu: Công cụ nâng cao" "Switched menu: Advanced Tools") $cDim
            if ($wasInAction) { $script:skipFinallyRedraw = $true }
            return "BREADCRUMB_NAV"
        }
        "BREADCRUMB_SYS_OPT" {
            if (Test-IsAnyTaskRunning) {
                Write-RightLog "#" (T "Điều hướng bị chặn: Tác vụ đang chạy" "Navigation blocked: Task is running") $cYellow
                return "HANDLED"
            }
            $wasInAction = ($global:currentActionName -or $leftConsoleLines.Count -gt 0)
            $global:navTarget = "SYS_OPT"
            $global:actionBreadcrumbs.Clear()
            $global:currentActionName = $null
            $global:currentActionBorderColor = $null
            $leftConsoleLines.Clear()
            $global:activeMenu = "SYS_OPT"
            Draw-LeftMenu $false
            Draw-StatusPane
            Write-RightLog "$" (T "Chuyển menu: Tối ưu hệ thống" "Switched menu: System Optimization") $cDim
            if ($wasInAction) { $script:skipFinallyRedraw = $true }
            return "BREADCRUMB_NAV"
        }
        "BREADCRUMB_SYS_UTIL" {
            if (Test-IsAnyTaskRunning) {
                Write-RightLog "#" (T "Điều hướng bị chặn: Tác vụ đang chạy" "Navigation blocked: Task is running") $cYellow
                return "HANDLED"
            }
            $wasInAction = ($global:currentActionName -or $leftConsoleLines.Count -gt 0)
            $global:navTarget = "SYS_UTIL"
            $global:actionBreadcrumbs.Clear()
            $global:currentActionName = $null
            $global:currentActionBorderColor = $null
            $leftConsoleLines.Clear()
            $global:activeMenu = "SYS_UTIL"
            Draw-LeftMenu $false
            Draw-StatusPane
            Write-RightLog "$" (T "Chuyển menu: Tiện ích hệ thống" "Switched menu: System Utilities") $cDim
            if ($wasInAction) { $script:skipFinallyRedraw = $true }
            return "BREADCRUMB_NAV"
        }
        "BREADCRUMB_WINGET" {
            if (Test-IsAnyTaskRunning) {
                Write-RightLog "#" (T "Điều hướng bị chặn: Tác vụ đang chạy" "Navigation blocked: Task is running") $cYellow
                return "HANDLED"
            }
            $global:navTarget = "WINGET"
            Write-RightLog "$" (T "Chuyển menu: Quản lý Winget" "Switched menu: Winget Manager") $cDim
            return "BREADCRUMB_NAV"
        }
    }
    return "NONE"
    } catch {
        Write-RightLog "ERROR" (T "Lỗi thao tác toàn cục: $_" "Global click error: $_") $cRed
        return "ERROR"
    }
}

# --- Input Controllers & Keyboard Processing ---
# --- [6.4] Input & Console Events ---
function Lock-Input($durationMs = 500) {
    $script:inputLockedUntil = [Environment]::TickCount + $durationMs
    Write-DebugLog "&&" "Input locked for ${durationMs}ms"
    $script:currentHoverTarget = "NONE"
    $script:currentClickTarget = "NONE"
    if (([System.Management.Automation.PSTypeName]'ConsoleMouse').Type) {
        try {
            $hIn = [ConsoleMouse]::GetStdHandle([ConsoleMouse]::STD_INPUT_HANDLE)
            [ConsoleMouse]::FlushConsoleInputBuffer($hIn) | Out-Null
        } catch {}
    }
}

function Get-LeftInput($prompt, $initialValue = "") {
    if ($prompt) {
        Write-LeftConsole "${prompt}:" $cYellow
    }
    Show-LeftBackButton
    Draw-FooterBar

    Add-LeftConsoleLineRaw "$cWhite> $cReset"
    $inputBuffer = if ($initialValue) { [string]$initialValue } else { "" }
    $cursorPos = $inputBuffer.Length
    $maxVisibleLen = 34
    $cursorVisible = $true
    $lastBlinkTick = [Environment]::TickCount

    function Local:Render-InputLine() {
        $bufLen = $inputBuffer.Length
        $curPos = [math]::Max(0, [math]::Min($bufLen, $cursorPos))
        
        $cInv = "$ESC[7m"
        $cNoInv = "$ESC[27m"

        $viewStart = 0
        $prefix = ""
        $suffix = ""
        $visibleLen = $bufLen

        if ($bufLen -gt $maxVisibleLen) {
            $visibleLen = $maxVisibleLen - 2
            $viewStart = [math]::Max(0, $curPos - $visibleLen + 1)
            if (($viewStart + $visibleLen) -gt $bufLen) {
                $viewStart = $bufLen - $visibleLen
            }
            $viewStart = [math]::Max(0, $viewStart)
            if ($viewStart -gt 0) { $prefix = ".." }
            $avail = $maxVisibleLen - $prefix.Length
            if (($viewStart + $avail) -lt $bufLen) { $suffix = ".." }
            $visibleLen = $maxVisibleLen - $prefix.Length - $suffix.Length
        }

        $sub = if ($bufLen -gt 0) {
            $inputBuffer.Substring($viewStart, [math]::Min($visibleLen, $bufLen - $viewStart))
        } else { "" }

        $relCursor = $curPos - $viewStart

        $body = ""
        for ($k = 0; $k -lt $sub.Length; $k++) {
            $ch = $sub[$k]
            if ($k -eq $relCursor) {
                if ($cursorVisible) {
                    $body += "$cInv$ch$cNoInv"
                } else {
                    $body += $ch
                }
            } else {
                $body += $ch
            }
        }

        $endCursor = ""
        $curCharLen = 0
        if ($relCursor -eq $sub.Length) {
            $curChar = if ($cursorVisible) { "_" } else { " " }
            $endCursor = "${cWhite}${curChar}${cReset}"
            $curCharLen = 1
        }

        $rendered = "${cWhite}> ${cReset}${prefix}${body}${endCursor}${suffix}"

        if ($leftConsoleLines.Count -gt 0) {
            $lastIdx = $leftConsoleLines.Count - 1
            $leftConsoleLines[$lastIdx] = $rendered
            $targetY = 5 + $lastIdx
            $plainLen = 2 + $prefix.Length + $sub.Length + $curCharLen + $suffix.Length
            $padSpaces = " " * [math]::Max(0, 39 - $plainLen)
            Set-CursorPos 2 $targetY
            Write-Host "$rendered$padSpaces" -NoNewline
        }
    }

    Render-InputLine

    # Fallback mode if ConsoleMouse is not loaded
    if (-not (([System.Management.Automation.PSTypeName]'ConsoleMouse').Type)) {
        while ($true) {
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true)
                $cursorVisible = $true
                $lastBlinkTick = [Environment]::TickCount

                $isCtrlV = ($key.Key -eq [ConsoleKey]::V -and ($key.Modifiers -band [ConsoleModifiers]::Control)) -or ($key.KeyChar -eq [char]0x16)
                if ($isCtrlV) {
                    $clip = ""
                    try { Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue; $clip = [System.Windows.Forms.Clipboard]::GetText() } catch {}
                    if ($clip) {
                        $clipClean = $clip -replace "[\r\n]", ""
                        $inputBuffer = $inputBuffer.Substring(0, $cursorPos) + $clipClean + $inputBuffer.Substring($cursorPos)
                        $cursorPos += $clipClean.Length
                        Render-InputLine
                    }
                    continue
                }
                if ($key.Key -eq [ConsoleKey]::Enter) { break }
                if ($key.Key -eq [ConsoleKey]::Escape) { $inputBuffer = ""; break }
                if ($key.Key -eq [ConsoleKey]::LeftArrow) {
                    if ($cursorPos -gt 0) { $cursorPos--; Render-InputLine }
                    continue
                }
                if ($key.Key -eq [ConsoleKey]::RightArrow) {
                    if ($cursorPos -lt $inputBuffer.Length) { $cursorPos++; Render-InputLine }
                    continue
                }
                if ($key.Key -eq [ConsoleKey]::Home) {
                    $cursorPos = 0; Render-InputLine
                    continue
                }
                if ($key.Key -eq [ConsoleKey]::End) {
                    $cursorPos = $inputBuffer.Length; Render-InputLine
                    continue
                }
                if ($key.Key -eq [ConsoleKey]::Delete) {
                    if ($cursorPos -lt $inputBuffer.Length) {
                        $inputBuffer = $inputBuffer.Substring(0, $cursorPos) + $inputBuffer.Substring($cursorPos + 1)
                        Render-InputLine
                    }
                    continue
                }
                if ($key.Key -eq [ConsoleKey]::Backspace) {
                    if ($cursorPos -gt 0) {
                        $inputBuffer = $inputBuffer.Substring(0, $cursorPos - 1) + $inputBuffer.Substring($cursorPos)
                        $cursorPos--
                        Render-InputLine
                    }
                    continue
                }
                if (-not [char]::IsControl($key.KeyChar) -or [int]$key.KeyChar -ge 32) {
                    $inputBuffer = $inputBuffer.Substring(0, $cursorPos) + $key.KeyChar + $inputBuffer.Substring($cursorPos)
                    $cursorPos++
                    Render-InputLine
                }
            } else {
                $now = [Environment]::TickCount
                if (($now - $lastBlinkTick) -gt 450) {
                    $cursorVisible = -not $cursorVisible
                    $lastBlinkTick = $now
                    Render-InputLine
                }
            }
            Start-Sleep -Milliseconds 30
        }
        $finalDisplay = if ($inputBuffer.Length -gt 35) { $inputBuffer.Substring(0, 32) + "..." } else { $inputBuffer }
        Update-LeftConsoleLine "> $finalDisplay" $cWhite
        return [string]$inputBuffer
    }

    # Native ConsoleMouse Input Loop
    $hInput = [ConsoleMouse]::GetStdHandle([ConsoleMouse]::STD_INPUT_HANDLE)
    try { [ConsoleMouse]::FlushConsoleInputBuffer($hInput) | Out-Null } catch {}
    $records = New-Object ConsoleMouse+INPUT_RECORD[] 64

    $reading = $true
    while ($reading) {
        Start-Sleep -Milliseconds 25

        $now = [Environment]::TickCount
        if (($now - $lastBlinkTick) -gt 450) {
            $cursorVisible = -not $cursorVisible
            $lastBlinkTick = $now
            Render-InputLine
        }

        [uint32]$eventsCount = 0
        [ConsoleMouse]::GetNumberOfConsoleInputEvents($hInput, [ref]$eventsCount) | Out-Null
        if ($eventsCount -le 0) { continue }

        [uint32]$toRead = [math]::Min([uint32]$records.Length, $eventsCount)
        [uint32]$read = 0
        [ConsoleMouse]::ReadConsoleInput($hInput, $records, $toRead, [ref]$read) | Out-Null

        for ($i = 0; $i -lt $read; $i++) {
            $rec = $records[$i]

            # Window resize
            if ($rec.EventType -eq 4) {
                $script:termSizeDirty = $true
                Get-TermSize -force
                Draw-FullLayout $false
                Render-InputLine
                continue
            }

            # Key Event
            if ($rec.EventType -eq 1 -and $rec.KeyEvent.bKeyDown -ne 0) {
                $cursorVisible = $true
                $lastBlinkTick = [Environment]::TickCount

                $vk = $rec.KeyEvent.wVirtualKeyCode
                $uChar = $rec.KeyEvent.UnicodeChar
                $ctrlDown = (($rec.KeyEvent.dwControlKeyState -band 0x0008) -ne 0 -or ($rec.KeyEvent.dwControlKeyState -band 0x0004) -ne 0)
                $isCtrlV = ($vk -eq 0x56 -and $ctrlDown) -or ([int]$uChar -eq 0x16)

                if ($isCtrlV) {
                    $clip = ""
                    try {
                        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
                        $clip = [System.Windows.Forms.Clipboard]::GetText()
                    } catch {}
                    if ($clip) {
                        $clipClean = $clip -replace "[\r\n]", ""
                        $inputBuffer = $inputBuffer.Substring(0, $cursorPos) + $clipClean + $inputBuffer.Substring($cursorPos)
                        $cursorPos += $clipClean.Length
                        $cursorVisible = $true
                        $lastBlinkTick = [Environment]::TickCount
                        Render-InputLine
                    }
                    continue
                }

                if ($vk -eq 0x0D) { # Enter
                    $reading = $false
                    break
                }
                if ($vk -eq 0x1B) { # ESC
                    $inputBuffer = ""
                    $reading = $false
                    break
                }
                if ($vk -eq 0x08) { # Backspace
                    if ($cursorPos -gt 0) {
                        $inputBuffer = $inputBuffer.Substring(0, $cursorPos - 1) + $inputBuffer.Substring($cursorPos)
                        $cursorPos--
                        Render-InputLine
                    }
                    continue
                }
                if ($vk -eq 0x2E) { # Delete
                    if ($cursorPos -lt $inputBuffer.Length) {
                        $inputBuffer = $inputBuffer.Substring(0, $cursorPos) + $inputBuffer.Substring($cursorPos + 1)
                        Render-InputLine
                    }
                    continue
                }
                if ($vk -eq 0x25) { # Left Arrow
                    if ($cursorPos -gt 0) {
                        $cursorPos--
                        Render-InputLine
                    }
                    continue
                }
                if ($vk -eq 0x27) { # Right Arrow
                    if ($cursorPos -lt $inputBuffer.Length) {
                        $cursorPos++
                        Render-InputLine
                    }
                    continue
                }
                if ($vk -eq 0x24) { # Home
                    $cursorPos = 0
                    Render-InputLine
                    continue
                }
                if ($vk -eq 0x23) { # End
                    $cursorPos = $inputBuffer.Length
                    Render-InputLine
                    continue
                }

                # Regular Printable Character
                if ($uChar -and [int]$uChar -ge 32) {
                    $inputBuffer = $inputBuffer.Substring(0, $cursorPos) + $uChar + $inputBuffer.Substring($cursorPos)
                    $cursorPos++
                    Render-InputLine
                }
            }

            # Mouse Event (Right-click paste or Back click)
            if ($rec.EventType -eq 2) {
                $mEvent = $rec.MouseEvent
                if (Process-LogScrollEvents $mEvent) { continue }
                $posX = $mEvent.dwMousePosition.X
                $posY = $mEvent.dwMousePosition.Y
                $isRightDown = ($mEvent.dwButtonState -band 2) -ne 0
                $isLeftDown = ($mEvent.dwButtonState -band 1) -ne 0

                if ($isRightDown) {
                    $clip = ""
                    try {
                        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
                        $clip = [System.Windows.Forms.Clipboard]::GetText()
                    } catch {}
                    if ($clip) {
                        $clipClean = $clip -replace "[\r\n]", ""
                        $inputBuffer = $inputBuffer.Substring(0, $cursorPos) + $clipClean + $inputBuffer.Substring($cursorPos)
                        $cursorPos += $clipClean.Length
                        $cursorVisible = $true
                        $lastBlinkTick = [Environment]::TickCount
                        Render-InputLine
                    }
                } elseif ($isLeftDown) {
                    $target = Get-HoverTarget $posX $posY
                    if ($target -eq "BACK_BTN" -or $target.StartsWith("BREADCRUMB_")) {
                        if ($target.StartsWith("BREADCRUMB_")) {
                            Handle-GlobalClick $posX $posY | Out-Null
                        }
                        $inputBuffer = ""
                        $reading = $false
                        break
                    }
                    if ($target.StartsWith("TOP_") -or $target.StartsWith("LANG_") -or $target.StartsWith("LOG_") -or $target.StartsWith("STATUS_")) {
                        Handle-GlobalClick $posX $posY | Out-Null
                    }
                }

                # Mouse Hover Detection during input mode
                $target = Get-HoverTarget $posX $posY
                if ($target -ne $script:currentHoverTarget) {
                    $oldTarget = $script:currentHoverTarget
                    $script:currentHoverTarget = $target
                    if ($target.StartsWith("TOP_") -or $oldTarget.StartsWith("TOP_") -or $target.StartsWith("LANG_") -or $oldTarget.StartsWith("LANG_") -or $target.StartsWith("LOG_") -or $oldTarget.StartsWith("LOG_")) {
                        Draw-TopMenuBar
                        Render-InputLine
                    }
                    if ($target.StartsWith("STATUS_") -or $oldTarget.StartsWith("STATUS_") -or $target.StartsWith("BREADCRUMB_") -or $oldTarget.StartsWith("BREADCRUMB_")) {
                        Draw-StatusPane
                        Render-InputLine
                    }
                    if ($target -eq "LOG_SCROLL" -or $oldTarget -eq "LOG_SCROLL") {
                        Draw-RightLogPane
                        Render-InputLine
                    }
                    if ($target -eq "BACK_BTN" -or $oldTarget -eq "BACK_BTN") {
                        Show-LeftBackButton $target
                        Render-InputLine
                    }
                }
            }
        }
    }

    $finalDisplay = if ($inputBuffer.Length -gt 35) { $inputBuffer.Substring(0, 32) + "..." } else { $inputBuffer }
    Update-LeftConsoleLine "> $finalDisplay" $cWhite
    Hide-LeftBackButton
    return [string]$inputBuffer
}

function Wait-SingleKey($prompt, $validKeys = @('Y','N'), $timeoutMs = 0) {
    $isYesNo = ($validKeys.Count -eq 2 -and 'Y' -in $validKeys -and 'N' -in $validKeys)
    $yesNoLineIdx = -1
    if ($prompt) {
        if ($isYesNo) {
            $btnYesTxt = if ($global:selectedLang -eq "Vietnamese") { "[  Có   ]" } else { "[  Yes  ]" }
            $btnNoTxt  = if ($global:selectedLang -eq "Vietnamese") { "[ Không ]" } else { "[  No  ]" }
            Write-LeftConsole "$prompt" $cYellow
            Write-LeftConsole ""
            $yesNoLineIdx = $leftConsoleLines.Count
            Write-LeftConsole "       $cGreen$btnYesTxt$cReset        $cRed$btnNoTxt$cReset"
        } else {
            Write-LeftConsole "$prompt ($($validKeys -join '/')): " $cYellow
        }
    }
    Show-LeftBackButton
    Draw-FooterBar
    if (-not (([System.Management.Automation.PSTypeName]'ConsoleMouse').Type)) {
        $swFall = [System.Diagnostics.Stopwatch]::StartNew()
        while ($true) {
            if ($timeoutMs -gt 0 -and $swFall.ElapsedMilliseconds -ge $timeoutMs) {
                return "TIMEOUT"
            }
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true)
                if ($isYesNo -and ($key.Key -eq 'Enter' -or $key.KeyChar -eq 'y' -or $key.KeyChar -eq 'Y')) {
                    $script:lastActionEscPressed = $false
                    Hide-LeftBackButton
                    return 'Y'
                }
                if ($isYesNo -and ($key.Key -eq 'Escape' -or $key.KeyChar -eq 'n' -or $key.KeyChar -eq 'N')) {
                    $script:lastActionEscPressed = ($key.Key -eq 'Escape')
                    Hide-LeftBackButton
                    return 'N'
                }
                if ($key.Key -eq 'Escape') {
                    $script:lastActionEscPressed = $true
                    Hide-LeftBackButton
                    return $null
                }
                $char = $key.KeyChar.ToString().ToUpper()
                if ($char -in $validKeys) {
                    $script:lastActionEscPressed = $false
                    if ($prompt) { Write-LeftConsole " -> $char" $cGreen }
                    Hide-LeftBackButton
                    return $char
                }
            }
            Start-Sleep -Milliseconds 50
        }
    }

    $hInput = [ConsoleMouse]::GetStdHandle([ConsoleMouse]::STD_INPUT_HANDLE)
    try { [ConsoleMouse]::FlushConsoleInputBuffer($hInput) | Out-Null } catch {}
    $records = New-Object ConsoleMouse+INPUT_RECORD[] 64
    $lastHoverLine = if ($script:lastMenuHoverLine -ge 0 -and $script:lastMenuHoverLine -lt $leftConsoleLines.Count) { $script:lastMenuHoverLine } else { -1 }
    $lastHoverSub = if ($lastHoverLine -ge 0) { $script:lastMenuHoverSub } else { 0 }
    $swMouse = [System.Diagnostics.Stopwatch]::StartNew()
    $isTimingOut = $false

    try {
        while ($true) {
            if ($timeoutMs -gt 0 -and $swMouse.ElapsedMilliseconds -ge $timeoutMs) {
                $isTimingOut = $true
                $script:lastMenuHoverLine = $lastHoverLine
                $script:lastMenuHoverSub = $lastHoverSub
                return "TIMEOUT"
            }
            Start-Sleep -Milliseconds 30
            [uint32]$eventsCount = 0
            [ConsoleMouse]::GetNumberOfConsoleInputEvents($hInput, [ref]$eventsCount) | Out-Null
            if ($eventsCount -le 0) { continue }

            [uint32]$toRead = [math]::Min([uint32]$records.Length, $eventsCount)
            [uint32]$read = 0
            [ConsoleMouse]::ReadConsoleInput($hInput, $records, $toRead, [ref]$read) | Out-Null

            for ($i = 0; $i -lt $read; $i++) {
                $rec = $records[$i]

                if ($rec.EventType -eq 4) {
                    $script:termSizeDirty = $true
                    Get-TermSize -force
                    Draw-FullLayout
                    Clear-LeftPane
                    Show-LeftBackButton
                    for ($l = 0; $l -lt $leftConsoleLines.Count; $l++) {
                        Set-CursorPos 2 (5 + $l)
                        Write-Host $leftConsoleLines[$l] -NoNewline
                    }
                    $lastHoverLine = -1
                    continue
                }

                if ($rec.EventType -eq 1 -and $rec.KeyEvent.bKeyDown -ne 0) {
                    $vk = $rec.KeyEvent.wVirtualKeyCode
                    $char = $rec.KeyEvent.UnicodeChar.ToString().ToUpper()
                    if ($isYesNo -and ($vk -eq 0x0D -or $char -eq 'Y')) {
                        Lock-Input 300
                        Hide-LeftBackButton
                        return 'Y'
                    }
                    if ($isYesNo -and ($vk -eq 0x1B -or $char -eq 'N')) {
                        Lock-Input 300
                        Hide-LeftBackButton
                        return 'N'
                    }
                    if ($vk -eq 0x1B) {
                        $script:lastActionEscPressed = $true
                        Lock-Input 300
                        return $null
                    }
                    if ($char -in $validKeys) {
                        $script:lastActionEscPressed = $false
                        Lock-Input 300
                        Hide-LeftBackButton
                        return $char
                    }
                }

                if ($rec.EventType -eq 2) {
                    $mEvent = $rec.MouseEvent
                    if (Process-LogScrollEvents $mEvent) { continue }

                    $posX = $mEvent.dwMousePosition.X
                    $posY = $mEvent.dwMousePosition.Y
                    $isLeftDown = ($mEvent.dwButtonState -band 1) -ne 0

                    $target = Get-HoverTarget $posX $posY
                    if ($target -ne $script:currentHoverTarget) {
                        $oldTarget = $script:currentHoverTarget
                        $script:currentHoverTarget = $target
                        if ($target.StartsWith("TOP_") -or $oldTarget.StartsWith("TOP_") -or $target.StartsWith("LANG_") -or $oldTarget.StartsWith("LANG_") -or $target.StartsWith("LOG_") -or $oldTarget.StartsWith("LOG_")) {
                            Draw-TopMenuBar
                        }
                        if ($target.StartsWith("STATUS_") -or $oldTarget.StartsWith("STATUS_") -or $target -eq "ACTIVITY_STOP" -or $oldTarget -eq "ACTIVITY_STOP" -or $target.StartsWith("BREADCRUMB_") -or $oldTarget.StartsWith("BREADCRUMB_")) {
                            Draw-StatusPane
                        }
                        if ($target -eq "BACK_BTN" -or $oldTarget -eq "BACK_BTN") {
                            if ($global:activeMenu -ne "MAIN" -or $global:currentActionName) {
                                Show-LeftBackButton $target
                            } else {
                                Hide-LeftBackButton
                            }
                        }
                    }

                    # Option lines hover highlight inside left console
                    $curHoverLine = -1
                    $curHoverSub = 0
                    if ($posY -ge 5) {
                        $lIdx = $posY - 5
                        if ($lIdx -ge 0 -and $lIdx -lt $leftConsoleLines.Count) {
                            $origL = $leftConsoleLines[$lIdx]
                            $plainL = [System.Text.RegularExpressions.Regex]::Replace($origL, "\x1b\[[0-9;]*m", "")
                            $rawL = $plainL.Trim()
                            if ($isYesNo -and $lIdx -eq $yesNoLineIdx) {
                                $btnNoLen = if ($global:selectedLang -eq "Vietnamese") { 9 } else { 8 }
                                if ($posX -ge 9 -and $posX -le 17) {
                                    $curHoverLine = $lIdx
                                    $curHoverSub = 1
                                } elseif ($posX -ge 26 -and $posX -le (26 + $btnNoLen - 1)) {
                                    $curHoverLine = $lIdx
                                    $curHoverSub = 2
                                }
                            } elseif ($rawL -match "\[ESC\]" -and $posX -ge 2 -and $posX -le 40) {
                                $curHoverLine = $lIdx
                            } elseif ($validKeys -contains "RAM_STATUS" -and ($rawL -match "Khởi động|Startup|Windows Autostart|Tiến trình|Process|File Module|Trạng thái File|Module File|Tệp Module")) {
                                $bMatches = [System.Text.RegularExpressions.Regex]::Matches($plainL, "\[[^\]]+\]")
                                for ($bi = 0; $bi -lt $bMatches.Count; $bi++) {
                                    $bm = $bMatches[$bi]
                                    $bStart = 2 + $bm.Index
                                    $bEnd = $bStart + $bm.Length - 1
                                    if ($posX -ge $bStart -and $posX -le $bEnd) {
                                        $curHoverLine = $lIdx
                                        $curHoverSub = $bi + 1
                                        break
                                    }
                                }
                            } else {
                                if ($posX -ge 2 -and $posX -le 40) {
                                    foreach ($k in $validKeys) {
                                        if ($rawL -match "\[$k\]" -or $rawL -match "^#?\[?$k\]?") {
                                            $curHoverLine = $lIdx
                                            break
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if ($curHoverLine -ne $lastHoverLine -or $curHoverSub -ne $lastHoverSub) {
                        if ($lastHoverLine -ge 0 -and $lastHoverLine -lt $leftConsoleLines.Count) {
                            Set-CursorPos 2 (5 + $lastHoverLine)
                            if ($isYesNo -and $lastHoverLine -eq $yesNoLineIdx) {
                                $bYes = if ($global:selectedLang -eq "Vietnamese") { "[  Có   ]" } else { "[  Yes  ]" }
                                $bNo  = if ($global:selectedLang -eq "Vietnamese") { "[ Không ]" } else { "[  No  ]" }
                                Write-Host "       $cGreen$bYes$cReset        $cRed$bNo$cReset       " -NoNewline
                            } else {
                                $prevOrig = $leftConsoleLines[$lastHoverLine]
                                $prevPlain = [System.Text.RegularExpressions.Regex]::Replace($prevOrig, "\x1b\[[0-9;]*m", "")
                                $prevPad = " " * [math]::Max(0, 39 - $prevPlain.Length)
                                Write-Host "$prevOrig$prevPad" -NoNewline
                            }
                        }
                        if ($curHoverLine -ge 0 -and $curHoverLine -lt $leftConsoleLines.Count) {
                            $curOrig = $leftConsoleLines[$curHoverLine]
                            $curPlain = [System.Text.RegularExpressions.Regex]::Replace($curOrig, "\x1b\[[0-9;]*m", "")
                            if ($isYesNo -and $curHoverLine -eq $yesNoLineIdx) {
                                $bYes = if ($global:selectedLang -eq "Vietnamese") { "[  Có   ]" } else { "[  Yes  ]" }
                                $bNo  = if ($global:selectedLang -eq "Vietnamese") { "[ Không ]" } else { "[  No  ]" }
                                $yesPart = if ($curHoverSub -eq 1) { "$ESC[48;2;40;140;40m$ESC[38;2;255;255;255m$bYes$cReset" } else { "$cGreen$bYes$cReset" }
                                $noPart  = if ($curHoverSub -eq 2) { "$ESC[48;2;200;40;40m$ESC[38;2;255;255;255m$bNo$cReset" } else { "$cRed$bNo$cReset" }
                                Set-CursorPos 2 (5 + $yesNoLineIdx)
                                Write-Host "       $yesPart        $noPart       " -NoNewline
                            } elseif ($validKeys -contains "RAM_STATUS") {
                                if ($curHoverSub -gt 0) {
                                    $origBadges = [System.Text.RegularExpressions.Regex]::Matches($curOrig, "(?<!\x1b)\[[^\]]+\]")
                                    $tIdx = $curHoverSub - 1
                                    if ($tIdx -lt $origBadges.Count) {
                                        $tm = $origBadges[$tIdx]
                                        $bHov = if ($tm.Value -eq "[ GUI ]") {
                                            "$ESC[48;2;0;105;140m$ESC[38;2;255;255;255m$($tm.Value)$cReset"
                                        } else {
                                            "$ESC[48;2;45;50;62m$ESC[38;2;255;255;255m$($tm.Value)$cReset"
                                        }
                                        $lineOut = $curOrig.Substring(0, $tm.Index) + $bHov + $curOrig.Substring($tm.Index + $tm.Length)
                                        $pad = " " * [math]::Max(0, 39 - $curPlain.Length)
                                        Set-CursorPos 2 (5 + $curHoverLine)
                                        Write-Host "$lineOut$pad" -NoNewline
                                    }
                                }
                            } else {
                                $paddedText = $curPlain.PadRight(39)
                                Set-CursorPos 2 (5 + $curHoverLine)
                                Write-Host "$ESC[48;2;45;48;54m$ESC[38;2;255;255;255m$paddedText$cReset" -NoNewline
                            }
                        }
                        $lastHoverLine = $curHoverLine
                        $lastHoverSub = $curHoverSub
                        $script:lastMenuHoverLine = $lastHoverLine
                        $script:lastMenuHoverSub = $lastHoverSub
                    }

                    if ($isLeftDown -and -not $script:wasLeftDown) {
                        $script:wasLeftDown = $true
                        if ($target -eq "BACK_BTN" -or $target.StartsWith("BREADCRUMB_")) {
                            $script:lastActionEscPressed = $true
                            Lock-Input 300
                            if ($target.StartsWith("BREADCRUMB_")) {
                                Handle-GlobalClick $posX $posY | Out-Null
                            }
                            return $null
                        }

                        if ($posY -ge 5) {
                            $lineIdx = $posY - 5
                            if ($lineIdx -ge 0 -and $lineIdx -lt $leftConsoleLines.Count) {
                                if ($isYesNo -and $lineIdx -eq $yesNoLineIdx) {
                                    $btnNoLen = if ($global:selectedLang -eq "Vietnamese") { 9 } else { 8 }
                                    if ($posX -ge 9 -and $posX -le 17) {
                                        Lock-Input 300
                                        Hide-LeftBackButton
                                        return 'Y'
                                    }
                                    if ($posX -ge 26 -and $posX -le (26 + $btnNoLen - 1)) {
                                        Lock-Input 300
                                        Hide-LeftBackButton
                                        return 'N'
                                    }
                                }
                                $linePlain = [System.Text.RegularExpressions.Regex]::Replace($leftConsoleLines[$lineIdx], "\x1b\[[0-9;]*m", "")
                                $rawLine = $linePlain.Trim()
                                if ($rawLine -match "\[ESC\]" -and $posX -ge 2 -and $posX -le 40) {
                                    $script:lastActionEscPressed = $true
                                    Lock-Input 300
                                    return $null
                                }
                                if ($validKeys -contains "RAM_STATUS") {
                                    $bMatches = [System.Text.RegularExpressions.Regex]::Matches($linePlain, "\[[^\]]+\]")
                                    $clickedBadge = $null
                                    for ($bi = 0; $bi -lt $bMatches.Count; $bi++) {
                                        $bm = $bMatches[$bi]
                                        $bStart = 2 + $bm.Index
                                        $bEnd = $bStart + $bm.Length - 1
                                        if ($posX -ge $bStart -and $posX -le $bEnd) {
                                            $clickedBadge = $bm.Value
                                            break
                                        }
                                    }
                                    if ($clickedBadge) {
                                        $script:lastMenuHoverLine = -1
                                        $script:lastMenuHoverSub = 0
                                        if ($clickedBadge -match "GUI") {
                                            Lock-Input 300
                                            return "GUI"
                                        }
                                        if ($rawLine -match "Tiến trình|Process") {
                                            Lock-Input 300
                                            if ($rawLine -match "ĐANG CHẠY|RUNNING") { return "4" } else { return "3" }
                                        }
                                        if ($rawLine -match "Khởi động|Startup|Windows Autostart") {
                                            Lock-Input 300
                                            return "5"
                                        }
                                        if ($rawLine -match "File Module|Trạng thái File|Module File|Tệp Module") {
                                            Lock-Input 300
                                            if ($rawLine -match "CHƯA TẠO|CHƯA CÓ|MISSING") { return "1" } else { return "2" }
                                        }
                                    }
                                } else {
                                    if ($posX -ge 2 -and $posX -le 40) {
                                        foreach ($k in $validKeys) {
                                            if ($rawLine -match "\[$k\]" -or $rawLine -match "^#?\[?$k\]?") {
                                                Lock-Input 300
                                                return $k
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        if ($target -ne "STATUS_ADMIN") {
                            $res = Handle-GlobalClick $posX $posY
                            if ($res -eq "BREADCRUMB_NAV") {
                                Lock-Input 300
                                return $null
                            }
                        }
                    } elseif (-not $isLeftDown) {
                        $script:wasLeftDown = $false
                    }
                }
            }
        }
    } finally {
        if (-not $isTimingOut -and $lastHoverLine -ge 0 -and $lastHoverLine -lt $leftConsoleLines.Count) {
            Set-CursorPos 2 (5 + $lastHoverLine)
            if ($isYesNo -and $lastHoverLine -eq $yesNoLineIdx) {
                $bYes = if ($global:selectedLang -eq "Vietnamese") { "[  CÃ³   ]" } else { "[  Yes  ]" }
                $bNo  = if ($global:selectedLang -eq "Vietnamese") { "[ KhÃ´ng ]" } else { "[  No  ]" }
                Write-Host "       $cGreen$bYes$cReset        $cRed$bNo$cReset       " -NoNewline
            } else {
                $orig = $leftConsoleLines[$lastHoverLine]
                $plain = [System.Text.RegularExpressions.Regex]::Replace($orig, "\x1b\[[0-9;]*m", "")
                $pad = " " * [math]::Max(0, 39 - $plain.Length)
                Write-Host "$orig$pad" -NoNewline
            }
        }
    }
}

function Process-ConsoleEvents() {
    if (-not (([System.Management.Automation.PSTypeName]'ConsoleMouse').Type)) { return }
    $hInput = [ConsoleMouse]::GetStdHandle([ConsoleMouse]::STD_INPUT_HANDLE)
    [uint32]$eventsCount = 0
    [ConsoleMouse]::GetNumberOfConsoleInputEvents($hInput, [ref]$eventsCount) | Out-Null
    if ($eventsCount -le 0) { return }

    $records = New-Object ConsoleMouse+INPUT_RECORD[] $eventsCount
    [uint32]$read = 0
    [ConsoleMouse]::ReadConsoleInput($hInput, $records, $eventsCount, [ref]$read) | Out-Null

    for ($i = 0; $i -lt $read; $i++) {
        $rec = $records[$i]
        if ($rec.EventType -eq 4) {
            $script:termSizeDirty = $true
            Get-TermSize -force
            $script:currentHoverTarget = "NONE"
            $script:currentClickTarget = "NONE"
            Draw-FullLayout $false
            Write-RightLog "@" (T "Kích thước cửa sổ thay đổi khi task chạy" "Window resized during active task") $cDim
            continue
        }

        if ($rec.EventType -eq 1 -and $rec.KeyEvent.bKeyDown -ne 0) {
            $vk = $rec.KeyEvent.wVirtualKeyCode
            if ($vk -eq 0x1B) {
                $script:stopRequested = $true
                $script:lastTaskCancelled = $true
                Write-RightLog "WARN" (T "Người dùng bấm ESC yêu cầu HỦY tác vụ." "User pressed ESC to CANCEL task.") $cRed
            }
            continue
        }

        if ($rec.EventType -eq 2) {
            $mEvent = $rec.MouseEvent
            if (Process-LogScrollEvents $mEvent) { continue }

            $posX = $mEvent.dwMousePosition.X
            $posY = $mEvent.dwMousePosition.Y
            $isLeftDown = ($mEvent.dwButtonState -band 1) -ne 0
            if ($isLeftDown -and -not $script:wasLeftDown) {
                $script:wasLeftDown = $true
                if ((Handle-GlobalClick $posX $posY) -ne "NONE") {
                    continue
                }
            } elseif (-not $isLeftDown) {
                $script:wasLeftDown = $false
            }

            # Mouse Hover Detection for Top Bar & Status Bar during task execution
            $target = Get-HoverTarget $posX $posY
            if ($target -ne $script:currentHoverTarget) {
                $oldTarget = $script:currentHoverTarget
                $script:currentHoverTarget = $target

                if ($target.StartsWith("TOP_") -or $oldTarget.StartsWith("TOP_") -or $target.StartsWith("LANG_") -or $oldTarget.StartsWith("LANG_") -or $target.StartsWith("LOG_") -or $oldTarget.StartsWith("LOG_")) {
                    Draw-TopMenuBar
                }
                if ($target.StartsWith("STATUS_") -or $oldTarget.StartsWith("STATUS_") -or $target -eq "ACTIVITY_STOP" -or $oldTarget -eq "ACTIVITY_STOP" -or $target -eq "BREADCRUMB_MAIN" -or $oldTarget -eq "BREADCRUMB_MAIN") {
                    Draw-StatusPane
                }
            }
        }
    }
}

# --- Permissions & Menu Dispatch Routing ---
# --- [6.5] Menu Routing & Guards ---
function Invoke-MenuBack() {
    if (Test-IsAnyTaskRunning) {
        Write-RightLog "#" (T "Quay lại bị chặn: Tác vụ đang chạy" "Back blocked: Task is running") $cYellow
        return
    }
    if ($global:currentActionName -or $global:currentActionBorderColor) {
        $oldAction = $global:currentActionName
        $global:currentActionName = $null
        $global:currentActionBorderColor = $null
        $script:currentHoverTarget = "NONE"
        $script:currentClickTarget = "NONE"
        $leftConsoleLines.Clear()
        Update-IdleActivity
        Draw-LeftMenu $false
        Draw-StatusPane
        if ($oldAction) {
            Write-RightLog "$" (T "Đã thoát: $oldAction" "Exited: $oldAction") $cDim
        }
        return
    }
    if ($script:menuParent.ContainsKey($global:activeMenu)) {
        $global:activeMenu = $script:menuParent[$global:activeMenu]
    } else {
        $global:activeMenu = "MAIN"
    }
    $script:currentHoverTarget = "NONE"
    $script:currentClickTarget = "NONE"
    $global:currentActionName = $null
    $global:currentActionBorderColor = $null
    $pTitle = if ($global:activeMenu -eq "MAIN") {
        T "Menu chính" "Main Menu"
    } elseif ($script:menuCatalog.ContainsKey($global:activeMenu)) {
        if ($global:selectedLang -eq "Vietnamese") { $script:menuCatalog[$global:activeMenu].TitleVi } else { $script:menuCatalog[$global:activeMenu].TitleEn }
    } else { $global:activeMenu }
    $pTitle = ($pTitle -replace '\x1b\[[0-9;]*m', '').Trim()
    Draw-LeftMenu $false
    Draw-StatusPane
    Write-RightLog "$" (T "Quay lại: $pTitle" "Returned to: $pTitle") $cDim
}
function Invoke-MenuItem($targetItem) {
    Write-DebugLog "&&" "Menu item activated: $($targetItem.Handler) ($($targetItem.SubMenu))"
    if (-not $targetItem) { return }
    $isExpReq = ($targetItem.RequireExpert -or ($targetItem.TextEn -and $targetItem.TextEn.Contains("[i]")) -or ($targetItem.TextVi -and $targetItem.TextVi.Contains("[i]")))
    if ($isExpReq -and -not $global:expertMode) {
        Write-RightLog "WARN" (T "Chức năng này yêu cầu Chế độ chuyên gia! Nhấp [BẬT] ở Chế độ chuyên gia để kích hoạt." "This feature requires Expert Mode! Click [ON] Expert Mode to enable.") $cYellow
        return
    }
    if ($targetItem.SubMenu) {
        $global:activeMenu = $targetItem.SubMenu
        $subTitle = if ($script:menuCatalog.ContainsKey($targetItem.SubMenu)) {
            if ($global:selectedLang -eq "Vietnamese") { $script:menuCatalog[$targetItem.SubMenu].TitleVi } else { $script:menuCatalog[$targetItem.SubMenu].TitleEn }
        } else { $targetItem.SubMenu }
        Write-RightLog "$" (T "Mở menu: $subTitle" "Opened menu: $subTitle") $cCyan
        Draw-LeftMenu $true
        Draw-StatusPane
    } elseif ($targetItem.Handler) {
        $script:skipFinallyRedraw = $false
        $script:lastActionEscPressed = $false
        $rawT = if ($global:selectedLang -eq "Vietnamese") { $targetItem.TextVi } else { $targetItem.TextEn }
        $cleanT = [System.Text.RegularExpressions.Regex]::Replace($rawT, "^[\*#]?\[.*?\]\s*", "")
        $cleanT = [System.Text.RegularExpressions.Regex]::Replace($cleanT, "\s*\[i\]$", "").Trim()
        Write-RightLog "IN" (T "Chọn: $cleanT" "Selected: $cleanT") $cWhite
        try {
            if ($targetItem.ContainsKey("Arg") -and $targetItem.Arg) {
                & $targetItem.Handler $targetItem.Arg
            } else {
                & $targetItem.Handler
            }
        } catch {
            $errMsg = "$_"
            if ($errMsg -notmatch "STOP_REQUESTED") {
                Write-RightLog "ERROR" (T "Lỗi thực thi: $errMsg" "Execution error: $errMsg") $cRed
            }
        } finally {
            $script:isTaskRunning = $false
            $script:stopRequested = $false
            if ($script:skipFinallyRedraw) {
                $script:skipFinallyRedraw = $false
                $leftConsoleLines.Clear()
                $global:currentActionName = $null
                $global:currentActionBorderColor = $null
            } elseif ($global:currentActionName -or $leftConsoleLines.Count -gt 0) {
                $leftConsoleLines.Clear()
                $global:currentActionName = $null
                $global:currentActionBorderColor = $null
                Update-IdleActivity
                Draw-LeftMenu $false
                Draw-StatusPane
            }
        }
    }
}

function Invoke-ElevateAdmin() {
    if ($isAdmin) {
        Write-RightLog "OUT" (T "Đang chạy dưới quyền Quản trị viên." "Already running as Admin.") $cGreen
        return
    }
    Write-RightLog "IN" (T "Đang khởi chạy lại với quyền Quản trị viên..." "Relaunching toolkit with Administrator privileges (UAC Prompt)...") $cYellow
    try {
        $scriptPath = $global:WCAO_BAT_PATH
        if (-not $scriptPath -or -not (Test-Path -LiteralPath $scriptPath)) {
            if ($PSCommandPath -and (Test-Path -LiteralPath $PSCommandPath)) { $scriptPath = $PSCommandPath }
            elseif ($MyInvocation.MyCommand.Path -and (Test-Path -LiteralPath $MyInvocation.MyCommand.Path)) { $scriptPath = $MyInvocation.MyCommand.Path }
        }
        if (-not $scriptPath -or -not (Test-Path -LiteralPath $scriptPath)) {
            Write-RightLog "ERROR" (T "Không xác định được đường dẫn tệp lệnh để nâng quyền Quản trị viên." "Cannot determine script path for Administrator elevation.") $cRed
            return
        }

        # Release single-instance Mutex before launching elevated instance
        if ($script:appMutex) {
            try { $script:appMutex.ReleaseMutex() } catch {}
            try { $script:appMutex.Dispose() } catch {}
            $script:appMutex = $null
        }

        Start-Process cmd.exe -ArgumentList "/c `"`"$scriptPath`"`"" -Verb RunAs
        [System.Environment]::Exit(0)
    } catch {
        Write-RightLog "ERROR" (T "Nâng quyền UAC bị hủy hoặc thất bại." "UAC elevation cancelled or failed.") $cRed
        # Re-acquire single-instance Mutex since UAC was cancelled but current instance continues running
        if (-not $script:appMutex) {
            try {
                $script:appMutex = New-Object System.Threading.Mutex($true, $script:mutexName, [ref]$script:createdNew)
            } catch {}
        }
    }
}

function Require-AdminOrPrompt($viewTitle = "") {
    if ($isAdmin) { return $true }
    $isVi = ($global:selectedLang -eq "Vietnamese")
    if (-not $viewTitle) {
        $viewTitle = if ($isVi) { "YÊU CẦU QUYỀN ADMINISTRATOR" } else { "ADMIN PRIVILEGE REQUIRED" }
    }
    Start-ActionView $viewTitle $cRed
    $msgReq = if ($isVi) { " [!!] Chức năng này yêu cầu quyền Administrator!" } else { " [!!] Admin privileges required!" }
    $msgPrompt = if ($isVi) { "Nâng quyền Admin ngay?" } else { "Relaunch as Admin now?" }
    $msgY = if ($isVi) { " [Y] Đồng ý nâng quyền Admin" } else { " [Y] Elevate Admin now" }
    $msgN = if ($isVi) { " [N] Hủy bỏ" } else { " [N] Cancel" }
    $promptStr = if ($isVi) { "Chọn thao tác" } else { "Select option" }

    Write-LeftConsole $msgReq $cRed
    Write-LeftConsole $msgPrompt $cYellow
    Write-LeftConsole ""
    Write-LeftConsole $msgY $cGreen
    Write-LeftConsole $msgN $cWhite
    $ans = Wait-SingleKey $promptStr @('Y', 'N')
    Lock-Input 300
    if ($ans -eq "Y") {
        Invoke-ElevateAdmin
    }
    $global:currentActionName = $null
    $global:currentActionBorderColor = $null
    Update-IdleActivity
    Draw-LeftMenu $false
    Draw-StatusPane
    return $false
}

function Require-ExpertOrBlock($titleVi, $titleEn = "") {
    if ($global:expertMode) { return $true }
    $title = if ($titleEn) { T $titleVi $titleEn } else { $titleVi }
    Start-ActionView $title $cRed
    Write-LeftConsole (T "[-] Yêu cầu Chế độ chuyên gia!" "[-] Expert Mode required!") $cRed
    Wait-LeftReturn
    return $false
}

# ===============================================================================
#  ZONE 7: WCAO_RAM C++ MANAGEMENT & COMPATIBILITY TEST SUITE
# ===============================================================================
function Get-RamTrayPathFromLink() {
    $defExe1 = "$script:scriptDir\WCaO_RAM.exe"
    $defExe2 = "$script:scriptDir\WCaO_RAM\WCaO_RAM.exe"
    $defExe3 = "$env:LocalAppData\WCaO\WCaO_RAM\WCaO_RAM.exe"
    $linkFile = "$env:LocalAppData\WCaO\Link.wcao"
    if (-not (Test-Path $linkFile)) {
        $oldLink = "$env:LocalAppData\WCaO_Toolkit\Link.wcao"
        if (Test-Path $oldLink) { $linkFile = $oldLink }
    }
    if (Test-Path $linkFile) {
        try {
            foreach ($line in [System.IO.File]::ReadAllLines($linkFile, [System.Text.Encoding]::UTF8)) {
                if ($line -match '^\s*WCAO_RAM=(.*)$') {
                    $p = $matches[1].Trim()
                    if ($p -and (Test-Path $p)) {
                        # Auto-upgrade from legacy .bat to C++ .exe if .exe is available
                        if ($p -match '\.bat$' -and (Test-Path $defExe1)) {
                            Update-WcaoLinkRegistry -ramTrayPath $defExe1
                            return $defExe1
                        }
                        if ($p -match '\.bat$' -and (Test-Path $defExe2)) {
                            Update-WcaoLinkRegistry -ramTrayPath $defExe2
                            return $defExe2
                        }
                        return $p
                    }
                }
            }
        } catch {}
    }
    if (Test-Path $defExe1) { return $defExe1 }
    if (Test-Path $defExe2) { return $defExe2 }
    if (Test-Path $defExe3) { return $defExe3 }
    $defBat1 = "$script:scriptDir\WCaO_RAM.bat"
    if (Test-Path $defBat1) { return $defBat1 }
    $defBat2 = "$env:LocalAppData\WCaO\WCaO_RAM\WCaO_RAM.bat"
    if (Test-Path $defBat2) { return $defBat2 }
    return "$defExe1"
}

function New-RamTrayScriptFile($targetPath) {
    $targetDir = Split-Path $targetPath
    if ($targetDir -and -not (Test-Path $targetDir)) { [System.IO.Directory]::CreateDirectory($targetDir) | Out-Null }
    $candidates = @(
        "$script:scriptDir\WCaO_RAM\WCaO_RAM.exe",
        "$script:scriptDir\WCaO_RAM.exe",
        "$env:LocalAppData\WCaO\WCaO_RAM\WCaO_RAM.exe",
        "$script:scriptDir\WCaO_RAM.bat"
    )
    $src = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($src) {
        Copy-Item -Path $src -Destination $targetPath -Force
    }
    Update-WcaoLinkRegistry -ramTrayPath $targetPath
}

function Prompt-SaveRamTrayPath($currentPath) {
    $isVi = ($global:selectedLang -eq "Vietnamese")
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
        $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
        $saveDialog.FileName = "WCaO_RAM.exe"
        $saveDialog.Filter = "Executable Files (*.exe)|*.exe|Batch Files (*.bat)|*.bat|All Files (*.*)|*.*"
        $saveDialog.Title = if ($isVi) { "Chọn vị trí lưu WCaO_RAM.exe" } else { "Save WCaO_RAM.exe To..." }
        $initDir = if ($currentPath -and (Split-Path $currentPath) -and (Test-Path (Split-Path $currentPath))) {
            Split-Path $currentPath
        } else {
            "$env:LocalAppData\WCaO\WCaO_RAM"
        }
        if (-not (Test-Path $initDir)) { [System.IO.Directory]::CreateDirectory($initDir) | Out-Null }
        $saveDialog.InitialDirectory = $initDir
        if ($saveDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            return $saveDialog.FileName
        }
    } catch {
        Write-RightLog "ERR" (T "Lỗi khi mở hộp thoại lưu tệp: $_" "Error opening save file dialog: $_") $cRed
    }
    return $null
}

function Test-WcaoRamMutexRunning() {
    $names = @("WCaO_RAM_Tray_Mutex", "Global\WCaO_RAM_Tray_Mutex", "WCaO_RAM_GUI_Mutex", "Global\WCaO_RAM_GUI_Mutex", "WCaO_RAM_Single_Mutex")
    foreach ($n in $names) {
        $m = $null
        try {
            if ([System.Threading.Mutex]::TryOpenExisting($n, [ref]$m)) {
                if ($m) { $m.Close() }
                return $true
            }
        } catch [System.UnauthorizedAccessException] {
            return $true
        } catch {}
        if ($m) { try { $m.Close() } catch {} }
    }
    return $false
}

function Get-WcaoRamRunningProcess() {
    try {
        $p = Get-Process -Name "WCaO_RAM" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($p) { return $p }
    } catch {}
    try {
        $cim = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
            Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -like "*WCaO_RAM.bat*" } | Select-Object -First 1
        if ($cim) { return [PSCustomObject]@{ Id = $cim.ProcessId; ProcessName = "powershell" } }
    } catch {}
    return $null
}

function Test-WcaoRamAutostartEnabled() {
    $startupPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\WCaO_RAM.lnk"
    if (Test-Path $startupPath) { return $true }
    $ts = $null
    try {
        $ts = New-Object -ComObject "Schedule.Service"
        $ts.Connect()
        $folder = $ts.GetFolder("\")
        $task = $folder.GetTask("WCaO_RAM_Daemon")
        if ($task -and $task.Enabled) { return $true }
    } catch {}
    finally {
        if ($ts) { try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($ts) | Out-Null } catch {} }
    }
    return $false
}

function Stop-WcaoRamGracefully() {
    try {
        $msgQuit = [ConsoleMouse]::RegisterWindowMessage("WCaO_RAM_Quit")
        if ($msgQuit -ne 0) {
            [ConsoleMouse]::PostMessage([IntPtr]0xFFFF, $msgQuit, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
        }
    } catch {}
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.ElapsedMilliseconds -lt 400) {
        if (-not (Test-WcaoRamMutexRunning) -and -not (Get-WcaoRamRunningProcess)) { return }
        Start-Sleep -Milliseconds 40
    }
    try {
        Get-Process -Name "WCaO_RAM" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    } catch {}
}

# --- [4.3] RAM Management & Tray ---
function Invoke-RamTrayManager() {
    Write-DebugLog "&&" "[4.3] Invoking RAM Management & Tray Manager..."
    $actionTitle = if ($global:selectedLang -eq "Vietnamese") { "QUẢN LÝ RAM" } else { "RAM MANAGEMENT" }
    Write-RightLog "IN" (T "Mở bảng điều khiển Quản lý RAM ngầm" "Opened RAM Management dashboard") $cWhite
    Write-RightLog "INFO" (T "[i] Click chuột vào các thẻ [ ... ] để bật/tắt hoặc cấu hình" "[i] Click [ ... ] badges to toggle or configure") $cLightCyan

    $isVi = ($global:selectedLang -eq "Vietnamese")
    $lblFile = T "  Tệp Module  : " "  Module File : "
    $lblProc = T "  Tiến trình  : " "  Tray Process: "
    $lblAuto = T "  Khởi động   : " "  Win Startup : "
    $lblHint = T "  Nhấp các thẻ [ ... ] để điều khiển." "  Click [ ... ] badges to control."
    $badgeGui = "${cCyan}[ GUI ]${cReset}"

    $firstRun = $true
    $needRedraw = $true

    while ($true) {
        $ramTrayPath = Get-RamTrayPathFromLink
        $fileExists = ($ramTrayPath -and (Test-Path $ramTrayPath))

        $mutexRunning = Test-WcaoRamMutexRunning
        $runningProc = Get-WcaoRamRunningProcess

        $isRunning = $mutexRunning -or [bool]$runningProc
        $runningPid = if ($runningProc) { $runningProc.Id } else { $null }
        $startupPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\WCaO_RAM.lnk"
        $isAutostart = Test-WcaoRamAutostartEnabled

        $badgeReady = T "[ SẴN SÀNG ]" "[ READY ]"
        $badgeMissing = T "[ CHƯA TẠO ]" "[ MISSING ]"
        $badgeRunning = T "[ ĐANG CHẠY ]" "[ RUNNING ]"
        $badgeStopped = T "[ ĐÃ DỪNG ]" "[ STOPPED ]"
        $badgeEnabled = T "[ BẬT ]" "[ ENABLED ]"
        $badgeDisabled = T "[ TẮT ]" "[ DISABLED ]"

        $fileStatus = if ($fileExists) { "${cGreen}$badgeReady${cReset}" } else { "${cRed}$badgeMissing${cReset}" }
        $procStatus = if ($isRunning) { "${cGreen}$badgeRunning${cReset}" } else { "${cYellow}$badgeStopped${cReset}" }
        $autoStatus = if ($isAutostart) { "${cGreen}$badgeEnabled${cReset}" } else { "${cRed}$badgeDisabled${cReset}" }
        $guiGap = if ($isVi -and $isRunning) { "  " } else { "   " }

        if ($firstRun) {
            Start-ActionView $actionTitle $cCyan
            $firstRun = $false
        }

        if ($needRedraw) {
            $targetLines = @(
                "$lblFile$fileStatus",
                "$lblProc$procStatus$guiGap$badgeGui",
                "$lblAuto$autoStatus",
                "",
                $lblHint
            )
            $maxLines = [math]::Max($targetLines.Count, [math]::Max($leftConsoleLines.Count, 7))
            for ($li = 0; $li -lt $maxLines; $li++) {
                $fLine = if ($li -lt $targetLines.Count) { $targetLines[$li] } else { "" }
                Set-CursorPos 2 (5 + $li)
                $plain = [System.Text.RegularExpressions.Regex]::Replace($fLine, "\x1b\[[0-9;]*m", "")
                $pad = " " * [math]::Max(0, 39 - $plain.Length)
                Write-Host "$fLine$pad" -NoNewline
            }
            $leftConsoleLines.Clear()
            foreach ($tl in $targetLines) {
                $leftConsoleLines.Add($tl)
            }
            $needRedraw = $false
        }

        $opt = Wait-SingleKey $null @('RAM_STATUS') 1000
        if ($opt -eq 'TIMEOUT') {
            $curRunning = (Test-WcaoRamMutexRunning) -or [bool](Get-WcaoRamRunningProcess)
            $curAuto = Test-WcaoRamAutostartEnabled
            $curFile = ($ramTrayPath -and (Test-Path $ramTrayPath))

            if ($curRunning -ne $isRunning -or $curAuto -ne $isAutostart -or $curFile -ne $fileExists) {
                $needRedraw = $true
                $script:lastMenuHoverLine = -1
                $script:lastMenuHoverSub = 0
            }
            continue
        }

        if (-not $opt -or $opt -eq 'ESC') {
            $script:lastMenuHoverLine = -1
            $script:lastMenuHoverSub = 0
            Write-RightLog "$" (T "Đã thoát Quản lý RAM Khay Hệ thống" "Exited RAM Tray Manager") $cDim
            break
        }

        $needRedraw = $true
        $script:lastMenuHoverLine = -1
        $script:lastMenuHoverSub = 0

        if ($opt -eq 'GUI') {
            if (-not (Test-Path $ramTrayPath)) {
                $ramTrayPath = Get-RamTrayPathFromLink
            }
            if (Test-Path $ramTrayPath) {
                if ($ramTrayPath -match '\.exe$') {
                    Start-Process -FilePath $ramTrayPath
                } else {
                    Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$ramTrayPath`"" -WindowStyle Hidden
                }
                Write-RightLog "OUT" (T "Đã mở Giao diện Quản lý RAM!" "Opened RAM Manager GUI window!") $cGreen
                Set-Activity "OK" (T "Mở RAM GUI" "Opened RAM GUI") $cGreen

                $swWait = [System.Diagnostics.Stopwatch]::StartNew()
                while ($swWait.ElapsedMilliseconds -lt 2500) {
                    Start-Sleep -Milliseconds 80
                    if (Test-WcaoRamMutexRunning) {
                        Start-Sleep -Milliseconds 60
                        break
                    }
                }
            } else {
                Write-RightLog "WARN" (T "Chưa tìm thấy tệp WCaO_RAM!" "WCaO_RAM not found!") $cYellow
            }
            continue
        }

        if ($opt -eq '1') {
            $chosenPath = Prompt-SaveRamTrayPath $ramTrayPath
            if ($chosenPath) {
                New-RamTrayScriptFile $chosenPath
                Update-WcaoLinkRegistry -ramTrayPath $chosenPath
                $ramTrayPath = $chosenPath
                Write-RightLog "OUT" (T "Đã tạo tệp WCaO_RAM tại $chosenPath" "Created WCaO_RAM at $chosenPath") $cGreen
                Set-Activity "OK" (T "Đã tạo Quản lý RAM" "Created RAM Manager") $cGreen
            } else {
                Write-RightLog "IN" (T "Đã hủy tạo tệp Quản lý RAM." "Cancelled RAM Manager creation.") $cDim
            }
            $needRedraw = $true
        } elseif ($opt -eq '2') {
            if ($ramTrayPath -eq "$script:scriptDir\WCaO_RAM\WCaO_RAM.exe" -or $ramTrayPath -eq "$script:scriptDir\WCaO_RAM.exe" -or $ramTrayPath -eq "$script:scriptDir\WCaO_RAM.bat") {
                Write-RightLog "INFO" (T "Tệp WCaO_RAM đang ở thư mục gốc ứng dụng ($ramTrayPath)" "WCaO_RAM is at root directory ($ramTrayPath)") $cLightCyan
                continue
            }
            if ($isRunning) {
                Stop-WcaoRamGracefully
            }
            if (Test-Path $ramTrayPath) {
                Remove-Item -Path $ramTrayPath -Force -ErrorAction SilentlyContinue
                Write-RightLog "OUT" (T "Đã xóa tệp WCaO_RAM tại $ramTrayPath" "Deleted WCaO_RAM at $ramTrayPath") $cYellow
                Set-Activity "OK" (T "Đã xóa Quản lý RAM" "Deleted RAM Manager") $cYellow
            }
            Start-Sleep -Milliseconds 100
        } elseif ($opt -eq '3') {
            if ($isRunning) {
                Write-RightLog "WARN" (T "Quản lý RAM đang chạy rồi$(if ($runningPid) { " (PID: $runningPid)" })" "RAM Manager already running$(if ($runningPid) { " (PID: $runningPid)" })") $cYellow
            } else {
                if (-not (Test-Path $ramTrayPath)) {
                    Write-RightLog "IN" (T "Chưa có tệp WCaO_RAM! Vui lòng chọn nơi lưu tệp..." "WCaO_RAM missing! Please select destination...") $cYellow
                    $chosenPath = Prompt-SaveRamTrayPath $ramTrayPath
                    if ($chosenPath) {
                        New-RamTrayScriptFile $chosenPath
                        Update-WcaoLinkRegistry -ramTrayPath $chosenPath
                        $ramTrayPath = $chosenPath
                    } else {
                        Write-RightLog "IN" (T "Đã hủy khởi chạy RAM Tray." "Cancelled RAM Tray start.") $cDim
                        continue
                    }
                    $needRedraw = $true
                }
                if ($ramTrayPath -match '\.exe$') {
                    Start-Process -FilePath $ramTrayPath -ArgumentList "-tray"
                } else {
                    Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$ramTrayPath`" -tray" -WindowStyle Hidden
                }
                Write-RightLog "OUT" (T "Đã khởi chạy Quản lý RAM ngầm dưới Khay hệ thống!" "Started WCaO_RAM Tray in background") $cGreen
                Set-Activity "OK" (T "Đang chạy RAM Tray" "Running RAM Tray") $cGreen

                $swWait = [System.Diagnostics.Stopwatch]::StartNew()
                while ($swWait.ElapsedMilliseconds -lt 2500) {
                    Start-Sleep -Milliseconds 80
                    if (Test-WcaoRamMutexRunning) {
                        Start-Sleep -Milliseconds 60
                        break
                    }
                }
            }
        } elseif ($opt -eq '4') {
            if ($isRunning) {
                Stop-WcaoRamGracefully
                Write-RightLog "OUT" (T "Đã dừng tiến trình Quản lý RAM$(if ($runningPid) { " (PID: $runningPid)" })!" "Stopped WCaO_RAM process$(if ($runningPid) { " (PID: $runningPid)" })!") $cGreen
                Set-Activity "OK" (T "Đã dừng RAM Tray" "Stopped RAM Tray") $cGreen
            } else {
                Write-RightLog "WARN" (T "Tiến trình Quản lý RAM chưa chạy." "RAM Manager process not running.") $cYellow
            }
        } elseif ($opt -eq '5') {
            if ($isAutostart) {
                if (Test-Path $startupPath) {
                    Remove-Item -Path $startupPath -Force -ErrorAction SilentlyContinue
                }
                try {
                    Start-Process -FilePath "$env:SystemRoot\System32\schtasks.exe" -ArgumentList "/delete /tn `"WCaO_RAM_Daemon`" /f" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
                } catch {}
                Write-RightLog "OUT" (T "Đã TẮT tự khởi động cùng Windows!" "Disabled Autostart for WCaO_RAM") $cYellow
                Set-Activity "OK" (T "Tắt khởi động cùng Win" "Autostart Disabled") $cYellow
            } else {
                if (-not (Test-Path $ramTrayPath)) {
                    Write-RightLog "IN" (T "Chưa có file WCaO_RAM! Vui lòng chọn nơi lưu file..." "WCaO_RAM missing! Please select destination...") $cYellow
                    $chosenPath = Prompt-SaveRamTrayPath $ramTrayPath
                    if ($chosenPath) {
                        New-RamTrayScriptFile $chosenPath
                        Update-WcaoLinkRegistry -ramTrayPath $chosenPath
                        $ramTrayPath = $chosenPath
                    } else {
                        Write-RightLog "IN" (T "Đã hủy cài đặt khởi động cùng Win." "Cancelled autostart setup.") $cDim
                        continue
                    }
                    $needRedraw = $true
                }
                $wsh = New-Object -ComObject WScript.Shell
                $sc = $wsh.CreateShortcut($startupPath)
                $sc.TargetPath = $ramTrayPath
                $sc.Arguments = "-tray"
                $sc.WorkingDirectory = Split-Path $ramTrayPath
                $sc.WindowStyle = 7
                $sc.Description = "WCaO RAM Manager Tray Daemon"
                $sc.Save()
                Write-RightLog "OUT" (T "Đã BẬT tự khởi động cùng Windows!" "Enabled Autostart for WCaO_RAM") $cGreen
                Set-Activity "OK" (T "Bật khởi động cùng Win" "Autostart Enabled") $cGreen
            }
        }
    }
}

# --- [4.4] Automated WCaO_RAM C++ Compatibility Test Suite ---
function Invoke-TestRamCompatibility() {
    Start-ActionView (T "KIỂM TRA TƯƠNG THÍCH" "COMPATIBILITY TEST") $cLightCyan
    Write-RightLog "IN" (T "Bắt đầu kiểm tra độ tương thích WCaO_RAM C++..." "Starting WCaO_RAM C++ compatibility verification...") $cCyan

    $ramPath = Get-RamTrayPathFromLink
    Write-LeftConsole (T " [1/5] Kiểm tra đường dẫn..." " [1/5] Checking binary path...") $cYellow
    if ($ramPath -and (Test-Path $ramPath)) {
        Update-LeftConsoleLine (T " [OK] Đã tìm thấy tệp thực thi" " [OK] Found executable") $cGreen
        Write-RightLog "OUT" "Target: $ramPath" $cGreen
    } else {
        Update-LeftConsoleLine (T " [ERR] Không tìm thấy WCaO_RAM.exe!" " [ERR] WCaO_RAM.exe not found!") $cRed
        Write-RightLog "ERR" "Missing executable: $ramPath" $cRed
        Wait-LeftReturn
        return
    }

    Write-LeftConsole (T " [2/5] Kiểm tra chạy ngầm (-tray)..." " [2/5] Testing background Tray mode...") $cYellow
    Stop-WcaoRamGracefully
    Start-Sleep -Milliseconds 150
    $swStart = [System.Diagnostics.Stopwatch]::StartNew()
    Start-Process -FilePath $ramPath -ArgumentList "-tray_direct"
    $mutexOk = $false
    while ($swStart.ElapsedMilliseconds -lt 2000) {
        if (Test-WcaoRamMutexRunning) { $mutexOk = $true; break }
        Start-Sleep -Milliseconds 20
    }
    $swStart.Stop()
    if ($mutexOk) {
        Update-LeftConsoleLine (T " [OK] Tray Mutex sẵn sàng ($($swStart.ElapsedMilliseconds)ms)" " [OK] Tray Mutex ready ($($swStart.ElapsedMilliseconds)ms)") $cGreen
        Write-RightLog "OUT" "Mutex verified in $($swStart.ElapsedMilliseconds) ms" $cGreen
    } else {
        Update-LeftConsoleLine (T " [ERR] Không nhận diện được Mutex!" " [ERR] Mutex not detected!") $cRed
        Write-RightLog "ERR" "Tray Mutex failed to initialize" $cRed
    }

    Write-LeftConsole (T " [3/5] Đo mức tiêu thụ RAM..." " [3/5] Measuring RAM footprint...") $cYellow
    Start-Sleep -Milliseconds 300
    $proc = Get-Process -Name "WCaO_RAM" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($proc) {
        $wsMB = [math]::Round($proc.WorkingSet64 / 1MB, 2)
        $privMB = [math]::Round($proc.PrivateMemorySize64 / 1MB, 2)
        Update-LeftConsoleLine (T " [OK] RAM: WS=$wsMB MB | Private=$privMB MB" " [OK] RAM: WS=$wsMB MB | Private=$privMB MB") $cGreen
        Write-RightLog "OUT" "WCaO_RAM.exe Footprint -> WorkingSet: $wsMB MB | Private: $privMB MB" $cLightCyan
    }

    Write-LeftConsole (T " [4/5] Kiểm tra Link.wcao & Settings..." " [4/5] Checking Link.wcao & Settings...") $cYellow
    $cfgFile = "$env:LocalAppData\WCaO\WCaO_RAM\Settings.wcao"
    $linkFile = "$env:LocalAppData\WCaO\Link.wcao"
    if ((Test-Path $cfgFile) -and (Test-Path $linkFile)) {
        Update-LeftConsoleLine (T " [OK] Settings.wcao & Link.wcao hợp lệ" " [OK] Settings.wcao & Link.wcao valid") $cGreen
        Write-RightLog "OUT" "Verified Settings.wcao and Link.wcao synchronization" $cGreen
    } else {
        Update-LeftConsoleLine (T " [WARN] Chưa đồng bộ đủ tệp cấu hình" " [WARN] Config files not yet synced") $cYellow
    }

    Write-LeftConsole (T " [5/5] Kiểm tra mở GUI qua IPC..." " [5/5] Testing GUI wakeup via IPC...") $cYellow
    $msgShow = [ConsoleMouse]::RegisterWindowMessage("WCaO_RAM_ShowGUI")
    if ($msgShow -ne 0) {
        [ConsoleMouse]::PostMessage([IntPtr]0xFFFF, $msgShow, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
        Start-Sleep -Milliseconds 300
        Update-LeftConsoleLine (T " [OK] Đã kích hoạt cửa sổ GUI!" " [OK] Triggered GUI window via IPC!") $cGreen
        Write-RightLog "OUT" "Broadcast WCaO_RAM_ShowGUI succeeded" $cGreen
    }

    Set-Activity "OK" (T "Hoàn tất kiểm tra tương thích" "Compatibility Test Complete") $cGreen
    Wait-LeftReturn
}
# --- [7.0] Toolkit Options ---
function Invoke-Options() {
    Write-DebugLog "&&" "[7.0] Invoking Toolkit Options & Expert Mode..."
    $global:expertMode = -not $global:expertMode
    $expStrVi = if ($global:expertMode) { "BẬT" } else { "TẮT" }
    $expStrEn = if ($global:expertMode) { "ENABLED" } else { "DISABLED" }
    Write-RightLog "CONFIG" (T "Chế độ chuyên gia hiện đang $expStrVi." "Expert Mode is now $expStrEn.") $cYellow
    Draw-StatusPane
    Draw-LeftMenuItems $false
}

# ===============================================================================
#  ZONE 8: APPLICATION LIFECYCLE & MAIN TUI EVENT LOOP
# ===============================================================================
# --- Startup Animation Engine ---
# --- [8.1] Startup Animation ---
function Get-NextStartupFrame($frameIdx) {
    $f1 = @"
 /WW      /WW  /CCCCCC             /OOOOOO 
| WW  /W | WW /CC__  CC           /OO__  OO
| WW /WWW| WW| CC  \__/  /aaaaaa | OO  \ OO
| WW/WW WW WW| CC       |____  aa| OO  | OO
| WWWW_  WWWW| CC        /aaaaaaa| OO  | OO
| WWW/ \  WWW| CC    CC /aa__  aa| OO  | OO
| WW/   \  WW|  CCCCCC/|  aaaaaaa|  OOOOOO/
|__/     \__/ \______/  \_______/ \______/ 
"@
    $f2 = @"
 __       __   ______              ______  
|  \  _  |  \ /      \            /      \ 
| WW / \ | WW|  CCCCCC\  ______  |  OOOOOO\
| WW/  W\| WW| CC   \CC |      \ | OO  | OO
| WW  WWW\ WW| CC        \aaaaaa\| OO  | OO
| WW WW\WW\WW| CC   __  /      aa| OO  | OO
| WWWW  \WWWW| CC__/  \|  aaaaaaa| OO__/ OO
| WWW    \WWW \CC    CC \aa    aa \OO    OO
 \WW      \WW  \CCCCCC   \aaaaaaa  \OOOOOO 
"@
    $f3 = @"
 __       __   ______              ______  
/  |  _  /  | /      \            /      \ 
WW | / \ WW |/CCCCCC  |  ______  /OOOOOO  |
WW |/W  \WW |CC |  CC/  /      \ OO |  OO |
WW /WWW  WW |CC |       aaaaaa  |OO |  OO |
WW WW/WW WW |CC |   __  /    aa |OO |  OO |
WWWW/  WWWW |CC \__/  |/aaaaaaa |OO \__OO |
WWW/    WWW |CC    CC/ aa    aa |OO    OO/ 
WW/      WW/  CCCCCC/   aaaaaaa/  OOOOOO/  
"@
    $f4 = @"
WW\      WW\  CCCCCC\             OOOOOO\  
WW | W\  WW |CC  __CC\           OO  __OO\ 
WW |WWW\ WW |CC /  \__| aaaaaa\  OO /  OO |
WW WW WW\WW |CC |       \____aa\ OO |  OO |
WWWW  _WWWW |CC |       aaaaaaa |OO |  OO |
WWW  / \WWW |CC |  CC\ aa  __aa |OO |  OO |
WW  /   \WW |\CCCCCC  |\aaaaaaa | OOOOOO  |
\__/     \__| \______/  \_______/ \______/ 
"@
    $frames = @($f1, $f2, $f3, $f4)
    $colors = @("$ESC[38;2;18;90;128m", "$ESC[38;2;58;162;200m", "$ESC[38;2;86;198;234m", "$ESC[38;2;170;235;255m")
    return @{
        FrameText = $frames[$frameIdx % $frames.Count]
        ColorCode = $colors[$frameIdx % $frames.Count]
    }
}

function Draw-StartupAnimation($initTask = $null) {
    Get-TermSize
    $psObj = $null
    $asyncResult = $null
    if ($initTask) {
        try {
            $psObj = [powershell]::Create()
            $null = $psObj.AddScript($initTask.ToString())
            $asyncResult = $psObj.BeginInvoke()
        } catch {
            $psObj = $null
            $asyncResult = $null
        }
    }

    $frameIdx = 0
    $minFrames = 4
    $renderedCount = 0

    while ($true) {
        try { [Console]::Clear() } catch { [Console]::Write("$ESC[3J$ESC[2J$ESC[H") }
        $fData = Get-NextStartupFrame $frameIdx
        $lines = $fData.FrameText -split "`r?\n"
        $startY = [math]::Max(2, [int](($script:termH - $lines.Count) / 2))
        $col = $fData.ColorCode

        for ($li = 0; $li -lt $lines.Count; $li++) {
            $line = $lines[$li]
            $startX = [math]::Max(0, [int](($script:termW - $line.Length) / 2))
            Set-CursorPos $startX ($startY + $li)
            Write-Host "$col$line$cReset" -NoNewline
        }

        $frameIdx++
        $renderedCount++
        Start-Sleep -Milliseconds 250

        $isDone = if ($asyncResult) { $asyncResult.IsCompleted } else { $true }
        if ($isDone -and $renderedCount -ge $minFrames) { break }
    }

    $taskResult = $null
    if ($psObj -and $asyncResult) {
        try { $taskResult = $psObj.EndInvoke($asyncResult) } catch {}
        try { $psObj.Dispose() } catch {}
    }
    try { [Console]::Clear() } catch { [Console]::Write("$ESC[3J$ESC[2J$ESC[H") }
    return $taskResult
}

# ===============================================================================
#  MAIN TUI INITIALIZATION & EVENT LOOP (MOUSE + KEY)
# ===============================================================================
# --- [8.2] App Initialization ---
$initTask = [scriptblock]::Create({
    $drives = @([System.IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq 'Fixed' -and $_.IsReady } | ForEach-Object { $_.Name.TrimEnd('\') })
    return $drives
})
$detectedDrives = Draw-StartupAnimation $initTask
Initialize-DrivesFromList $detectedDrives
Update-WcaoLinkRegistry -wcaoPath $global:WCAO_BAT_PATH
Draw-FullLayout
Write-RightLog "&" (T "Khởi động ứng dụng hoàn tất" "Application startup completed") $cDim
Write-RightLog "&" (T "Đã cập nhật liên kết cấu hình WCaO" "Updated WCaO Registry Link") $cDim
if ($global:selectedLang -eq "Vietnamese") {
    Write-RightLog "OUT" "Chào mừng đến với WCaO v$VERSION" $cLightCyan
    Write-RightLog "OUT" "Vui lòng chọn các mục ở bên trái để sử dụng chức năng" $cWhite
    Write-RightLog "OUT" "Nhấp chuột vào [ Có ] / [ Không ] hoặc [ BẬT ] / [ TẮT ] để đổi trạng thái" $cYellow
} else {
    Write-RightLog "OUT" "Welcome to WCaO v$VERSION" $cLightCyan
    Write-RightLog "OUT" "Please click options on the left to execute features" $cWhite
    Write-RightLog "OUT" "Please click [ Yes ] / [ No ] or [ ON ] / [ OFF ] to change status" $cYellow
}
# --- [8.3] Main Event Loop ---
if (([System.Management.Automation.PSTypeName]'ConsoleMouse').Type) {
    $hInput = [ConsoleMouse]::GetStdHandle([ConsoleMouse]::STD_INPUT_HANDLE)
    $records = New-Object ConsoleMouse+INPUT_RECORD[] 64

    $running = $true
    while ($running) {
        try {
        Start-Sleep -Milliseconds 15
        [uint32]$eventsCount = 0
        [ConsoleMouse]::GetNumberOfConsoleInputEvents($hInput, [ref]$eventsCount) | Out-Null
        if ($eventsCount -le 0) { continue }

        [uint32]$toRead = [math]::Min([uint32]$records.Length, $eventsCount)
        [uint32]$read = 0
        [ConsoleMouse]::ReadConsoleInput($hInput, $records, $toRead, [ref]$read) | Out-Null

        # Coalesce multiple resize events into a single redraw
        $hasResizeEvent = $false
        for ($i = 0; $i -lt $read; $i++) {
            if ($records[$i].EventType -eq 4) { $hasResizeEvent = $true }
        }
        if ($hasResizeEvent) {
            $script:termSizeDirty = $true
            Get-TermSize -force
            $script:currentHoverTarget = "NONE"
            $script:currentClickTarget = "NONE"
            Draw-FullLayout $false
        }

        for ($i = 0; $i -lt $read; $i++) {
            $rec = $records[$i]
            if ($rec.EventType -eq 4) {
                continue
            }

            # Key Event (Locked during menu transition)
            if ($rec.EventType -eq 1 -and $rec.KeyEvent.bKeyDown -ne 0) {
                if ([Environment]::TickCount -lt $script:inputLockedUntil) {
                    continue
                }
                $vk = $rec.KeyEvent.wVirtualKeyCode
                if ($vk -eq 0x1B) { # ESC Key
                    if (Test-IsAnyTaskRunning) {
                        Write-RightLog "#" (T "Quay lại bị chặn: Tác vụ đang chạy" "Back blocked: Task is running") $cYellow
                        continue
                    }
                    Invoke-MenuBack
                    continue
                }

                $ch = $rec.KeyEvent.UnicodeChar
                if ($ch -ge '1' -and $ch -le '9') {
                    if (Test-IsAnyTaskRunning) {
                        Write-RightLog "#" (T "Phím [$ch] bị chặn: Tác vụ đang chạy" "Key [$ch] blocked: Task is running") $cYellow
                        continue
                    }
                    $cat = $script:menuCatalog[$global:activeMenu]
                    if ($cat) {
                        $digit = [int][string]$ch
                        if ($digit -ge 1 -and $digit -le $cat.Items.Count) {
                            Invoke-MenuItem $cat.Items[$digit - 1]
                        }
                    }
                }
            }

            # Mouse Event
            if ($rec.EventType -eq 2) {
                $mEvent = $rec.MouseEvent
                if (Process-LogScrollEvents $mEvent) { continue }

                $posX = $mEvent.dwMousePosition.X
                $posY = $mEvent.dwMousePosition.Y
                $isLeftDown = ($mEvent.dwButtonState -band 1) -ne 0

                if ($isLeftDown -and -not $script:wasLeftDown) {
                    $script:wasLeftDown = $true
                    $clickTarget = Get-HoverTarget $posX $posY

                    if ($clickTarget -match '^LEFT_ITEM_(\d+)$') {
                        if (Test-IsAnyTaskRunning) {
                            Write-RightLog "#" (T "Click menu bị chặn: Tác vụ đang chạy" "Menu click blocked: Task is running") $cYellow
                            continue
                        }
                        if ([Environment]::TickCount -lt $script:inputLockedUntil) {
                            continue
                        }
                        $itemIdx = [int]$matches[1]
                        $script:currentClickTarget = $clickTarget
                        Draw-LeftMenuItems $false
                        Start-Sleep -Milliseconds 60
                        $script:currentClickTarget = "NONE"
                        $cat = $script:menuCatalog[$global:activeMenu]
                        if (-not $cat) { $cat = $script:menuCatalog["MAIN"] }
                        if ($cat -and $itemIdx -ge 0 -and $itemIdx -lt $cat.Items.Count) {
                            Invoke-MenuItem $cat.Items[$itemIdx]
                        }
                        continue
                    } elseif ($clickTarget -eq "BACK_BTN") {
                        if (Test-IsAnyTaskRunning) {
                            Write-RightLog "#" (T "Quay lại bị chặn: Tác vụ đang chạy" "Back blocked: Task is running") $cYellow
                            continue
                        }
                        if ([Environment]::TickCount -lt $script:inputLockedUntil) {
                            continue
                        }
                        $script:currentClickTarget = $clickTarget
                        Show-LeftBackButton "ACTIVE" -force
                        Start-Sleep -Milliseconds 60
                        $script:currentClickTarget = "NONE"
                        Invoke-MenuBack
                        continue
                    } elseif ($clickTarget.StartsWith("TOP_") -or $clickTarget.StartsWith("LANG_") -or $clickTarget.StartsWith("LOG_")) {
                        $script:currentClickTarget = $clickTarget
                        Draw-TopMenuBar
                        Start-Sleep -Milliseconds 60
                    } elseif ($clickTarget.StartsWith("STATUS_") -or $clickTarget -eq "ACTIVITY_STOP" -or $clickTarget.StartsWith("BREADCRUMB_")) {
                        $script:currentClickTarget = $clickTarget
                        Draw-StatusPane
                        Start-Sleep -Milliseconds 60
                    }
                    $script:currentClickTarget = "NONE"

                    if ((Handle-GlobalClick $posX $posY) -ne "NONE") {
                        continue
                    }
                } elseif (-not $isLeftDown) {
                    $script:wasLeftDown = $false
                    if ($script:isDraggingLogScroll) {
                        $script:isDraggingLogScroll = $false
                        Draw-RightLogPane
                    }
                }

                # Mouse Hover Detection for ALL Clickable Elements
                $target = Get-HoverTarget $posX $posY

                if ($target -ne $script:currentHoverTarget) {
                    $oldTarget = $script:currentHoverTarget
                    $script:currentHoverTarget = $target

                    if ($target.StartsWith("TOP_") -or $oldTarget.StartsWith("TOP_") -or $target.StartsWith("LANG_") -or $oldTarget.StartsWith("LANG_") -or $target.StartsWith("LOG_") -or $oldTarget.StartsWith("LOG_")) {
                        Draw-TopMenuBar
                    }
                    if ($target.StartsWith("STATUS_") -or $oldTarget.StartsWith("STATUS_") -or $target -eq "ACTIVITY_STOP" -or $oldTarget -eq "ACTIVITY_STOP" -or $target.StartsWith("BREADCRUMB_") -or $oldTarget.StartsWith("BREADCRUMB_")) {
                        Draw-StatusPane
                    }
                    if ($target.StartsWith("LEFT_ITEM_") -or $oldTarget.StartsWith("LEFT_ITEM_")) {
                        Draw-LeftMenuItems $false
                    }
                    if ($target -eq "BACK_BTN" -or $oldTarget -eq "BACK_BTN") {
                        if ($global:activeMenu -ne "MAIN" -or $global:currentActionName) {
                            Show-LeftBackButton $(if ($target -eq "BACK_BTN") { "HOVER" } else { "NORMAL" })
                        } else {
                            Hide-LeftBackButton
                        }
                    }
                    if ($target -eq "LOG_SCROLL" -or $oldTarget -eq "LOG_SCROLL") {
                        Draw-RightLogPane
                    }
                }
            }
        }
        } catch {
        Write-RightLog "ERROR" (T "Lỗi vòng lặp giao diện: $_" "UI Loop error: $_") $cRed
            Start-Sleep -Milliseconds 50
        }
    }
}

try { [Console]::Clear() } catch {}

try { [Console]::CursorVisible = $true } catch {}

Write-Host "${cGreen}Thank you for using Windows Cleanup & Optimizer TUI!${cReset}"
