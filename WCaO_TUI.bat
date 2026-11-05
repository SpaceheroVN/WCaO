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
$script:AnsiRegex = [regex]::new('\x1b\[[0-9;]*m', [System.Text.RegularExpressions.RegexOptions]::Compiled)
$script:LeadingAnsiRegex = [regex]::new('^(\x1b\[[0-9;]*m)+', [System.Text.RegularExpressions.RegexOptions]::Compiled)
$script:BadgeRegex = [regex]::new('(?<!\x1b)\[[^\]]+\]', [System.Text.RegularExpressions.RegexOptions]::Compiled)
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

# --- [2.4] Menu Catalogs ---
# Menu Catalogs ($script:menuCatalog, $script:menuParent)
$script:menuCatalog = @{
    "MAIN" = @{
        TitleVi     = "MENU CHÍNH - ${cLightCyan}WCaO v$VERSION$cCyan"
        TitleEn     = "MAIN MENU - ${cLightCyan}WCaO v$VERSION$cCyan"
        BorderColor = $cCyan
        Items       = @(
            @{ TextVi = "[1] Dọn dẹp nhanh";        TextEn = "[1] Quick Cleanup";        Color = $cLightGreen; Handler = "Invoke-QuickClean" }
            @{ TextVi = "*[2] Dọn dẹp sâu [i]";     TextEn = "*[2] Deep Cleanup [i]";    Color = $cDarkGreen;  Handler = "Invoke-DeepClean"; RequireExpert = $true }
            @{ TextVi = "[3] Tối ưu hệ thống";     TextEn = "[3] System Optimization"; Color = "$ESC[38;2;86;198;234m"; SubMenu = "SYS_OPT" }
            @{ TextVi = "[4] Tiện ích hệ thống";   TextEn = "[4] System Utilities";     Color = "$ESC[38;2;80;170;240m"; SubMenu = "SYS_UTIL" }
            @{ TextVi = "[5] Công cụ nâng cao";   TextEn = "[5] Advanced Tools";       Color = $cLightYellow; SubMenu = "ADV_TOOLS" }
            @{ TextVi = "*[6] Tự động bảo trì [i]"; TextEn = "*[6] Auto Maintenance [i]"; Color = $cDarkYellow; Handler = "Invoke-AutoRun"; RequireExpert = $true }
        )
    }
    "SYS_OPT" = @{
        TitleVi     = "TỐI ƯU HỆ THỐNG"
        TitleEn     = "SYSTEM OPTIMIZATION"
        BorderColor = $cCyan
        BaseRGB     = @(86, 198, 234)
        Items       = @(
            @{ TextVi = "*[1] Kiểm tra ổ đĩa";        TextEn = "*[1] Check Disk Integrity";   Handler = "Invoke-CheckDisk" }
            @{ TextVi = "*[2] Tối ưu & Chống phân mảnh [i]"; TextEn = "*[2] Defrag / Trim Drive [i]"; Handler = "Invoke-DefragDrive"; RequireExpert = $true }
            @{ TextVi = "[3] Sửa lỗi bo viền Edge";  TextEn = "[3] Edge Rounded Corners Fix"; Handler = "Invoke-EdgeFix" }
            @{ TextVi = "*[4] Tối ưu cấu hình nguồn"; TextEn = "*[4] Optimize Power Plan";     Handler = "Invoke-PowerPlan" }
            @{ TextVi = "[5] Dọn bộ nhớ đệm biểu tượng"; TextEn = "[5] Rebuild System Caches";   Handler = "Invoke-RebuildCaches" }
            @{ TextVi = "[6] Tối ưu hiệu ứng hình ảnh";  TextEn = "[6] Visual Effects Options";   Handler = "Invoke-VisualEffects" }
            @{ TextVi = "[7] Menu chuột phải Windows 11"; TextEn = "[7] Win 11 Context Menu";     Handler = "Invoke-ToggleContextMenu" }
            @{ TextVi = "*[8] Xóa trống dung lượng [i]";TextEn = "*[8] Wipe Free Space [i]";   Handler = "Invoke-WipeFreeSpace"; RequireExpert = $true }
        )
    }
    "SYS_UTIL" = @{
        TitleVi     = "TIỆN ÍCH HỆ THỐNG"
        TitleEn     = "SYSTEM UTILITIES"
        BorderColor = $cCyan
        BaseRGB     = @(80, 180, 235)
        Items       = @(
            @{ TextVi = "[1] Hệ thống & Bản quyền";    TextEn = "[1] System & License Info";   Handler = "Invoke-SystemLicenseCenter" }
            @{ TextVi = "[2] Đóng ứng dụng bị treo [i]";TextEn = "[2] Kill Frozen Tasks [i]";   Handler = "Invoke-KillNotRespondingTasks"; RequireExpert = $true }
            @{ TextVi = "[3] Quản lý RAM";            TextEn = "[3] RAM Management";       Handler = "Invoke-RamTrayManager" }
            @{ TextVi = "[4] Khởi động lại Explorer"; TextEn = "[4] Restart Windows Explorer"; Handler = "Invoke-RestartExplorer" }
            @{ TextVi = "[5] Mạng & Wi-Fi";           TextEn = "[5] Network & Wi-Fi";          Handler = "Invoke-NetworkCenter" }
            @{ TextVi = "[6] Tắt màn hình";           TextEn = "[6] Turn Off Screen";          Handler = "Invoke-ScreenPowerMenu" }
        )
    }
    "ADV_TOOLS" = @{
        TitleVi     = "CÔNG CỤ NÂNG CAO"
        TitleEn     = "ADVANCED TOOLS"
        BorderColor = $cLightYellow
        BaseRGB     = @(255, 235, 120)
        Items       = @(
            @{ TextVi = "*[1] Xóa bộ đệm cập nhật";       TextEn = "*[1] Clear Update Cache";       Handler = "Invoke-ClearWinUpdate" }
            @{ TextVi = "*[2] Tạo điểm khôi phục";     TextEn = "*[2] Create Restore Point";     Handler = "Invoke-CreateRestorePoint" }
            @{ TextVi = "*[3] Phân vùng ảo & Ngủ đông [i]";TextEn = "*[3] Pagefile & Hibernation [i]";Handler = "Invoke-PagefileMenu"; RequireExpert = $true }
            @{ TextVi = "[4] Đổi tên hàng loạt";        TextEn = "[4] Quick Rename";              Color = $cLightYellow; Handler = "Invoke-QuickRenamePro" }
            @{ TextVi = "*[5] Xóa thư mục Windows.old [i]";TextEn = "*[5] Remove Windows.old [i]"; Handler = "Invoke-RemoveWindowsOld"; RequireExpert = $true }
            @{ TextVi = "[6] Quản lý ứng dụng Winget";  TextEn = "[6] Winget Power Tools";        Handler = "Invoke-WingetDashboard" }
        )
    }
}
# --- [2.5] Winget Catalog ---
$script:wingetPackages = @{
    # Runtimes
    "10" = @("Microsoft.VCRedist.2005.x64","Microsoft.VCRedist.2005.x86","Microsoft.VCRedist.2008.x64","Microsoft.VCRedist.2008.x86","Microsoft.VCRedist.2010.x64","Microsoft.VCRedist.2010.x86","Microsoft.VCRedist.2012.x64","Microsoft.VCRedist.2012.x86","Microsoft.VCRedist.2013.x64","Microsoft.VCRedist.2013.x86","Microsoft.VCRedist.2015+.x64","Microsoft.VCRedist.2015+.x86")
    "11" = @("Microsoft.VCRedist.2005.x64","Microsoft.VCRedist.2005.x86")
    "13" = @("Microsoft.VCRedist.2008.x64","Microsoft.VCRedist.2008.x86")
    "15" = @("Microsoft.VCRedist.2010.x64","Microsoft.VCRedist.2010.x86")
    "17" = @("Microsoft.VCRedist.2012.x64","Microsoft.VCRedist.2012.x86")
    "19" = @("Microsoft.VCRedist.2013.x64","Microsoft.VCRedist.2013.x86")
    "21" = @("Microsoft.VCRedist.2015+.x64","Microsoft.VCRedist.2015+.x86")
    "12" = @("Microsoft.DotNet.DesktopRuntime.8")
    "14" = @("Amazon.Corretto.21")
    # Browsers
    "31" = @("Google.Chrome")
    "32" = @("Mozilla.Firefox")
    "33" = @("Microsoft.Edge")
    "34" = @("Brave.Brave")
    "35" = @("Opera.Opera")
    "36" = @("VivaldiTechnologies.Vivaldi")
    "37" = @("CocCoc.CocCoc")
    # Messaging
    "41" = @("Zoom.Zoom")
    "42" = @("Discord.Discord")
    "43" = @("Microsoft.Teams")
    "44" = @("Pidgin.Pidgin")
    "45" = @("Mozilla.Thunderbird")
    "46" = @("CeruleanStudios.Trillian")
    # Media
    "61" = @("Apple.iTunes")
    "62" = @("VideoLAN.VLC")
    "63" = @("AIMP.AIMP")
    "64" = @("PeterPawlowski.foobar2000")
    "65" = @("StevenMayall.MusicBee")
    "66" = @("Audacity.Audacity")
    "67" = @("CodecGuide.K-LiteCodecPack.Mega")
    "68" = @("Spotify.Spotify")
    "69" = @("HandBrake.HandBrake")
    "60" = @("Radionomy.Winamp")
    "601" = @("GRETECH.GOMPlayer")
    "602" = @("MediaMonkey.MediaMonkey")
    # Imaging
    "71" = @("KDE.Krita")
    "72" = @("BlenderFoundation.Blender")
    "73" = @("dotPDNLLC.paint.net")
    "74" = @("GIMP.GIMP")
    "75" = @("IrfanSkiljan.IrfanView")
    "76" = @("XnSoft.XnViewMP")
    "77" = @("Inkscape.Inkscape")
    "78" = @("Greenshot.Greenshot")
    "79" = @("ShareX.ShareX")
    "70" = @("FastStone.ImageViewer")
    # Docs & Compression
    "81" = @("Foxit.FoxitReader")
    "82" = @("TheDocumentFoundation.LibreOffice")
    "83" = @("SumatraPDF.SumatraPDF")
    "84" = @("7zip.7zip")
    "85" = @("GiorgioTani.PeaZip")
    "86" = @("RARLab.WinRAR")
    "87" = @("AcroSoftware.CutePDFWriter")
    "88" = @("Apache.OpenOffice")
    # Storage
    "91" = @("Dropbox.Dropbox")
    "92" = @("Google.Drive")
    "93" = @("Microsoft.OneDrive")
    "94" = @("qBittorrent.qBittorrent")
    # Security
    "101" = @("Malwarebytes.Malwarebytes")
    "102" = @("Avast.Antivirus.Free")
    "103" = @("AVG.AntivirusFree")
    "104" = @("Avira.FreeSecurity")
    "105" = @("SUPERAntiSpyware.SUPERAntiSpyware")
    # Dev
    "111" = @("Python.Python.3.12")
    "112" = @("Git.Git")
    "113" = @("Notepad++.Notepad++")
    "114" = @("Microsoft.VisualStudioCode")
    "115" = @("TimKosse.FileZillaClient")
    "116" = @("MartinPrikryl.WinSCP")
    "117" = @("SimonTatham.PuTTY")
    "118" = @("WinMerge.WinMerge")
    "119" = @("Cursor.Cursor")
    "110" = @("EclipseFoundation.EclipseJava")
    # Utilities
    "121" = @("AnyDeskSoftwareGmbH.AnyDesk")
    "122" = @("TeamViewer.TeamViewer")
    "123" = @("VSRevoGroup.RevoUninstallerFree")
    "124" = @("AntibodySoftware.WizTree")
    "125" = @("WinDirStat.WinDirStat")
    "126" = @("Glarysoft.GlaryUtilities")
    "127" = @("Piriform.CCleaner")
    "128" = @("CodeSector.TeraCopy")
    "129" = @("OpenShell.OpenShell")
    "120" = @("LIGHTNINGUK.ImgBurn")
    "1201" = @("RealVNC.VNCViewer")
    "1202" = @("TightVNC.TightVNC")
    # Gaming & Other
    "131" = @("Valve.Steam")
    "132" = @("EpicGames.EpicGamesLauncher")
    "133" = @("voidtools.Everything")
    "134" = @("DominikReichl.KeePass")
    "135" = @("Google.EarthPro")
    "136" = @("Evernote.Evernote")
    "137" = @("NVAccess.NVDA")
}
$script:menuParent = @{
    "SYS_OPT" = "MAIN"
    "ADV_TOOLS" = "MAIN"
    "SYS_UTIL" = "MAIN"
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
    $cleanLine = $script:AnsiRegex.Replace($rawLine, '')

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
    $cachedW = if ($script:termW -gt 0) { $script:termW } else { 120 }
    $contentW = [math]::Max(10, [math]::Max(10, $cachedW - 45) - 4)

    if ($script:formattedLogCache -and $script:formattedLogVersion -eq $script:currentLogVersion -and $contentW -eq $script:lastLogContentW) {
        return $script:formattedLogCache
    }

    if (-not (Test-Path $tmpLog)) { return [System.Collections.Generic.List[PSCustomObject]]::new() }

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
    $cleanMsg = $script:AnsiRegex.Replace($msg, '')
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

# --- [3.6] Drive State Management ---
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
        $plainTitle = $script:AnsiRegex.Replace($title, "")
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
    [Console]::Write("$color$topLine$cReset")

    for ($i = 1; $i -lt ($h - 1); $i++) {
        Set-CursorPos $x ($y + $i)
        [Console]::Write("$color$chrVert$cReset")
        Set-CursorPos ($x + $w - 1) ($y + $i)
        [Console]::Write("$color$chrVert$cReset")
    }

    Set-CursorPos $x ($y + $h - 1)
    $botLine = "$chrBL" + ($chrLine * ($w - 2)) + "$chrBR"
    [Console]::Write("$color$botLine$cReset")
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
        [Console]::Write((" " * 41))
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
            [Console]::Write($leftConsoleLines[$l])
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
                [Console]::Write("$colActive$textPadded$cReset")
            } elseif ($script:currentHoverTarget -eq $itemTarget) {
                $colHover = "$ESC[48;2;45;48;54m$ESC[38;2;220;220;230m"
                [Console]::Write("$colHover$textPadded$cReset")
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
                [Console]::Write("$col$textPadded$cReset")
            }
            if ($animate) {
                Start-Sleep -Milliseconds 8
            }
            if (($currLine + 1) -lt ($leftH + 2)) {
                Set-CursorPos 2 ($currLine + 1)
                [Console]::Write((" " * 39))
            }
            $currLine += $lineStep
            $subIdx++
        }
    }
    while ($currLine -lt ($leftH + 2)) {
        Set-CursorPos 2 $currLine
        [Console]::Write((" " * 39))
        $currLine++
    }
}

function Update-IdleActivity() {
    if (-not ($script:currentRunningProc -and -not $script:currentRunningProc.HasExited)) {
        $cat = $script:menuCatalog[$global:activeMenu]
        $titleRaw = if ($global:selectedLang -eq "Vietnamese") { $cat.TitleVi } else { $cat.TitleEn }
        $cleanTitle = $script:AnsiRegex.Replace($titleRaw, '') -replace '\s*-\s*WCaO.*', ''
        $idleTag = if ($global:selectedLang -eq "Vietnamese") { "Chờ" } else { "Idle" }
        Set-Activity $idleTag $cleanTitle $cDim
    }
}

function Draw-LeftMenu($animate = $false) {
    if ($animate) { Lock-Input 300 }
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
            [Console]::Write("$fadedCol$txt$cReset")
        } else {
            [Console]::Write((" " * $contentW))
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
                [Console]::Write("$thumbCol$chrThumb$cReset")
            } else {
                [Console]::Write("$trackCol$chrVert$cReset")
            }
        }
    } else {
        for ($r = $startY; $r -le $endY; $r++) {
            Set-CursorPos $scrollCol $r
            [Console]::Write("$trackCol$chrVert$cReset")
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

        $delay = if ($animate) { 8 } else { 0 }

        # 1. Thanh trên top trước (Top bar text)
        Draw-TopBarText
        Invoke-StaggeredRevealDelay $delay

        # 2. Rồi thanh ngăn cách (Divider line)
        Draw-TopDivider
        Invoke-StaggeredRevealDelay $delay

            $rightW = [math]::Max(10, $script:termW - 45)
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
    $plain = $script:AnsiRegex.Replace($formattedLine, "")
    if ($plain.Length -gt 38) {
        $ansiMatch = $script:LeadingAnsiRegex.Match($formattedLine)
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
            $p = $script:AnsiRegex.Replace($leftConsoleLines[$i], "")
            $pad = " " * [math]::Max(0, 38 - $p.Length)
            Write-Host "$($leftConsoleLines[$i])$pad" -NoNewline
        }
    } else {
        $newIdx = $leftConsoleLines.Count - 1
        $targetY = 5 + $newIdx
        Set-CursorPos 2 $targetY
        $p = $script:AnsiRegex.Replace($formattedLine, "")
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

    $plainMsg = $script:AnsiRegex.Replace($msg, "")
    if ($plainMsg.Length -le $maxW) {
        Add-LeftConsoleLineRaw "$color$msg$cReset"
    } else {
        $cleanMsg = $msg.Trim()
        $rawWords = $cleanMsg -split "\s+"
        $currStr = ""
        $firstLine = $true

        $indent = $leadSpace
        $plainClean = $script:AnsiRegex.Replace($cleanMsg, "")
        if ($plainClean -match '^(\[[^\]]+\]|\(\S+\)|[+\-*!~>]+)') {
            $indent = " " * ([math]::Max(2, $leadSpace.Length + $matches[1].Length + 1))
        }

        # Pre-break any long word without spaces that exceeds available width (e.g. Device IDs)
        $words = @()
        $avail = [math]::Max(5, $maxW - $indent.Length)
        foreach ($rw in $rawWords) {
            $pW = $script:AnsiRegex.Replace($rw, "")
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
            $plainCurr = $script:AnsiRegex.Replace($currStr, "")
            $plainW = $script:AnsiRegex.Replace($w, "")
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
                    [Console]::Write($leftConsoleLines[$l])
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

# ===============================================================================
#  ZONE 6: NAVIGATION, EVENT ROUTING & INPUT CONTROLLERS
# ===============================================================================
# --- [6.0] List Navigation & Wheel Controllers ---
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
            $script:AnsiRegex.Replace($catTitle, '').Trim()

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
    $plain = $script:AnsiRegex.Replace($sb.ToString(), "")
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
                        [Console]::Write($leftConsoleLines[$l])
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
                            $plainL = $script:AnsiRegex.Replace($origL, "")
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
                                $bMatches = $script:BadgeRegex.Matches($plainL)
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
                                $prevPlain = $script:AnsiRegex.Replace($prevOrig, "")
                                $prevPad = " " * [math]::Max(0, 39 - $prevPlain.Length)
                                Write-Host "$prevOrig$prevPad" -NoNewline
                            }
                        }
                        if ($curHoverLine -ge 0 -and $curHoverLine -lt $leftConsoleLines.Count) {
                            $curOrig = $leftConsoleLines[$curHoverLine]
                            $curPlain = $script:AnsiRegex.Replace($curOrig, "")
                            if ($isYesNo -and $curHoverLine -eq $yesNoLineIdx) {
                                $bYes = if ($global:selectedLang -eq "Vietnamese") { "[  Có   ]" } else { "[  Yes  ]" }
                                $bNo  = if ($global:selectedLang -eq "Vietnamese") { "[ Không ]" } else { "[  No  ]" }
                                $yesPart = if ($curHoverSub -eq 1) { "$ESC[48;2;40;140;40m$ESC[38;2;255;255;255m$bYes$cReset" } else { "$cGreen$bYes$cReset" }
                                $noPart  = if ($curHoverSub -eq 2) { "$ESC[48;2;200;40;40m$ESC[38;2;255;255;255m$bNo$cReset" } else { "$cRed$bNo$cReset" }
                                Set-CursorPos 2 (5 + $yesNoLineIdx)
                                Write-Host "       $yesPart        $noPart       " -NoNewline
                            } elseif ($validKeys -contains "RAM_STATUS") {
                                if ($curHoverSub -gt 0) {
                                    $origBadges = $script:BadgeRegex.Matches($curOrig)
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
                                $linePlain = $script:AnsiRegex.Replace($leftConsoleLines[$lineIdx], "")
                                $rawLine = $linePlain.Trim()
                                if ($rawLine -match "\[ESC\]" -and $posX -ge 2 -and $posX -le 40) {
                                    $script:lastActionEscPressed = $true
                                    Lock-Input 300
                                    return $null
                                }
                                if ($validKeys -contains "RAM_STATUS") {
                                    $bMatches = $script:BadgeRegex.Matches($linePlain)
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
                $bYes = if ($global:selectedLang -eq "Vietnamese") { "[  Có   ]" } else { "[  Yes  ]" }
                $bNo  = if ($global:selectedLang -eq "Vietnamese") { "[ Không ]" } else { "[  No  ]" }
                Write-Host "       $cGreen$bYes$cReset        $cRed$bNo$cReset       " -NoNewline
            } else {
                $orig = $leftConsoleLines[$lastHoverLine]
                $plain = $script:AnsiRegex.Replace($orig, "")
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
    $pTitle = $script:AnsiRegex.Replace($pTitle, '').Trim()
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

function Require-AdminOrPrompt($viewTitle = "", $viewTitleEn = "") {
    if ($isAdmin) { return $true }
    $isVi = ($global:selectedLang -eq "Vietnamese")
    if (-not $viewTitle) {
        $viewTitle = "YÊU CẦU QUYỀN ADMINISTRATOR"
        $viewTitleEn = "ADMIN PRIVILEGE REQUIRED"
    }
    Start-ActionView $viewTitle $cRed $(if ($viewTitleEn) { $viewTitleEn } else { $viewTitle })
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
    Start-ActionView $titleVi $cRed $(if ($titleEn) { $titleEn } else { $titleVi })
    Write-LeftConsole (T "[-] Yêu cầu Chế độ chuyên gia!" "[-] Expert Mode required!") $cRed
    Wait-LeftReturn
    return $false
}

# ===============================================================================
#  ZONE 7: FEATURE SUITES & ACTION HANDLERS (ORGANIZED BY MENU CATEGORIES)
# ===============================================================================
# -------------------------------------------------------------------------------
#  SECTION 7.1: QUICK & DEEP CLEANUP (MENU [1], [2])
# -------------------------------------------------------------------------------
# --- [1.0] Quick Cleanup ---
function Invoke-QuickClean($autoMode = $false) {
    Write-DebugLog "&&" "[1.0] Invoking Quick Cleanup..."
    $isVi = ($global:selectedLang -eq "Vietnamese")
    Start-ActionView "THỰC THI: DỌN DẸP NHANH" $cLightGreen "EXECUTION: QUICK CLEANUP"

    $oldProgressPref = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'

    Write-RightLog "IN" (T "Bắt đầu dọn dẹp nhanh..." "Starting Quick Cleanup...") $cYellow

    $drivesToMeasure = if ($global:targetDrive -eq "ALL") {
        @([System.IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq 'Fixed' -and $_.IsReady })
    } else {
        $driveRoot = if ($global:targetDrive -match '^[A-Za-z]:?$') { "$($global:targetDrive.Substring(0,1)):\" } else { $global:targetDrive }
        @([System.IO.DriveInfo]::new($driveRoot))
    }
    [long]$freeBefore = 0
    foreach ($d in $drivesToMeasure) { $freeBefore += $d.AvailableFreeSpace }

    if (Test-Path $env:TEMP) {
        $msgTempIn = if ($isVi) { "Đang dọn thư mục Temp..." } else { "Cleaning User Temp folder..." }
        Write-RightLog "IN" (T "Đang dọn thư mục Temp người dùng (%TEMP%)..." "Cleaning User Temp (%TEMP%)...") $cYellow

        Invoke-ScriptWithSpinner { Remove-Item "$env:TEMP\*" -Recurse -Force -EA SilentlyContinue } $msgTempIn $cYellow

        $msgTempOk = if ($isVi) { " [OK] Đã dọn thư mục Temp người dùng." } else { " [OK] User Temp folder cleared." }
        Update-LeftConsoleLine $msgTempOk $cGreen
        Write-RightLog "OUT" (T "Đã dọn sạch User Temp (%TEMP%)" "Cleared User Temp (%TEMP%)") $cGreen
    }

    $rec = "$env:APPDATA\Microsoft\Windows\Recent"
    if (Test-Path $rec) {
        $msgRecIn = if ($isVi) { "Đang dọn lối tắt gần đây..." } else { "Cleaning Recent shortcuts..." }
        Write-RightLog "IN" (T "Đang dọn lối tắt truy cập gần đây..." "Cleaning Recent shortcuts...") $cYellow

        Invoke-ScriptWithSpinner { Remove-Item "$env:APPDATA\Microsoft\Windows\Recent\*" -Recurse -Force -EA SilentlyContinue } $msgRecIn $cYellow

        $msgRecOk = if ($isVi) { " [OK] Đã dọn lối tắt gần đây." } else { " [OK] Recent shortcuts cleared." }
        Update-LeftConsoleLine $msgRecOk $cGreen
        Write-RightLog "OUT" (T "Đã dọn sạch lối tắt gần đây" "Cleared shortcuts in Recent folder") $cGreen
    }

    if ($isAdmin) {
        if (Test-Path "$env:SystemRoot\Temp") {
            $msgSysTempIn = if ($isVi) { "Đang dọn System Temp..." } else { "Cleaning System Temp..." }
            Write-RightLog "IN" (T "Đang dọn Temp hệ thống..." "Cleaning System Temp...") $cYellow

            Invoke-ScriptWithSpinner { Remove-Item "$env:SystemRoot\Temp\*" -Recurse -Force -EA SilentlyContinue } $msgSysTempIn $cYellow

            $msgSysTempOk = if ($isVi) { " [OK] Đã dọn thư mục System Temp." } else { " [OK] System Temp folder cleared." }
            Update-LeftConsoleLine $msgSysTempOk $cGreen
            Write-RightLog "OUT" (T "Đã dọn sạch Temp hệ thống" "Cleared System Temp") $cGreen
        }

        if (Test-Path "$env:SystemRoot\Prefetch") {
            $msgPrefIn = if ($isVi) { "Đang dọn Prefetch..." } else { "Cleaning Prefetch folder..." }
            Write-RightLog "IN" (T "Đang dọn thư mục Prefetch..." "Cleaning Prefetch folder...") $cYellow

            Invoke-ScriptWithSpinner { Remove-Item "$env:SystemRoot\Prefetch\*" -Recurse -Force -EA SilentlyContinue } $msgPrefIn $cYellow

            $msgPrefOk = if ($isVi) { " [OK] Đã dọn thư mục Prefetch." } else { " [OK] Prefetch folder cleared." }
            Update-LeftConsoleLine $msgPrefOk $cGreen
            Write-RightLog "OUT" (T "Đã dọn sạch Prefetch" "Cleared Prefetch") $cGreen
        }

        $msgDnsIn = if ($isVi) { "Đang xóa bộ đệm DNS..." } else { "Flushing DNS Cache..." }
        Write-LeftConsoleProgress $msgDnsIn $cYellow
        Run-And-LogCommand "ipconfig" "/flushdns" | Out-Null
        $msgDnsOk = if ($isVi) { " [OK] Đã xóa bộ đệm DNS." } else { " [OK] DNS Cache flushed." }
        Update-LeftConsoleLine $msgDnsOk $cGreen
    } else {
        $msgSkip = if ($isVi) { " [->] Bỏ qua Prefetch & System Temp." } else { " [->] Skipped Prefetch & System Temp." }
        Write-LeftConsole $msgSkip $cYellow
        Write-RightLog "WARN" (T "Đã bỏ qua Prefetch và Temp hệ thống (Cần quyền quản trị viên)" "Skipped Prefetch & System Temp (Admin rights required)") $cYellow
    }

    $msgRecycleIn = if ($isVi) { "Đang làm rỗng Thùng rác..." } else { "Emptying Recycle Bin..." }
    Write-RightLog "IN" (T "Đang dọn sạch Thùng rác..." "Emptying Recycle Bin...") $cYellow

    Invoke-ScriptWithSpinner { try { Clear-RecycleBin -Force -Confirm:$false -ErrorAction SilentlyContinue } catch {} } $msgRecycleIn $cYellow

    $msgRecycleOk = if ($isVi) { " [OK] Đã làm rỗng Thùng rác." } else { " [OK] Recycle Bin emptied." }
    Update-LeftConsoleLine $msgRecycleOk $cGreen
    Write-RightLog "OUT" (T "Đã dọn sạch Thùng rác" "Emptied Recycle Bin") $cGreen

    $ProgressPreference = $oldProgressPref

    [long]$freeAfter = 0
    foreach ($d in $drivesToMeasure) {
        $dObj = [System.IO.DriveInfo]::new($d.Name)
        $freeAfter += $dObj.AvailableFreeSpace
    }
    [long]$totalFreedBytes = [math]::Max(0L, ($freeAfter - $freeBefore))

    $formattedSize = Format-BytesAuto $totalFreedBytes
    $msgDone = if ($isVi) { " [>>] Dọn dẹp nhanh hoàn tất!" } else { " [>>] Quick Cleanup completed!" }
    Write-LeftConsole $msgDone $cCyan

    Write-RightLog "OUT" (T "Dọn dẹp nhanh hoàn tất. Đã giải phóng: $formattedSize" "Quick Cleanup completed. Freed: $formattedSize") $cGreen

    $actDone = if ($isVi) { "Hoàn thành: Dọn dẹp nhanh ($formattedSize)" } else { "Done: Quick Cleanup ($formattedSize)" }
    if ($script:lastTaskCancelled) {
        Set-Activity "!" (T "Đã dừng: Dọn dẹp nhanh" "Stopped: Quick Cleanup") $cYellow
        if (-not $autoMode) { Wait-LeftReturn }
        return $false
    }
    Set-Activity "OK" $actDone $cGreen
    if (-not $autoMode) { Wait-LeftReturn }
    return $true
}

# --- [2.0] Deep Cleanup ---
function Invoke-DeepClean($autoMode = $false) {
    Write-DebugLog "&&" "[2.0] Invoking Deep Cleanup..."
    if (-not (Require-AdminOrPrompt "DỌN DẸP CHUYÊN SÂU" "EXECUTION: DEEP CLEANUP")) { return }
    Start-ActionView "DỌN DẸP CHUYÊN SÂU" $cDarkGreen "EXECUTION: DEEP CLEANUP"
    Write-LeftConsole (T " [i] Quá trình DISM/SFC có thể mất 10-25 phút tùy tốc độ máy." " [i] DISM/SFC may take 10-25 minutes depending on system speed.") $cYellow
    Write-LeftConsole ""

    if (-not (Invoke-StepCommand "Đang chạy DISM RestoreHealth..." "Running DISM RestoreHealth..." "Dism" "/Online /Cleanup-Image /RestoreHealth" " [OK] Đã chạy xong DISM RestoreHealth." " [OK] DISM RestoreHealth finished.")) { if (-not $autoMode) { Wait-LeftReturn }; return $false }
    if ($script:lastTaskCancelled) { if (-not $autoMode) { Wait-LeftReturn }; return $false }
    if (-not (Invoke-StepCommand "Đang chạy SFC scannow..." "Running SFC scannow..." "sfc" "/scannow" " [OK] Đã chạy xong SFC scannow." " [OK] SFC scannow finished.")) { if (-not $autoMode) { Wait-LeftReturn }; return $false }
    if ($script:lastTaskCancelled) { if (-not $autoMode) { Wait-LeftReturn }; return $false }
    if (-not (Invoke-StepCommand "Đang dọn dẹp ổ đĩa hệ thống..." "Running Disk Cleanup..." "cleanmgr" "/autoclean" " [OK] Đã dọn dẹp ổ đĩa xong." " [OK] Disk Cleanup finished.")) { if (-not $autoMode) { Wait-LeftReturn }; return $false }
    if ($script:lastTaskCancelled) { if (-not $autoMode) { Wait-LeftReturn }; return $false }

    Write-LeftConsole (T " [>>] Dọn dẹp chuyên sâu hoàn tất!" " [>>] Deep Cleanup completed!") $cCyan
    Write-RightLog "SUMMARY" (T "Dọn dẹp sâu hoàn tất thành công!" "Deep Cleanup completed successfully!") $cGreen
    Set-Activity "OK" (T "Hoàn thành: Dọn dẹp chuyên sâu" "Done: Deep Cleanup") $cGreen
    if (-not $autoMode) { Wait-LeftReturn }
    return $true
}

# -------------------------------------------------------------------------------
#  SECTION 7.2: SYSTEM OPTIMIZATION (MENU [3])
# -------------------------------------------------------------------------------
# --- [3.1] Check Disk Integrity ---
function Invoke-CheckDisk() {
    Write-DebugLog "&&" "[3.1] Invoking Check Disk Integrity on drive: $global:targetDrive"
    if (-not (Require-AdminOrPrompt "KIỂM TRA TÍNH TOÀN VẸN Ổ ĐĨA" "CHECK DISK INTEGRITY")) { return }
    Start-ActionView "KIỂM TRA TÍNH TOÀN VẸN Ổ ĐĨA" $cCyan "CHECK DISK INTEGRITY"

    Write-LeftConsole (T " [!] Lệnh chkdsk /scan sẽ quét kiểm tra ổ đĩa và có thể làm chậm I/O trong vài phút." " [!] chkdsk /scan checks filesystem integrity and may slow down I/O for a few minutes.") $cYellow
    $cf = Wait-SingleKey (T "Tiếp tục quét kiểm tra ổ đĩa?" "Proceed with disk integrity scan?") @('Y','N')
    if ($cf -ne 'Y') {
        Write-LeftConsole (T " [i] Đã hủy quét ổ đĩa." " [i] Disk check cancelled.") $cYellow
        Set-Activity "!" (T "Đã hủy: Kiểm tra ổ đĩa" "Cancelled: Check Disk") $cYellow
        Wait-LeftReturn
        return
    }
    Write-LeftConsole ""

    $drivesToScan = if ($global:targetDrive -eq "ALL") {
        @([System.IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq 'Fixed' -and $_.IsReady } | ForEach-Object { $_.Name.TrimEnd('\') })
    } else {
        @($global:targetDrive)
    }

    $allOk = $true
    foreach ($d in $drivesToScan) {
        $ok = Invoke-StepCommand "Đang quét kiểm tra ổ $d..." "Scanning drive $d /scan..." "chkdsk" "$d /scan" " [OK] Đã quét kiểm tra ổ $d xong." " [OK] Check disk scan finished for $d."
        if (-not $ok) { $allOk = $false; break }
    }
    if ($allOk) {
        Set-Activity "OK" (T "Hoàn thành: Kiểm tra ổ đĩa" "Done: Check Disk") $cGreen
    } else {
        Set-Activity "!" (T "Đã dừng: Kiểm tra ổ đĩa" "Stopped: Check Disk") $cYellow
    }
    Wait-LeftReturn
}

# --- [3.2] Defrag / Trim Drive ---
function Invoke-DefragDrive() {
    Write-DebugLog "&&" "[3.2] Invoking Defrag / Trim on drive: $global:targetDrive"
    if (-not (Require-AdminOrPrompt "CHỐNG PHÂN MẢNH & TỐI ƯU Ổ" "DEFRAG / TRIM DRIVE")) { return }
    Start-ActionView "CHỐNG PHÂN MẢNH & TỐI ƯU Ổ" $cCyan "DEFRAG / TRIM DRIVE"

    $ok = $true
    if ($global:targetDrive -eq "ALL") {
        $ok = Invoke-StepCommand "Đang tối ưu/Trim toàn bộ ổ đĩa..." "Defrag/Trim all drives..." "defrag" "/C /O /U" " [OK] Đã tối ưu/Trim toàn bộ ổ đĩa xong." " [OK] Defrag/Trim all finished."
    } else {
        $ok = Invoke-StepCommand "Đang chống phân mảnh/Trim ổ $global:targetDrive..." "Defrag/Trim drive $global:targetDrive..." "defrag" "$global:targetDrive /O /L /U" " [OK] Đã tối ưu/Trim ổ đĩa xong." " [OK] Defrag/Trim finished."
    }
    if ($ok) {
        Set-Activity "OK" (T "Hoàn thành: Tối ưu ổ đĩa" "Done: Defrag/Trim Drive") $cGreen
    } else {
        Set-Activity "!" (T "Đã dừng: Tối ưu ổ đĩa" "Stopped: Defrag/Trim Drive") $cYellow
    }
    Wait-LeftReturn
}

function Restart-EdgeIfRunning() {
    $edgeProcs = Get-Process msedge -ErrorAction SilentlyContinue
    if ($edgeProcs) {
        Write-LeftConsole (T " [i] Đang khởi động lại Edge..." " [i] Restarting Edge to apply...") $cYellow
        $edgeProcs | ForEach-Object { [void]$_.CloseMainWindow() }
        $deadline = [DateTime]::Now.AddSeconds(4)
        while ((Get-Process msedge -EA SilentlyContinue) -and [DateTime]::Now -lt $deadline) { Start-Sleep -Milliseconds 300 }
        Stop-Process -Name msedge -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 500
        $desk = [Environment]::GetFolderPath('Desktop')
        $paths = @(
            "$env:AppData\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Microsoft Edge.lnk",
            "$desk\Microsoft Edge.lnk",
            "$env:Public\Desktop\Microsoft Edge.lnk",
            "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk"
        )
        $edgeLnk = $null
        foreach ($p in $paths) { if (Test-Path $p) { $edgeLnk = $p; break } }
        if ($edgeLnk) {
            $sh = New-Object -ComObject WScript.Shell
            $s = $sh.CreateShortcut($edgeLnk)
            Start-Process $s.TargetPath -ArgumentList ($s.Arguments + ' --restore-last-session')
        } else {
            $x86 = [System.Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
            $cands = @(($x86 + '\Microsoft\Edge\Application\msedge.exe'), ($env:ProgramFiles + '\Microsoft\Edge\Application\msedge.exe'))
            foreach ($c in $cands) { if (Test-Path $c) { Start-Process $c -ArgumentList '--restore-last-session'; break } }
        }
    }
}

# --- [3.3] Edge Rounded Corners Fix ---
function Invoke-EdgeFix() {
    Write-DebugLog "&&" "[3.3] Invoking Edge Rounded Corners Fix..."

    while ($true) {
        Start-ActionView "SỬA LỖI BO VIỀN EDGE" $cCyan "EDGE ROUNDED CORNERS FIX"

        $regP = "HKCU:\Software\Policies\Microsoft\Edge"
        $isApplied = $false
        try {
            $val = (Get-ItemProperty -Path $regP -Name "Windows11VisualEffectsEnabled" -ErrorAction SilentlyContinue).Windows11VisualEffectsEnabled
            if ($val -eq 0) { $isApplied = $true }
        } catch {}

        $statText = if ($isApplied) {
            T "Trạng thái: Đã tắt bo viền Edge" "Status: Rounded corners disabled"
        } else {
            T "Trạng thái: Mặc định" "Status: Default"
        }

        $opt1Text = T "Tắt bo viền Edge" "Disable rounded corners"
        $opt2Text = T "Khôi phục mặc định Edge" "Restore default Edge"

        $tag1 = if ($isApplied) { " (#)" } else { "" }
        $tag2 = if (-not $isApplied) { " (#)" } else { "" }

        Write-LeftConsole " [i] $statText" $cYellow
        Write-LeftConsole ""
        Write-LeftConsole " [1] $opt1Text$tag1" $(if ($isApplied) { $cGreen } else { $cWhite })
        Write-LeftConsole " [2] $opt2Text$tag2" $(if (-not $isApplied) { $cGreen } else { $cWhite })

        $eOpt = Wait-SingleKey $null @('1', '2', 'Q')
        if (-not $eOpt -or $eOpt -in @('Q', 'ESC') -or $script:lastActionEscPressed) { break }

        if ($eOpt -eq "1") {
            if ($isApplied) {
                Write-LeftConsole ""
                Write-LeftConsole (T " [i] Đang ở chế độ này." " [i] Already in this mode.") $cYellow
                Start-Sleep -Milliseconds 600
                continue
            }
            Write-LeftConsoleProgress (T "Đang áp dụng sửa lỗi Edge..." "Applying Edge fix...") $cYellow
            $psScript = "$env:TEMP\edge_fix.ps1"
            $psCode = @'
$sh = New-Object -ComObject WScript.Shell
$dirs = @(
    "$env:Public\Desktop",
    "$env:USERPROFILE\Desktop",
    [Environment]::GetFolderPath('Desktop'),
    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs",
    "$env:AppData\Microsoft\Windows\Start Menu\Programs",
    "$env:AppData\Microsoft\Internet Explorer\Quick Launch",
    "$env:AppData\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
)
foreach ($d in $dirs) {
    if (Test-Path $d) {
        Get-ChildItem -Path $d -Recurse -Force -Filter '*.lnk' -EA SilentlyContinue | ForEach-Object {
            try {
                $s = $sh.CreateShortcut($_.FullName)
                if ($s.TargetPath -like '*msedge.exe*') {
                    $a = $s.Arguments
                    $a = $a -replace '--disable-features=msFeatureGroupNewLookAndFeelHoldout', ''
                    if ($a -notmatch 'msForceNoRoundedCornerAndMargin') {
                        $s.Arguments = ($a.Trim() + ' --enable-features=msForceNoRoundedCornerAndMargin').Trim()
                        $s.Save()
                    }
                }
            } catch {}
        }
    }
}
try { reg.exe export "HKCU\Software\Policies\Microsoft\Edge" "$env:TEMP\edge_policy_backup.reg" /y 2>$null | Out-Null } catch {}
New-Item -Path 'HKCU:\Software\Policies\Microsoft\Edge' -Force -EA SilentlyContinue | Out-Null
Set-ItemProperty -Path 'HKCU:\Software\Policies\Microsoft\Edge' -Name 'Windows11VisualEffectsEnabled' -Value 0 -Type DWord -EA SilentlyContinue
Set-ItemProperty -Path 'HKCU:\Software\Policies\Microsoft\Edge' -Name 'StartupBoostEnabled' -Value 0 -Type DWord -EA SilentlyContinue
Set-ItemProperty -Path 'HKCU:\Software\Policies\Microsoft\Edge' -Name 'BackgroundModeEnabled' -Value 0 -Type DWord -EA SilentlyContinue
'@
            Set-Content -Path $psScript -Value $psCode -Encoding UTF8
            Run-And-LogCommand "powershell" "-NoProfile -ExecutionPolicy Bypass -File `"$psScript`"" | Out-Null
            Remove-Item $psScript -Force -EA SilentlyContinue
            Run-And-LogCommand "ie4uinit.exe" "-show" | Out-Null

            # Restart Edge if running
            Restart-EdgeIfRunning

            Update-LeftConsoleLine (T " [OK] Đã tắt bo viền Edge." " [OK] Edge rounded fix applied.") $cGreen
            Write-RightLog "OUT" (T "Đã áp dụng sửa lỗi bo viền Edge & cập nhật lối tắt" "Applied Edge rounded corners fix & patched shortcuts") $cGreen
            Set-Activity "OK" (T "Đã tắt bo viền Edge" "Applied: Edge Fix") $cGreen
            Start-Sleep -Milliseconds 800
        } elseif ($eOpt -eq "2") {
            if (-not $isApplied) {
                Write-LeftConsole ""
                Write-LeftConsole (T " [i] Đang ở chế độ này." " [i] Already in this mode.") $cYellow
                Start-Sleep -Milliseconds 600
                continue
            }
            Write-LeftConsoleProgress (T "Đang gỡ bỏ sửa lỗi Edge..." "Restoring default Edge...") $cYellow
            $psScript = "$env:TEMP\edge_unfix.ps1"
            $psCode = @'
$sh = New-Object -ComObject WScript.Shell
$dirs = @(
    "$env:Public\Desktop",
    "$env:USERPROFILE\Desktop",
    [Environment]::GetFolderPath('Desktop'),
    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs",
    "$env:AppData\Microsoft\Windows\Start Menu\Programs",
    "$env:AppData\Microsoft\Internet Explorer\Quick Launch",
    "$env:AppData\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
)
foreach ($d in $dirs) {
    if (Test-Path $d) {
        Get-ChildItem -Path $d -Recurse -Force -Filter '*.lnk' -EA SilentlyContinue | ForEach-Object {
            try {
                $s = $sh.CreateShortcut($_.FullName)
                if ($s.TargetPath -like '*msedge.exe*') {
                    $a = $s.Arguments
                    $a = $a -replace '--enable-features=msForceNoRoundedCornerAndMargin', ''
                    $a = $a -replace '--disable-features=msFeatureGroupNewLookAndFeelHoldout', ''
                    $s.Arguments = $a.Trim()
                    $s.Save()
                }
            } catch {}
        }
    }
}
Remove-ItemProperty -Path 'HKCU:\Software\Policies\Microsoft\Edge' -Name 'Windows11VisualEffectsEnabled' -ErrorAction SilentlyContinue
Remove-ItemProperty -Path 'HKCU:\Software\Policies\Microsoft\Edge' -Name 'StartupBoostEnabled' -ErrorAction SilentlyContinue
Remove-ItemProperty -Path 'HKCU:\Software\Policies\Microsoft\Edge' -Name 'BackgroundModeEnabled' -ErrorAction SilentlyContinue
'@
            Set-Content -Path $psScript -Value $psCode -Encoding UTF8
            Run-And-LogCommand "powershell" "-NoProfile -ExecutionPolicy Bypass -File `"$psScript`"" | Out-Null
            Remove-Item $psScript -Force -EA SilentlyContinue
            Run-And-LogCommand "ie4uinit.exe" "-show" | Out-Null

            # Restart Edge if running
            Restart-EdgeIfRunning

            Update-LeftConsoleLine (T " [OK] Đã khôi phục mặc định Edge." " [OK] Edge fix removed.") $cGreen
            Write-RightLog "OUT" (T "Đã khôi phục góc bo viền Edge mặc định" "Restored default Edge rounded corners") $cGreen
            Set-Activity "OK" (T "Đã khôi phục viền Edge" "Restored default Edge") $cGreen
            Start-Sleep -Milliseconds 800
        }
    }
}

# --- [3.4] Optimize Power Plan ---
function Invoke-PowerPlan() {
    Write-DebugLog "&&" "[3.4] Invoking Optimize Power Plan..."
    if (-not $isAdmin) {
        Start-ActionView "TỐI ƯU CẤU HÌNH NGUỒN" $cRed "OPTIMIZE POWER PLAN"
        Write-LeftConsole (T "[-] Cần quyền Quản trị viên!" "[-] Administrator rights required!") $cRed
        Wait-LeftReturn
        return
    }

    while ($true) {
        Start-ActionView "TỐI ƯU CẤU HÌNH NGUỒN" $cCyan "OPTIMIZE POWER PLAN"

        $rawList = powercfg /list
        $schemes = [System.Collections.Generic.List[PSCustomObject]]::new()
        foreach ($l in ($rawList -split "`r?\n")) {
            if ($l -match '([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})\s+\(([^)]+)\)(\s*\*+)?') {
                $guid = $matches[1]
                $name = $matches[2]
                $isActive = [bool]($matches[3])
                $schemes.Add([PSCustomObject]@{ GUID = $guid; Name = $name; IsActive = $isActive })
            }
        }

        $activePlan = $schemes | Where-Object { $_.IsActive } | Select-Object -First 1
        $activeName = if ($activePlan) { $activePlan.Name } else { "Unknown" }
        Write-LeftConsole (T " [i] Trạng thái: $activeName" " [i] Status: $activeName") $cYellow
        Write-LeftConsole ""

        $validKeys = @()
        for ($idx = 0; $idx -lt [math]::Min(5, $schemes.Count); $idx++) {
            $sch = $schemes[$idx]
            $k = [string]($idx + 1)
            $validKeys += $k
            $tag = if ($sch.IsActive) { " (#)" } else { "" }
            $col = if ($sch.IsActive) { $cGreen } else { $cWhite }
            Write-LeftConsole " [$k] $($sch.Name)$tag" $col
        }
        if ($schemes.Count -gt 5) {
            Write-LeftConsole (T " [i] Đang hiển thị 5 cấu hình đầu tiên." " [i] Showing top 5 power schemes.") $cGray
        }

        Write-LeftConsole ""
        Write-LeftConsole (T " [A] Thêm gói hiệu năng tối đa" " [A] Add Ultimate Performance") $cCyan
        Write-LeftConsole (T " [R] Khôi phục cài đặt mặc định" " [R] Restore Default Schemes") $cPurp
        Write-LeftConsole (T " [D] Xóa bớt cấu hình tùy chỉnh" " [D] Delete Inactive Scheme") $cRed
        $validKeys += @('A', 'R', 'D')

        $sel = Wait-SingleKey $null ($validKeys + @('Q'))
        if (-not $sel -or $sel -in @('Q', 'ESC') -or $script:lastActionEscPressed) { break }

        if ($sel -in @('1','2','3','4','5')) {
            $selIdx = [int]$sel - 1
            if ($selIdx -ge 0 -and $selIdx -lt $schemes.Count) {
                $target = $schemes[$selIdx]
                if ($target.IsActive) {
                    Write-LeftConsole ""
                    Write-LeftConsole (T " [i] Đang ở chế độ này." " [i] Already in this mode.") $cYellow
                    Start-Sleep -Milliseconds 600
                    continue
                }
                Write-RightLog "IN" (T "Đang kích hoạt cấu hình nguồn $($target.Name)..." "Activating Power Plan $($target.Name)...") $cYellow
                Run-And-LogCommand "powercfg" "/setactive $($target.GUID)" | Out-Null
                Write-LeftConsole (T " [OK] Đã kích hoạt: $($target.Name)" " [OK] Activated: $($target.Name)") $cGreen
                Write-RightLog "OUT" (T "Đã kích hoạt cấu hình nguồn: $($target.Name)" "Activated Power Plan: $($target.Name)") $cWhite
                Set-Activity "OK" (T "Đã kích hoạt: $($target.Name)" "Activated: $($target.Name)") $cGreen
                Start-Sleep -Milliseconds 600
            }
        } elseif ($sel -eq "A") {
            Write-RightLog "IN" (T "Đang thêm gói hiệu năng tối đa..." "Adding Ultimate Performance Power Plan...") $cYellow
            Run-And-LogCommand "powercfg" "-duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61" | Out-Null
            Write-LeftConsole (T " [OK] Đã thêm cấu hình hiệu năng tối đa." " [OK] Ultimate Performance Plan added.") $cGreen
            Write-RightLog "OUT" (T "Đã thêm gói hiệu năng tối đa" "Added Ultimate Performance Power Plan") $cWhite
            Set-Activity "OK" (T "Đã thêm: Hiệu năng tối đa" "Applied: Ultimate Power Plan") $cGreen
            Start-Sleep -Milliseconds 600
        } elseif ($sel -eq "R") {
            Write-RightLog "IN" (T "Đang khôi phục cài đặt nguồn mặc định..." "Restoring default Power Schemes...") $cYellow
            Run-And-LogCommand "powercfg" "/restoredefaultschemes" | Out-Null
            Write-LeftConsole (T " [OK] Đã khôi phục cấu hình nguồn mặc định." " [OK] Default power schemes restored.") $cGreen
            Write-RightLog "OUT" (T "Đã khôi phục cài đặt nguồn mặc định" "Restored default Power Schemes") $cWhite
            Set-Activity "OK" (T "Đã khôi phục: Cấu hình mặc định" "Applied: Default Power Schemes") $cGreen
            Start-Sleep -Milliseconds 600
        } elseif ($sel -eq "D") {
            Start-ActionView "XÓA CẤU HÌNH NGUỒN TÙY CHỈNH" $cRed "DELETE POWER PLAN"
            $deletable = @($schemes | Where-Object { -not $_.IsActive })
            if ($deletable.Count -eq 0) {
                Write-LeftConsole (T " [!] Không có cấu hình nào có thể xóa." " [!] No inactive schemes to delete.") $cYellow
                Start-Sleep -Milliseconds 1200
                continue
            }
            Write-LeftConsole (T "Chọn cấu hình cần xóa:" "Select scheme to delete:") $cYellow
            Write-LeftConsole ""
            $delKeys = @()
            for ($di = 0; $di -lt [math]::Min(5, $deletable.Count); $di++) {
                $dk = [string]($di + 1)
                $delKeys += $dk
                Write-LeftConsole " [$dk] $($deletable[$di].Name)" $cWhite
            }
            $dSel = Wait-SingleKey $null $delKeys
            if ($dSel -and $dSel -in $delKeys) {
                $delTarget = $deletable[[int]$dSel - 1]
                Write-LeftConsole ""
                $ans = Wait-SingleKey (T "Xác nhận xóa $($delTarget.Name)?" "Confirm delete $($delTarget.Name)?") @('Y','N')
                if ($ans -eq 'Y') {
                    Run-And-LogCommand "powercfg" "/delete $($delTarget.GUID)" | Out-Null
                    Write-LeftConsole (T " [OK] Đã xóa: $($delTarget.Name)" " [OK] Deleted: $($delTarget.Name)") $cGreen
                    Write-RightLog "OUT" (T "Đã xóa cấu hình nguồn: $($delTarget.Name)" "Deleted Power Plan: $($delTarget.Name)") $cWhite
                    Set-Activity "OK" (T "Đã xóa: $($delTarget.Name)" "Deleted: $($delTarget.Name)") $cGreen
                    Start-Sleep -Milliseconds 800
                }
            }
        }
    }
}

# --- [3.5] Rebuild System Caches ---
function Invoke-RebuildCaches() {
    Write-DebugLog "&&" "[3.5] Invoking Rebuild System Caches..."
    $isVi = ($global:selectedLang -eq "Vietnamese")
    Start-ActionView "DỌN BỘ ĐỆM BIỂU TƯỢNG" $cCyan "REBUILD SYSTEM CACHES"
    $ans = Wait-SingleKey (T "Khởi động lại Explorer để dọn bộ đệm biểu tượng?" "Restart Explorer to rebuild Icon Cache?") @('Y','N')
    if ($ans -ne "Y") { return }
    $msgRebuild = if ($isVi) { "Đang dọn bộ đệm biểu tượng & Explorer..." } else { "Rebuilding Cache & Explorer..." }
    Write-LeftConsoleProgress $msgRebuild $cYellow
    Run-And-LogCommand "taskkill" "/f /im explorer.exe" | Out-Null
    Start-Sleep -Seconds 1
    Remove-Item "$env:localappdata\IconCache.db" -Force -EA SilentlyContinue
    Remove-Item "$env:localappdata\Microsoft\Windows\Explorer\thumbcache_*.db" -Force -EA SilentlyContinue
    Start-Process explorer.exe
    if ($isAdmin) {
        Run-And-LogCommand "net" "stop WSearch" | Out-Null
        Run-And-LogCommand "net" "start WSearch" | Out-Null
    }
    Update-LeftConsoleLine (T " [OK] Đã dọn bộ đệm biểu tượng & hệ thống xong." " [OK] Rebuild cache finished.") $cGreen
    Write-RightLog "DECLARED" (T "Đã làm mới bộ đệm biểu tượng & khởi động lại Explorer" "Cleared IconCache & Restarted Explorer") $cGreen
    Set-Activity "OK" (T "Hoàn thành: Dọn bộ nhớ đệm" "Done: Rebuild Caches") $cGreen
    Wait-LeftReturn
}

# --- [3.6] Visual Effects Options ---
function Invoke-VisualEffects() {
    Write-DebugLog "&&" "[3.6] Invoking Visual Effects Options..."

    while ($true) {
        Start-ActionView "HIỆU ỨNG HÌNH ẢNH" $cCyan "VISUAL EFFECTS"

        $curSetting = -1
        try {
            $curSetting = (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFxSetting" -ErrorAction SilentlyContinue).VisualFxSetting
        } catch {}

        $curName = if ($curSetting -eq 2) {
            T "Hiệu năng tối đa" "Best Performance"
        } elseif ($curSetting -eq 3) {
            T "Tối ưu không vỡ phông chữ" "Smooth Fonts"
        } elseif ($curSetting -eq 0) {
            T "Mặc định Windows" "Windows Default"
        } elseif ($curSetting -eq 1) {
            T "Giao diện đẹp nhất" "Best Appearance"
        } else {
            T "Chưa thiết lập" "Not Configured"
        }

        Write-LeftConsole (T " [i] Trạng thái: $curName" " [i] Status: $curName") $cCyan
        Write-LeftConsole ""

        $tag1 = if ($curSetting -eq 2) { " (#)" } else { "" }
        $tag2 = if ($curSetting -eq 3) { " (#)" } else { "" }
        $tag3 = if ($curSetting -eq 0) { " (#)" } else { "" }
        $tag4 = if ($curSetting -eq 1) { " (#)" } else { "" }

        Write-LeftConsole " [1] $(T 'Hiệu năng tối đa' 'Best Performance')$tag1" $(if ($curSetting -eq 2) { $cGreen } else { $cWhite })
        Write-LeftConsole " [2] $(T 'Tối ưu không vỡ phông chữ' 'Smooth Fonts')$tag2" $(if ($curSetting -eq 3) { $cGreen } else { $cWhite })
        Write-LeftConsole " [3] $(T 'Mặc định Windows' 'Windows Default')$tag3" $(if ($curSetting -eq 0) { $cGreen } else { $cWhite })
        Write-LeftConsole " [4] $(T 'Giao diện đẹp nhất' 'Best Appearance')$tag4" $(if ($curSetting -eq 1) { $cGreen } else { $cWhite })

        $v = Wait-SingleKey (T "Chọn tùy chọn [1-4]" "Select option [1-4]") @("1","2","3","4","Q")
        if (-not $v -or $v -in @("Q", "ESC") -or $script:lastActionEscPressed) { break }

        if ($v -in @("1","2","3","4")) {
            $setting = if ($v -eq "1") { 2 } elseif ($v -eq "2") { 3 } elseif ($v -eq "3") { 0 } else { 1 }
            if ($curSetting -eq $setting) {
                Write-LeftConsole ""
                Write-LeftConsole (T " [i] Đang ở chế độ này." " [i] Already in this mode.") $cYellow
                Start-Sleep -Milliseconds 600
                continue
            }

            Write-LeftConsoleProgress (T "Đang áp dụng hiệu ứng hình ảnh..." "Applying visual effects...") $cYellow
            Write-RightLog "IN" (T "Đang đặt VisualFxSetting thành $setting..." "Setting VisualFxSetting to $setting...") $cYellow
            Run-And-LogCommand "reg" "add `"HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects`" /v `"VisualFxSetting`" /t REG_DWORD /d $setting /f" | Out-Null
            try {
                if ($setting -eq 2) {
                    # Performance mode: disable animations and listview effects
                    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAnimations" -Value 0 -Type DWord -Force -EA SilentlyContinue
                    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ListviewAlphaSelect" -Value 0 -Type DWord -Force -EA SilentlyContinue
                    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ListviewShadow" -Value 0 -Type DWord -Force -EA SilentlyContinue
                } elseif ($setting -eq 3) {
                    # Smooth fonts mode: keep font smoothing, turn off heavy animations
                    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "FontSmoothing" -Value "2" -Type String -Force -EA SilentlyContinue
                    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "FontSmoothingType" -Value 2 -Type DWord -Force -EA SilentlyContinue
                    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAnimations" -Value 0 -Type DWord -Force -EA SilentlyContinue
                } elseif ($setting -eq 1) {
                    # Best appearance mode: enable animations
                    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAnimations" -Value 1 -Type DWord -Force -EA SilentlyContinue
                    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ListviewAlphaSelect" -Value 1 -Type DWord -Force -EA SilentlyContinue
                    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ListviewShadow" -Value 1 -Type DWord -Force -EA SilentlyContinue
                }
            } catch {}
            Update-LeftConsoleLine (T " [OK] Đã cập nhật hiệu ứng hình ảnh." " [OK] Visual effects updated.") $cGreen
            Write-RightLog "OUT" (T "Đã cập nhật giá trị registry VisualFxSetting thành $setting" "Updated VisualFxSetting registry value to $setting") $cWhite
            Set-Activity "OK" (T "Đã áp dụng: Hiệu ứng hình ảnh" "Applied: Visual Effects") $cGreen
            Start-Sleep -Milliseconds 700
        }
    }
}

# --- [3.7] Win 11 Classic Context Menu ---
function Invoke-ToggleContextMenu() {
    Write-DebugLog "&&" "[3.7] Invoking Toggle Windows 11 Classic Context Menu..."
    $regP = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}"

    while ($true) {
        Start-ActionView "MENU CHUỘT PHẢI WINDOWS 11" $cCyan "WINDOWS 11 CONTEXT MENU"

        $isClassic = Test-Path $regP
        $statText = if ($isClassic) {
            T "Menu cổ điển Windows 10" "Windows 10 Classic Menu"
        } else {
            T "Mặc định Windows 11" "Windows 11 Default Menu"
        }

        Write-LeftConsole " $(T 'Trạng thái' 'Status   '): $statText" $(if ($isClassic) { $cCyan } else { $cGreen })
        Write-LeftConsole ""

        $tag1 = if ($isClassic) { " (#)" } else { "" }
        $tag2 = if (-not $isClassic) { " (#)" } else { "" }

        Write-LeftConsole " [1] $(T 'Bật Menu cổ điển Windows 10' 'Enable Windows 10 Classic Menu')$tag1" $(if ($isClassic) { $cGreen } else { $cWhite })
        Write-LeftConsole " [2] $(T 'Khôi phục Menu mặc định Windows 11' 'Restore Windows 11 Default Menu')$tag2" $(if (-not $isClassic) { $cGreen } else { $cWhite })

        $choice = Wait-SingleKey (T "Chọn tùy chọn [1-2]" "Select option [1-2]") @('1', '2', 'Q')
        if (-not $choice -or $choice -in @('Q', 'ESC') -or $script:lastActionEscPressed) { break }

        if ($choice -eq '1') {
            if ($isClassic) {
                Write-LeftConsole ""
                Write-LeftConsole (T " [i] Đang sử dụng Menu cổ điển Windows 10." " [i] Already using Windows 10 Classic Menu.") $cYellow
                Start-Sleep -Milliseconds 600
                continue
            }
            Write-RightLog "IN" (T "Đang bật Menu chuột phải cổ điển Windows 10..." "Enabling Windows 10 Classic Context Menu...") $cYellow
            New-Item -Path "$regP\InprocServer32" -Force | Out-Null
            Write-LeftConsole (T " [OK] Đã bật Menu cổ điển Windows 10." " [OK] Enabled Windows 10 Classic Menu.") $cGreen
            Write-RightLog "OUT" (T "Đã bật Menu chuột phải cổ điển Windows 10" "Enabled Windows 10 Classic Context Menu") $cWhite
            Set-Activity "OK" (T "Menu cổ điển Windows 10" "Win 10 Classic Menu") $cGreen
        } elseif ($choice -eq '2') {
            if (-not $isClassic) {
                Write-LeftConsole ""
                Write-LeftConsole (T " [i] Đang sử dụng Menu mặc định Windows 11." " [i] Already using Windows 11 Default Menu.") $cYellow
                Start-Sleep -Milliseconds 600
                continue
            }
            Write-RightLog "IN" (T "Đang khôi phục Menu chuột phải mặc định Windows 11..." "Restoring Windows 11 Context Menu...") $cYellow
            Remove-Item $regP -Recurse -Force -EA SilentlyContinue
            Write-LeftConsole (T " [OK] Đã khôi phục Menu mặc định Windows 11." " [OK] Restored Windows 11 Default Menu.") $cGreen
            Write-RightLog "OUT" (T "Đã khôi phục Menu chuột phải mặc định Windows 11" "Restored Windows 11 Default Context Menu") $cWhite
            Set-Activity "OK" (T "Menu mặc định Windows 11" "Win 11 Default Menu") $cGreen
        }

        Write-LeftConsole ""
        $ansRestart = Wait-SingleKey (T "Khởi động lại Explorer ngay?" "Restart Explorer now?") @('Y','N')
        if ($ansRestart -eq "Y") {
            Write-LeftConsole (T " [>>] Đang khởi động lại Explorer..." " [>>] Restarting Explorer...") $cYellow
            Run-And-LogCommand "taskkill" "/f /im explorer.exe" | Out-Null
            Start-Sleep -Seconds 1
            Start-Process explorer.exe
            Write-LeftConsole (T " [OK] Đã khởi động lại Explorer!" " [OK] Explorer restarted!") $cGreen
            Start-Sleep -Milliseconds 800
        } else {
            Write-LeftConsole (T " [i] Bỏ qua khởi động lại Explorer." " [i] Skipped Explorer restart.") $cYellow
            Start-Sleep -Milliseconds 600
        }
    }
}

# --- [3.8] Wipe Free Space ---
function Invoke-WipeFreeSpace() {
    Write-DebugLog "&&" "[3.8] Invoking Wipe Free Space on drive: $global:targetDrive"
    if (-not (Require-ExpertOrBlock "GHI ĐÈ DUNG LƯỢNG TRỐNG" "WIPE FREE SPACE")) { return }
    if (-not (Require-AdminOrPrompt "GHI ĐÈ DUNG LƯỢNG TRỐNG" "WIPE FREE SPACE")) { return }
    Start-ActionView "GHI ĐÈ DUNG LƯỢNG TRỐNG" $cRed "WIPE FREE SPACE"
    Write-LeftConsole (T " [!] CẢNH BÁO: Thao tác ghi đè vĩnh viễn dữ liệu trống!" " [!] WARNING: Permanent wipe of free drive space!") $cRed
    Write-LeftConsole (T " [i] KHUYÊN DÙNG: Chỉ dùng cho ổ cứng HDD truyền thống." " [i] NOTICE: Recommended for traditional HDDs only.") $cYellow
    Write-LeftConsole (T "     KHÔNG nên dùng cho SSD/NVMe (làm hao mòn chip nhớ flash)." "     Do NOT use on SSD/NVMe (causes unnecessary flash wear).") $cYellow
    $conf = Get-LeftInput (T "Gõ 'WIPE' để xác nhận" "Type 'WIPE' to confirm")
    if ($conf -ne "WIPE") { return }
    $drivesToWipe = if ($global:targetDrive -eq "ALL") {
        @([System.IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq 'Fixed' -and $_.IsReady } | ForEach-Object { $_.Name.TrimEnd('\') })
    } else {
        @($global:targetDrive)
    }
    $wipeCancelled = $false
    foreach ($d in $drivesToWipe) {
        Write-LeftConsoleProgress (T "Đang ghi đè dung lượng trống ổ $d\..." "Wiping Free Space $d\...") $cYellow
        $wipeResult = Run-And-LogCommand "cipher" "/w:$d\"
        if ($wipeResult -eq -1 -or $script:stopRequested) {
            $wipeCancelled = $true
            Write-LeftConsole (T " [-] Đã hủy ghi đè ổ $d." " [-] Wipe cancelled for $d.") $cYellow
            break
        }
        Update-LeftConsoleLine (T " [OK] Đã ghi đè dung lượng trống ổ $d." " [OK] Disk wipe complete for $d.") $cGreen
    }
    if ($wipeCancelled) {
        Set-Activity "!" (T "Đã dừng: Ghi đè dung lượng trống" "Stopped: Wipe Free Space") $cYellow
    } else {
        Set-Activity "OK" (T "Hoàn thành: Ghi đè dung lượng trống" "Done: Wipe Free Space") $cGreen
    }
    Wait-LeftReturn
}

# -------------------------------------------------------------------------------
#  SECTION 7.3: SYSTEM UTILITIES & POWER TOOLS (MENU [4])
# -------------------------------------------------------------------------------

# --- [4.1] Unified System & License Info Center ---
function Invoke-SystemLicenseCenter() {
    Write-DebugLog "&&" "[4.1] Invoking Unified System & License Info Center..."
    Start-ActionView "HỆ THỐNG & BẢN QUYỀN" $cCyan "SYSTEM & LICENSE INFO"
    Write-RightLog "IN" (T "Đang mở Thông tin Hệ thống & Bản quyền..." "Opening System & License Info...") $cYellow

    Get-TermSize

    # Ensure Console Mouse mode
    $hInput = [ConsoleMouse]::GetStdHandle([ConsoleMouse]::STD_INPUT_HANDLE)
    try {
        $inMode = 0
        [ConsoleMouse]::GetConsoleMode($hInput, [ref]$inMode) | Out-Null
        $inMode = ($inMode -band (-bnot [ConsoleMouse]::ENABLE_QUICK_EDIT_MODE)) -bor [ConsoleMouse]::ENABLE_MOUSE_INPUT -bor [ConsoleMouse]::ENABLE_EXTENDED_FLAGS
        [ConsoleMouse]::SetConsoleMode($hInput, $inMode) | Out-Null
        [ConsoleMouse]::FlushConsoleInputBuffer($hInput) | Out-Null
    } catch {}

    $spChars = if ($global:spinnerChars -and $global:spinnerChars.Count -gt 0) { $global:spinnerChars } else { @('⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏') }
    $spInit = $spChars[0]

    # --- Section States & Async Results ---
    $script:winLoading = $true
    $script:winResultObj = $null
    $script:winStatusText = ""
    $script:winIsLicensed = $false

    $script:hwLoading = $true
    $script:hwScanData = $null
    $hwItems = [System.Collections.Generic.List[PSCustomObject]]::new()

    $script:officeLoading = $true
    $script:officeResultObj = $null
    $script:officeStatusText = ""
    $script:officeFound = $false
    $script:officeIsLicensed = $false
    $script:officeKey5 = ""
    $script:officeVbsPath = ""
    $script:confirmUninstallOffice = $false
    $script:confirmUninstallOfficeTick = 0

    # --- Launch Async Tasks ---
    # Task 1: Windows License async
    $winScript = @'
$res = [PSCustomObject]@{ Status = "Chưa kích hoạt"; Channel = "Unknown"; Expiry = ""; Key5 = ""; IsLicensed = $false }
try {
    $dli = cscript //nologo "$env:windir\System32\slmgr.vbs" /dli 2>$null
    foreach ($l in $dli) {
        if ($l -match '(?i)(?:License Status|Trạng thái [Gg]iấy phép):\s*(.+)') {
            $s = $matches[1].Trim()
            $res.Status = $s
            if ($s -match '(?i)Licensed|Đã có giấy phép|Đã kích hoạt') { $res.IsLicensed = $true }
        }
        if ($l -match '(?i)(?:Description|Mô tả|Mo ta):\s*(.+)') { $res.Channel = $matches[1].Trim() }
        if ($l -match '(?i)(?:Partial Product Key|Khóa [Ss]ản phẩm [Mm]ột phần):\s*(.+)') { $res.Key5 = $matches[1].Trim() }
    }
    $xpr = cscript //nologo "$env:windir\System32\slmgr.vbs" /xpr 2>$null
    $xLine = ($xpr -join ' ').Trim()
    if ($xLine -match '(?i)permanently|vĩnh viễn') { $res.Expiry = "Vĩnh viễn" }
    elseif ($xLine -match '(\d{1,2}/\d{1,2}/\d{4}|\d{4}-\d{2}-\d{2})') { $res.Expiry = $matches[1] }
    elseif ($xLine) { $res.Expiry = $xLine }
} catch {}
return $res
'@
    $psWin = [powershell]::Create()
    $null = $psWin.AddScript($winScript)
    $asyncWin = $psWin.BeginInvoke()

    # Task 2: Hardware Scan async
    $hwScanCode = @'
$os = $null; try { $os = Get-CimInstance Win32_OperatingSystem -EA SilentlyContinue } catch {}
$cs = $null; try { $cs = Get-CimInstance Win32_ComputerSystem -EA SilentlyContinue } catch {}
$bios = $null; try { $bios = Get-CimInstance Win32_BIOS -EA SilentlyContinue } catch {}
$cpu = $null; try { $cpu = Get-CimInstance Win32_Processor -EA SilentlyContinue | Select-Object -First 1 } catch {}
$gpus = @(); try { $gpus = @(Get-CimInstance Win32_VideoController -EA SilentlyContinue | Where-Object { $_.Caption }) } catch {}

$regNT = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -EA SilentlyContinue
$regBios = Get-ItemProperty "HKLM:\HARDWARE\DESCRIPTION\System\BIOS" -EA SilentlyContinue
$regCpu = Get-ItemProperty "HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor\0" -EA SilentlyContinue

$osCaption = if ($os -and $os.Caption) { $os.Caption } else {
    $prod = if ($regNT) { $regNT.ProductName } else { "Windows" }
    $dispVer = if ($regNT) { $regNT.DisplayVersion } else { "" }
    "$prod $dispVer".Trim()
}
$osVer = if ($os -and $os.Version) { $os.Version } elseif ($regNT) { "$($regNT.CurrentMajorVersionNumber).$($regNT.CurrentMinorVersionNumber).$($regNT.CurrentBuildNumber)" } else { [System.Environment]::OSVersion.Version.ToString() }
$buildLab = if ($regNT -and $regNT.BuildLabEx) { $regNT.BuildLabEx } elseif ($regNT -and $regNT.BuildLab) { $regNT.BuildLab } else { "" }
if ($buildLab -and $buildLab -match '^(\d+)\.') { $osVer += " Build $($matches[1])" }

$sysName = if ($cs -and $cs.Name) { $cs.Name } else { $env:COMPUTERNAME }
$sysModel = if ($cs -and $cs.Model) { $cs.Model } elseif ($regBios -and $regBios.SystemProductName) { $regBios.SystemProductName } else { "Unknown" }
$sysMfr = if ($cs -and $cs.Manufacturer) { $cs.Manufacturer } elseif ($regBios -and $regBios.SystemManufacturer) { $regBios.SystemManufacturer } else { "Unknown" }
$sysType = if ($cs -and $cs.SystemType) { $cs.SystemType } else { if ([Environment]::Is64BitOperatingSystem) { "x64-based PC" } else { "x86-based PC" } }

$cpuName = if ($cpu -and $cpu.Name) { $cpu.Name } elseif ($regCpu -and $regCpu.ProcessorNameString) { $regCpu.ProcessorNameString.Trim() } else { $env:PROCESSOR_IDENTIFIER }
$gpuList = @()
if ($gpus.Count -gt 0) {
    foreach ($g in $gpus) { if ($g.Caption) { $gpuList += $g.Caption.Trim() } }
}
if ($gpuList.Count -eq 0) { $gpuList += "Default Display Adapter" }

$ramTotal = if ($cs -and $cs.TotalPhysicalMemory) { [math]::Round($cs.TotalPhysicalMemory / 1GB, 2) } else { 0 }
$ramAvail = if ($os -and $os.FreePhysicalMemory) { [math]::Round($os.FreePhysicalMemory / 1MB, 2) } else { 0 }

$biosVendor = if ($bios -and $bios.Manufacturer) { $bios.Manufacturer } elseif ($regBios -and $regBios.BIOSVendor) { $regBios.BIOSVendor } else { "" }
$biosVerNum = if ($bios -and $bios.SMBIOSBIOSVersion) { $bios.SMBIOSBIOSVersion } elseif ($regBios -and $regBios.BIOSVersion) { "$($regBios.BIOSVersion)".Trim() } else { "" }
$biosDate = if ($bios -and $bios.ReleaseDate) { (Get-Date $bios.ReleaseDate -Format "MM/dd/yyyy") } elseif ($regBios -and $regBios.BIOSReleaseDate) { "$($regBios.BIOSReleaseDate)".Trim() } else { "" }
$biosStr = "$biosVendor $biosVerNum" + $(if ($biosDate) { ", $biosDate" } else { "" })

$biosMode = "Legacy"
if ($env:firmware_type) { $biosMode = $env:firmware_type }
elseif (Test-Path "HKLM:\System\CurrentControlSet\Control\SystemInformation") {
    $bm = (Get-ItemProperty "HKLM:\System\CurrentControlSet\Control\SystemInformation" -Name BiosMode -EA SilentlyContinue).BiosMode
    if ($bm -eq 2) { $biosMode = "UEFI" }
}

$secureBoot = "Off"
try { if (Confirm-SecureBootUEFI -EA SilentlyContinue) { $secureBoot = "On" } } catch {
    $sbReg = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State" -Name UEFISecureBootEnabled -EA SilentlyContinue).UEFISecureBootEnabled
    if ($sbReg -eq 1) { $secureBoot = "On" }
}

$locale = [System.Globalization.RegionInfo]::CurrentRegion.EnglishName
if (-not $locale) { $locale = (Get-Culture).EnglishName }
$timeZone = [System.TimeZoneInfo]::Local.StandardName

$pnpGPU = @()
try {
    $gpuDevs = Get-PnpDevice -Class Display -PresentOnly -EA SilentlyContinue | Where-Object { $_.InstanceId }
    foreach ($dev in $gpuDevs) { $pnpGPU += $dev.InstanceId }
} catch {}

$pnpCPU = ""
try {
    $pnpDev = Get-PnpDevice -Class Processor -PresentOnly -EA SilentlyContinue | Where-Object { $_.InstanceId } | Select-Object -First 1
    if ($pnpDev) { $pnpCPU = $pnpDev.InstanceId }
} catch {}

[PSCustomObject]@{
    OSName      = $osCaption
    Version     = $osVer
    SysName     = $sysName
    SysModel    = $sysModel
    SysMfr      = $sysMfr
    SysType     = $sysType
    CPUName     = $cpuName
    GPUs        = $gpuList
    RAMTotal    = $ramTotal
    RAMAvail    = $ramAvail
    BIOSVer     = $biosStr
    BIOSMode    = $biosMode
    SecureBoot  = $secureBoot
    Locale      = $locale
    TimeZone    = $timeZone
    PnpGPU      = $pnpGPU
    PnpCPU      = $pnpCPU
}
'@
    $psHw = [powershell]::Create()
    $null = $psHw.AddScript($hwScanCode)
    $asyncHw = $psHw.BeginInvoke()

    # Task 3: Office License async
    $officeScanCode = @'
$res = [PSCustomObject]@{ Found = $false; Name = ""; Status = ""; Key5 = ""; Grace = ""; IsLicensed = $false; VbsPath = "" }
$candidatePaths = @(
    "C:\Program Files\Microsoft Office\Office16\ospp.vbs",
    "C:\Program Files (x86)\Microsoft Office\Office16\ospp.vbs",
    "C:\Program Files\Microsoft Office\root\Office16\ospp.vbs",
    "C:\Program Files (x86)\Microsoft Office\root\Office16\ospp.vbs",
    "C:\Program Files\Microsoft Office\Office15\ospp.vbs",
    "C:\Program Files (x86)\Microsoft Office\Office15\ospp.vbs",
    "C:\Program Files\Microsoft Office\Office14\ospp.vbs",
    "C:\Program Files (x86)\Microsoft Office\Office14\ospp.vbs"
)
foreach ($cp in $candidatePaths) {
    if (Test-Path $cp) { $res.VbsPath = $cp; break }
}
if ($res.VbsPath) {
    try {
        $out = cscript //nologo "$($res.VbsPath)" /dstatus 2>$null
        foreach ($line in $out) {
            if ($line -match '(?i)(?:LICENSE NAME|Tên gói|Tên giấy phép):\s*(.+)') {
                $res.Name = $matches[1].Trim()
                $res.Found = $true
            }
            if ($line -match '(?i)(?:LICENSE STATUS|Trạng thái giấy phép):\s*(.+)') {
                $s = $matches[1].Trim()
                $res.Status = $s
                if ($s -match '(?i)LICENSED|ĐÃ CÓ GIẤY PHÉP|ĐÃ KÍCH HOẠT') { $res.IsLicensed = $true }
            }
            if ($line -match '(?i)(?:Last 5 characters of installed product key|5 ký tự cuối của khóa):\s*([A-Za-z0-9]{5})') {
                $res.Key5 = $matches[1].Trim()
                $res.Found = $true
            }
            if ($line -match '(?i)(?:REMAINING GRACE|Thời gian ân hạn):\s*(.+)') {
                $res.Grace = $matches[1].Trim()
            }
        }
    } catch {}
}
return $res
'@
    $psOffice = [powershell]::Create()
    $null = $psOffice.AddScript($officeScanCode)
    $asyncOffice = $psOffice.BeginInvoke()

    # --- Interactive State Variables ---
    $hwHorizOffset = 0
    $hwVertOffset = 0
    $hoverControl = "NONE"
    $hoverHwRow = -1
    $flashHwRow = -1
    $flashTick = 0
    $isDraggingHScroll = $false
    $spinIdx = 0
    $lastSpinTick = [Environment]::TickCount

    function Local:Calc-MaxHwHoriz() {
        $maxLen = 0
        foreach ($it in $hwItems) {
            $vStr = [string]$it.Value
            if ($vStr.Length -gt $maxLen) { $maxLen = $vStr.Length }
        }
        $valCols = 27
        return [math]::Max(0, $maxLen - $valCols)
    }

    # --- Dynamic Multi-Language String Builder ---
    function Local:Update-SystemLicenseStrings() {
        $isVi = ($global:selectedLang -eq "Vietnamese")
        $spChar = $spChars[$spinIdx % $spChars.Count]

        # 1. Windows License String (Clean compact badge, no trailing cutoffs)
        if ($script:winLoading) {
            $script:winStatusText = if ($isVi) { "[$spChar] Đang kiểm tra..." } else { "[$spChar] Checking..." }
        } elseif ($script:winResultObj) {
            $script:winIsLicensed = ($script:winResultObj.IsLicensed -eq $true)
            $statStr = if ($script:winIsLicensed) { if ($isVi) { "Đã kích hoạt" } else { "Licensed" } } else { if ($isVi) { "Chưa kích hoạt" } else { "Unlicensed" } }
            $script:winStatusText = "[$statStr]"
        } else {
            $script:winStatusText = if ($isVi) { "Không xác định" } else { "Unknown" }
        }

        # 2. Hardware Scan Items List
        if ($script:hwLoading) {
            $hwItems.Clear()
            $hwItems.Add([PSCustomObject]@{
                Label = if ($isVi) { "Phần cứng" } else { "Hardware" }
                Value = if ($isVi) { "[$spChar] Đang quét phần cứng chi tiết..." } else { "[$spChar] Scanning detailed hardware..." }
                ValColor = $cYellow
            })
        } elseif ($script:hwScanData) {
            $hw = $script:hwScanData
            $hwItems.Clear()
            $hwItems.Add([PSCustomObject]@{ Label = if ($isVi) { "Tên HĐH" } else { "OS Name" }; Value = "$($hw.OSName)"; ValColor = $cWhite })
            if ($hw.Version) { $hwItems.Add([PSCustomObject]@{ Label = if ($isVi) { "Phiên bản" } else { "Version" }; Value = "$($hw.Version)"; ValColor = $cWhite }) }
            $hwItems.Add([PSCustomObject]@{ Label = if ($isVi) { "Tên máy" } else { "System Name" }; Value = "$($hw.SysName)"; ValColor = $cLightCyan })
            $hwItems.Add([PSCustomObject]@{ Label = if ($isVi) { "Dòng máy" } else { "System Model" }; Value = "$($hw.SysModel)"; ValColor = $cLightCyan })
            $hwItems.Add([PSCustomObject]@{ Label = if ($isVi) { "Hãng SX" } else { "System Mfr" }; Value = "$($hw.SysMfr)"; ValColor = $cLightCyan })
            $hwItems.Add([PSCustomObject]@{ Label = if ($isVi) { "Kiểu máy" } else { "System Type" }; Value = "$($hw.SysType)"; ValColor = $cLightCyan })
            $hwItems.Add([PSCustomObject]@{ Label = "CPU"; Value = "$($hw.CPUName)"; ValColor = $cLightGreen })
            foreach ($g in $hw.GPUs) {
                $hwItems.Add([PSCustomObject]@{ Label = "GPU"; Value = "$g"; ValColor = $cLightGreen })
            }
            $hwItems.Add([PSCustomObject]@{ Label = "RAM"; Value = "$($hw.RAMTotal) GB Total / $($hw.RAMAvail) GB Free"; ValColor = $cLightGreen })
            $hwItems.Add([PSCustomObject]@{ Label = if ($isVi) { "Bản BIOS" } else { "BIOS Ver" }; Value = "$($hw.BIOSVer)"; ValColor = $cLightCyan })
            $hwItems.Add([PSCustomObject]@{ Label = if ($isVi) { "Chế độ BIOS" } else { "BIOS Mode" }; Value = "$($hw.BIOSMode)"; ValColor = $cLightCyan })
            $secVal = if ($isVi) { if ($hw.SecureBoot -eq "On") { "Bật" } else { "Tắt" } } else { $hw.SecureBoot }
            $hwItems.Add([PSCustomObject]@{ Label = "SecureBoot"; Value = "$secVal"; ValColor = $(if ($hw.SecureBoot -eq "On") { $cGreen } else { $cYellow }) })
            $hwItems.Add([PSCustomObject]@{ Label = if ($isVi) { "Khu vực" } else { "Locale" }; Value = "$($hw.Locale)"; ValColor = $cWhite })
            $hwItems.Add([PSCustomObject]@{ Label = if ($isVi) { "Múi giờ" } else { "Time Zone" }; Value = "$($hw.TimeZone)"; ValColor = $cWhite })
            foreach ($g in $hw.PnpGPU) {
                $hwItems.Add([PSCustomObject]@{ Label = if ($isVi) { "Mã GPU" } else { "GPU ID" }; Value = "$g"; ValColor = $cGray })
            }
            if ($hw.PnpCPU) {
                $hwItems.Add([PSCustomObject]@{ Label = if ($isVi) { "Mã CPU" } else { "CPU ID" }; Value = "$($hw.PnpCPU)"; ValColor = $cGray })
            }
        }

        # 3. Office License String
        if ($script:officeLoading) {
            $script:officeStatusText = if ($isVi) { "[$spChar] Đang kiểm tra..." } else { "[$spChar] Checking..." }
        } elseif ($script:officeResultObj -and $script:officeResultObj.Found) {
            $script:officeFound = $true
            $script:officeIsLicensed = ($script:officeResultObj.IsLicensed -eq $true)
            $script:officeKey5 = $script:officeResultObj.Key5
            $script:officeVbsPath = $script:officeResultObj.VbsPath
            $oStatStr = if ($script:officeIsLicensed) { if ($isVi) { "Đã kích hoạt" } else { "Licensed" } } else { if ($isVi) { "Chưa kích hoạt" } else { "Unlicensed" } }
            $kStr = if ($script:officeKey5) { " (****-$($script:officeKey5))" } else { "" }
            $script:officeStatusText = "[$oStatStr]$kStr"
        } else {
            $script:officeFound = $false
            $script:officeStatusText = if ($isVi) { "Chưa cài đặt" } else { "Not installed" }
        }
    }

    Update-SystemLicenseStrings

    # --- Custom Renderer ---
    function Local:Render-SystemLicenseView() {
        Get-TermSize
        $script:sysLeftH = [math]::Max(5, $script:termH - 4)
        $isVi = ($global:selectedLang -eq "Vietnamese")
        $width = 38
        $maxHwHorizOffset = Calc-MaxHwHoriz

        # ==============================================================================
        # 1. Row Y = 5: Top Section (Windows License + Battery Button without emoji)
        # ==============================================================================
        Set-CursorPos 2 5
        $winTag = "Win : "
        $winStatDisp = $script:winStatusText
        $winColor = if ($script:winLoading) { $cYellow }
                    elseif ($script:winIsLicensed) { $cGreen }
                    else { $cRed }

        $btnBatText = if ($isVi) { "[ Báo cáo Pin ]" } else { "[ Battery Report ]" }
        $batStyle = if ($hoverControl -eq "BATTERY_BTN") {
            "$ESC[48;2;40;110;170m$ESC[38;2;255;255;255m$btnBatText$cReset"
        } else {
            "$cPurp$btnBatText$cReset"
        }

        $availWinW = [math]::Max(8, $width - $btnBatText.Length - 1 - $winTag.Length)
        $winSlice = if ($winStatDisp.Length -gt $availWinW) { $winStatDisp.Substring(0, $availWinW) } else { $winStatDisp.PadRight($availWinW) }
        Write-Host "$cCyan$winTag$cReset$winColor$winSlice$cReset $batStyle" -NoNewline

        # ==============================================================================
        # 2. Row Y = 6: Separator Line
        # ==============================================================================
        Set-CursorPos 2 6
        Write-Host ("$cDim" + ($chrLine * $width) + "$cReset") -NoNewline

        # ==============================================================================
        # Layout Math: Anchor Hints & Office at Bottom
        # ==============================================================================
        $hintY = $script:sysLeftH + 1
        $officeRowY = $script:sysLeftH
        $sepOfficeY = $officeRowY - 1
        $hScrollY = $sepOfficeY - 1

        $hwStartY = 7
        $hwHeight = [math]::Max(3, $hScrollY - $hwStartY)
        $maxVert = [math]::Max(0, $hwItems.Count - $hwHeight)
        if ($hwVertOffset -gt $maxVert) { $hwVertOffset = $maxVert; Set-Variable -Name hwVertOffset -Value $maxVert -Scope 1 }
        if ($hwVertOffset -lt 0) { $hwVertOffset = 0; Set-Variable -Name hwVertOffset -Value 0 -Scope 1 }

        # ==============================================================================
        # 3. Middle Section: Hardware Info Items (Always fully pad with cReset to clear hover)
        # ==============================================================================
        $valCols = 27
        for ($i = 0; $i -lt $hwHeight; $i++) {
            $dataIdx = $hwVertOffset + $i
            $rowY = $hwStartY + $i
            Set-CursorPos 2 $rowY

            if ($dataIdx -lt $hwItems.Count) {
                $item = $hwItems[$dataIdx]
                $isHoverThis = ($hoverHwRow -eq $dataIdx)
                $isFlashThis = ($flashHwRow -eq $dataIdx)

                $lblRaw = [string]$item.Label
                $lblTag = if ($lblRaw.Length -gt 9) { $lblRaw.Substring(0, 9) + ": " } else { $lblRaw.PadRight(9) + ": " }
                $valStr = [string]$item.Value
                $valSlice = Get-HorizSlice $valStr $hwHorizOffset $valCols
                $padLen = [math]::Max(0, $width - ($lblTag.Length + $valSlice.Length))
                $padSpaces = " " * $padLen

                if ($isFlashThis) {
                    $full = "$lblTag$valSlice$padSpaces"
                    Write-Host ("$ESC[48;2;30;85;45m$ESC[38;2;140;255;160m" + $full + "$cReset") -NoNewline
                } elseif ($isHoverThis) {
                    $full = "$lblTag$valSlice$padSpaces"
                    Write-Host ("$ESC[48;2;45;50;62m$ESC[38;2;255;255;255m" + $full + "$cReset") -NoNewline
                } else {
                    $vCol = if ($item.ValColor) { $item.ValColor } else { $cWhite }
                    Write-Host "$cCyan$lblTag$cReset$vCol$valSlice$cReset$padSpaces" -NoNewline
                }
            } else {
                Write-Host (" " * $width) -NoNewline
            }
        }

        # ==============================================================================
        # 4. Horizontal Scrollbar for Hardware Values (Dynamic calculation)
        # ==============================================================================
        Set-CursorPos 2 $hScrollY
        if ($maxHwHorizOffset -gt 0) {
            $trackW = $width - 2
            $travel = $trackW - 2
            $thumbPos = [math]::Round(($hwHorizOffset / $maxHwHorizOffset) * $travel)
            $thumbPos = [math]::Max(0, [math]::Min($travel, $thumbPos))
            $thumbCol = if ($hoverControl -eq "HSCROLL" -or $isDraggingHScroll) { "$ESC[38;2;255;255;255m" } else { $cCyan }
            $leftTrack = "$cDim" + ($chrLine * $thumbPos) + "$cReset"
            $thumbBlock = "$thumbCol" + ($chrHThumb * 2) + "$cReset"
            $rightTrack = "$cDim" + ($chrLine * ($travel - $thumbPos)) + "$cReset"
            Write-Host (" " + $leftTrack + $thumbBlock + $rightTrack + " ") -NoNewline
        } else {
            Write-Host (" " * $width) -NoNewline
        }

        # ==============================================================================
        # 5. Row above Office: Separator Line
        # ==============================================================================
        Set-CursorPos 2 $sepOfficeY
        Write-Host ("$cDim" + ($chrLine * $width) + "$cReset") -NoNewline

        # ==============================================================================
        # 6. Row Office License + Uninstall Button (Compact, 2-step confirm)
        # ==============================================================================
        Set-CursorPos 2 $officeRowY
        $offTag = "Office: "
        $offStatDisp = $script:officeStatusText
        $offColor = if ($script:officeLoading) { $cYellow }
                    elseif ($script:officeIsLicensed) { $cGreen }
                    elseif ($script:officeFound) { $cYellow }
                    else { $cDim }

        $btnOffText = if ($script:confirmUninstallOffice) {
            if ($isVi) { "[ ⚠️ Xác nhận gỡ? ]" } else { "[ ⚠️ Confirm? ]" }
        } else {
            if ($isVi) { "[ Gỡ mã key ]" } else { "[ Remove Key ]" }
        }

        $offBtnStyle = if (-not $script:officeFound -or $script:officeLoading) {
            "$cDim$btnOffText$cReset"
        } elseif ($script:confirmUninstallOffice) {
            "$ESC[48;2;190;30;30m$ESC[38;2;255;255;255m$btnOffText$cReset"
        } elseif ($hoverControl -eq "OFFICE_UNINSTALL") {
            "$ESC[48;2;170;40;40m$ESC[38;2;255;255;255m$btnOffText$cReset"
        } else {
            "$cRed$btnOffText$cReset"
        }

        $availOffW = [math]::Max(6, $width - $btnOffText.Length - 1 - $offTag.Length)
        $offSlice = if ($offStatDisp.Length -gt $availOffW) { $offStatDisp.Substring(0, $availOffW) } else { $offStatDisp.PadRight($availOffW) }
        Write-Host "$cCyan$offTag$cReset$offColor$offSlice$cReset $offBtnStyle" -NoNewline

        # ==============================================================================
        # 7. Hint Line Anchored at Bottom (Concise & strictly clamped to 38 cols)
        # ==============================================================================
        Set-CursorPos 2 $hintY
        $hintStr = if ($global:expertMode) {
            if ($isVi) { "[i] Bấm để copy | Cuộn: Lăn chuột" } else { "[i] Click to copy | Scroll: Wheel" }
        } else {
            if ($isVi) { "[i] Bấm để copy | Gỡ key: Cần Expert" } else { "[i] Click to copy | Key: Need Expert" }
        }
        $plain = $script:AnsiRegex.Replace($hintStr, '')
        if ($plain.Length -gt 38) { $hintStr = $hintStr.Substring(0, 38); $plain = $plain.Substring(0, 38) }
        $pad = " " * [math]::Max(0, 38 - $plain.Length)
        Write-Host "$cDim$hintStr$cReset$pad" -NoNewline

        Show-LeftBackButton
    }

    # Register instant global callback when language or expert mode is clicked
    $global:onLanguageChanged = {
        Update-SystemLicenseStrings
        Render-SystemLicenseView
        Draw-FooterBar
    }

    Render-SystemLicenseView

    # --- Event Loop ---
    $records = New-Object ConsoleMouse+INPUT_RECORD[] 64
    $wasLeft = $false
    $running = $true

    try {
        while ($running) {
            Start-Sleep -Milliseconds 25

            # Flash effect timeout
            if ($flashHwRow -ge 0 -and ([Environment]::TickCount - $flashTick) -gt 250) {
                $flashHwRow = -1
                Render-SystemLicenseView
            }
            # 2-step confirmation timeout (revert after 3.5 seconds)
            if ($script:confirmUninstallOffice -and ([Environment]::TickCount - $script:confirmUninstallOfficeTick) -gt 3500) {
                $script:confirmUninstallOffice = $false
                Render-SystemLicenseView
            }

            # Spinner & Async Task Poll (every 70ms)
            $nowTick = [Environment]::TickCount
            if (($nowTick - $lastSpinTick) -ge 70) {
                $lastSpinTick = $nowTick
                $spinIdx++
                $spChar = $spChars[$spinIdx % $spChars.Count]
                $needsRedraw = $false

                # 1. Check Windows Task
                if ($asyncWin -and $asyncWin.IsCompleted) {
                    try {
                        $wRes = $psWin.EndInvoke($asyncWin)
                        $script:winResultObj = $wRes
                    } catch {}
                    $script:winLoading = $false
                    try { $psWin.Dispose() } catch {}
                    $psWin = $null
                    $asyncWin = $null
                    $needsRedraw = $true
                } elseif ($script:winLoading) {
                    $needsRedraw = $true
                }

                # 2. Check Hardware Scan Task
                if ($asyncHw -and $asyncHw.IsCompleted) {
                    try {
                        $hwRes = $psHw.EndInvoke($asyncHw)
                        if ($hwRes -and $hwRes.Count -gt 0) {
                            $script:hwScanData = $hwRes[0]
                        }
                    } catch {}
                    $script:hwLoading = $false
                    try { $psHw.Dispose() } catch {}
                    $psHw = $null
                    $asyncHw = $null
                    $needsRedraw = $true
                } elseif ($script:hwLoading) {
                    $needsRedraw = $true
                }

                # 3. Check Office Task
                if ($asyncOffice -and $asyncOffice.IsCompleted) {
                    try {
                        $offRes = $psOffice.EndInvoke($asyncOffice)
                        $script:officeResultObj = $offRes
                    } catch {}
                    $script:officeLoading = $false
                    try { $psOffice.Dispose() } catch {}
                    $psOffice = $null
                    $asyncOffice = $null
                    $needsRedraw = $true
                } elseif ($script:officeLoading) {
                    $needsRedraw = $true
                }

                if ($needsRedraw) {
                    Update-SystemLicenseStrings
                    Render-SystemLicenseView
                }
            }

            # Poll Console Input Events
            [uint32]$eventsCount = 0
            [ConsoleMouse]::GetNumberOfConsoleInputEvents($hInput, [ref]$eventsCount) | Out-Null
            if ($eventsCount -le 0) { continue }
            [uint32]$toRead = [math]::Min([uint32]$records.Length, $eventsCount)
            [uint32]$read = 0
            [ConsoleMouse]::ReadConsoleInput($hInput, $records, $toRead, [ref]$read) | Out-Null

            for ($evIdx = 0; $evIdx -lt $read; $evIdx++) {
                $rec = $records[$evIdx]

                # 1. Resize Window
                if ($rec.EventType -eq 4) {
                    $script:termSizeDirty = $true
                    Get-TermSize -force
                    Draw-FullLayout $false
                    Render-SystemLicenseView
                    continue
                }

                # 2. Key Event (ESC to return)
                if ($rec.EventType -eq 1 -and $rec.KeyEvent.bKeyDown) {
                    $vk = $rec.KeyEvent.wVirtualKeyCode
                    if ($vk -eq 27) { # ESC
                        Write-RightLog "$" (T "Đã thoát Thông tin Hệ thống" "Exited System Info") $cDim
                        $running = $false
                        break
                    }
                    if ($vk -eq 38) { # UP
                        if ($hwVertOffset -gt 0) { $hwVertOffset--; Render-SystemLicenseView }
                        continue
                    }
                    if ($vk -eq 40) { # DOWN
                        $hwHeightCurr = [math]::Max(3, $script:sysLeftH - 3 - 7)
                        $maxV = [math]::Max(0, $hwItems.Count - $hwHeightCurr)
                        if ($hwVertOffset -lt $maxV) { $hwVertOffset++; Render-SystemLicenseView }
                        continue
                    }
                    if ($vk -eq 37) { # LEFT
                        if ($hwHorizOffset -gt 0) { $hwHorizOffset = [math]::Max(0, $hwHorizOffset - 2); Render-SystemLicenseView }
                        continue
                    }
                    if ($vk -eq 39) { # RIGHT
                        $dynMaxH = Calc-MaxHwHoriz
                        if ($hwHorizOffset -lt $dynMaxH) { $hwHorizOffset = [math]::Min($dynMaxH, $hwHorizOffset + 2); Render-SystemLicenseView }
                        continue
                    }
                }

                # 3. Mouse Event
                if ($rec.EventType -eq 2) {
                    $mEvent = $rec.MouseEvent
                    $posX = $mEvent.dwMousePosition.X
                    $posY = $mEvent.dwMousePosition.Y
                    $isLeft = (($mEvent.dwButtonState -band 1) -ne 0)
                    $isLeftClick = ($isLeft -and -not $wasLeft)
                    $wasLeft = $isLeft

                    $script:sysLeftH = [math]::Max(5, $script:termH - 4)
                    $officeRowYCoord = $script:sysLeftH
                    $sepOfficeYCoord = $officeRowYCoord - 1
                    $hScrollYCoord = $sepOfficeYCoord - 1
                    $hwHeightCurr = [math]::Max(3, $hScrollYCoord - 7)
                    $dynMaxH = Calc-MaxHwHoriz

                    $isVi = ($global:selectedLang -eq "Vietnamese")
                    $btnBatText = if ($isVi) { "[ Báo cáo Pin ]" } else { "[ Battery Report ]" }
                    $batStartX = 39 - $btnBatText.Length + 1

                    $btnOffText = if ($script:confirmUninstallOffice) {
                        if ($isVi) { "[ ⚠️ Xác nhận gỡ? ]" } else { "[ ⚠️ Confirm? ]" }
                    } else {
                        if ($isVi) { "[ Gỡ mã key ]" } else { "[ Remove Key ]" }
                    }
                    $offStartX = 39 - $btnOffText.Length + 1

                    # Mouse Wheel over middle hardware pane
                    if ($mEvent.dwEventFlags -eq 4) {
                        if ($posX -ge 1 -and $posX -le 42) {
                            $delta = [int]$mEvent.dwButtonState
                            $isOverH = ($posY -eq $hScrollYCoord)
                            $maxV = [math]::Max(0, $hwItems.Count - $hwHeightCurr)
                            if (Handle-ListMouseWheel $delta $isOverH ([ref]$hwVertOffset) ([ref]$hwHorizOffset) $maxV $dynMaxH 1 4) {
                                Render-SystemLicenseView
                            }
                            continue
                        }
                    }

                    if (Process-LogScrollEvents $mEvent) { continue }

                    # Global target hover
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

                    # Back Button / Breadcrumb click
                    if ($isLeftClick) {
                        if ($target -eq "BACK_BTN" -or $target.StartsWith("BREADCRUMB_")) {
                            Lock-Input 300
                            Write-RightLog "$" (T "Đã thoát Thông tin Hệ thống & Bản quyền" "Exited System & License Info") $cDim
                            $running = $false
                            break
                        }
                        $gClick = Handle-GlobalClick $posX $posY
                        if ($gClick -and $gClick -ne "NONE") {
                            if ($gClick -eq "BREADCRUMB_NAV") {
                                Write-RightLog "$" (T "Thoát qua Breadcrumb" "Exited via Breadcrumb") $cDim
                                $running = $false
                                break
                            }
                            if ($gClick -eq "LANG_CHANGED") {
                                Update-SystemLicenseStrings
                                Render-SystemLicenseView
                                Draw-FooterBar
                            }
                            continue
                        }
                    }

                    # Drag release on scrollbar
                    if (-not $isLeft -and $isDraggingHScroll) {
                        $isDraggingHScroll = $false
                        Render-SystemLicenseView
                    }

                    # Horizontal Scrollbar Click / Drag
                    $onHScroll = ($posX -ge 2 -and $posX -le 39 -and $posY -eq $hScrollYCoord)
                    if ($dynMaxH -gt 0) {
                        if ($isLeft -and ($onHScroll -or $isDraggingHScroll)) {
                            $isDraggingHScroll = $true
                            $clickCol = [math]::Max(2, [math]::Min(39, $posX))
                            $relX = $clickCol - 2
                            $targetRatio = [math]::Max(0.0, [math]::Min(1.0, $relX / 36.0))
                            $newOffset = [int][math]::Round($targetRatio * $dynMaxH)
                            if ($newOffset -ne $hwHorizOffset) {
                                $hwHorizOffset = $newOffset
                                Render-SystemLicenseView
                            }
                            continue
                        }
                    }

                    # Hit Detection for Controls
                    $newControl = "NONE"
                    $newHwHover = -1

                    # 1. Battery button (Row 5, col batStartX to 39)
                    if ($posY -eq 5 -and $posX -ge $batStartX -and $posX -le 39) {
                        $newControl = "BATTERY_BTN"
                    }
                    # 2. Office Uninstall button (Row officeRowYCoord, col offStartX to 39)
                    elseif ($posY -eq $officeRowYCoord -and $posX -ge $offStartX -and $posX -le 39 -and $script:officeFound -and -not $script:officeLoading) {
                        $newControl = "OFFICE_UNINSTALL"
                    }
                    # 3. Horizontal Scrollbar hover
                    elseif ($onHScroll -and $dynMaxH -gt 0) {
                        $newControl = "HSCROLL"
                    }
                    # 4. Hardware row hover
                    elseif ($posY -ge 7 -and $posY -lt (7 + $hwHeightCurr) -and $posX -ge 2 -and $posX -le 39) {
                        $rowRel = $posY - 7
                        $hIdx = $hwVertOffset + $rowRel
                        if ($hIdx -lt $hwItems.Count) {
                            $newHwHover = $hIdx
                        }
                    }

                    if ($newControl -ne $hoverControl -or $newHwHover -ne $hoverHwRow) {
                        $hoverControl = $newControl
                        $hoverHwRow = $newHwHover
                        Render-SystemLicenseView
                    }

                    # Battery Report Button Click (Unrestricted - anyone can view battery report)
                    if ($isLeftClick -and $newControl -eq "BATTERY_BTN") {
                        Write-RightLog "IN" (T "Đang tạo Báo cáo Pin Windows..." "Generating Windows Battery Report...") $cCyan
                        Set-Activity "RUN" (T "Đang xuất báo cáo pin..." "Generating battery report...") $cYellow
                        try {
                            $batReportPath = "$env:TEMP\battery-report.html"
                            Start-Process -FilePath "powercfg.exe" -ArgumentList "/batteryreport /output `"$batReportPath`"" -WindowStyle Hidden -Wait | Out-Null
                            if (Test-Path $batReportPath) {
                                Start-Process $batReportPath
                                Write-RightLog "OUT" (T "Đã mở Báo cáo Pin HTML: $batReportPath" "Opened Battery Report HTML: $batReportPath") $cGreen
                                Set-Activity "OK" (T "Đã mở báo cáo pin" "Battery Report Opened") $cGreen
                            } else {
                                Write-RightLog "WARN" (T "Hệ thống không tìm thấy pin hoặc không thể tạo báo cáo." "No battery detected or report generation failed.") $cYellow
                                Set-Activity "!" (T "Không tìm thấy pin" "No battery detected") $cYellow
                            }
                        } catch {
                            Write-RightLog "ERROR" (T "Lỗi khi tạo báo cáo pin: $_" "Error creating battery report: $_") $cRed
                        }
                        continue
                    }

                    # Office Uninstall Key Button Click (Protected by Expert Mode + Admin + 2-Step Confirmation)
                    if ($isLeftClick -and $newControl -eq "OFFICE_UNINSTALL") {
                        # 1. Permission check: Expert Mode
                        if (-not $global:expertMode) {
                            Write-RightLog "WARN" (T "Gỡ mã bản quyền Office yêu cầu Chế độ chuyên gia! Vui lòng bật [Expert Mode]." "Uninstalling Office key requires Expert Mode! Please enable [Expert Mode].") $cYellow
                            Set-Activity "!" (T "Yêu cầu Chế độ chuyên gia" "Expert Mode Required") $cYellow
                            continue
                        }

                        # 2. Permission check: Admin
                        if (-not $isAdmin) {
                            Write-RightLog "WARN" (T "Gỡ mã bản quyền Office yêu cầu quyền Administrator!" "Uninstalling Office key requires Administrator privileges!") $cRed
                            Set-Activity "!" (T "Yêu cầu quyền Admin" "Admin Privileges Required") $cRed
                            if (Require-AdminOrPrompt "GỠ MÃ KEY OFFICE" "UNINSTALL OFFICE KEY") {}
                            continue
                        }

                        # 3. Two-step confirmation: Prevent accidental click
                        $nowTick = [Environment]::TickCount
                        if (-not $script:confirmUninstallOffice -or ($nowTick - $script:confirmUninstallOfficeTick) -gt 3500) {
                            $script:confirmUninstallOffice = $true
                            $script:confirmUninstallOfficeTick = $nowTick
                            Write-RightLog "WARN" (T "Cảnh báo: Nhấp nút lần nữa trong 3 giây để xác nhận gỡ key Office ($script:officeKey5)." "Warning: Click button again within 3s to confirm Office key removal ($script:officeKey5).") $cYellow
                            Set-Activity "?" (T "Nhấp lại để xác nhận" "Click again to confirm") $cYellow
                            Render-SystemLicenseView
                            continue
                        }
                        $script:confirmUninstallOffice = $false

                        $k5 = $script:officeKey5
                        $vbs = $script:officeVbsPath
                        if ($k5 -and $vbs -and (Test-Path $vbs)) {
                            Write-RightLog "WARN" (T "Đang gỡ khóa bản quyền Office đuôi $k5..." "Uninstalling Office product key ending in $k5...") $cYellow
                            Set-Activity "RUN" (T "Đang gỡ mã key Office..." "Uninstalling Office key...") $cYellow
                            try {
                                $null = cscript //nologo "$vbs" /unpkey:$k5 2>&1
                                Write-RightLog "OUT" (T "Đã gửi lệnh gỡ key Office: $k5" "Sent uninstall key command for $k5") $cGreen
                                Set-Activity "OK" (T "Đã gỡ mã key Office" "Office Key Uninstalled") $cGreen

                                # Re-trigger Office async scan to refresh status
                                $psOffice = [powershell]::Create()
                                $null = $psOffice.AddScript($officeScanCode)
                                $asyncOffice = $psOffice.BeginInvoke()
                                $script:officeLoading = $true
                                Update-SystemLicenseStrings
                                Render-SystemLicenseView
                            } catch {
                                Write-RightLog "ERROR" (T "Lỗi khi gỡ key Office: $_" "Error uninstalling Office key: $_") $cRed
                            }
                        } else {
                            Write-RightLog "WARN" (T "Không tìm thấy khóa Office 5 ký tự để gỡ." "No 5-digit Office key found to uninstall.") $cYellow
                        }
                        continue
                    }

                    # Hardware row click to copy
                    if ($isLeftClick -and $hoverHwRow -ge 0 -and $hoverHwRow -lt $hwItems.Count) {
                        $it = $hwItems[$hoverHwRow]
                        $v = [string]$it.Value
                        if ($v -and -not $script:hwLoading -and $v -notmatch '^\(') {
                            try {
                                Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
                                [System.Windows.Forms.Clipboard]::SetText($v)
                                $lbl = $it.Label.Trim()
                                Write-RightLog "CLIPBOARD" (T "Đã sao chép ${lbl}: $v" "Copied ${lbl}: $v") $cGreen
                                Set-Activity "OK" (T "Đã sao chép $lbl" "Copied $lbl") $cGreen
                            } catch {}
                            $flashHwRow = $hoverHwRow
                            $flashTick = [Environment]::TickCount
                            Render-SystemLicenseView
                        }
                    }
                }
            }
        }
    } finally {
        if ($psWin) { try { $psWin.Dispose() } catch {} }
        if ($psHw) { try { $psHw.Dispose() } catch {} }
        if ($psOffice) { try { $psOffice.Dispose() } catch {} }
        $script:currentHoverTarget = "NONE"
        $script:currentClickTarget = "NONE"
        $global:onLanguageChanged = $null
        $global:currentActionTitleVi = $null
        $global:currentActionTitleEn = $null
        $global:currentActionName = $null
        $global:currentActionBorderColor = $null
        Update-IdleActivity
        Draw-LeftMenu $false
        Draw-StatusPane
    }
}

# --- [4.2] Kill Frozen Tasks ---
function Invoke-KillNotRespondingTasks() {
    Write-DebugLog "&&" "[4.2] Invoking Kill Frozen Tasks..."
    Start-ActionView "TẮT TÁC VỤ BỊ TREO/ĐƠ" $cCyan "KILL FROZEN TASKS"
    Write-RightLog "IN" (T "Đang quét và tắt các tác vụ bị treo..." "Scanning and killing frozen tasks (Not Responding)...") $cYellow
    # Terminating frozen tasks
    Invoke-ActionWithSpinner 'taskkill.exe /F /FI "status eq NOT RESPONDING"' (T "Đang tắt tác vụ treo..." "Terminating frozen apps...") $cYellow 5 | Out-Null
    Update-LeftConsoleLine (T " [OK] Đã tắt các tác vụ bị treo." " [OK] Frozen tasks terminated.") $cGreen
    Write-RightLog "OUT" (T "Đã hoàn tất tắt các tiến trình bị treo." "Frozen tasks termination complete.") $cGreen
    Set-Activity "OK" (T "Hoàn thành: Tắt tác vụ treo" "Done: Kill Frozen Tasks") $cGreen
    Wait-LeftReturn
}

function Get-RamTrayPathFromLink() {
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
                    if ($p -and (Test-Path $p)) { return $p }
                }
            }
        } catch {}
    }
    $defExe1 = "$script:scriptDir\WCaO_RAM\WCaO_RAM.exe"
    if (Test-Path $defExe1) { return $defExe1 }
    $defExe2 = "$script:scriptDir\WCaO_RAM.exe"
    if (Test-Path $defExe2) { return $defExe2 }
    $defExe3 = "$env:LocalAppData\WCaO\WCaO_RAM\WCaO_RAM.exe"
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
    
    $downloadSuccess = $false
    $url = "https://raw.githubusercontent.com/SpaceheroVN/WCaO/refs/heads/main/WCaO_RAM/WCaO_RAM.exe"
    try {
        Write-RightLog "NET" (T "Đang tải WCaO_RAM.exe từ GitHub..." "Downloading WCaO_RAM.exe from GitHub...") $cCyan
        $tmpDownload = "$targetPath.tmp"
        if (Test-Path $tmpDownload) { Remove-Item -Path $tmpDownload -Force -ErrorAction SilentlyContinue }
        
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls13
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("User-Agent", "WCaO_Toolkit")
        $wc.DownloadFile($url, $tmpDownload)
        if ((Test-Path $tmpDownload) -and (Get-Item $tmpDownload).Length -gt 50000) {
            Move-Item -Path $tmpDownload -Destination $targetPath -Force
            $downloadSuccess = $true
            Write-RightLog "OK" (T "Đã tải thành công WCaO_RAM.exe từ GitHub!" "Downloaded WCaO_RAM.exe successfully from GitHub!") $cGreen
        } else {
            if (Test-Path $tmpDownload) { Remove-Item -Path $tmpDownload -Force -ErrorAction SilentlyContinue }
        }
    } catch {
        Write-RightLog "WARN" (T "Không thể tải từ GitHub: $($_.Exception.Message)" "Could not download from GitHub: $($_.Exception.Message)") $cYellow
    }

    if (-not $downloadSuccess) {
        $candidates = @(
            "$script:scriptDir\WCaO_RAM\WCaO_RAM.exe",
            "$script:scriptDir\WCaO_RAM.exe",
            "$env:LocalAppData\WCaO\WCaO_RAM\WCaO_RAM.exe",
            "$script:scriptDir\WCaO_RAM.bat"
        )
        $src = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($src) {
            Copy-Item -Path $src -Destination $targetPath -Force
            Write-RightLog "INFO" (T "Đã sao chép tệp từ nguồn cục bộ ($src)" "Copied file from local source ($src)") $cLightCyan
        }
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
    try {
        Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
            Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -like "*WCaO_RAM.bat*" } |
            ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    } catch {}
}

# --- [4.3] RAM Management & Tray ---
function Invoke-RamTrayManager() {
    Write-DebugLog "&&" "[4.3] Invoking RAM Management & Tray Manager..."
    Write-RightLog "IN" (T "Mở bảng điều khiển Quản lý RAM ngầm" "Opened RAM Management dashboard") $cWhite
    Write-RightLog "INFO" (T "[i] Click chuột vào các thẻ [ ... ] để bật/tắt hoặc cấu hình" "[i] Click [ ... ] badges to toggle or configure") $cLightCyan

    $badgeGui = "${cCyan}[ GUI ]${cReset}"
    $firstRun = $true
    $needRedraw = $true
    $lastLang = $global:selectedLang
    $script:ramLangDirty = $false
    $global:onLanguageChanged = { $script:ramLangDirty = $true }

    try {
        while ($true) {
            if ($script:ramLangDirty -or $global:selectedLang -ne $lastLang) {
                $lastLang = $global:selectedLang
                $script:ramLangDirty = $false
                $needRedraw = $true
            }

            $isVi = ($global:selectedLang -eq "Vietnamese")
            $lblFile = T "  Tệp Module  : " "  Module File : "
            $lblProc = T "  Tiến trình  : " "  Tray Process: "
            $lblAuto = T "  Khởi động   : " "  Win Startup : "
            $lblHint = T "  Nhấp các thẻ [ ... ] để điều khiển." "  Click [ ... ] badges to control."

            $ramTrayPath = Get-RamTrayPathFromLink
            $fileExists = [bool]($ramTrayPath -and (Test-Path -LiteralPath $ramTrayPath))

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
                Start-ActionView "QUẢN LÝ RAM" $cCyan "RAM MANAGEMENT"
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
                    $plain = $script:AnsiRegex.Replace($fLine, "")
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
                if ($script:ramLangDirty -or $global:selectedLang -ne $lastLang) {
                    $lastLang = $global:selectedLang
                    $script:ramLangDirty = $false
                    $needRedraw = $true
                }
                $curRunning = (Test-WcaoRamMutexRunning) -or [bool](Get-WcaoRamRunningProcess)
                $curAuto = Test-WcaoRamAutostartEnabled
                $curFile = [bool]($ramTrayPath -and (Test-Path -LiteralPath $ramTrayPath))

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
                if ($isRunning) {
                    try {
                        $msgShow = [ConsoleMouse]::RegisterWindowMessage("WCaO_RAM_ShowGUI")
                        if ($msgShow -ne 0) {
                            [ConsoleMouse]::PostMessage([IntPtr]0xFFFF, $msgShow, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
                        }
                    } catch {}
                    Write-RightLog "OUT" (T "Đã gửi tín hiệu hiển thị Giao diện Quản lý RAM!" "Brought RAM Manager GUI to foreground!") $cGreen
                    Set-Activity "OK" (T "Mở RAM GUI" "Opened RAM GUI") $cGreen
                } else {
                    if (-not $ramTrayPath -or -not (Test-Path -LiteralPath $ramTrayPath)) {
                        $ramTrayPath = Get-RamTrayPathFromLink
                    }
                    if ($ramTrayPath -and (Test-Path -LiteralPath $ramTrayPath)) {
                        if ($ramTrayPath -match '\.exe$') {
                            Start-Process -FilePath $ramTrayPath -ArgumentList "-gui_direct"
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
                }
                continue
            }

            if ($opt -eq '1') {
                $chosenPath = Prompt-SaveRamTrayPath $ramTrayPath
                if ($chosenPath) {
                    New-RamTrayScriptFile $chosenPath
                    Update-WcaoLinkRegistry -ramTrayPath $chosenPath
                    $ramTrayPath = $chosenPath
                    Write-RightLog "OUT" (T "Đã thiết lập tệp WCaO_RAM tại $chosenPath" "Configured WCaO_RAM at $chosenPath") $cGreen
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
                        Start-Process -FilePath $ramTrayPath -ArgumentList "-tray_direct"
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

                $swWait = [System.Diagnostics.Stopwatch]::StartNew()
                while ($swWait.ElapsedMilliseconds -lt 1500) {
                    Start-Sleep -Milliseconds 80
                    if (-not (Test-WcaoRamMutexRunning)) { break }
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
    } finally {
        $global:onLanguageChanged = $null
    }
}


# --- [4.4] Restart Windows Explorer ---
function Invoke-RestartExplorer() {
    Write-DebugLog "&&" "[4.4] Invoking Restart Windows Explorer..."
    Start-ActionView "KHỞI ĐỘNG EXPLORER" $cCyan "RESTART EXPLORER"
    $ans = Wait-SingleKey (T "Khởi động lại Windows Explorer ngay?" "Restart Windows Explorer now?") @('Y','N')
    if ($ans -ne "Y") { return }
    Write-RightLog "IN" (T "Đang khởi động lại Windows Explorer..." "Restarting Windows Explorer...") $cYellow
    Write-LeftConsole (T " [>>] Đang khởi động lại Explorer..." " [>>] Restarting Explorer...") $cYellow
    Run-And-LogCommand "taskkill" "/f /im explorer.exe" | Out-Null
    Start-Sleep -Seconds 1
    Start-Process explorer.exe
    Write-LeftConsole (T " [OK] Đã khởi động lại Explorer." " [OK] Explorer restarted.") $cGreen
    Write-RightLog "OUT" (T "Đã hoàn tất khởi động lại Windows Explorer." "Windows Explorer restarted successfully.") $cGreen
    Set-Activity "OK" (T "Hoàn thành: Khởi động lại Explorer" "Done: Restart Explorer") $cGreen
    Wait-LeftReturn
}

# --- [4.5] Network, DNS & Wi-Fi Center ---
function Invoke-NetworkCenter() {
    Write-DebugLog "&&" "[4.5] Invoking Network, DNS & Wi-Fi Center..."
    Start-ActionView "MẠNG & WI-FI" $cCyan "NETWORK & WI-FI"
    Write-RightLog "IN" (T "Đang mở Trung tâm Mạng, DNS & Wi-Fi..." "Opening Network, DNS & Wi-Fi Center...") $cYellow

    Get-TermSize

    # Ensure Console Mouse mode
    $hInput = [ConsoleMouse]::GetStdHandle([ConsoleMouse]::STD_INPUT_HANDLE)
    try {
        $inMode = 0
        [ConsoleMouse]::GetConsoleMode($hInput, [ref]$inMode) | Out-Null
        $inMode = ($inMode -band (-bnot [ConsoleMouse]::ENABLE_QUICK_EDIT_MODE)) -bor [ConsoleMouse]::ENABLE_MOUSE_INPUT -bor [ConsoleMouse]::ENABLE_EXTENDED_FLAGS
        [ConsoleMouse]::SetConsoleMode($hInput, $inMode) | Out-Null
        [ConsoleMouse]::FlushConsoleInputBuffer($hInput) | Out-Null
    } catch {}

    # --- 1. Async Adapter & Network Discovery ---
    $spChars = if ($global:spinnerChars -and $global:spinnerChars.Count -gt 0) { $global:spinnerChars } else { @('⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏') }
    $spInit = $spChars[0]
    $isViInit = ($global:selectedLang -eq "Vietnamese")
    $loadingText = if ($isViInit) { "[$spInit] Đang kiểm tra..." } else { "[$spInit] Checking..." }

    $script:netCenterAdapter = $null
    $script:isV4Enabled = $true
    $script:isV6Enabled = $false
    $script:netAdapterResult = $null
    $script:wanResult = $null
    $script:wifiResult = $null

    $netItems = [System.Collections.Generic.List[PSCustomObject]]::new()

    # Row 0: IPv6 with [ON]/[OFF] button
    $netItems.Add([PSCustomObject]@{
        Id = "IPV6"
        PrefixTag = "IPv6 : "
        Value = $loadingText
        IsV6Row = $true
        IsLoading = $true
        RawCopyVal = ""
    })

    # Row 1: IPv4 (LAN)
    $netItems.Add([PSCustomObject]@{
        Id = "LAN_V4"
        PrefixTag = "IPv4 : "
        Value = $loadingText
        IsV6Row = $false
        IsLoading = $true
        RawCopyVal = ""
    })

    # Row 2: IPv4 (WAN) - Async
    $netItems.Add([PSCustomObject]@{
        Id = "WAN_V4"
        PrefixTag = "WAN  : "
        Value = $loadingText
        IsV6Row = $false
        IsLoading = $true
        RawCopyVal = ""
    })

    # Row 3: Gateway
    $netItems.Add([PSCustomObject]@{
        Id = "GATEWAY"
        PrefixTag = "Gate : "
        Value = $loadingText
        IsV6Row = $false
        IsLoading = $true
        RawCopyVal = ""
    })

    # Row 4: DNS IPv4
    $netItems.Add([PSCustomObject]@{
        Id = "DNS_V4"
        PrefixTag = "DNSv4: "
        Value = $loadingText
        IsV6Row = $false
        IsLoading = $true
        RawCopyVal = ""
    })

    # Row 5: DNS IPv6
    $netItems.Add([PSCustomObject]@{
        Id = "DNS_V6"
        PrefixTag = "DNSv6: "
        Value = $loadingText
        IsV6Row = $false
        IsLoading = $true
        RawCopyVal = ""
    })

    # Row 6: Wi-Fi Password / Connection - Async
    $netItems.Add([PSCustomObject]@{
        Id = "WIFI_PASS"
        PrefixTag = "Wi-Fi: "
        Value = $loadingText
        IsV6Row = $false
        IsLoading = $true
        RawCopyVal = ""
    })

    # Task 1: Local Adapter Information Async
    $adapterScanCode = @'
$res = [PSCustomObject]@{
    Adapter  = $null
    IsV4     = $true
    IsV6     = $false
    LAN_V4   = ""
    Local_V6 = ""
    Gateway  = ""
    DNS_V4   = ""
    DNS_V6   = ""
}
try {
    $upAdapters = @(Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' })
    if ($upAdapters.Count -gt 0) {
        $adapterObj = $upAdapters | Where-Object { $_.InterfaceAlias -match 'Wi-Fi|Wireless|Ethernet|LAN' } | Select-Object -First 1
        if (-not $adapterObj) { $adapterObj = $upAdapters[0] }
        $res.Adapter = $adapterObj.Name

        $v6Bind = Get-NetAdapterBinding -Name $res.Adapter -ComponentID ms_tcpip6 -ErrorAction SilentlyContinue
        $res.IsV6 = ($v6Bind.Enabled -eq $true)
        $v4Bind = Get-NetAdapterBinding -Name $res.Adapter -ComponentID ms_tcpip -ErrorAction SilentlyContinue
        $res.IsV4 = ($v4Bind.Enabled -eq $true)

        $ipConf = Get-NetIPConfiguration -InterfaceAlias $res.Adapter -ErrorAction SilentlyContinue
        if ($ipConf) {
            if ($ipConf.IPv4Address) {
                $res.LAN_V4 = ($ipConf.IPv4Address.IPAddress -join ', ')
            }
            if ($res.IsV6 -and $ipConf.IPv6Address) {
                $globV6 = @($ipConf.IPv6Address | Where-Object { $_.IPAddress -notlike 'fe80:*' } | Select-Object -ExpandProperty IPAddress)
                if ($globV6.Count -gt 0) { $res.Local_V6 = ($globV6 -join ', ') } else { $res.Local_V6 = ($ipConf.IPv6Address.IPAddress -join ', ') }
            }
            if ($ipConf.IPv4DefaultGateway) {
                $res.Gateway = ($ipConf.IPv4DefaultGateway.NextHop -join ', ')
            } elseif ($ipConf.IPv6DefaultGateway) {
                $res.Gateway = ($ipConf.IPv6DefaultGateway.NextHop -join ', ')
            }

            $rawDnsV4 = (Get-DnsClientServerAddress -InterfaceAlias $res.Adapter -AddressFamily IPv4 -ErrorAction SilentlyContinue).ServerAddresses
            if ($rawDnsV4 -and $rawDnsV4.Count -gt 0) {
                $res.DNS_V4 = (($rawDnsV4 | Select-Object -Unique) -join ', ')
            }

            if ($res.IsV6) {
                $rawDnsV6 = (Get-DnsClientServerAddress -InterfaceAlias $res.Adapter -AddressFamily IPv6 -ErrorAction SilentlyContinue).ServerAddresses
                if ($rawDnsV6 -and $rawDnsV6.Count -gt 0) {
                    $res.DNS_V6 = (($rawDnsV6 | Select-Object -Unique) -join ', ')
                }
            }
        }
    }
} catch {}
return $res
'@
    $psAdapter = [powershell]::Create()
    $null = $psAdapter.AddScript($adapterScanCode)
    $asyncAdapter = $psAdapter.BeginInvoke()

    # Task 2: Public WAN IP Async
    $wanCode = '$services = @("http://api.ipify.org", "http://icanhazip.com", "http://ipinfo.io/ip"); foreach ($srv in $services) { try { $req = [System.Net.HttpWebRequest]::Create($srv); $req.Timeout = 2500; $resp = $req.GetResponse(); $stream = $resp.GetResponseStream(); $reader = New-Object System.IO.StreamReader($stream); $ip = $reader.ReadToEnd().Trim(); $reader.Close(); $resp.Close(); if ($ip) { return $ip } } catch {} }; return "N/A"'
    $psWan = [powershell]::Create()
    $null = $psWan.AddScript($wanCode)
    $asyncWan = $psWan.BeginInvoke()

    # Task 3: Wi-Fi Password / Ethernet Profile Async
    $wifiCode = '$res = [PSCustomObject]@{ Type = "NONE"; SSID = ""; Pass = "" }; try { $iface = netsh wlan show interfaces 2>$null; $prof = $iface | Select-String -Pattern "^\s*(?:Profile|Hồ sơ|SSID)\s*:\s*(.+)$"; if ($prof) { $ssid = $prof.Matches[0].Groups[1].Value.Trim(); $res.Type = "WIFI"; $res.SSID = $ssid; $key = (netsh wlan show profile name="$ssid" key=clear 2>$null) | Select-String -Pattern "^\s*(?:Key Content|Nội dung khóa|Nội dung khoá)\s*:\s*(.+)$"; if ($key) { $res.Pass = $key.Matches[0].Groups[1].Value.Trim() }; return $res } } catch {}; try { $eth = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" -and $_.InterfaceAlias -match "Ethernet|LAN" }; if (-not $eth) { $eth = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" } }; if ($eth) { $res.Type = "ETHERNET"; $res.SSID = $eth[0].Name; return $res } } catch {}; return $res'
    $psWifi = [powershell]::Create()
    $null = $psWifi.AddScript($wifiCode)
    $asyncWifi = $psWifi.BeginInvoke()

    # --- 2. Interactive State Variables ---
    $horizOffset = 0
    $vertOffset = 0
    $hoverIdx = -1
    $hoverToggle = $false
    $hoverReset = $false
    $flashIdx = -1
    $flashTick = 0
    $isDraggingHScroll = $false
    $spinIdx = 0
    $lastSpinTick = [Environment]::TickCount
    $resetFlash = $false
    $resetFlashTick = 0
    $script:confirmResetNet = $false
    $script:confirmResetNetTick = 0
    $script:isV6Toggling = $false
    $script:v6TargetAction = ""
    $asyncV6Toggle = $null
    $psV6Toggle = $null

    function Local:Calc-MaxHoriz() {
        $maxLen = 0
        foreach ($it in $netItems) {
            $vStr = [string]$it.Value
            if ($vStr.Length -gt $maxLen) { $maxLen = $vStr.Length }
        }
        $valCols = 25
        return [math]::Max(0, $maxLen - $valCols)
    }

    # --- Dynamic Multi-Language String Builder (with Permission Gating) ---
    function Local:Update-NetworkStrings() {
        $isVi = ($global:selectedLang -eq "Vietnamese")
        $spChar = $spChars[$spinIdx % $spChars.Count]
        $loadingText = if ($isVi) { "[$spChar] Đang kiểm tra..." } else { "[$spChar] Checking..." }

        # 1. Local Adapter Information
        if ($script:netAdapterResult) {
            $ad = $script:netAdapterResult
            $script:netCenterAdapter = $ad.Adapter
            $script:isV4Enabled = ($ad.IsV4 -eq $true)
            $script:isV6Enabled = ($ad.IsV6 -eq $true)

            # Row 0: IPv6
            $v6Val = if ($script:isV6Toggling) {
                if ($isVi) { "[$spChar] Đang chuyển đổi..." } else { "[$spChar] Switching..." }
            } elseif ($script:isV6Enabled) {
                if ($ad.Local_V6) { $ad.Local_V6 } else { if ($isVi) { "(Không có IPv6)" } else { "(No IPv6)" } }
            } else {
                if ($isVi) { "(IPv6 đã tắt)" } else { "(IPv6 Disabled)" }
            }
            $netItems[0].Value = $v6Val
            $netItems[0].RawCopyVal = if ($script:isV6Enabled -and -not $script:isV6Toggling) { $ad.Local_V6 } else { "" }
            $netItems[0].IsLoading = ($script:isV6Toggling -eq $true)

            # Row 1: LAN IPv4
            $v4Val = if ($ad.LAN_V4) { $ad.LAN_V4 } else { if ($isVi) { "(Không có IPv4)" } else { "(No IPv4)" } }
            $netItems[1].Value = $v4Val
            $netItems[1].RawCopyVal = $ad.LAN_V4
            $netItems[1].IsLoading = $false

            # Row 3: Gateway
            $gwVal = if ($ad.Gateway) { $ad.Gateway } else { if ($isVi) { "(Không có)" } else { "(None)" } }
            $netItems[3].Value = $gwVal
            $netItems[3].RawCopyVal = $ad.Gateway
            $netItems[3].IsLoading = $false

            # Row 4: DNS IPv4
            $d4Val = if ($ad.DNS_V4) { $ad.DNS_V4 } else { if ($isVi) { "(Tự động / DHCP)" } else { "(DHCP / Auto)" } }
            $netItems[4].Value = $d4Val
            $netItems[4].RawCopyVal = $ad.DNS_V4
            $netItems[4].IsLoading = $false

            # Row 5: DNS IPv6
            $d6Val = if ($script:isV6Enabled) {
                if ($ad.DNS_V6) { $ad.DNS_V6 } else { if ($isVi) { "(Không có)" } else { "(None)" } }
            } else {
                if ($isVi) { "(IPv6 đã tắt)" } else { "(IPv6 Disabled)" }
            }
            $netItems[5].Value = $d6Val
            $netItems[5].RawCopyVal = if ($script:isV6Enabled) { $ad.DNS_V6 } else { "" }
            $netItems[5].IsLoading = $false
        } else {
            for ($k = 0; $k -le 5; $k++) {
                if ($k -eq 2) { continue }
                if ($netItems[$k].IsLoading) {
                    $netItems[$k].Value = $loadingText
                }
            }
        }

        # 2. Public WAN IP
        if ($script:wanResult) {
            $netItems[2].Value = $script:wanResult
            $netItems[2].RawCopyVal = $script:wanResult
            $netItems[2].IsLoading = $false
        } elseif ($netItems[2].IsLoading) {
            $netItems[2].Value = $loadingText
        }

        # 3. Wi-Fi / Ethernet (Gated: Wi-Fi password requires Expert Mode to view)
        if ($script:wifiResult) {
            $wf = $script:wifiResult
            if ($wf.Type -eq "WIFI") {
                if ($wf.Pass) {
                    if ($global:expertMode) {
                        $netItems[6].Value = "SSID: $($wf.SSID) | Pass: $($wf.Pass)"
                        $netItems[6].RawCopyVal = $wf.Pass
                    } else {
                        $netItems[6].Value = "SSID: $($wf.SSID) | Pass: [••••••••]"
                        $netItems[6].RawCopyVal = ""
                    }
                } else {
                    $netItems[6].Value = if ($isVi) { "SSID: $($wf.SSID) (Mạng mở - Không pass)" } else { "SSID: $($wf.SSID) (Open network - No pass)" }
                    $netItems[6].RawCopyVal = $wf.SSID
                }
            } elseif ($wf.Type -eq "ETHERNET") {
                $netItems[6].Value = if ($isVi) { "Mạng dây: $($wf.SSID) (Không dùng Wi-Fi)" } else { "Wired: $($wf.SSID) (No Wi-Fi)" }
                $netItems[6].RawCopyVal = $wf.SSID
            } else {
                $netItems[6].Value = if ($isVi) { "(Không có kết nối mạng)" } else { "(No network connection)" }
                $netItems[6].RawCopyVal = ""
            }
            $netItems[6].IsLoading = $false
        } elseif ($netItems[6].IsLoading) {
            $netItems[6].Value = $loadingText
        }
    }

    Update-NetworkStrings

    # --- 3. Custom Renderer ---
    function Local:Render-NetworkView() {
        Get-TermSize
        $script:netLeftH = [math]::Max(5, $script:termH - 4)
        $isVi = ($global:selectedLang -eq "Vietnamese")
        $pageSize = [math]::Min($netItems.Count, $script:netLeftH - 8)
        $maxVert = [math]::Max(0, $netItems.Count - $pageSize)
        if ($vertOffset -gt $maxVert) { $vertOffset = $maxVert; Set-Variable -Name vertOffset -Value $maxVert -Scope 1 }
        if ($vertOffset -lt 0) { $vertOffset = 0; Set-Variable -Name vertOffset -Value 0 -Scope 1 }

        $valCols = 25
        $width = 38

        for ($i = 0; $i -lt $pageSize; $i++) {
            $dataIdx = $vertOffset + $i
            $rowY = 5 + $i
            Set-CursorPos 2 $rowY

            if ($dataIdx -lt $netItems.Count) {
                $item = $netItems[$dataIdx]
                $isHoverRow = ($hoverIdx -eq $dataIdx -and -not ($dataIdx -eq 0 -and $hoverToggle))
                $isFlashRow = ($flashIdx -eq $dataIdx)

                $valStr = [string]$item.Value
                $valSlice = Get-HorizSlice $valStr $horizOffset $valCols

                if ($item.IsV6Row) {
                    $spChar = $spChars[$spinIdx % $spChars.Count]
                    $togText = if ($script:isV6Toggling) {
                        "[ $spChar]"
                    } elseif ($script:isV6Enabled) {
                        "[ON]"
                    } else {
                        "[OFF]"
                    }

                    $togStyle = if ($script:isV6Toggling) {
                        "$cYellow$togText$cReset"
                    } elseif ($hoverToggle) {
                        if ($script:isV6Enabled) { "$ESC[48;2;30;85;45m$ESC[38;2;140;255;160m$togText$cReset" }
                        else { "$ESC[48;2;120;30;30m$ESC[38;2;255;160;160m$togText$cReset" }
                    } else {
                        if ($script:isV6Enabled) { "$cGreen$togText$cReset" } else { "$cRed$togText$cReset" }
                    }

                    $pre = " IPv6 : "
                    $plainLen = $togText.Length + $pre.Length + $valSlice.Length
                    $padSpaces = " " * [math]::Max(0, $width - $plainLen)

                    if ($isFlashRow) {
                        $full = "$pre$valSlice$padSpaces"
                        Write-Host "$togStyle$ESC[48;2;30;85;45m$ESC[38;2;140;255;160m$full$cReset" -NoNewline
                    } elseif ($isHoverRow) {
                        $full = "$pre$valSlice$padSpaces"
                        Write-Host "$togStyle$ESC[48;2;45;50;62m$ESC[38;2;255;255;255m$full$cReset" -NoNewline
                    } else {
                        $vCol = if ($item.IsLoading) { $cYellow } elseif ($script:isV6Enabled) { $cWhite } else { $cDim }
                        Write-Host "$togStyle$cCyan$pre$cReset$vCol$valSlice$cReset$padSpaces" -NoNewline
                    }
                } else {
                    $pre = "  " + $item.PrefixTag
                    $plainLen = $pre.Length + $valSlice.Length
                    $padSpaces = " " * [math]::Max(0, $width - $plainLen)

                    if ($isFlashRow) {
                        $full = "$pre$valSlice$padSpaces"
                        Write-Host ("$ESC[48;2;30;85;45m$ESC[38;2;140;255;160m" + $full + "$cReset") -NoNewline
                    } elseif ($isHoverRow) {
                        $full = "$pre$valSlice$padSpaces"
                        Write-Host ("$ESC[48;2;45;50;62m$ESC[38;2;255;255;255m" + $full + "$cReset") -NoNewline
                    } else {
                        $vCol = if ($item.IsLoading) { $cYellow } else { $cWhite }
                        Write-Host "$cCyan$pre$cReset$vCol$valSlice$cReset$padSpaces" -NoNewline
                    }
                }
            } else {
                Write-Host (" " * $width) -NoNewline
            }
        }

        # Clear gap line above scrollbar
        $gapY = 5 + $pageSize
        Set-CursorPos 2 $gapY
        Write-Host (" " * $width) -NoNewline

        # Horizontal scrollbar (dynamic calculation)
        $hScrollY = $gapY + 1
        $dynMaxH = Calc-MaxHoriz
        Set-CursorPos 2 $hScrollY
        if ($dynMaxH -gt 0) {
            $trackW = $width - 2
            $travel = $trackW - 2
            $thumbPos = [math]::Round(($horizOffset / $dynMaxH) * $travel)
            $thumbPos = [math]::Max(0, [math]::Min($travel, $thumbPos))
            $thumbCol = if ($hoverIdx -eq 998 -or $isDraggingHScroll) { "$ESC[38;2;255;255;255m" } else { $cCyan }
            $leftTrack = "$cDim" + ($chrLine * $thumbPos) + "$cReset"
            $thumbBlock = "$thumbCol" + ($chrHThumb * 2) + "$cReset"
            $rightTrack = "$cDim" + ($chrLine * ($travel - $thumbPos)) + "$cReset"
            Write-Host (" " + $leftTrack + $thumbBlock + $rightTrack + " ") -NoNewline
        } else {
            Write-Host (" " * $width) -NoNewline
        }

        # Clear gap line between scrollbar and Reset button
        $gapY2 = $hScrollY + 1
        Set-CursorPos 2 $gapY2
        Write-Host (" " * $width) -NoNewline

        # Reset Network & DNS Action Button (Row Y = hScrollY + 2)
        $resetBtnY = $hScrollY + 2
        Set-CursorPos 2 $resetBtnY
        $chrRef = [char]0x21BA
        $resetTxt = if ($script:confirmResetNet) {
            if ($isVi) { "[ ⚠️ Xác nhận đặt lại mạng? ]" } else { "[ ⚠️ Confirm Network Reset? ]" }
        } else {
            if ($isVi) { "[ $chrRef Đặt lại Mạng & DNS ]" } else { "[ $chrRef Reset Network & DNS ]" }
        }
        $padTotal = [math]::Max(0, $width - $resetTxt.Length)
        $padL = " " * [math]::Floor($padTotal / 2)
        $padR = " " * ($padTotal - $padL.Length)

        $btnStyle = if ($resetFlash) {
            "$ESC[48;2;30;85;45m$ESC[38;2;140;255;160m$resetTxt$cReset"
        } elseif ($script:confirmResetNet) {
            "$ESC[48;2;170;40;40m$ESC[38;2;255;255;255m$resetTxt$cReset"
        } elseif ($hoverReset) {
            "$ESC[48;2;110;50;170m$ESC[38;2;255;255;255m$resetTxt$cReset"
        } else {
            "$cPurp$resetTxt$cReset"
        }
        Write-Host "$padL$btnStyle$padR" -NoNewline

        # Hints anchored at bottom of box (strictly clamped to 38 cols, no log bleed)
        $hintY = $script:netLeftH
        if ($hintY -gt ($resetBtnY + 1)) {
            Set-CursorPos 2 $hintY
        $h1 = if ($global:expertMode) {
            if ($isVi) { "[i] Bấm dòng để sao chép IP/Pass" } else { "[i] Click row to copy IP or Password" }
        } else {
            if ($isVi) { "[i] Bấm copy IP | Wi-Fi: Cần Expert" } else { "[i] Click copy IP | Wi-Fi: Expert" }
        }
        $plain1 = $script:AnsiRegex.Replace($h1, '')
        if ($plain1.Length -gt 38) { $h1 = $h1.Substring(0, 38); $plain1 = $plain1.Substring(0, 38) }
        $pad1 = " " * [math]::Max(0, 38 - $plain1.Length)
        Write-Host "$cDim$h1$cReset$pad1" -NoNewline

        $hintY2 = $script:netLeftH + 1
        Set-CursorPos 2 $hintY2
        $h2 = if ($global:expertMode) {
            if ($isVi) { "[i] Bấm [ON/OFF] để bật/tắt IPv6" } else { "[i] Click [ON/OFF] to toggle IPv6" }
        } else {
            if ($isVi) { "[i] Bật [Expert Mode] để cấu hình" } else { "[i] Turn [Expert Mode] ON for Reset" }
        }
        $plain2 = $script:AnsiRegex.Replace($h2, '')
        if ($plain2.Length -gt 38) { $h2 = $h2.Substring(0, 38); $plain2 = $plain2.Substring(0, 38) }
        $pad2 = " " * [math]::Max(0, 38 - $plain2.Length)
        Write-Host "$cDim$h2$cReset$pad2" -NoNewline

        }

        # Clear lines between reset button and bottom hints
        $curY = $resetBtnY + 1
        while ($curY -lt $hintY) {
            Set-CursorPos 2 $curY
            Write-Host (" " * $width) -NoNewline
            $curY++
        }

        Show-LeftBackButton
    }

    # Register instant global callback when language or expert mode is clicked
    $global:onLanguageChanged = {
        Update-NetworkStrings
        Render-NetworkView
        Draw-FooterBar
    }

    Render-NetworkView

    # --- 4. Event Loop with ConsoleMouse ---
    $records = New-Object ConsoleMouse+INPUT_RECORD[] 64

    $wasLeft = $false
    $running = $true

    try {
        while ($running) {
            Start-Sleep -Milliseconds 25

            # Flash effect timeout
            if ($flashIdx -ge 0 -and ([Environment]::TickCount - $flashTick) -gt 250) {
                $flashIdx = -1
                Render-NetworkView
            }
            if ($resetFlash -and ([Environment]::TickCount - $resetFlashTick) -gt 350) {
                $resetFlash = $false
                Render-NetworkView
            }
            # 2-step confirmation timeout (revert after 3.5 seconds)
            if ($script:confirmResetNet -and ([Environment]::TickCount - $script:confirmResetNetTick) -gt 3500) {
                $script:confirmResetNet = $false
                Render-NetworkView
            }

            # Check and Update Spinners / Background Tasks
            $nowTick = [Environment]::TickCount
            if (($nowTick - $lastSpinTick) -ge 70) {
                $lastSpinTick = $nowTick
                $spinIdx++
                $spChar = $spChars[$spinIdx % $spChars.Count]
                $needsRedraw = $false

                # 0. Check IPv6 Toggle Task
                if ($asyncV6Toggle -and $asyncV6Toggle.IsCompleted) {
                    try {
                        $v6EndRes = $psV6Toggle.EndInvoke($asyncV6Toggle)
                        $v6Obj = if ($v6EndRes -and $v6EndRes.Count -gt 0) { $v6EndRes[0] } else { $v6EndRes }
                        if ($v6Obj -and $v6Obj.Success) {
                            $script:isV6Enabled = ($script:v6TargetAction -eq "ENABLE")
                            Clear-DnsClientCache
                            ipconfig /flushdns | Out-Null
                            $adName = if ($script:netCenterAdapter) { $script:netCenterAdapter } else { "Ethernet" }
                            if ($script:v6TargetAction -eq "DISABLE") {
                                Write-RightLog "OUT" (T "Đã tắt IPv6 thành công trên card $adName." "IPv6 disabled successfully on $adName.") $cGreen
                                Set-Activity "OK" (T "Đã tắt IPv6" "IPv6 Disabled") $cYellow
                            } else {
                                Write-RightLog "OUT" (T "Đã bật IPv6 thành công trên card $adName." "IPv6 enabled successfully on $adName.") $cGreen
                                Set-Activity "OK" (T "Đã bật IPv6" "IPv6 Enabled") $cGreen
                            }

                            # Flush any input events (clicks) accumulated during toggle to prevent spamming
                            try { [ConsoleMouse]::FlushConsoleInputBuffer($hInput) | Out-Null } catch {}

                            # Re-trigger Adapter Scan async to get updated IPv6 addresses
                            $script:netAdapterResult = $null
                            $netItems[0].IsLoading = $true
                            $netItems[5].IsLoading = $true
                            if ($psAdapter) { try { $psAdapter.Dispose() } catch {} }
                            $psAdapter = [powershell]::Create()
                            $null = $psAdapter.AddScript($adapterScanCode)
                            $asyncAdapter = $psAdapter.BeginInvoke()
                        } else {
                            $errMsg = if ($v6Obj -and $v6Obj.Error) { $v6Obj.Error } else { "Unknown error" }
                            Write-RightLog "ERROR" (T "Lỗi khi đổi IPv6: $errMsg" "Error changing IPv6: $errMsg") $cRed
                            Set-Activity "!" (T "Lỗi đổi IPv6" "IPv6 Error") $cRed
                            $netItems[0].IsLoading = $false
                        }
                    } catch {
                        Write-RightLog "ERROR" (T "Lỗi khi xử lý IPv6: $_" "Error processing IPv6: $_") $cRed
                        $netItems[0].IsLoading = $false
                    }
                    try { $psV6Toggle.Dispose() } catch {}
                    $psV6Toggle = $null
                    $asyncV6Toggle = $null
                    $script:isV6Toggling = $false
                    $needsRedraw = $true
                } elseif ($script:isV6Toggling) {
                    $needsRedraw = $true
                }
                # 1. Check Adapter Scan Task
                if ($asyncAdapter -and $asyncAdapter.IsCompleted) {
                    try {
                        $adRes = $psAdapter.EndInvoke($asyncAdapter)
                        if ($adRes) {
                            $script:netAdapterResult = if ($adRes.Count -gt 0) { $adRes[0] } else { $adRes }
                        }
                    } catch {}
                    try { $psAdapter.Dispose() } catch {}
                    $psAdapter = $null
                    $asyncAdapter = $null
                    $needsRedraw = $true
                } elseif ($netItems[0].IsLoading -or $netItems[1].IsLoading -or $netItems[3].IsLoading -or $netItems[4].IsLoading -or $netItems[5].IsLoading) {
                    $needsRedraw = $true
                }

                # 2. Check WAN task
                if ($asyncWan -and $asyncWan.IsCompleted) {
                    try {
                        $wanRes = $psWan.EndInvoke($asyncWan)
                        $script:wanResult = if ($wanRes) { [string]$wanRes } else { "N/A" }
                    } catch {}
                    try { $psWan.Dispose() } catch {}
                    $psWan = $null
                    $asyncWan = $null
                    $needsRedraw = $true
                } elseif ($netItems[2].IsLoading) {
                    $needsRedraw = $true
                }

                # 3. Check Wi-Fi task
                if ($asyncWifi -and $asyncWifi.IsCompleted) {
                    try {
                        $wifiRes = $psWifi.EndInvoke($asyncWifi)
                        $script:wifiResult = $wifiRes
                    } catch {}
                    try { $psWifi.Dispose() } catch {}
                    $psWifi = $null
                    $asyncWifi = $null
                    $needsRedraw = $true
                } elseif ($netItems[6].IsLoading) {
                    $needsRedraw = $true
                }

                if ($needsRedraw) {
                    Update-NetworkStrings
                    Render-NetworkView
                }
            }

            # Poll Console Input Events
            [uint32]$eventsCount = 0
            [ConsoleMouse]::GetNumberOfConsoleInputEvents($hInput, [ref]$eventsCount) | Out-Null
            if ($eventsCount -le 0) { continue }
            [uint32]$toRead = [math]::Min([uint32]$records.Length, $eventsCount)
            [uint32]$read = 0
            [ConsoleMouse]::ReadConsoleInput($hInput, $records, $toRead, [ref]$read) | Out-Null

            for ($evIdx = 0; $evIdx -lt $read; $evIdx++) {
                $rec = $records[$evIdx]

                # 1. Resize Window
                if ($rec.EventType -eq 4) {
                    $script:termSizeDirty = $true
                    Get-TermSize -force
                    Draw-FullLayout $false
                    Render-NetworkView
                    continue
                }

                # 2. Key Event (ESC to return)
                if ($rec.EventType -eq 1 -and $rec.KeyEvent.bKeyDown) {
                    $vk = $rec.KeyEvent.wVirtualKeyCode
                    if ($vk -eq 27) { # ESC
                        Write-RightLog "$" (T "Đã thoát Trung tâm Mạng & Wi-Fi" "Exited Network Center") $cDim
                        $running = $false
                        break
                    }
                    if ($vk -eq 38) { # UP
                        if ($vertOffset -gt 0) { $vertOffset--; Render-NetworkView }
                        continue
                    }
                    if ($vk -eq 40) { # DOWN
                        $pageSizeCurrent = [math]::Min($netItems.Count, $script:netLeftH - 8)
                        $maxV = [math]::Max(0, $netItems.Count - $pageSizeCurrent)
                        if ($vertOffset -lt $maxV) { $vertOffset++; Render-NetworkView }
                        continue
                    }
                    if ($vk -eq 37) { # LEFT
                        if ($horizOffset -gt 0) { $horizOffset = [math]::Max(0, $horizOffset - 2); Render-NetworkView }
                        continue
                    }
                    if ($vk -eq 39) { # RIGHT
                        $dynMaxH = Calc-MaxHoriz; if ($horizOffset -lt $dynMaxH) { $horizOffset = [math]::Min($dynMaxH, $horizOffset + 2); Render-NetworkView }
                        continue
                    }
                }

                # 3. Mouse Event
                if ($rec.EventType -eq 2) {
                    $mEvent = $rec.MouseEvent
                    $posX = $mEvent.dwMousePosition.X
                    $posY = $mEvent.dwMousePosition.Y
                    $isLeft = (($mEvent.dwButtonState -band 1) -ne 0)
                    $isLeftClick = ($isLeft -and -not $wasLeft)
                    $wasLeft = $isLeft

                    $script:netLeftH = [math]::Max(5, $script:termH - 4)
                    $pageSizeCurrent = [math]::Min($netItems.Count, $script:netLeftH - 8)
                    $hScrollYCoord = 5 + $pageSizeCurrent + 1
                    $resetBtnYCoord = $hScrollYCoord + 2

                    $isVi = ($global:selectedLang -eq "Vietnamese")
                    $chrRef = [char]0x21BA
                    $resetTxt = if ($script:confirmResetNet) {
                        if ($isVi) { "[ ⚠️ Xác nhận đặt lại mạng? ]" } else { "[ ⚠️ Confirm Network Reset? ]" }
                    } else {
                        if ($isVi) { "[ $chrRef Đặt lại Mạng & DNS ]" } else { "[ $chrRef Reset Network & DNS ]" }
                    }
                    $padTotal = [math]::Max(0, 38 - $resetTxt.Length)
                    $padLCount = [math]::Floor($padTotal / 2)
                    $btnStartX = 2 + $padLCount
                    $btnEndX = $btnStartX + $resetTxt.Length - 1

                    $dynMaxH = Calc-MaxHoriz
                    # Mouse Wheel over network pane
                    if ($mEvent.dwEventFlags -eq 4) {
                        if ($posX -ge 1 -and $posX -le 42) {
                            $delta = [int]$mEvent.dwButtonState
                            $isOverH = ($posY -eq $hScrollYCoord)
                            $maxV = [math]::Max(0, $netItems.Count - $pageSizeCurrent)
                            if (Handle-ListMouseWheel $delta $isOverH ([ref]$vertOffset) ([ref]$horizOffset) $maxV $dynMaxH 1 4) {
                                Render-NetworkView
                            }
                            continue
                        }
                    }

                    if (Process-LogScrollEvents $mEvent) { continue }

                    # Global target hover
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

                    # Back Button / Breadcrumb click
                    if ($isLeftClick) {
                        if ($target -eq "BACK_BTN" -or $target.StartsWith("BREADCRUMB_")) {
                            Lock-Input 300
                            Write-RightLog "$" (T "Đã thoát Trung tâm Mạng & Wi-Fi" "Exited Network Center") $cDim
                            $running = $false
                            break
                        }
                        $gClick = Handle-GlobalClick $posX $posY
                        if ($gClick -and $gClick -ne "NONE") {
                            if ($gClick -eq "BREADCRUMB_NAV") {
                                Write-RightLog "$" (T "Thoát qua Breadcrumb" "Exited via Breadcrumb") $cDim
                                $running = $false
                                break
                            }
                            if ($gClick -eq "LANG_CHANGED") {
                                Update-NetworkStrings
                                Render-NetworkView
                                Draw-FooterBar
                            }
                            continue
                        }
                    }

                    # Drag release on scrollbar
                    if (-not $isLeft -and $isDraggingHScroll) {
                        $isDraggingHScroll = $false
                        Render-NetworkView
                    }

                    # Horizontal Scrollbar Click / Drag
                    $onHScroll = ($posX -ge 2 -and $posX -le 39 -and $posY -eq $hScrollYCoord)
                    if ($dynMaxH -gt 0) {
                        if ($isLeft -and ($onHScroll -or $isDraggingHScroll)) {
                            $isDraggingHScroll = $true
                            $clickCol = [math]::Max(2, [math]::Min(39, $posX))
                            $relX = $clickCol - 2
                            $targetRatio = [math]::Max(0.0, [math]::Min(1.0, $relX / 36.0))
                            $newOffset = [int][math]::Round($targetRatio * $dynMaxH)
                            if ($newOffset -ne $horizOffset) {
                                $horizOffset = $newOffset
                                Render-NetworkView
                            }
                            continue
                        }
                    }

                    # Reset Button Click (Only when clicked directly inside the button)
                    $onResetBtn = ($posX -ge $btnStartX -and $posX -le $btnEndX -and $posY -eq $resetBtnYCoord)
                    if ($isLeftClick -and $onResetBtn) {
                        if ($script:isV6Toggling) { continue }
                        # 1. Permission check: Expert Mode
                        if (-not $global:expertMode) {
                            Write-RightLog "WARN" (T "Đặt lại Mạng & DNS yêu cầu Chế độ chuyên gia! Vui lòng bật [Expert Mode]." "Resetting Network & DNS requires Expert Mode! Please turn ON [Expert Mode].") $cYellow
                            Set-Activity "!" (T "Yêu cầu Chế độ chuyên gia" "Expert Mode Required") $cYellow
                            continue
                        }

                        # 2. Permission check: Admin
                        if (-not $isAdmin) {
                            Write-RightLog "WARN" (T "Đặt lại Mạng & DNS yêu cầu quyền Administrator!" "Resetting Network & DNS requires Administrator privileges!") $cRed
                            Set-Activity "!" (T "Yêu cầu quyền Admin" "Admin Privileges Required") $cRed
                            if (Require-AdminOrPrompt "ĐẶT LẠI MẠNG & XÓA BỘ NHỚ ĐỆM DNS" "RESET NETWORK & FLUSH DNS") {}
                            continue
                        }

                        # 3. Two-step confirmation: Prevent accidental click
                        $nowTick = [Environment]::TickCount
                        if (-not $script:confirmResetNet -or ($nowTick - $script:confirmResetNetTick) -gt 3500) {
                            $script:confirmResetNet = $true
                            $script:confirmResetNetTick = $nowTick
                            Write-RightLog "WARN" (T "Cảnh báo: Nhấp nút lần nữa trong 3 giây để xác nhận Đặt lại Mạng & DNS." "Warning: Click button again within 3s to confirm Network & DNS Reset.") $cYellow
                            Set-Activity "?" (T "Nhấp lại để xác nhận" "Click again to confirm") $cYellow
                            Render-NetworkView
                            continue
                        }
                        $script:confirmResetNet = $false

                        $resetFlash = $true
                        $resetFlashTick = [Environment]::TickCount
                        Render-NetworkView

                        Write-RightLog "IN" (T "Đang đặt lại cấu hình mạng & xóa cache DNS..." "Resetting Network & DNS...") $cYellow
                        Set-Activity "RUN" (T "Đang đặt lại mạng..." "Resetting network...") $cYellow
                        try {
                            ipconfig /flushdns | Out-Null
                            Clear-DnsClientCache
                            netsh winsock reset | Out-Null
                            netsh int ip reset | Out-Null
                            Write-RightLog "OUT" (T "Đã đặt lại Winsock, TCP/IP stack và xóa cache DNS xong." "Winsock, TCP/IP stack reset and DNS flushed.") $cGreen
                            Set-Activity "OK" (T "Đã đặt lại mạng & DNS" "Network Reset Complete") $cGreen
                            try { [ConsoleMouse]::FlushConsoleInputBuffer($hInput) | Out-Null } catch {}

                            # Re-trigger Adapter Scan async
                            $psAdapter = [powershell]::Create()
                            $null = $psAdapter.AddScript($adapterScanCode)
                            $asyncAdapter = $psAdapter.BeginInvoke()
                            $script:netAdapterResult = $null
                            for ($k = 0; $k -le 5; $k++) {
                                if ($k -ne 2) {
                                    $netItems[$k].IsLoading = $true
                                }
                            }
                            Update-NetworkStrings
                            Render-NetworkView
                        } catch {
                            Write-RightLog "ERROR" (T "Lỗi khi đặt lại mạng: $_" "Error resetting network: $_") $cRed
                        }
                        continue
                    }

                    # Row Hover & Toggle Hover detection
                    $newHover = -1
                    $newToggle = $false
                    $newResetHover = $false

                    if ($posX -ge 2 -and $posX -le 39 -and $posY -ge 5 -and $posY -lt (5 + $pageSizeCurrent)) {
                        $newHover = $vertOffset + ($posY - 5)
                        if ($newHover -eq 0 -and $posX -ge 2 -and $posX -le 7) {
                            $newToggle = $true
                        }
                    } elseif ($onHScroll -and $dynMaxH -gt 0) {
                        $newHover = 998
                    } elseif ($onResetBtn) {
                        $newResetHover = $true
                    }

                    if ($newHover -ne $hoverIdx -or $newToggle -ne $hoverToggle -or $newResetHover -ne $hoverReset) {
                        $hoverIdx = $newHover
                        $hoverToggle = $newToggle
                        $hoverReset = $newResetHover
                        Render-NetworkView
                    }

                    # IPv6 ON/OFF Toggle Click
                    if ($isLeftClick -and $posY -eq 5 -and $vertOffset -eq 0 -and $posX -ge 2 -and $posX -le 7) {
                        # Strictly block click if already toggling or resetting
                        if ($script:isV6Toggling -or $resetFlash) {
                            continue
                        }

                        # Safety check: Cannot disable both IPv4 and IPv6!
                        if ($script:isV6Enabled -and -not $script:isV4Enabled) {
                            Write-RightLog "WARN" (T "Cảnh báo an toàn: Không thể tắt cả IPv4 và IPv6 cùng lúc!" "Safety: Cannot disable both IPv4 and IPv6 simultaneously!") $cYellow
                            Set-Activity "!" (T "Không thể tắt cả v4 và v6" "Cannot disable both v4 & v6") $cRed
                            continue
                        }

                        # Permission check: Expert Mode
                        if (-not $global:expertMode) {
                            Write-RightLog "WARN" (T "Bật/Tắt giao thức IPv6 yêu cầu Chế độ chuyên gia! Vui lòng bật [Expert Mode]." "Toggling IPv6 protocol requires Expert Mode! Please enable [Expert Mode].") $cYellow
                            Set-Activity "!" (T "Yêu cầu Chế độ chuyên gia" "Expert Mode Required") $cYellow
                            continue
                        }

                        # Permission check: Admin
                        if (-not $isAdmin) {
                            Write-RightLog "WARN" (T "Thay đổi cấu hình card mạng yêu cầu quyền Administrator!" "Modifying network adapter requires Administrator privileges!") $cRed
                            Set-Activity "!" (T "Yêu cầu quyền Admin" "Admin Privileges Required") $cRed
                            if (Require-AdminOrPrompt "BẬT/TẮT GIAO THỨC IPV6" "TOGGLE IPV6 PROTOCOL") {}
                            continue
                        }

                        # Lock and start asynchronous toggle with button spinner
                        $script:isV6Toggling = $true
                        $script:v6TargetAction = if ($script:isV6Enabled) { "DISABLE" } else { "ENABLE" }
                        $netItems[0].IsLoading = $true

                        $adName = if ($script:netCenterAdapter) { $script:netCenterAdapter } else { "Ethernet" }
                        $targetAct = $script:v6TargetAction

                        $logMsg = if ($targetAct -eq "DISABLE") { (T "Đang tắt IPv6 trên card $adName..." "Disabling IPv6 on adapter $adName...") } else { (T "Đang bật IPv6 trên card $adName..." "Enabling IPv6 on adapter $adName...") }
                        $actMsg = if ($targetAct -eq "DISABLE") { (T "Đang tắt IPv6..." "Disabling IPv6...") } else { (T "Đang bật IPv6..." "Enabling IPv6...") }
                        Write-RightLog "IN" $logMsg $cYellow
                        Set-Activity "RUN" $actMsg $cYellow
                        Render-NetworkView

                        $v6ToggleScript = @'
param($adapter, $action)
$result = [PSCustomObject]@{ Success = $false; Action = $action; Error = "" }
try {
    if ($action -eq "DISABLE") {
        Disable-NetAdapterBinding -Name $adapter -ComponentID ms_tcpip6 -ErrorAction Stop
    } else {
        Enable-NetAdapterBinding -Name $adapter -ComponentID ms_tcpip6 -ErrorAction Stop
    }
    $result.Success = $true
} catch {
    $result.Error = $_.ToString()
}
return $result
'@
                        if ($psV6Toggle) { try { $psV6Toggle.Dispose() } catch {} }
                        $psV6Toggle = [powershell]::Create()
                        $null = $psV6Toggle.AddScript($v6ToggleScript).AddArgument($adName).AddArgument($targetAct)
                        $asyncV6Toggle = $psV6Toggle.BeginInvoke()
                        continue
                    }

                    # Click on item row to copy
                    if ($isLeftClick -and $hoverIdx -ge 0 -and $hoverIdx -lt $netItems.Count -and -not ($hoverIdx -eq 0 -and $hoverToggle)) {
                        $item = $netItems[$hoverIdx]

                        # Wi-Fi Password permission guard: If Expert Mode is OFF, warn user
                        if ($item.Id -eq "WIFI_PASS" -and -not $global:expertMode -and $script:wifiResult -and $script:wifiResult.Pass) {
                            Write-RightLog "WARN" (T "Xem mật khẩu Wi-Fi yêu cầu Chế độ chuyên gia! Nhấp [ON] ở Expert Mode để bật." "Viewing Wi-Fi password requires Expert Mode! Click [ON] at Expert Mode to enable.") $cYellow
                            Set-Activity "!" (T "Yêu cầu Chế độ chuyên gia" "Expert Mode Required") $cYellow
                            continue
                        }

                        $copyVal = if ($item.RawCopyVal) { $item.RawCopyVal } else { [string]$item.Value }
                        if ($copyVal -and -not $item.IsLoading -and $copyVal -notmatch '^\(') {
                            try {
                                Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
                                [System.Windows.Forms.Clipboard]::SetText($copyVal)
                                $lbl = $item.PrefixTag.Trim().Replace(":", "")
                                Write-RightLog "CLIPBOARD" (T "Đã sao chép ${lbl}: $copyVal" "Copied ${lbl}: $copyVal") $cGreen
                                Set-Activity "OK" (T "Đã sao chép $lbl" "Copied $lbl") $cGreen
                            } catch {}
                            $flashIdx = $hoverIdx
                            $flashTick = [Environment]::TickCount
                            Render-NetworkView
                        }
                    }
                }
            }
        }
    } finally {
        if ($psAdapter) { try { $psAdapter.Dispose() } catch {} }
        if ($psWan) { try { $psWan.Dispose() } catch {} }
        if ($psWifi) { try { $psWifi.Dispose() } catch {} }
        if ($psV6Toggle) { try { $psV6Toggle.Dispose() } catch {} }
        $script:currentHoverTarget = "NONE"
        $script:currentClickTarget = "NONE"
        $global:onLanguageChanged = $null
        $global:currentActionTitleVi = $null
        $global:currentActionTitleEn = $null
        $global:currentActionName = $null
        $global:currentActionBorderColor = $null
        Update-IdleActivity
        Draw-LeftMenu $false
        Draw-StatusPane
    }
}

function Invoke-ScreenPowerShortcut() {
    $isVi = ($global:selectedLang -eq "Vietnamese")
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
        $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
        $saveDialog.FileName = "Turn Off Screen.bat"
        $saveDialog.Filter = "Batch Files (*.bat)|*.bat|All Files (*.*)|*.*"
        $saveDialog.Title = if ($isVi) { "Chọn vị trí lưu lối tắt tắt màn hình" } else { "Save Turn Off Screen Shortcut To..." }
        $saveDialog.InitialDirectory = [Environment]::GetFolderPath('Desktop')
        if ($saveDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $destPath = $saveDialog.FileName
            $batLines = @(
                "<# :",
                "@echo off",
                "set `"SCREEN_BAT_PATH=%~f0`"",
                "powershell -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -Command `"`$code = [System.IO.File]::ReadAllText(`$env:SCREEN_BAT_PATH, [System.Text.Encoding]::UTF8); & {[ScriptBlock]::Create(`$code).Invoke()}`"",
                "exit /b",
                "#>",
                "Start-Sleep -Seconds 1",
                "try {",
                "    `$type = Add-Type -MemberDefinition '[DllImport(`"user32.dll`")]public static extern int SendMessage(int hWnd, int hMsg, int wParam, int lParam);' -Name ScreenOff -Namespace Win32 -PassThru",
                "    `$type::SendMessage(-1, 0x0112, 0xF170, 2) | Out-Null",
                "} catch {}"
            )
            [System.IO.File]::WriteAllLines($destPath, $batLines, [System.Text.Encoding]::ASCII)
            Write-LeftConsole (T " [OK] Đã tạo lối tắt tại $destPath" " [OK] Shortcut created at $destPath") $cGreen
            Write-RightLog "OUT" (T "Đã tạo lối tắt tắt màn hình tại $destPath" "Created screen shortcut at $destPath") $cGreen
            Set-Activity "OK" (T "Hoàn thành: Đã tạo lối tắt" "Done: Desktop Shortcut Created") $cGreen
            Start-Sleep -Milliseconds 800
        } else {
            Write-RightLog "IN" (T "Đã hủy tạo lối tắt." "Shortcut creation cancelled.") $cDim
        }
    } catch {
        Write-RightLog "ERR" (T "Lỗi khi tạo lối tắt: $_" "Error creating shortcut: $_") $cRed
    }
}

# --- [4.6] Screen & Power Tools ---
function Invoke-ScreenPowerMenu() {
    Write-DebugLog "&&" "[4.6] Invoking Screen & Power Tools Menu..."
    Write-RightLog "IN" (T "Mở bảng chọn Tắt màn hình" "Opened Turn Off Screen menu") $cWhite
    Write-RightLog "INFO" (T "[i] Chọn [1] để tắt màn hình ngay, [2] để tạo lối tắt ra Màn hình chính" "[i] Press [1] to turn off screen now, [2] to create shortcut") $cLightCyan
    while ($true) {
        Start-ActionView "TẮT MÀN HÌNH" $cYellow "TURN OFF SCREEN"
        Write-LeftConsole (T " [1] Tắt màn hình ngay" " [1] Turn Off Screen Now") $cLightGreen
        Write-LeftConsole (T " [2] Tạo lối tắt tắt màn hình" " [2] Create Screen Shortcut") $cCyan

        $choice = Wait-SingleKey $null @('1', '2', 'Q')
        if (-not $choice -or $choice -in @('Q', 'ESC') -or $script:lastActionEscPressed) { break }

        if ($choice -eq '1') {
            Write-RightLog "OUT" (T "Đang tắt màn hình ngay lập tức..." "Turning off screen immediately...") $cYellow
            Write-LeftConsole ""
            Write-LeftConsole (T " [*] Đang tắt màn hình ngay lập tức..." " [*] Turning off screen immediately...") $cLightGreen

            if (-not $script:win32ScreenType) {
                try {
                    $script:win32ScreenType = Add-Type '[DllImport("user32.dll")]public static extern int SendMessage(int hWnd, int hMsg, int wParam, int lParam);' -Name "Win32ScreenOff" -Namespace "WCaO" -PassThru -ErrorAction SilentlyContinue
                } catch {
                    try { $script:win32ScreenType = [WCaO.Win32ScreenOff] } catch {}
                }
            }
            if ($script:win32ScreenType) {
                $script:win32ScreenType::SendMessage(-1, 0x0112, 0xF170, 2) | Out-Null
            }

            # Screen wakes up on user activity
            Set-Activity "OK" (T "Đã tắt màn hình ngay lập tức" "Screen turned off immediately") $cGreen
            Write-RightLog "OUT" (T "Màn hình đã bật lại sau khi tắt" "Screen woke up after turn-off") $cGreen
        } elseif ($choice -eq '2') {
            Invoke-ScreenPowerShortcut
        }
    }
}

# -------------------------------------------------------------------------------
#  SECTION 7.4: ADVANCED SYSTEM TOOLS (MENU [5])
# -------------------------------------------------------------------------------
# --- [5.1] Clear Update Cache ---
function Invoke-ClearWinUpdate($autoMode = $false) {
    Write-DebugLog "&&" "[5.1] Invoking Clear Windows Update Cache..."
    if (-not (Require-AdminOrPrompt "XÓA BỘ ĐỆM WINDOWS UPDATE" "CLEAR WINDOWS UPDATE CACHE")) { return }
    Start-ActionView "XÓA BỘ ĐỆM WINDOWS UPDATE" $cPurp "CLEAR WINDOWS UPDATE CACHE"

    Write-LeftConsoleProgress (T "Đang dừng dịch vụ cập nhật..." "Stopping update services...") $cYellow
    Run-And-LogCommand "net" "stop wuauserv /y" | Out-Null
    Run-And-LogCommand "net" "stop bits" | Out-Null
    Run-And-LogCommand "net" "stop cryptsvc" | Out-Null
    Start-Sleep -Seconds 1
    Update-LeftConsoleLine (T " [OK] Đã dừng dịch vụ cập nhật." " [OK] Update services stopped.") $cGreen

    if (Test-Path "$env:windir\SoftwareDistribution") {
        $msgDel1 = T "Đang xóa SoftwareDistribution..." "Deleting SoftwareDistribution..."
        Invoke-ScriptWithSpinner { Remove-Item "$env:windir\SoftwareDistribution" -Recurse -Force -EA SilentlyContinue } $msgDel1 $cYellow
        Update-LeftConsoleLine (T " [OK] Đã xóa SoftwareDistribution." " [OK] Deleted SoftwareDistribution.") $cGreen
    }
    if (Test-Path "$env:windir\System32\catroot2") {
        $msgDel2 = T "Đang xóa catroot2..." "Deleting catroot2..."
        Invoke-ScriptWithSpinner { Remove-Item "$env:windir\System32\catroot2" -Recurse -Force -EA SilentlyContinue } $msgDel2 $cYellow
        Update-LeftConsoleLine (T " [OK] Đã xóa catroot2." " [OK] Deleted catroot2.") $cGreen
    }

    Write-LeftConsoleProgress (T "Đang khởi động lại dịch vụ cập nhật..." "Restarting update services...") $cYellow
    Run-And-LogCommand "net" "start cryptsvc" | Out-Null
    Run-And-LogCommand "net" "start bits" | Out-Null
    Run-And-LogCommand "net" "start wuauserv" | Out-Null
    Update-LeftConsoleLine (T " [OK] Đã khởi động lại dịch vụ cập nhật." " [OK] Update services restarted.") $cGreen

    if ($script:lastTaskCancelled) {
        Set-Activity "!" (T "Đã dừng: Xóa bộ đệm cập nhật" "Stopped: Clear Windows Update Cache") $cYellow
        if (-not $autoMode) { Wait-LeftReturn }
        return $false
    }
    Write-LeftConsole (T " [OK] Đã xóa bộ đệm Windows Update." " [OK] Windows Update Cache cleared.") $cGreen
    Set-Activity "OK" (T "Hoàn thành: Xóa bộ đệm cập nhật" "Done: Clear Windows Update Cache") $cGreen
    if (-not $autoMode) { Wait-LeftReturn }
    return $true
}

# --- [5.2] Create Restore Point ---
function Invoke-CreateRestorePoint() {
    Write-DebugLog "&&" "[5.2] Invoking Create System Restore Point..."
    if (-not (Require-AdminOrPrompt "TẠO ĐIỂM KHÔI PHỤC HỆ THỐNG" "CREATE RESTORE POINT")) { return }
    Start-ActionView "TẠO ĐIỂM KHÔI PHỤC HỆ THỐNG" $cPurp "CREATE RESTORE POINT"
    $rpScript = "try { Enable-ComputerRestore -Drive '$sysDrive' -ErrorAction SilentlyContinue; `$w = `$null; Checkpoint-Computer -Description 'WCaO_Backup' -RestorePointType 'MODIFY_SETTINGS' -WarningVariable w -WarningAction SilentlyContinue -ErrorAction Stop; if (`$w) { return `$false }; return `$true } catch { return `$false }"
    $rpRes = Invoke-ActionWithSpinner $rpScript (T "Đang tạo điểm khôi phục..." "Creating Restore Point...") $cYellow 8
    $rpOk = (@($rpRes) -contains $true)
    if ($rpOk) {
        Update-LeftConsoleLine (T " [OK] Đã tạo điểm khôi phục thành công." " [OK] Restore Point created.") $cGreen
        Set-Activity "OK" (T "Hoàn thành: Tạo điểm khôi phục" "Done: Create Restore Point") $cGreen
    } else {
        Update-LeftConsoleLine (T " [!] Không thể tạo điểm khôi phục (giới hạn 24h hoặc VSS bị tắt)." " [!] Could not create Restore Point (24h limit or VSS disabled).") $cYellow
        Set-Activity "!" (T "Không thể tạo điểm khôi phục" "Restore Point failed") $cYellow
    }
    Write-LeftConsole (T " [i] Lưu ý: Windows chỉ cho phép tạo 1 điểm khôi phục mỗi 24 giờ theo mặc định." " [i] Note: Windows allows only 1 restore point per 24 hours by default.") $cDim
    Wait-LeftReturn
}

# --- [5.3] Pagefile & Hibernation ---
function Invoke-PagefileMenu() {
    Write-DebugLog "&&" "[5.3] Invoking Pagefile & Hibernation Manager..."
    if (-not (Require-ExpertOrBlock "QUẢN LÝ PHÂN VÙNG ẢO & NGỦ ĐÔNG" "PAGEFILE & HIBERNATION")) { return }
    if (-not (Require-AdminOrPrompt "QUẢN LÝ PHÂN VÙNG ẢO & NGỦ ĐÔNG" "PAGEFILE & HIBERNATION")) { return }

    while ($true) {
        Start-ActionView "PHÂN VÙNG ẢO & NGỦ ĐÔNG" $cPurp "PAGEFILE & HIBERNATION"

        $autoPf = $true
        try {
            $autoPf = (Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue).AutomaticManagedPagefile
        } catch {}

        $hiberOn = Test-Path "$env:SystemDrive\hiberfil.sys"

        Write-LeftConsole " $(T 'Phân vùng ảo   ' 'Virtual Memory '): $(if ($autoPf) { T 'Tự động' 'Auto' } else { T 'Thủ công' 'Manual' })" $(if ($autoPf) { $cGreen } else { $cYellow })
        Write-LeftConsole " $(T 'Chế độ ngủ đông' 'Hibernation    '): $(if ($hiberOn) { T 'Đang bật' 'Enabled' } else { T 'Đang tắt' 'Disabled' })" $(if ($hiberOn) { $cGreen } else { $cGray })
        Write-LeftConsole ""

        $tagPfManual = if (-not $autoPf) { " (#)" } else { "" }
        $tagPfAuto   = if ($autoPf) { " (#)" } else { "" }
        $tagHiberOff = if (-not $hiberOn) { " (#)" } else { "" }
        $tagHiberOn  = if ($hiberOn) { " (#)" } else { "" }

        Write-LeftConsole " [1] $(T 'Tắt tự động quản lý phân vùng ảo' 'Disable automatic pagefile management')$tagPfManual" $(if (-not $autoPf) { $cGreen } else { $cWhite })
        Write-LeftConsole " [2] $(T 'Tự động quản lý phân vùng ảo (Khuyên dùng)' 'Automatically manage pagefile (Recommended)')$tagPfAuto" $(if ($autoPf) { $cGreen } else { $cWhite })
        Write-LeftConsole " [3] $(T 'Tắt chế độ ngủ đông' 'Disable hibernation')$tagHiberOff" $(if (-not $hiberOn) { $cGreen } else { $cWhite })
        Write-LeftConsole " [4] $(T 'Bật chế độ ngủ đông' 'Enable hibernation')$tagHiberOn" $(if ($hiberOn) { $cGreen } else { $cWhite })

        $pf = Wait-SingleKey (T "Chọn thao tác [1-4]" "Select option [1-4]") @('1', '2', '3', '4', 'Q')
        if (-not $pf -or $pf -in @('Q', 'ESC') -or $script:lastActionEscPressed) { break }

        if ($pf -eq "1") {
            if (-not $autoPf) {
                Write-LeftConsole ""
                Write-LeftConsole (T " [i] Phân vùng ảo đã ở chế độ thủ công." " [i] Pagefile is already set to manual.") $cYellow
                Start-Sleep -Milliseconds 600
                continue
            }
            Write-RightLog "IN" (T "Đang đặt quản lý phân vùng ảo thành thủ công..." "Setting AutomaticManagedPagefile = False...") $cYellow
            try {
                Set-CimInstance -Query "Select * from Win32_ComputerSystem" -Property @{AutomaticManagedPagefile=$False} -ErrorAction SilentlyContinue | Out-Null
            } catch {
                try { (Get-WmiObject Win32_ComputerSystem -ErrorAction SilentlyContinue).AutomaticManagedPagefile = $false } catch {}
            }
            Write-LeftConsole (T " [OK] Đã tắt tự động quản lý phân vùng ảo." " [OK] Auto Pagefile disabled.") $cGreen
            Write-RightLog "OUT" (T "Đã đặt AutomaticManagedPagefile thành False" "AutomaticManagedPagefile set to False") $cGreen
            Set-Activity "OK" (T "Đã tắt tự động phân vùng ảo" "Disabled Auto Pagefile") $cGreen
            Start-Sleep -Milliseconds 700
        } elseif ($pf -eq "2") {
            if ($autoPf) {
                Write-LeftConsole ""
                Write-LeftConsole (T " [i] Phân vùng ảo đã ở chế độ tự động." " [i] Pagefile is already set to auto.") $cYellow
                Start-Sleep -Milliseconds 600
                continue
            }
            Write-RightLog "IN" (T "Đang khôi phục tự động quản lý phân vùng ảo..." "Enabling AutomaticManagedPagefile = True...") $cYellow
            try {
                Set-CimInstance -Query "Select * from Win32_ComputerSystem" -Property @{AutomaticManagedPagefile=$True} -ErrorAction SilentlyContinue | Out-Null
            } catch {
                try { (Get-WmiObject Win32_ComputerSystem -ErrorAction SilentlyContinue).AutomaticManagedPagefile = $true } catch {}
            }
            Write-LeftConsole (T " [OK] Đã khôi phục tự động quản lý phân vùng ảo." " [OK] Auto Pagefile restored.") $cGreen
            Write-RightLog "OUT" (T "Đã đặt AutomaticManagedPagefile thành True" "AutomaticManagedPagefile set to True") $cGreen
            Set-Activity "OK" (T "Đã bật tự động phân vùng ảo" "Enabled Auto Pagefile") $cGreen
            Start-Sleep -Milliseconds 700
        } elseif ($pf -eq "3") {
            if (-not $hiberOn) {
                Write-LeftConsole ""
                Write-LeftConsole (T " [i] Chế độ ngủ đông đang tắt." " [i] Hibernation is already disabled.") $cYellow
                Start-Sleep -Milliseconds 600
                continue
            }
            Run-And-LogCommand "powercfg" "-h off" | Out-Null
            Write-LeftConsole (T " [OK] Đã tắt chế độ ngủ đông." " [OK] Hibernation disabled.") $cGreen
            Write-RightLog "OUT" (T "Đã tắt chế độ ngủ đông" "Hibernation disabled") $cGreen
            Set-Activity "OK" (T "Đã tắt chế độ ngủ đông" "Disabled Hibernation") $cGreen
            Start-Sleep -Milliseconds 700
        } elseif ($pf -eq "4") {
            if ($hiberOn) {
                Write-LeftConsole ""
                Write-LeftConsole (T " [i] Chế độ ngủ đông đang bật." " [i] Hibernation is already enabled.") $cYellow
                Start-Sleep -Milliseconds 600
                continue
            }
            Run-And-LogCommand "powercfg" "-h on" | Out-Null
            Write-LeftConsole (T " [OK] Đã bật chế độ ngủ đông." " [OK] Hibernation enabled.") $cGreen
            Write-RightLog "OUT" (T "Đã bật chế độ ngủ đông" "Hibernation enabled") $cGreen
            Set-Activity "OK" (T "Đã bật chế độ ngủ đông" "Enabled Hibernation") $cGreen
            Start-Sleep -Milliseconds 700
        }
    }
}

function Invoke-UndoBatchRename() {
    $uLog = if ($script:undoLog) { $script:undoLog } else { "$baseDir\Rename.undo" }
    if (Test-Path $uLog) {
        Write-LeftConsoleProgress (T "Đang hoàn tác đợt đổi tên gần nhất..." "Undoing last batch...") $cYellow
        $lines = @(Get-Content $uLog)
        $idx = -1
        for ($i = $lines.Count - 1; $i -ge 0; $i--) { if ($lines[$i] -eq '---BATCH_START---') { $idx = $i; break } }
        if ($idx -ne -1) {
            $b = @(); if ($idx -lt $lines.Count - 1) { $b = @($lines[($idx + 1)..($lines.Count - 1)]) }
            [array]::Reverse($b)
            foreach ($l in $b) {
                $p = $l -split '\|'
                if ($p.Length -eq 3) {
                    $fp = Join-Path $p[0] $p[1]
                    if (Test-Path -LiteralPath $fp) {
                        try { Rename-Item -LiteralPath $fp -NewName $p[2] -Force -EA Stop; Write-LeftConsole "[UNDO OK] $($p[1]) -> $($p[2])" $cGreen } catch {}
                    }
                }
            }
            if ($idx -gt 0) { Set-Content -Path $uLog -Value $lines[0..($idx - 1)] -Force } else { Remove-Item $uLog -Force }
        }
        Update-LeftConsoleLine (T " [OK] Hoàn tác đổi tên hoàn tất." " [OK] Undo batch complete.") $cGreen
        Set-Activity "OK" (T "Hoàn thành: Hoàn tác đổi tên" "Done: Undo Batch Rename") $cGreen
    } else {
        Write-LeftConsole (T " [!] Không có dữ liệu để hoàn tác." " [!] Nothing to undo.") $cYellow
        Set-Activity "!" (T "Không có dữ liệu hoàn tác" "Nothing to undo") $cYellow
    }
}

# --- [5.4] Quick Rename ---
function Invoke-QuickRenamePro {
    Write-DebugLog "&&" "[5.4] Invoking Quick Rename Pro..."
    Write-RightLog "IN" (T "Mở công cụ Đổi tên hàng loạt" "Opened Quick Rename") $cWhite
    Write-RightLog "INFO" (T "[i] Nhập đường dẫn thư mục để xử lý, hoặc gõ '9' để hoàn tác" "[i] Enter target folder path, or type '9' to undo") $cLightCyan

    $targetDir = $null
    while ($true) {
        Start-ActionView "ĐỔI TÊN HÀNG LOẠT" $cLightYellow "QUICK RENAME"

        Write-LeftConsole (T "Nhập đường dẫn thư mục cần xử lý:" "Enter target folder path:") $cWhite
        Write-LeftConsole (T " (Gõ '9' để Hoàn tác, hoặc bấm ESC để Trở về)" " (Type '9' to Undo, or press ESC to Back)") $cGray
        Write-LeftConsole ""

        $inp = Get-LeftInput (T "Đường dẫn thư mục" "Folder path")
        if (-not $inp -or [string]$inp -match '^(exit|quit)$') {
            $leftConsoleLines.Clear()
            $global:currentActionName = $null
            $global:currentActionBorderColor = $null
            Update-IdleActivity
            Draw-LeftMenu $false
            Draw-StatusPane
            return
        }

        $inpTrim = ([string]$inp).Trim('"').Trim()

        if ($inpTrim -in @('9', 'undo')) {
            Invoke-UndoBatchRename
            Wait-LeftReturn
            return
        }

        $driveRoot = [System.IO.Path]::GetPathRoot($inpTrim)
        if (-not $driveRoot -or -not (Test-Path $driveRoot)) {
            Write-LeftConsole (T "[-] Phân vùng/ổ đĩa không tồn tại ($driveRoot)!" "[-] Partition/Drive does not exist ($driveRoot)!") $cRed
            Set-Activity "!" (T "Phân vùng không hợp lệ" "Invalid Partition") $cRed
            Start-Sleep -Milliseconds 1200
            continue
        }
        if (-not (Test-Path -LiteralPath $inpTrim)) {
            Write-LeftConsole (T "[-] Thư mục không tồn tại trên ổ $driveRoot! Thử lại..." "[-] Folder not found on $driveRoot! Retry...") $cRed
            Set-Activity "!" (T "Đường dẫn không tồn tại" "Path does not exist") $cRed
            Start-Sleep -Milliseconds 1200
            continue
        }

        $targetDir = $inpTrim
        break
    }

    $qrModes = @(
        @{ Key = '1'; Vi = "Trích xuất ngoặc tệp"; En = "Extract Brackets File"; ExVi = "VD: Tep(2023).txt -> 2023.txt"; ExEn = "Ex: File(2023).txt -> 2023.txt" },
        @{ Key = '2'; Vi = "Chuỗi số thứ tự tệp"; En = "Sequential Series File"; ExVi = "VD: ThuMuc - 1.ext, 2.ext..."; ExEn = "Ex: Folder - 1.ext, 2.ext..." },
        @{ Key = '3'; Vi = "Xóa phần đuôi tên tệp"; En = "Remove Suffix File"; ExVi = "VD: Anh_copy.png -> Anh.png"; ExEn = "Ex: Image_copy.png -> Image.png" },
        @{ Key = '4'; Vi = "Thay thế chuỗi tên tệp"; En = "Replace String File"; ExVi = "VD: Chuỗi A -> B"; ExEn = "Ex: String A -> B" },
        @{ Key = '5'; Vi = "Trích xuất ngoặc thư mục"; En = "Extract Brackets Folder"; ExVi = "VD: TaiLieu(Mat) -> Mat"; ExEn = "Ex: Docs(Secret) -> Secret" },
        @{ Key = '6'; Vi = "Xóa phần đuôi thư mục"; En = "Remove Suffix Folder"; ExVi = "VD: SaoLuu_cu -> SaoLuu"; ExEn = "Ex: Backup_old -> Backup" },
        @{ Key = '7'; Vi = "Đổi tên từ tệp văn bản"; En = "Rename from .txt list"; ExVi = "VD: Đọc danh sách dòng"; ExEn = "Ex: Read lines from file" },
        @{ Key = '8'; Vi = "Đổi tên từng mục"; En = "Fast Rename Step-by-Step"; ExVi = "VD: Từng tệp / thư mục"; ExEn = "Ex: Each file / folder" },
        @{ Key = '9'; Vi = "Hoàn tác đợt gần nhất"; En = "Undo Last Batch"; ExVi = "VD: Khôi phục tên cũ"; ExEn = "Ex: Restore old names" },
        @{ Key = 'R'; Vi = "Làm mới danh sách"; En = "Refresh Folder View"; ExVi = "VD: Cập nhật lại thư mục"; ExEn = "Ex: Re-check current folder" }
    )

    $script:qrItemBounds = @{}
    for ($i = 0; $i -lt $qrModes.Count; $i++) {
        $k = $qrModes[$i].Key
        $script:qrItemBounds[$k] = @{
            Index  = $i
            StartY = 8 + $i
            EndY   = 8 + $i
        }
    }

    $inQrMenu = $true
    while ($inQrMenu) {
        $hoverKey = $null

        function Local:Render-QrRow($idx, $isHover) {
            $item = $qrModes[$idx]
            $k = $item.Key
            $title = if ($global:selectedLang -eq "Vietnamese") { $item.Vi } else { $item.En }
            $ex = if ($global:selectedLang -eq "Vietnamese") { $item.ExVi } else { $item.ExEn }
            $rowY = 8 + $idx
            $l1 = " [$k] $title"
            if ($l1.Length -gt 38) { $l1 = $l1.Substring(0, 38) } else { $l1 = $l1.PadRight(38) }
            Set-CursorPos 2 $rowY
            if ($isHover) {
                $hBgHover = "$ESC[48;2;45;48;54m$ESC[38;2;255;255;255m"
                [Console]::Write("$hBgHover$l1 $cReset")
                $exLine = " $ex"
                if ($exLine.Length -gt 38) { $exLine = $exLine.Substring(0, 38) } else { $exLine = $exLine.PadRight(38) }
                Set-CursorPos 2 20
                [Console]::Write("$cLightCyan$exLine $cReset")
            } else {
                [Console]::Write("$cWhite$l1 $cReset")
            }
        }

        function Local:Draw-RenameScreen([string]$activeHover, $animate = $false) {
            Start-ActionView "ĐỔI TÊN HÀNG LOẠT" $cLightYellow "QUICK RENAME"

            $displayPath = if ($targetDir.Length -gt 28) { $targetDir.Substring(0, 12) + "..." + $targetDir.Substring($targetDir.Length - 13) } else { $targetDir }
            Write-LeftConsole " $(T 'Thư mục' 'Folder '): $displayPath" $cCyan
            $fCount = @(Get-ChildItem -LiteralPath $targetDir -File -ErrorAction SilentlyContinue).Count
            $dCount = @(Get-ChildItem -LiteralPath $targetDir -Directory -ErrorAction SilentlyContinue).Count
            Write-LeftConsole (T "   ($fCount tệp, $dCount thư mục con)" "   ($fCount files, $dCount subfolders)") $cDim
            Write-LeftConsole (T " --- Chọn chế độ xử lý ---" " --- Select Rename Mode ---") $cLightYellow

            for ($i = 0; $i -lt $qrModes.Count; $i++) {
                $item = $qrModes[$i]
                $k = $item.Key
                $title = if ($global:selectedLang -eq "Vietnamese") { $item.Vi } else { $item.En }
                $isHov = ($activeHover -eq $k)

                if ($isHov) {
                    $hBgHover = "$ESC[48;2;45;48;54m$ESC[38;2;255;255;255m"
                    Write-LeftConsole " [$k] $title" $hBgHover
                } else {
                    Write-LeftConsole " [$k] $title" $cWhite
                }

                if ($animate) { Start-Sleep -Milliseconds 10 }
            }
            Write-LeftConsole ""
            Write-LeftConsole " -------------------------------------" $cDim
            $initEx = if ($activeHover) {
                $hovItem = $qrModes | Where-Object { $_.Key -eq $activeHover } | Select-Object -First 1
                if ($hovItem) { if ($global:selectedLang -eq "Vietnamese") { $hovItem.ExVi } else { $hovItem.ExEn } }
            } else {
                if ($global:selectedLang -eq "Vietnamese") { " Di chuột xem ví dụ | Phím/Click chọn" } else { " Hover for example | Key/Click to select" }
            }
            Write-LeftConsole " $initEx" $cLightCyan
        }

        Draw-RenameScreen $hoverKey $true

        # ConsoleMouse interactive loop for Quick Rename
        $hInput = [ConsoleMouse]::GetStdHandle([ConsoleMouse]::STD_INPUT_HANDLE)
        try { [ConsoleMouse]::FlushConsoleInputBuffer($hInput) | Out-Null } catch {}
        $records = New-Object ConsoleMouse+INPUT_RECORD[] 64

        $selectedOption = $null
        $waitingForChoice = $true
        while ($waitingForChoice) {
            Start-Sleep -Milliseconds 25
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
                    Draw-FullLayout $false
                    Draw-RenameScreen $hoverKey
                    continue
                }

                # Key Event
                if ($rec.EventType -eq 1 -and $rec.KeyEvent.bKeyDown -ne 0) {
                    $vk = $rec.KeyEvent.wVirtualKeyCode
                    $char = $rec.KeyEvent.UnicodeChar.ToString().ToUpper()

                    if ($vk -eq 0x1B) { # ESC
                        $selectedOption = 'ESC'
                        $waitingForChoice = $false
                        break
                    }
                    if ($char -in @('1','2','3','4','5','6','7','8','9','R')) {
                        $selectedOption = $char
                        $waitingForChoice = $false
                        break
                    }
                }

                # Mouse Event
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

                    # Hover detection for QR items
                    $newHov = $null
                    if ($posX -ge 2 -and $posX -le 40) {
                        foreach ($k in $script:qrItemBounds.Keys) {
                            $b = $script:qrItemBounds[$k]
                            if ($posY -ge $b.StartY -and $posY -le $b.EndY) {
                                $newHov = $k
                                break
                            }
                        }
                    }
                    if ($newHov -ne $hoverKey) {
                        if ($hoverKey -and $script:qrItemBounds.ContainsKey($hoverKey)) {
                            Render-QrRow $script:qrItemBounds[$hoverKey].Index $false
                        }
                        if ($newHov -and $script:qrItemBounds.ContainsKey($newHov)) {
                            Render-QrRow $script:qrItemBounds[$newHov].Index $true
                        } else {
                            $defEx = if ($global:selectedLang -eq "Vietnamese") { " Di chuột xem ví dụ | Phím/Click chọn" } else { " Hover for example | Key/Click to select" }
                            if ($defEx.Length -gt 38) { $defEx = $defEx.Substring(0, 38) } else { $defEx = $defEx.PadRight(38) }
                            Set-CursorPos 2 20
                            [Console]::Write("$cLightCyan$defEx $cReset")
                        }
                        $hoverKey = $newHov
                    }

                    if ($isLeftDown -and -not $script:wasLeftDown) {
                        $script:wasLeftDown = $true
                        if ($target -eq "BACK_BTN" -or $target.StartsWith("BREADCRUMB_")) {
                            if ($target.StartsWith("BREADCRUMB_")) {
                                Handle-GlobalClick $posX $posY | Out-Null
                            }
                            $selectedOption = 'ESC'
                            $waitingForChoice = $false
                            break
                        }
                        if ($hoverKey) {
                            $selectedOption = $hoverKey
                            $waitingForChoice = $false
                            break
                        }
                        $prevLang = $global:selectedLang
                        $res = Handle-GlobalClick $posX $posY
                        if ($res -eq "LANG_CHANGED" -or ($res -eq "HANDLED" -and $global:selectedLang -ne $prevLang)) {
                            Draw-RenameScreen $hoverKey
                        }
                    } elseif (-not $isLeftDown) {
                        $script:wasLeftDown = $false
                    }
                }
            }
        }

        if (-not $selectedOption -or $selectedOption -eq 'ESC') {
            $leftConsoleLines.Clear()
            $global:currentActionName = $null
            $global:currentActionBorderColor = $null
            Update-IdleActivity
            Draw-LeftMenu $false
            Draw-StatusPane
            Write-RightLog "$" (T "Đã thoát Đổi tên hàng loạt" "Exited Quick Rename Pro") $cDim
            return
        }

        if ($selectedOption -eq 'R') {
            Write-RightLog "OUT" (T "Đã làm mới thư mục $targetDir" "Refreshed folder view for $targetDir") $cGreen
            Set-Activity "OK" (T "Đã làm mới thư mục" "Refreshed Folder") $cGreen
            continue
        }

        $m = $selectedOption
        Start-ActionView "ĐỔI TÊN HÀNG LOẠT" $cLightYellow "QUICK RENAME"
        Write-LeftConsole " $(T 'Thư mục' 'Folder '): $targetDir" $cLightCyan
        Write-LeftConsole ""

        if ($m -eq "9") {
            Invoke-UndoBatchRename
            Wait-LeftReturn
            continue
        }

        Add-Content -Path $undoLog -Value "---BATCH_START---"

        if ($m -eq "1") {
            Get-ChildItem -LiteralPath $targetDir -File | Where-Object { $_.BaseName -match '\(([^()]+)\)$' } | ForEach-Object {
                $extracted = [regex]::Match($_.BaseName, '\(([^()]+)\)$').Groups[1].Value
                $nn = $extracted + $_.Extension; $old = $_.Name
                if ($nn -eq $old) { return }
                $targetPath = Join-Path $_.DirectoryName $nn
                if (Test-Path -LiteralPath $targetPath) {
                    Write-LeftConsole (T "[-] Trùng tên (bỏ qua): $nn" "[-] Name collision (skipped): $nn") $cYellow
                    return
                }
                try { Rename-Item -LiteralPath $_.FullName -NewName $nn -Force -EA Stop; Write-LeftConsole "[OK] $old -> $nn" $cGreen; Add-Content -Path $undoLog -Value ($_.DirectoryName + "|" + $nn + "|" + $old) } catch { Write-LeftConsole (T "[-] Lỗi đổi tên: $($_.Exception.Message)" "[-] Rename error: $($_.Exception.Message)") $cRed }
            }
            Write-RightLog "DECLARED" (T "Đã trích xuất ngoặc tên tệp trong $targetDir" "Ran File Extract Brackets in $targetDir") $cGreen
        } elseif ($m -eq "2") {
            $fName = (Get-Item -LiteralPath $targetDir).Name; $files = Get-ChildItem -LiteralPath $targetDir -File | Sort-Object @{e={[regex]::Replace($_.BaseName, '\d+', [System.Text.RegularExpressions.MatchEvaluator]{param($match) $match.Value.PadLeft(10, '0')})}}, Name
            $pairs = @()
            $i = 1
            foreach ($f in $files) {
                $nn = "$fName - $i$($f.Extension)"
                $pairs += @{ File = $f; FinalName = $nn; OrigName = $f.Name; Dir = $f.DirectoryName; Full = $f.FullName }
                $i++
            }
            # Pass 1: Đổi tất cả sang tên tạm để tránh va chạm số thứ tự
            $tempEntries = @()
            $tempCounter = 0
            foreach ($p in $pairs) {
                if ($p.FinalName -eq $p.OrigName) { continue }
                $tempCounter++
                $tempName = "__WCAO_TMP_{0}_{1}__" -f $tempCounter, [guid]::NewGuid().ToString('N').Substring(0,8)
                $tempFull = Join-Path $p.Dir $tempName
                try {
                    Rename-Item -LiteralPath $p.Full -NewName $tempName -Force -EA Stop
                    $tempEntries += @{ TempFull = $tempFull; TempName = $tempName; FinalName = $p.FinalName; OrigName = $p.OrigName; Dir = $p.Dir }
                } catch {
                    Write-LeftConsole (T "[-] Lỗi đổi tên tạm: $($_.Exception.Message)" "[-] Temp rename error: $($_.Exception.Message)") $cRed
                }
            }
            # Pass 2: Đổi từ tên tạm sang tên đích cuối cùng
            foreach ($t in $tempEntries) {
                $finalFull = Join-Path $t.Dir $t.FinalName
                try {
                    if ((Test-Path -LiteralPath $finalFull) -and $t.OrigName -ne $t.FinalName) {
                        Write-LeftConsole (T "[-] Trùng tên cuối cùng (bỏ qua): $($t.FinalName)" "[-] Final name collision (skipped): $($t.FinalName)") $cYellow
                        try {
                            Rename-Item -LiteralPath $t.TempFull -NewName $t.OrigName -Force -EA Stop
                        } catch {
                            Write-LeftConsole (T " [!!] CẢNH BÁO: Tệp vẫn ở tên tạm: $($t.TempName)" " [!!] WARNING: File remains with temp name: $($t.TempName)") $cRed
                        }
                        continue
                    }
                    Rename-Item -LiteralPath $t.TempFull -NewName $t.FinalName -Force -EA Stop
                    Write-LeftConsole "[OK] $($t.OrigName) -> $($t.FinalName)" $cGreen
                    Add-Content -Path $undoLog -Value ($t.Dir + "|" + $t.FinalName + "|" + $t.OrigName)
                } catch {
                    Write-LeftConsole (T "[-] Lỗi đổi tên: $($_.Exception.Message)" "[-] Rename error: $($_.Exception.Message)") $cRed
                    try {
                        Rename-Item -LiteralPath $t.TempFull -NewName $t.OrigName -Force -EA Stop
                    } catch {
                        Write-LeftConsole (T " [!!] CẢNH BÁO: Tệp vẫn ở tên tạm: $($t.TempName)" " [!!] WARNING: File remains with temp name: $($t.TempName)") $cRed
                    }
                }
            }

            
            Write-RightLog "DECLARED" (T "Đã đánh số thứ tự tệp trong $targetDir" "Ran File Sequential Series in $targetDir") $cGreen
        } elseif ($m -eq "3") {
            $suf = Get-LeftInput (T "Nhập phần đuôi cần xóa (Tệp)" "Enter suffix to remove (File)")
            if ($suf) {
                $rx = [regex]::Escape($suf)
                Get-ChildItem -LiteralPath $targetDir -File | Where-Object { $_.BaseName -match ($rx + '$') } | ForEach-Object {
                    $nn = ($_.BaseName -replace ($rx + '$'), '') + $_.Extension; $old = $_.Name
                    if ($nn -eq $old) { return }
                    $targetPath = Join-Path $_.DirectoryName $nn
                    if (Test-Path -LiteralPath $targetPath) {
                        Write-LeftConsole (T "[-] Trùng tên (bỏ qua): $nn" "[-] Name collision (skipped): $nn") $cYellow
                        return
                    }
                    try { Rename-Item -LiteralPath $_.FullName -NewName $nn -Force -EA Stop; Write-LeftConsole "[OK] $old -> $nn" $cGreen; Add-Content -Path $undoLog -Value ($_.DirectoryName + "|" + $nn + "|" + $_.Name) } catch { Write-LeftConsole (T "[-] Lỗi đổi tên: $($_.Exception.Message)" "[-] Rename error: $($_.Exception.Message)") $cRed }
                }
                Write-RightLog "DECLARED" (T "Đã xóa phần đuôi tên tệp trong $targetDir" "Ran File Remove Suffix in $targetDir") $cGreen
            }
        } elseif ($m -eq "4") {
            $strA = Get-LeftInput (T "Chuỗi cần tìm [A]" "Find string [A]")
            $strB = Get-LeftInput (T "Chuỗi thay thế [B]" "Replace with [B]")
            if ($strA) {
                $ra = [regex]::Escape($strA)
                Get-ChildItem -LiteralPath $targetDir -File | Where-Object { $_.Name -match $ra } | ForEach-Object {
                    $nn = $_.Name -replace $ra, $strB; $old = $_.Name
                    if ($nn -eq $old) { return }
                    $targetPath = Join-Path $_.DirectoryName $nn
                    if (Test-Path -LiteralPath $targetPath) {
                        Write-LeftConsole (T "[-] Trùng tên (bỏ qua): $nn" "[-] Name collision (skipped): $nn") $cYellow
                        return
                    }
                    try { Rename-Item -LiteralPath $_.FullName -NewName $nn -Force -EA Stop; Write-LeftConsole "[OK] $old -> $nn" $cGreen; Add-Content -Path $undoLog -Value ($_.DirectoryName + "|" + $nn + "|" + $old) } catch { Write-LeftConsole (T "[-] Lỗi đổi tên: $($_.Exception.Message)" "[-] Rename error: $($_.Exception.Message)") $cRed }
                }
                Write-RightLog "DECLARED" (T "Đã thay thế chuỗi tên tệp trong $targetDir" "Ran File Replace String in $targetDir") $cGreen
            }
        } elseif ($m -eq "5") {
            Get-ChildItem -LiteralPath $targetDir -Directory | Where-Object { $_.Name -match '\(([^()]+)\)$' } | ForEach-Object {
                $nn = [regex]::Match($_.Name, '\(([^()]+)\)$').Groups[1].Value; $old = $_.Name
                if ($nn -eq $old) { return }
                $targetPath = Join-Path $_.Parent.FullName $nn
                if (Test-Path -LiteralPath $targetPath) {
                    Write-LeftConsole (T "[-] Trùng tên thư mục (bỏ qua): $nn" "[-] Folder collision (skipped): $nn") $cYellow
                    return
                }
                try { Rename-Item -LiteralPath $_.FullName -NewName $nn -Force -EA Stop; Write-LeftConsole "[OK] $old -> $nn" $cGreen; Add-Content -Path $undoLog -Value ($_.Parent.FullName + "|" + $nn + "|" + $old) } catch { Write-LeftConsole (T "[-] Lỗi đổi tên: $($_.Exception.Message)" "[-] Rename error: $($_.Exception.Message)") $cRed }
            }
            Write-RightLog "DECLARED" (T "Đã trích xuất ngoặc tên thư mục trong $targetDir" "Ran Folder Extract Brackets in $targetDir") $cGreen
        } elseif ($m -eq "6") {
            $suf = Get-LeftInput (T "Nhập phần đuôi cần xóa (Thư mục)" "Enter suffix to remove (Folder)")
            if ($suf) {
                $rx = [regex]::Escape($suf)
                Get-ChildItem -LiteralPath $targetDir -Directory | Where-Object { $_.Name -match ($rx + '$') } | ForEach-Object {
                    $nn = $_.Name -replace ($rx + '$'), ''; $old = $_.Name
                    if ($nn -eq $old) { return }
                    $targetPath = Join-Path $_.Parent.FullName $nn
                    if (Test-Path -LiteralPath $targetPath) {
                        Write-LeftConsole (T "[-] Trùng tên thư mục (bỏ qua): $nn" "[-] Folder collision (skipped): $nn") $cYellow
                        return
                    }
                    try { Rename-Item -LiteralPath $_.FullName -NewName $nn -Force -EA Stop; Write-LeftConsole "[OK] $old -> $nn" $cGreen; Add-Content -Path $undoLog -Value ($_.Parent.FullName + "|" + $nn + "|" + $old) } catch { Write-LeftConsole (T "[-] Lỗi đổi tên: $($_.Exception.Message)" "[-] Rename error: $($_.Exception.Message)") $cRed }
                }
                Write-RightLog "DECLARED" (T "Đã xóa phần đuôi tên thư mục trong $targetDir" "Ran Folder Remove Suffix in $targetDir") $cGreen
            }
        } elseif ($m -eq "7") {
            $txtPath = Get-LeftInput (T "Nhập đường dẫn tệp danh sách (.txt)" "Enter path to .txt file with names")
            $txtPath = $txtPath.Trim('"')
            if (Test-Path $txtPath) {
                $names = @(Get-Content -LiteralPath $txtPath | Where-Object { $_.Trim().Length -gt 0 })
                $items = @(Get-ChildItem -LiteralPath $targetDir -File | Sort-Object @{e={[regex]::Replace($_.BaseName, '\d+', [System.Text.RegularExpressions.MatchEvaluator]{param($match) $match.Value.PadLeft(10, '0')})}}, Name)
                $count = [math]::Min($names.Count, $items.Count)
                # Preview
                $pairs = @()
                for ($k = 0; $k -lt $count; $k++) {
                    $newName = $names[$k].Trim()
                    if (-not $newName.EndsWith($items[$k].Extension)) { $newName += $items[$k].Extension }
                    $pairs += @{ Old = $items[$k].Name; New = $newName; Full = $items[$k].FullName; Dir = $items[$k].DirectoryName }
                    Write-LeftConsole "  $($items[$k].Name)  ->  $newName" $cWhite
                }
                Write-LeftConsole ""
                Write-LeftConsole (T "  Tổng cộng: $count mục sẽ được đổi tên." "  Total: $count items will be renamed.") $cCyan
                $confirm = Wait-SingleKey (T "Xác nhận đổi tên?" "Confirm rename?") @('Y','N')
                if ($confirm -eq 'Y') {
                    # Pass 1: Đổi tất cả sang tên tạm để tránh va chạm chéo / hoán đổi tên (Fix #3)
                    $tempEntries = @()
                    $tempCounter = 0
                    foreach ($p in $pairs) {
                        if ($p.New -eq $p.Old) { continue }
                        $tempCounter++
                        $tempName = "__WCAO_TMP_{0}_{1}__" -f $tempCounter, [guid]::NewGuid().ToString('N').Substring(0,8)
                        $tempFull = Join-Path $p.Dir $tempName
                        try {
                            Rename-Item -LiteralPath $p.Full -NewName $tempName -Force -EA Stop
                            $tempEntries += @{ TempFull = $tempFull; TempName = $tempName; FinalName = $p.New; OrigName = $p.Old; Dir = $p.Dir }
                        } catch {
                            Write-LeftConsole (T "[-] Lỗi đổi tên tạm: $($_.Exception.Message)" "[-] Temp rename error: $($_.Exception.Message)") $cRed
                        }
                    }
                    # Pass 2: Đổi từ tên tạm sang tên đích cuối cùng
                    foreach ($t in $tempEntries) {
                        $finalFull = Join-Path $t.Dir $t.FinalName
                        try {
                            if (Test-Path -LiteralPath $finalFull) {
                                Write-LeftConsole (T "[-] Trùng tên cuối cùng (bỏ qua): $($t.FinalName)" "[-] Final name collision (skipped): $($t.FinalName)") $cYellow
                                try {
                                    Rename-Item -LiteralPath $t.TempFull -NewName $t.OrigName -Force -EA Stop
                                    Write-LeftConsole (T " [i] Đã khôi phục tên gốc: $($t.OrigName)" " [i] Restored original name: $($t.OrigName)") $cYellow
                                } catch {
                                    Write-LeftConsole (T " [!!] CẢNH BÁO: Tệp vẫn ở tên tạm: $($t.TempName)" " [!!] WARNING: File remains with temp name: $($t.TempName)") $cRed
                                    Write-LeftConsole "      $($t.TempFull)" $cRed
                                }
                                continue
                            }
                            Rename-Item -LiteralPath $t.TempFull -NewName $t.FinalName -Force -EA Stop
                            Write-LeftConsole "[OK] $($t.OrigName) -> $($t.FinalName)" $cGreen
                            Add-Content -Path $undoLog -Value ($t.Dir + "|" + $t.FinalName + "|" + $t.OrigName)
                        } catch {
                            Write-LeftConsole (T "[-] Lỗi đổi tên cuối: $($_.Exception.Message)" "[-] Final rename error: $($_.Exception.Message)") $cRed
                            try {
                                Rename-Item -LiteralPath $t.TempFull -NewName $t.OrigName -Force -EA Stop
                                Write-LeftConsole (T " [i] Đã khôi phục tên gốc: $($t.OrigName)" " [i] Restored original name: $($t.OrigName)") $cYellow
                            } catch {
                                Write-LeftConsole (T " [!!] CẢNH BÁO: Tệp vẫn ở tên tạm: $($t.TempName)" " [!!] WARNING: File remains with temp name: $($t.TempName)") $cRed
                                Write-LeftConsole "      $($t.TempFull)" $cRed
                            }
                        }
                    }
                    Write-RightLog "DECLARED" (T "Đã đổi tên $count tệp từ danh sách $txtPath" "Renamed $count files from $txtPath") $cGreen
                } else {
                    Write-LeftConsole (T " [i] Đã hủy đổi tên." " [i] Rename cancelled.") $cYellow
                }
            } else {
                Write-LeftConsole (T " [-] Tệp danh sách không tồn tại!" " [-] .txt file not found!") $cRed
            }
        } elseif ($m -eq "8") {
            Write-LeftConsole (T " [1] Đổi tên từng tệp" " [1] Step-by-Step Files") $cWhite
            Write-LeftConsole (T " [2] Đổi tên từng thư mục" " [2] Step-by-Step Folders") $cWhite
            $subM = Wait-SingleKey (T "Chọn đối tượng [1-2]" "Select target [1-2]") @('1', '2')
            if ($subM -in @('1', '2')) {
                $isDir = ($subM -eq '2')
                $items = if ($isDir) { @(Get-ChildItem -LiteralPath $targetDir -Directory) } else { @(Get-ChildItem -LiteralPath $targetDir -File) }
                $idx = 0
                while ($idx -ge 0 -and $idx -lt $items.Count) {
                    $cur = $items[$idx]
                    Write-LeftConsole "[$($idx+1)/$($items.Count)] $($cur.Name)" $cLightCyan
                    $inp = Get-LeftInput (T "Tên mới (gõ 's' bỏ qua, 'exit' dừng lại)" "New name (type 's' skip, 'exit' stop)")
                    if ($inp -match '^(exit|quit)$') { break }
                    if ($inp -eq 's' -or [string]::IsNullOrWhiteSpace($inp)) { $idx++; continue }
                    $nn = $inp
                    if (-not $isDir -and -not $nn.EndsWith($cur.Extension)) { $nn += $cur.Extension }
                    $targetPath = if ($isDir) { Join-Path $cur.Parent.FullName $nn } else { Join-Path $cur.DirectoryName $nn }
                    if ((Test-Path -LiteralPath $targetPath) -and $cur.Name -ne $nn) {
                        Write-LeftConsole (T "[-] Tên đã tồn tại, vui lòng chọn tên khác!" "[-] Name already exists, please choose another!") $cYellow
                        continue
                    }
                    try {
                        Rename-Item -LiteralPath $cur.FullName -NewName $nn -Force -EA Stop
                        Write-LeftConsole "[OK] $($cur.Name) -> $nn" $cGreen
                        Add-Content -Path $undoLog -Value ($(if ($isDir) { $cur.Parent.FullName } else { $cur.DirectoryName }) + "|" + $nn + "|" + $cur.Name)
                    } catch {
                        Write-LeftConsole (T "[-] Lỗi đổi tên: $($_.Exception.Message)" "[-] Rename error: $($_.Exception.Message)") $cRed
                    } finally {
                        $idx++
                    }
                }
                Write-RightLog "DECLARED" (T "Đã hoàn thành đổi tên từng mục trong $targetDir" "Completed Step-by-Step Rename in $targetDir") $cGreen
            }
        }
        Write-LeftConsole ""
        Write-LeftConsole (T " [OK] Thao tác đổi tên hoàn tất!" " [OK] Rename operation completed!") $cCyan
        Set-Activity "OK" (T "Hoàn thành: Đổi tên hàng loạt" "Done: Quick Rename") $cGreen
        Wait-LeftReturn
    }
}

# --- [5.5] Remove Windows.old ---
function Invoke-RemoveWindowsOld() {
    Write-DebugLog "&&" "[5.5] Invoking Remove Windows.old..."
    if (-not (Require-ExpertOrBlock "XÓA THƯ MỤC WINDOWS.OLD" "REMOVE WINDOWS.OLD FOLDER")) { return }
    if (-not (Require-AdminOrPrompt "XÓA THƯ MỤC WINDOWS.OLD" "REMOVE WINDOWS.OLD FOLDER")) { return }
    Start-ActionView "XÓA THƯ MỤC WINDOWS.OLD" $cPurp "REMOVE WINDOWS.OLD FOLDER"
    $wOld = "$sysDrive\Windows.old"
    if (Test-Path $wOld) {
        $conf = Get-LeftInput (T "Gõ 'YES' để xác nhận xóa" "Type 'YES' to confirm")
        if ($conf -ne "YES") { return }
        Write-LeftConsoleProgress (T "Đang tiếp quản quyền thư mục Windows.old..." "Taking ownership of Windows.old...") $cYellow
        Run-And-LogCommand "takeown" "/F `"$wOld`" /R /D Y" | Out-Null
        Update-LeftConsoleLine (T " [OK] Đã tiếp quản quyền sở hữu." " [OK] Ownership acquired.") $cGreen

        Write-LeftConsoleProgress (T "Đang cấp toàn quyền thư mục..." "Granting permissions...") $cYellow
        Run-And-LogCommand "icacls" "`"$wOld`" /grant *S-1-5-32-544:F /T" | Out-Null
        Update-LeftConsoleLine (T " [OK] Đã cấp quyền hoàn tất." " [OK] Permissions granted.") $cGreen

        $msgDelOld = T "Đang xóa thư mục Windows.old..." "Deleting Windows.old folder..."
        Invoke-ScriptWithSpinner { Remove-Item -LiteralPath $wOld -Recurse -Force -EA SilentlyContinue } $msgDelOld $cYellow
        Update-LeftConsoleLine (T " [OK] Đã xóa thư mục Windows.old." " [OK] Windows.old removed.") $cGreen
        Set-Activity "OK" (T "Hoàn thành: Xóa Windows.old" "Done: Removed Windows.old") $cGreen
    } else {
        Write-LeftConsole (T "[!] Không tìm thấy thư mục Windows.old." "[!] Windows.old not found.") $cYellow
        Set-Activity "!" (T "Không tìm thấy Windows.old" "Windows.old not found") $cYellow
    }
    Wait-LeftReturn
}

# --- [5.6] Winget Power Tools ---
function Invoke-WingetDashboard() {
    Write-DebugLog "&&" "[5.6] Invoking Winget Dashboard..."
    $global:actionBreadcrumbs.Clear()
    $global:actionBreadcrumbs.Add(@{ Key = "WINGET"; Vi = "Công cụ Winget"; En = "Winget Power Tools" })
    Start-ActionView "CÔNG CỤ WINGET" $cCyan "WINGET POWER TOOLS"

    $script:wingetAppList = @()
    $script:maxWingetOffset = 0
    $script:isDraggingWingetScroll = $false

    function Local:Query-WingetUpdates() {
        for ($r = 5; $r -le 21; $r++) {
            Set-CursorPos 2 $r
            Write-Host (" " * 40) -NoNewline
        }
        $leftConsoleLines.Clear()
        $global:currentProgressMsg = $null
        Write-RightLog "IN" (T "Đang kiểm tra các bản cập nhật ứng dụng qua Winget..." "Checking for application updates via Winget...") $cYellow
        $script:wingetAppList = @()

        $rawLines = Invoke-ActionWithSpinner {
            [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
            winget upgrade --include-unknown --accept-source-agreements
        } (T "Đang quét ứng dụng qua Winget..." "Scanning apps via Winget...") $cYellow 6

        if ($rawLines -eq $null) {
            Write-RightLog "WARN" (T "Quá trình quét Winget đã bị hủy." "Winget scan was cancelled.") $cYellow
            return
        }

        $outLines = @($rawLines)

        # Parse header
        $headerIdx = -1
        for ($i = 0; $i -lt $outLines.Count; $i++) {
            $line = [string]$outLines[$i]
            if ($line.Contains("Name") -and $line.Contains("Id") -and $line.Contains("Version")) {
                $headerIdx = $i
                break
            }
        }

        $isNoUpdate = $false
        if ($headerIdx -ge 0 -and ($headerIdx + 2) -lt $outLines.Count) {
            $header = [string]$outLines[$headerIdx]
            $idIdx = $header.IndexOf("Id")
            $verIdx = $header.IndexOf("Version")
            $availIdx = $header.IndexOf("Available")
            $srcIdx = $header.IndexOf("Source")

            for ($i = $headerIdx + 2; $i -lt $outLines.Count; $i++) {
                $line = [string]$outLines[$i]
                if (-not $line -or $line.Trim().Length -eq 0) { continue }
                if ($line.StartsWith("-")) { continue }

                # Filter summary / footnote lines
                if ($line -match '(?i)^\s*(\d+\s+(upgrades?\s+available|package\(s\))|use\s+--|no\s+(applicable|installed))') {
                    continue
                }
                if ($line.Length -lt $verIdx) { continue }

                $name = $line.Substring(0, [math]::Min($line.Length, $idIdx)).Trim()
                $rem = if ($line.Length -gt $idIdx) { $line.Substring($idIdx) } else { "" }
                $id = if ($line.Length -gt $verIdx) { $line.Substring($idIdx, $verIdx - $idIdx).Trim() } else { $rem.Trim() }
                
                $ver = ""
                $avail = ""
                if ($line.Length -gt $availIdx) {
                    $ver = $line.Substring($verIdx, $availIdx - $verIdx).Trim()
                    if ($srcIdx -gt 0 -and $line.Length -gt $srcIdx) {
                        $avail = $line.Substring($availIdx, $srcIdx - $availIdx).Trim()
                    } else {
                        $avail = $line.Substring($availIdx).Trim()
                    }
                } elseif ($line.Length -gt $verIdx) {
                    $ver = $line.Substring($verIdx).Trim()
                }

                # Clean trailing source text if attached to version
                if ($avail) { $avail = ($avail -split '\s+')[0] }
                if ($ver) { $ver = ($ver -split '\s+')[0] }

                # Strict validation of application entry
                if (-not $id -or $id.Contains(" ") -or $id -eq "Id") { continue }
                if (-not $name) { continue }
                if (-not $avail) { continue }

                $updStr = if ($avail) { "$ver -> $avail" } else { $ver }
                $script:wingetAppList += @{
                    Name = $name
                    Id = $id
                    Version = $ver
                    Available = $avail
                    Update = $updStr
                }
            }
        } else {
            foreach ($line in $outLines) {
                if ($line -match '(?i)(no\s+(applicable|installed)|không\s+tìm\s+thấy|tất\s+cả\s+đã\s+ở|up\s+to\s+date)') {
                    $isNoUpdate = $true
                    break
                }
            }
            if (-not $isNoUpdate -and $outLines.Count -gt 0) {
                Write-RightLog "WARN" (T "Không tìm thấy bảng dữ liệu Winget hoặc định dạng không khớp." "Winget table header not found or unrecognized format.") $cYellow
            }
        }

        # Dynamic column sizing based on longest items
        $maxNameLen = 4  # "Name".Length
        $maxIdLen   = 2  # "Id".Length
        $maxUpdLen  = 6  # "Update".Length

        foreach ($app in $script:wingetAppList) {
            if ($app.Name.Length -gt $maxNameLen) { $maxNameLen = $app.Name.Length }
            if ($app.Id.Length -gt $maxIdLen)     { $maxIdLen = $app.Id.Length }
            if ($app.Update.Length -gt $maxUpdLen) { $maxUpdLen = $app.Update.Length }
        }

        $script:colNameW = $maxNameLen + 2
        $script:colIdW   = $maxIdLen + 2
        $script:hdrRaw = ("Name").PadRight($script:colNameW) + ("Id").PadRight($script:colIdW) + "Update"

        for ($idx = 0; $idx -lt $script:wingetAppList.Count; $idx++) {
            $app = $script:wingetAppList[$idx]
            $app.FullRow = $app.Name.PadRight($script:colNameW) + $app.Id.PadRight($script:colIdW) + $app.Update
            $app.IdStart = $script:colNameW
            $app.IdLen   = $app.Id.Length
        }

        $script:maxRowLen = 38
        if ($script:hdrRaw.Length -gt $script:maxRowLen) { $script:maxRowLen = $script:hdrRaw.Length }
        foreach ($app in $script:wingetAppList) {
            if ($app.FullRow.Length -gt $script:maxRowLen) {
                $script:maxRowLen = $app.FullRow.Length
            }
        }
        $script:maxWingetOffset = [math]::Max(0, $script:maxRowLen - 38)
        Set-Activity "OK" (T "Tìm thấy $($script:wingetAppList.Count) ứng dụng" "Found $($script:wingetAppList.Count) upgrade(s)") $cGreen
        if ($script:wingetAppList.Count -eq 0) {
            if ($headerIdx -ge 0 -or $isNoUpdate) {
                Write-RightLog "OUT" (T "Tất cả ứng dụng đã ở phiên bản mới nhất." "All applications are up to date.") $cGreen
            }
        } else {
            Write-RightLog "OUT" (T "Tìm thấy $($script:wingetAppList.Count) bản cập nhật ứng dụng khả dụng." "Found $($script:wingetAppList.Count) available application update(s).") $cGreen
            Write-RightLog "INFO" (T "[i] Bạn có thể click chuột vào ID ứng dụng để sao chép vào Clipboard." "[i] Click an App ID to copy ID to Clipboard.") $cLightCyan
        }
    }

    Query-WingetUpdates

    $horizOffset = 0
    $vertOffset = 0
    $flashIdx = -1
    $flashTick = 0
    $inlineInputOpen = $false
    $inputBuffer = ""
    $cursorPos = 0
    $cursorVisible = $true
    $lastBlinkTick = [Environment]::TickCount
    $hoverControl = "NONE" # PAN_LEFT, PAN_RIGHT, PAN_THUMB, PAN_TRACK, ACT_1, ACT_2, ACT_3, ACT_4, APP_ID, BACK_BTN, V_SCROLL
    $hoverRowIdx = -1
    $isLeftMouseDown = $false
    $lastHoldTick = 0
    $script:isDraggingWingetVScroll = $false

    # --- [5.9.1] Winget: Update All ---
    function Local:Invoke-UpgradeAllApps() {
        Write-DebugLog "&&" "[5.9.1] Invoking Winget Upgrade All Applications..."
        if ($script:wingetAppList.Count -eq 0) {
            Write-RightLog "WINGET" (T "Không có ứng dụng nào cần cập nhật." "No applications need updating.") $cLightGreen
        } else {
            Write-RightLog "WINGET" (T "Bắt đầu cập nhật toàn bộ $($script:wingetAppList.Count) ứng dụng..." "Updating all $($script:wingetAppList.Count) app(s)...") $cYellow
            $upCancelled = $false
            foreach ($app in $script:wingetAppList) {
                Write-LeftConsoleProgress (T "Đang cập nhật $($app.Id)..." "Updating $($app.Id)...") $cYellow
                $upRes = Run-And-LogCommand "winget" "upgrade --id=`"$($app.Id)`" --exact --accept-source-agreements --accept-package-agreements --disable-interactivity"
                if ($upRes -eq -1 -or $script:stopRequested -or $script:lastTaskCancelled) {
                    $upCancelled = $true
                    Write-RightLog "WARN" (T "Đã dừng cập nhật tại: $($app.Id)" "Upgrade stopped at: $($app.Id)") $cYellow
                    break
                }
                Write-RightLog "WINGET" (T "Hoàn tất: $($app.Id)" "Updated: $($app.Id)") $cGreen
            }
            if ($upCancelled) {
                Set-Activity "!" (T "Đã dừng cập nhật ứng dụng" "Stopped: Winget Upgrade") $cYellow
            } else {
                Set-Activity "OK" (T "Cập nhật hoàn tất" "All updates finished") $cGreen
            }
            Query-WingetUpdates
            Render-Dashboard
        }
    }

    function Local:Format-WingetRowSlice($fullRow, $idStart, $idLen, $offset, $isHoverId, $isFlashId, $viewW = 38) {
        $len = $fullRow.Length
        $maxOffset = [math]::Max(0, $len - $viewW)
        $off = [math]::Max(0, [math]::Min($maxOffset, $offset))
        $idEnd = $idStart + $idLen

        $rawChars = [System.Collections.Generic.List[char]]::new()
        $inIdList = [System.Collections.Generic.List[bool]]::new()

        for ($i = 0; $i -lt $viewW; $i++) {
            $strIdx = -1
            $ch = [char]' '
            if ($len -le $viewW) {
                if ($i -lt $len) { $ch = $fullRow[$i]; $strIdx = $i }
            } elseif ($off -eq 0) {
                if ($i -lt ($viewW - 2)) { $ch = $fullRow[$i]; $strIdx = $i }
                else { $ch = [char]'.' }
            } elseif ($off -ge $maxOffset) {
                if ($i -lt 2) { $ch = [char]'.' }
                else { $strIdx = ($len - ($viewW - 2)) + ($i - 2); $ch = $fullRow[$strIdx] }
            } else {
                if ($i -lt 2 -or $i -ge ($viewW - 2)) { $ch = [char]'.' }
                else { $strIdx = ($off + 2) + ($i - 2); $ch = $fullRow[$strIdx] }
            }
            $rawChars.Add($ch)
            $isId = ($strIdx -ge $idStart -and $strIdx -lt $idEnd)
            $inIdList.Add($isId)
        }

        $sb = New-Object System.Text.StringBuilder
        $curState = -1
        for ($i = 0; $i -lt $viewW; $i++) {
            $isId = $inIdList[$i]
            $state = if ($isId -and ($isHoverId -or $isFlashId)) { 1 } else { 0 }
            if ($state -ne $curState) {
                $curState = $state
                if ($curState -eq 1) {
                    if ($isFlashId) {
                        $sb.Append("$ESC[48;2;30;85;45m$ESC[38;2;140;255;160m") | Out-Null
                    } else {
                        $sb.Append("$ESC[48;2;45;50;62m$ESC[38;2;120;255;160m") | Out-Null
                    }
                } else {
                    $sb.Append("$cReset$cWhite") | Out-Null
                }
            }
            $sb.Append($rawChars[$i]) | Out-Null
        }
        $sb.Append($cReset) | Out-Null
        return $sb.ToString()
    }

    function Local:Render-Dashboard($animate = $false) {
        # Render Back button at Y=3
        if (Test-IsAnyTaskRunning) {
            Hide-LeftBackButton
        } else {
            Show-LeftBackButton $(if ($hoverControl -eq "BACK_BTN") { "HOVER" } else { "NORMAL" })
        }

        # Line 0: Sliced Table Header
        $hdrSlice = Get-HorizSlice $script:hdrRaw $horizOffset 38
        $lineHdr = "$cLightCyan$hdrSlice$cReset"

        # Line 1: Separator
        $lineSep = "$cDim" + ("-" * 38) + "$cReset"

        # App Rows: Flexible height 1..5 rows
        $visibleRowCount = [math]::Min(5, [math]::Max(1, $script:wingetAppList.Count))
        $maxVScroll = [math]::Max(0, $script:wingetAppList.Count - 5)
        if ($vertOffset -gt $maxVScroll) { $vertOffset = $maxVScroll; Set-Variable -Name vertOffset -Value $maxVScroll -Scope 1 }
        if ($vertOffset -lt 0) { $vertOffset = 0; Set-Variable -Name vertOffset -Value 0 -Scope 1 }

        $renderedRows = @()
        if ($script:wingetAppList.Count -eq 0) {
            $msg = (T " [OK] Tất cả ứng dụng đã mới nhất!" " [OK] All applications up-to-date!")
            $renderedRows += "$cLightGreen" + $msg.PadRight(38) + "$cReset"
        } else {
            for ($v = 0; $v -lt $visibleRowCount; $v++) {
                $r = $v + $vertOffset
                if ($r -lt $script:wingetAppList.Count) {
                    $app = $script:wingetAppList[$r]
                    $isHov = ($hoverControl -eq "APP_ID" -and $hoverRowIdx -eq $r)
                    $isFl  = ($flashIdx -eq $r)
                    $rowStr = Format-WingetRowSlice $app.FullRow $app.IdStart $app.IdLen $horizOffset $isHov $isFl 38
                    $renderedRows += $rowStr
                } else {
                    $renderedRows += (" " * 38)
                }
            }
        }

        # Horizontal Scrollbar & Inline Refresh Button [↺]
        $trackW = 33
        $thumbW = 2
        $travel = $trackW - $thumbW # 31
        $thumbPos = if ($script:maxWingetOffset -gt 0) { [math]::Round(($horizOffset / $script:maxWingetOffset) * $travel) } else { 0 }
        $thumbPos = [math]::Max(0, [math]::Min($travel, $thumbPos))

        $isHoverThumb = ($hoverControl -eq "PAN_THUMB" -or $script:isDraggingWingetScroll)
        $trackCol = $cDim
        $thumbCol = if ($isHoverThumb) { "$ESC[38;2;255;255;255m" } else { $cLightGreen }

        $leftTrack = $trackCol + ($chrLine * $thumbPos) + $cReset
        $thumbBlock = $thumbCol + ($chrHThumb * 2) + $cReset
        $rightTrack = $trackCol + ($chrLine * ($travel - $thumbPos)) + $cReset
        $scrollPart = "$leftTrack$thumbBlock$rightTrack"

        $isHoverRef = ($hoverControl -eq "REFRESH_BTN")
        $refStyle = if ($isHoverRef) { "$ESC[48;2;45;50;62m$cWhite" } else { "$cCyan" }
        $refBtn = "  $refStyle[↺]$cReset"
        $lineHScroll = "$scrollPart$refBtn"

        # Section Title
        $secTitle = (T "--- THAO TÁC CẬP NHẬT ---" "--- UPDATE ACTIONS ---")
        $lineSec = "$cYellow" + $secTitle.PadRight(38) + "$cReset"

        # 3 Action Lines with Bright-to-Dim Gradient
        $col1 = "$ESC[38;2;120;240;130m" # Bright green
        $col2 = "$ESC[38;2;80;190;110m"  # Medium green
        $col3 = "$ESC[38;2;55;140;85m"   # Dimmer / muted green

        $act1Txt = (T "[1] Cập nhật tất cả ứng dụng" "[1] Update ALL Applications")
        $act1Style = if ($hoverControl -eq "ACT_1") { "$ESC[48;2;45;50;62m$cWhite" } else { $col1 }
        $lineAct1 = "$act1Style" + $act1Txt.PadRight(38) + "$cReset"

        $act2Txt = (T "[2] Cập nhật ứng dụng theo ID" "[2] Update Application by ID")
        $act2Style = if ($hoverControl -eq "ACT_2") { "$ESC[48;2;45;50;62m$cWhite" } else { $col2 }
        $lineAct2 = "$act2Style" + $act2Txt.PadRight(38) + "$cReset"

        $act3Txt = (T "[3] Cài đặt phần mềm khác" "[3] Install Other Packages")
        $act3Style = if ($hoverControl -eq "ACT_3") { "$ESC[48;2;45;50;62m$cWhite" } else { $col3 }
        $lineAct3 = "$act3Style" + $act3Txt.PadRight(38) + "$cReset"

        # Input Line & Hint
        $lineIn = " " * 38
        $lineInHint = " " * 38
        if ($inlineInputOpen) {
            $bufLen = $inputBuffer.Length
            $curPos = [math]::Max(0, [math]::Min($bufLen, $cursorPos))
            $maxVis = 33
            $cInv = "$ESC[7m"
            $cNoInv = "$ESC[27m"
            $viewStart = 0; $prefix = ""; $suffix = ""; $visLen = $bufLen
            if ($bufLen -gt $maxVis) {
                $visLen = $maxVis - 2
                $viewStart = [math]::Max(0, $curPos - $visLen + 1)
                if (($viewStart + $visLen) -gt $bufLen) { $viewStart = $bufLen - $visLen }
                $viewStart = [math]::Max(0, $viewStart)
                if ($viewStart -gt 0) { $prefix = ".." }
                $avail = $maxVis - $prefix.Length
                if (($viewStart + $avail) -lt $bufLen) { $suffix = ".." }
                $visLen = $maxVis - $prefix.Length - $suffix.Length
            }
            $sub = if ($bufLen -gt 0) { $inputBuffer.Substring($viewStart, [math]::Min($visLen, $bufLen - $viewStart)) } else { "" }
            $relCur = $curPos - $viewStart
            $body = ""
            for ($k = 0; $k -lt $sub.Length; $k++) {
                $ch = $sub[$k]
                if ($k -eq $relCur) {
                    if ($cursorVisible) { $body += "$cInv$ch$cNoInv" } else { $body += $ch }
                } else { $body += $ch }
            }
            $endCur = ""
            $curLen = 0
            if ($relCur -eq $sub.Length) {
                $cCh = if ($cursorVisible) { "_" } else { " " }
                $endCur = "${cWhite}${cCh}${cReset}"
                $curLen = 1
            }
            $rendered = "${cWhite}> ${cReset}${prefix}${body}${endCur}${suffix}"
            $pLen = 2 + $prefix.Length + $sub.Length + $curLen + $suffix.Length
            $pad = " " * [math]::Max(0, 38 - $pLen)
            $lineIn = "$rendered$pad"

            $inHint = (T "[Enter] Cập nhật  [ESC] Hủy" "[Enter] Update  [ESC] Cancel")
            $lineInHint = "$cDim" + $inHint.PadRight(38) + "$cReset"
        }

        # Build output lines array
        $allLines = [System.Collections.Generic.List[string]]::new()
        $allLines.Add($lineHdr)
        $allLines.Add($lineSep)
        foreach ($rLine in $renderedRows) {
            $allLines.Add($rLine)
        }
        $allLines.Add($lineHScroll)
        $allLines.Add($lineSec)
        $allLines.Add($lineAct1)
        $allLines.Add($lineAct2)
        $allLines.Add($lineAct3)
        if ($inlineInputOpen) {
            $allLines.Add($lineIn)
            $allLines.Add($lineInHint)
        }

        # Render rows and clear past lines up to row Y=22
        $maxPaneLines = 18 # Y=5 to Y=22
        for ($idx = 0; $idx -lt $maxPaneLines; $idx++) {
            Set-CursorPos 2 (5 + $idx)
            if ($idx -lt $allLines.Count) {
            $line = $allLines[$idx]
            $plain = $script:AnsiRegex.Replace($line, '')
            $padN  = [math]::Max(0, 38 - $plain.Length)
            Write-Host ($line + (' ' * $padN)) -NoNewline
            } else {
                Write-Host (" " * 40) -NoNewline
            }
            if ($animate) {
                Start-Sleep -Milliseconds 18
            }
        }

        # Vertical Scrollbar on column 40 for table rows Y=7..11
        if ($script:wingetAppList.Count -gt 5) {
            $vTravel = 4
            $vThumbPos = [math]::Round(($vertOffset / $maxVScroll) * $vTravel)
            $isVHover = ($hoverControl -eq "V_SCROLL" -or $script:isDraggingWingetVScroll)
            $vTrackCol = if ($isVHover) { "$ESC[38;2;120;255;160m" } else { $cDim }
            $vThumbCol = if ($isVHover) { "$ESC[38;2;255;255;255m" } else { $cLightGreen }

            for ($vi = 0; $vi -lt 5; $vi++) {
                Set-CursorPos 40 (7 + $vi)
                if ($vi -eq $vThumbPos) {
                    Write-Host "$vThumbCol$chrThumb$cReset" -NoNewline
                } else {
                    Write-Host "$vTrackCol$chrVert$cReset" -NoNewline
                }
            }
        } else {
            for ($vi = 0; $vi -lt 5; $vi++) {
                Set-CursorPos 40 (7 + $vi)
                Write-Host "  " -NoNewline
            }
        }
    }

    Render-Dashboard $true

    # Event Loop
    $hInput = if (([System.Management.Automation.PSTypeName]'ConsoleMouse').Type) { [ConsoleMouse]::GetStdHandle([ConsoleMouse]::STD_INPUT_HANDLE) } else { $null }
    if ($hInput) { try { [ConsoleMouse]::FlushConsoleInputBuffer($hInput) | Out-Null } catch {} }
    $records = if ($hInput) { New-Object ConsoleMouse+INPUT_RECORD[] 64 } else { $null }

    $running = $true
    $wasLeft = $false
    try {
    while ($running) {
        Start-Sleep -Milliseconds 25
        $now = [Environment]::TickCount

        # Flash reset
        if ($flashIdx -ge 0 -and ($now - $flashTick) -gt 350) {
            $flashIdx = -1
            Render-Dashboard
        }

        # Cursor blink
        if ($inlineInputOpen -and ($now - $lastBlinkTick) -gt 450) {
            $cursorVisible = -not $cursorVisible
            $lastBlinkTick = $now
            Render-Dashboard
        }

        # Hold drag refresh
        if ($isLeftMouseDown -and $script:isDraggingWingetScroll -and ($now - $lastHoldTick) -gt 55) {
            $lastHoldTick = $now
        }

        # Read Console Events
        if ($hInput) {
            [uint32]$eventsCount = 0
            [ConsoleMouse]::GetNumberOfConsoleInputEvents($hInput, [ref]$eventsCount) | Out-Null
            if ($eventsCount -le 0) { continue }

            [uint32]$toRead = [math]::Min([uint32]$records.Length, $eventsCount)
            [uint32]$read = 0
            [ConsoleMouse]::ReadConsoleInput($hInput, $records, $toRead, [ref]$read) | Out-Null

            for ($i = 0; $i -lt $read; $i++) {
                $rec = $records[$i]

                # Window Resize
                if ($rec.EventType -eq 4) {
                    $script:termSizeDirty = $true
                    Get-TermSize -force
                    Draw-FullLayout $false
                    Render-Dashboard
                    continue
                }

                # Mouse Events
                if ($rec.EventType -eq 2) {
                    $mEvent = $rec.MouseEvent
                    $posX = $mEvent.dwMousePosition.X
                    $posY = $mEvent.dwMousePosition.Y

                    $visibleRowCount = [math]::Min(5, [math]::Max(1, $script:wingetAppList.Count))
                    $hScrollY = 7 + $visibleRowCount
                    $actY1 = $hScrollY + 2
                    $actY2 = $hScrollY + 3
                    $actY3 = $hScrollY + 4
                    $maxVScroll = [math]::Max(0, $script:wingetAppList.Count - 5)

                    # Mouse Wheel over left pane (vertical, or horizontal if over scrollbar)
                    if ($mEvent.dwEventFlags -eq 4 -and $posX -le 41) {
                        $delta = [int]$mEvent.dwButtonState
                        $isOverHScroll = ($posY -eq $hScrollY)
                        if (Handle-ListMouseWheel $delta $isOverHScroll ([ref]$vertOffset) ([ref]$horizOffset) $maxVScroll $script:maxWingetOffset 1 3) {
                            Render-Dashboard
                        }
                        continue
                    }

                    if (Process-LogScrollEvents $mEvent) { continue }
                    $btnState = $mEvent.dwButtonState
                    $isLeft = ($btnState -band 1) -ne 0
                    $isRight = ($btnState -band 2) -ne 0
                    $isLeftClick = ($isLeft -and -not $wasLeft)
                    $wasLeft = $isLeft

                    if ($isLeft) {
                        $isLeftMouseDown = $true
                    } else {
                        $isLeftMouseDown = $false
                        $script:isDraggingWingetScroll = $false
                        $script:isDraggingWingetVScroll = $false
                    }

                    # Determine Hover & Click Targets
                    $newControl = "NONE"
                    $newRowIdx = -1

                    # 1. Vertical scrollbar (when count > 5)
                    if ($script:wingetAppList.Count -gt 5 -and ($posX -ge 39 -and $posX -le 41) -and ($posY -ge 7 -and $posY -le 11)) {
                        $newControl = "V_SCROLL"
                    }
                    # 2. Table rows & ID hit detection
                    elseif ($posX -ge 2 -and $posX -le 39 -and $posY -ge 7 -and $posY -lt $hScrollY) {
                        $vIdx = $posY - 7
                        $rIdx = $vIdx + $vertOffset
                        if ($rIdx -lt $script:wingetAppList.Count) {
                            $app = $script:wingetAppList[$rIdx]
                            $colIdx = $posX - 2

                            $len = $app.FullRow.Length
                            $maxOffset = [math]::Max(0, $len - 38)
                            $off = [math]::Max(0, [math]::Min($maxOffset, $horizOffset))
                            $strIdx = -1
                            if ($len -le 38) {
                                if ($colIdx -lt $len) { $strIdx = $colIdx }
                            } elseif ($off -eq 0) {
                                if ($colIdx -lt 36) { $strIdx = $colIdx }
                            } elseif ($off -ge $maxOffset) {
                                if ($colIdx -ge 2) { $strIdx = ($len - 36) + ($colIdx - 2) }
                            } else {
                                if ($colIdx -ge 2 -and $colIdx -lt 36) { $strIdx = ($off + 2) + ($colIdx - 2) }
                            }

                            if ($strIdx -ge $app.IdStart -and $strIdx -lt ($app.IdStart + $app.IdLen)) {
                                $newControl = "APP_ID"
                                $newRowIdx = $rIdx
                            }
                        }
                    }
                    # 3. Horizontal Scrollbar & Refresh Button
                    elseif ($posY -eq $hScrollY -and $posX -ge 2 -and $posX -le 39) {
                        if ($posX -ge 35 -and $posX -le 39) {
                            $newControl = "REFRESH_BTN"
                        } else {
                            $travel = 31
                            $tPos = if ($script:maxWingetOffset -gt 0) { [math]::Round(($horizOffset / $script:maxWingetOffset) * $travel) } else { 0 }
                            if ($posX -ge (2 + $tPos) -and $posX -le (3 + $tPos)) {
                                $newControl = "PAN_THUMB"
                            }
                        }
                    }
                    # 4. Actions [1]..[3]
                    elseif ($posX -ge 2 -and $posX -le 39) {
                        if ($posY -eq $actY1) { $newControl = "ACT_1" }
                        elseif ($posY -eq $actY2) { $newControl = "ACT_2" }
                        elseif ($posY -eq $actY3) { $newControl = "ACT_3" }
                    }

                    # Top Bar / Back button hover
                    $gTarget = Get-HoverTarget $posX $posY
                    if ($gTarget -ne $script:currentHoverTarget) {
                        $oldTarget = $script:currentHoverTarget
                        $script:currentHoverTarget = $gTarget
                        if ($gTarget.StartsWith("STATUS_") -or $oldTarget.StartsWith("STATUS_") -or $gTarget.StartsWith("BREADCRUMB_") -or $oldTarget.StartsWith("BREADCRUMB_")) {
                            Draw-StatusPane
                        }
                        if ($gTarget.StartsWith("TOP_") -or $oldTarget.StartsWith("TOP_") -or $gTarget.StartsWith("LANG_") -or $oldTarget.StartsWith("LANG_") -or $gTarget.StartsWith("LOG_") -or $oldTarget.StartsWith("LOG_")) {
                            Draw-TopMenuBar
                        }
                    }
                    if ($gTarget -eq "BACK_BTN") {
                        $newControl = "BACK_BTN"
                    } elseif ($gTarget.StartsWith("BREADCRUMB_")) {
                        $newControl = $gTarget
                    }

                    # Dragging Horizontal Scrollbar
                    if ($isLeft) {
                        if ($script:isDraggingWingetScroll -or ($posY -eq $hScrollY -and $posX -ge 2 -and $posX -le 34)) {
                            $script:isDraggingWingetScroll = $true
                            $ratio = ($posX - 2) / 31.0
                            $ratio = [math]::Max(0.0, [math]::Min(1.0, $ratio))
                            $newOff = [math]::Round($ratio * $script:maxWingetOffset)
                            if ($newOff -ne $horizOffset) {
                                $horizOffset = $newOff
                                Render-Dashboard
                            }
                        }
                        # Dragging Vertical Scrollbar
                        elseif ($script:wingetAppList.Count -gt 5 -and ($script:isDraggingWingetVScroll -or (($posX -ge 39 -and $posX -le 41) -and ($posY -ge 7 -and $posY -le 11)))) {
                            $script:isDraggingWingetVScroll = $true
                            $ratio = ($posY - 7) / 4.0
                            $ratio = [math]::Max(0.0, [math]::Min(1.0, $ratio))
                            $newVOff = [math]::Round($ratio * $maxVScroll)
                            if ($newVOff -ne $vertOffset) {
                                $vertOffset = $newVOff
                                Render-Dashboard
                            }
                        }
                    }

                    if ($newControl -ne $hoverControl -or $newRowIdx -ne $hoverRowIdx) {
                        $isBackOnly = (($newControl -eq "BACK_BTN" -or $hoverControl -eq "BACK_BTN") -and $newRowIdx -eq $hoverRowIdx)
                        $hoverControl = $newControl
                        $hoverRowIdx = $newRowIdx
                        if ($isBackOnly) {
                            Show-LeftBackButton $(if ($hoverControl -eq "BACK_BTN") { "HOVER" } else { "NORMAL" })
                        } else {
                            Render-Dashboard
                        }
                    }

                    # Click Handling (on Left Down leading edge)
                    if ($isLeftClick) {
                        if ($newControl -eq "APP_ID" -and $newRowIdx -ge 0) {
                            $app = $script:wingetAppList[$newRowIdx]
                            try {
                                Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
                                [System.Windows.Forms.Clipboard]::SetText($app.Id)
                            } catch {}
                            $flashIdx = $newRowIdx
                            $flashTick = [Environment]::TickCount
                            Write-RightLog "CLIPBOARD" (T "Đã sao chép ID: $($app.Id)" "Copied ID: $($app.Id)") $cGreen
                            if ($inlineInputOpen) {
                                $inputBuffer = $app.Id
                                $cursorPos = $inputBuffer.Length
                                $cursorVisible = $true
                                $lastBlinkTick = [Environment]::TickCount
                            }
                            Render-Dashboard

                        } elseif ($newControl -eq "ACT_1") {
                            Invoke-UpgradeAllApps
                        } elseif ($newControl -eq "ACT_2") {
                            Write-RightLog "WINGET" (T "Nhập ID ứng dụng cần cập nhật (cách nhau bởi dấu cách nếu nhiều ID)..." "Enter App ID(s) to update (separated by space)...") $cWhite
                            $inlineInputOpen = $true
                            $inputBuffer = ""
                            $cursorPos = 0
                            $cursorVisible = $true
                            $lastBlinkTick = [Environment]::TickCount
                            Render-Dashboard
                        } elseif ($newControl -eq "REFRESH_BTN") {
                            Write-RightLog "IN" (T "Đang làm mới danh sách cập nhật Winget..." "Refreshing Winget update list...") $cYellow
                            Query-WingetUpdates
                            $horizOffset = 0
                            $vertOffset = 0
                            Render-Dashboard
                        } elseif ($newControl -eq "ACT_3") {
                            Invoke-WingetInstallPackages
                            Lock-Input 300
                            if ($hInput) { try { [ConsoleMouse]::FlushConsoleInputBuffer($hInput) | Out-Null } catch {} }
                            $wasLeft = $true
                            $hoverControl = "NONE"
                            if ($global:navTarget -and $global:navTarget -ne "WINGET") {
                                $running = $false
                                break
                            }
                            $global:navTarget = $null
                            if ($global:actionBreadcrumbs.Count -gt 1) {
                                $global:actionBreadcrumbs.RemoveAt($global:actionBreadcrumbs.Count - 1)
                            }
                            Start-ActionView "CÔNG CỤ WINGET" $cCyan "WINGET POWER TOOLS"
                            Set-Activity "OK" (T "Tìm thấy $($script:wingetAppList.Count) ứng dụng" "Found $($script:wingetAppList.Count) upgrade(s)") $cGreen
                            Draw-StatusPane
                            Render-Dashboard
                            Write-RightLog "$" (T "Quay lại Bảng điều khiển Winget" "Returned to Winget Dashboard") $cDim
                        } elseif ($newControl -eq "BACK_BTN") {
                            Lock-Input 300
                            Write-RightLog "$" (T "Đã thoát Công cụ Winget" "Exited Winget Dashboard") $cDim
                            $running = $false
                            break
                        } elseif ($gTarget.StartsWith("TOP_") -or $gTarget.StartsWith("LANG_") -or $gTarget.StartsWith("LOG_") -or $gTarget.StartsWith("STATUS_") -or $gTarget.StartsWith("BREADCRUMB_")) {
                            $res = Handle-GlobalClick $posX $posY
                            if ($res -eq "BREADCRUMB_NAV") {
                                if ($global:navTarget -and $global:navTarget -ne "WINGET") {
                                    $running = $false
                                    break
                                }
                            }
                            Render-Dashboard
                        }
                    }

                    # Right Click Paste
                    if ($isRight -and $inlineInputOpen) {
                        $clip = ""
                        try {
                            Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
                            $clip = [System.Windows.Forms.Clipboard]::GetText()
                        } catch {}
                        if ($clip) {
                            $clean = $clip -replace "[\r\n]", ""
                            $inputBuffer = $inputBuffer.Substring(0, $cursorPos) + $clean + $inputBuffer.Substring($cursorPos)
                            $cursorPos += $clean.Length
                            $cursorVisible = $true
                            $lastBlinkTick = [Environment]::TickCount
                            Render-Dashboard
                        }
                    }
                }

                # Key Events
                if ($rec.EventType -eq 1 -and $rec.KeyEvent.bKeyDown -ne 0) {
                    $vk = $rec.KeyEvent.wVirtualKeyCode
                    $uChar = $rec.KeyEvent.UnicodeChar
                    $ctrlDown = (($rec.KeyEvent.dwControlKeyState -band 0x0008) -ne 0 -or ($rec.KeyEvent.dwControlKeyState -band 0x0004) -ne 0)

                    if (-not $inlineInputOpen) {
                        if ($uChar -eq '1') {
                            Invoke-UpgradeAllApps
                        } elseif ($uChar -eq '2') {
                            $inlineInputOpen = $true
                            $inputBuffer = ""
                            $cursorPos = 0
                            $cursorVisible = $true
                            $lastBlinkTick = [Environment]::TickCount
                            Render-Dashboard
                        } elseif ($uChar -eq '3') {
                            Invoke-WingetInstallPackages
                            Lock-Input 300
                            if ($hInput) { try { [ConsoleMouse]::FlushConsoleInputBuffer($hInput) | Out-Null } catch {} }
                            $wasLeft = $true
                            $hoverControl = "NONE"
                            if ($global:navTarget -and $global:navTarget -ne "WINGET") {
                                $running = $false
                                break
                            }
                            $global:navTarget = $null
                            if ($global:actionBreadcrumbs.Count -gt 1) {
                                $global:actionBreadcrumbs.RemoveAt($global:actionBreadcrumbs.Count - 1)
                            }
                            Start-ActionView "CÔNG CỤ WINGET" $cCyan "WINGET POWER TOOLS"
                            Set-Activity "OK" (T "Tìm thấy $($script:wingetAppList.Count) ứng dụng" "Found $($script:wingetAppList.Count) upgrade(s)") $cGreen
                            Draw-StatusPane
                            Render-Dashboard
                            Write-RightLog "$" (T "Quay lại Bảng điều khiển Winget" "Returned to Winget Dashboard") $cDim
                        } elseif ($vk -eq 0x1B) { # ESC
                            Write-RightLog "$" (T "Đã thoát Công cụ Winget" "Exited Winget Dashboard") $cDim
                            $running = $false
                            break
                        } elseif (Handle-ListNavigationKey $vk ([ref]$vertOffset) ([ref]$horizOffset) $maxVScroll $script:maxWingetOffset 5) {
                            Render-Dashboard
                        }
                    } else {
                        $isCtrlV = ($vk -eq 0x56 -and $ctrlDown) -or ([int]$uChar -eq 0x16)
                        if ($isCtrlV) {
                            $clip = ""
                            try {
                                Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
                                $clip = [System.Windows.Forms.Clipboard]::GetText()
                            } catch {}
                            if ($clip) {
                                $clean = $clip -replace "[\r\n]", ""
                                $inputBuffer = $inputBuffer.Substring(0, $cursorPos) + $clean + $inputBuffer.Substring($cursorPos)
                                $cursorPos += $clean.Length
                                $cursorVisible = $true
                                $lastBlinkTick = [Environment]::TickCount
                                Render-Dashboard
                            }
                            continue
                        }

                        if ($vk -eq 0x0D) { # Enter
                            if ($inputBuffer.Trim()) {
                                $idList = $inputBuffer.Trim() -split '\s+'
                                $idCancelled = $false
                                foreach ($targetId in $idList) {
                                    if (-not $targetId) { continue }
                                    Write-LeftConsoleProgress (T "Đang cập nhật $targetId..." "Updating $targetId...") $cYellow
                                    # --- [5.9.2] Winget: Update by ID ---
                                    Write-DebugLog "&&" "[5.9.2] Invoking Winget Upgrade by ID: $targetId"
                                    $idRes = Run-And-LogCommand "winget" "upgrade --id=`"$targetId`" --exact --accept-source-agreements --accept-package-agreements --disable-interactivity"
                                    if ($idRes -eq -1 -or $script:stopRequested -or $script:lastTaskCancelled) {
                                        $idCancelled = $true
                                        Write-RightLog "WARN" (T "Đã dừng cập nhật: $targetId" "Cancelled update: $targetId") $cYellow
                                        break
                                    }
                                    Write-RightLog "WINGET" (T "Hoàn tất cập nhật: $targetId" "Finished updating: $targetId") $cGreen
                                }
                                if ($idCancelled) {
                                    Set-Activity "!" (T "Đã dừng cập nhật" "Update stopped") $cYellow
                                } else {
                                    Set-Activity "OK" (T "Cập nhật hoàn tất" "Updates finished") $cGreen
                                }
                                Query-WingetUpdates
                            }
                            $inlineInputOpen = $false
                            $inputBuffer = ""
                            Render-Dashboard
                            continue
                        }

                        if ($vk -eq 0x1B) { # ESC
                            $inlineInputOpen = $false
                            $inputBuffer = ""
                            Render-Dashboard
                            continue
                        }

                        if ($vk -eq 0x08) { # Backspace
                            if ($cursorPos -gt 0) {
                                $inputBuffer = $inputBuffer.Substring(0, $cursorPos - 1) + $inputBuffer.Substring($cursorPos)
                                $cursorPos--
                                $cursorVisible = $true
                                $lastBlinkTick = [Environment]::TickCount
                                Render-Dashboard
                            }
                            continue
                        }

                        if ($vk -eq 0x2E) { # Delete
                            if ($cursorPos -lt $inputBuffer.Length) {
                                $inputBuffer = $inputBuffer.Substring(0, $cursorPos) + $inputBuffer.Substring($cursorPos + 1)
                                $cursorVisible = $true
                                $lastBlinkTick = [Environment]::TickCount
                                Render-Dashboard
                            }
                            continue
                        }

                        if ($vk -eq 0x25) { # Left Arrow
                            if ($cursorPos -gt 0) {
                                $cursorPos--
                                $cursorVisible = $true
                                $lastBlinkTick = [Environment]::TickCount
                                Render-Dashboard
                            }
                            continue
                        }

                        if ($vk -eq 0x27) { # Right Arrow
                            if ($cursorPos -lt $inputBuffer.Length) {
                                $cursorPos++
                                $cursorVisible = $true
                                $lastBlinkTick = [Environment]::TickCount
                                Render-Dashboard
                            }
                            continue
                        }

                        if ($vk -eq 0x24) { # Home
                            $cursorPos = 0
                            $cursorVisible = $true
                            $lastBlinkTick = [Environment]::TickCount
                            Render-Dashboard
                            continue
                        }

                        if ($vk -eq 0x23) { # End
                            $cursorPos = $inputBuffer.Length
                            $cursorVisible = $true
                            $lastBlinkTick = [Environment]::TickCount
                            Render-Dashboard
                            continue
                        }

                        if ($uChar -and [int]$uChar -ge 32) {
                            $inputBuffer = $inputBuffer.Substring(0, $cursorPos) + $uChar + $inputBuffer.Substring($cursorPos)
                            $cursorPos++
                            $cursorVisible = $true
                            $lastBlinkTick = [Environment]::TickCount
                            Render-Dashboard
                        }
                    }
                }
            }
        }
    }
    } finally {
        $global:actionBreadcrumbs.Clear()
        $leftConsoleLines.Clear()
        $global:currentActionName = $null
        $global:currentActionTitleVi = $null
        $global:currentActionTitleEn = $null
        $global:currentActionBorderColor = $null
        if ($global:navTarget) {
            $global:activeMenu = $global:navTarget
            $global:navTarget = $null
        }
        $script:currentHoverTarget = "NONE"
        $script:currentClickTarget = "NONE"
        Update-IdleActivity
        Draw-LeftMenu $false
        Draw-StatusPane
    }
}

# --- [5.9.3] Winget: Install Packages ---
function Invoke-WingetInstallPackages() {
    Write-DebugLog "&&" "[5.9.3] Invoking Winget Install Packages..."
    $isVi = ($global:selectedLang -eq "Vietnamese")
    Write-RightLog "IN" (T "Mở danh mục Cài đặt Phần mềm Cần thiết" "Opened Essential Packages Installer") $cWhite
    Write-RightLog "INFO" (T "[i] Click chuột vào phần mềm để cài đặt tự động qua Winget" "[i] Click any package to install automatically via Winget") $cLightCyan

    $pages = @{
        "REC" = @{
            TitleVi = "--- Gợi ý khuyên dùng ---"
            TitleEn = "--- Recommended Packages ---"
            Items   = @(
                @{ Id = "10";  Name = "All VCRedist" },
                @{ Id = "12";  Name = ".NET 8 Runtime" },
                @{ Id = "37";  Name = "Cốc Cốc" },
                @{ Id = "42";  Name = "Discord" },
                @{ Id = "62";  Name = "VLC Player" },
                @{ Id = "72";  Name = "Blender" },
                @{ Id = "86";  Name = "WinRAR" },
                @{ Id = "84";  Name = "7-Zip" },
                @{ Id = "111"; Name = "Python 3.12" },
                @{ Id = "112"; Name = "Git" },
                @{ Id = "114"; Name = "VS Code" },
                @{ Id = "113"; Name = "Notepad++" },
                @{ Id = "121"; Name = "AnyDesk" },
                @{ Id = "133"; Name = "Everything" },
                @{ Id = "131"; Name = "Steam" },
                @{ Id = "132"; Name = "Epic Games" }
            )
        }
        "P1" = @{
            TitleVi = "--- Trang 1: Runtimes & Trình duyệt & Chat ---"
            TitleEn = "--- Page 1: Runtimes, Web & Chat ---"
            Items   = @(
                @{ Id = "11"; Name = "VC 2005" },
                @{ Id = "13"; Name = "VC 2008" },
                @{ Id = "15"; Name = "VC 2010" },
                @{ Id = "17"; Name = "VC 2012" },
                @{ Id = "19"; Name = "VC 2013" },
                @{ Id = "21"; Name = "VC 2015+" },
                @{ Id = "14"; Name = "Java 21" },
                @{ Id = "31"; Name = "Chrome" },
                @{ Id = "32"; Name = "Firefox" },
                @{ Id = "33"; Name = "Edge" },
                @{ Id = "34"; Name = "Brave" },
                @{ Id = "35"; Name = "Opera" },
                @{ Id = "36"; Name = "Vivaldi" },
                @{ Id = "41"; Name = "Zoom" },
                @{ Id = "43"; Name = "Teams" },
                @{ Id = "44"; Name = "Pidgin" },
                @{ Id = "45"; Name = "Thunderbird" },
                @{ Id = "46"; Name = "Trillian" }
            )
        }
        "P2" = @{
            TitleVi = "--- Trang 2: Đa phương tiện & Đồ họa ---"
            TitleEn = "--- Page 2: Media & Imaging ---"
            Items   = @(
                @{ Id = "61";  Name = "iTunes" },
                @{ Id = "63";  Name = "AIMP" },
                @{ Id = "64";  Name = "foobar2000" },
                @{ Id = "65";  Name = "MusicBee" },
                @{ Id = "66";  Name = "Audacity" },
                @{ Id = "67";  Name = "K-Lite Mega" },
                @{ Id = "68";  Name = "Spotify" },
                @{ Id = "69";  Name = "HandBrake" },
                @{ Id = "60";  Name = "Winamp" },
                @{ Id = "601"; Name = "GOM Player" },
                @{ Id = "602"; Name = "MediaMonkey" },
                @{ Id = "71";  Name = "Krita" },
                @{ Id = "73";  Name = "Paint.NET" },
                @{ Id = "74";  Name = "GIMP" },
                @{ Id = "75";  Name = "IrfanView" },
                @{ Id = "76";  Name = "XnView MP" },
                @{ Id = "77";  Name = "Inkscape" },
                @{ Id = "78";  Name = "Greenshot" },
                @{ Id = "79";  Name = "ShareX" },
                @{ Id = "70";  Name = "FastStone" }
            )
        }
        "P3" = @{
            TitleVi = "--- Trang 3: Tài liệu, Nén & Bảo mật ---"
            TitleEn = "--- Page 3: Docs, Compression & Sec ---"
            Items   = @(
                @{ Id = "81";  Name = "Foxit Reader" },
                @{ Id = "82";  Name = "LibreOffice" },
                @{ Id = "83";  Name = "SumatraPDF" },
                @{ Id = "85";  Name = "PeaZip" },
                @{ Id = "87";  Name = "CutePDF" },
                @{ Id = "88";  Name = "OpenOffice" },
                @{ Id = "91";  Name = "Dropbox" },
                @{ Id = "92";  Name = "Google Drive" },
                @{ Id = "93";  Name = "OneDrive" },
                @{ Id = "94";  Name = "qBittorrent" },
                @{ Id = "101"; Name = "Malwarebytes" },
                @{ Id = "102"; Name = "Avast Free" },
                @{ Id = "103"; Name = "AVG Free" },
                @{ Id = "104"; Name = "Avira Sec" },
                @{ Id = "105"; Name = "SUPERAntiSpy" },
                @{ Id = "134"; Name = "KeePass 2" }
            )
        }
        "P4" = @{
            TitleVi = "--- Trang 4: Lập trình & Tiện ích ---"
            TitleEn = "--- Page 4: Dev & Utilities ---"
            Items   = @(
                @{ Id = "115";  Name = "FileZilla" },
                @{ Id = "116";  Name = "WinSCP" },
                @{ Id = "117";  Name = "PuTTY" },
                @{ Id = "118";  Name = "WinMerge" },
                @{ Id = "119";  Name = "Cursor" },
                @{ Id = "110";  Name = "Eclipse" },
                @{ Id = "123";  Name = "Revo Unin" },
                @{ Id = "124";  Name = "WizTree" },
                @{ Id = "125";  Name = "WinDirStat" },
                @{ Id = "126";  Name = "Glary Util" },
                @{ Id = "127";  Name = "CCleaner" },
                @{ Id = "128";  Name = "TeraCopy" },
                @{ Id = "129";  Name = "OpenShell" },
                @{ Id = "120";  Name = "ImgBurn" },
                @{ Id = "1201"; Name = "RealVNC" },
                @{ Id = "1202"; Name = "TightVNC" },
                @{ Id = "122";  Name = "TeamViewer" },
                @{ Id = "135";  Name = "Google Earth" },
                @{ Id = "136";  Name = "Evernote" },
                @{ Id = "137";  Name = "NVDA" }
            )
        }
    }

        $curPage = "REC"
    $script:lastRenderedPage = $null
    $hoverControl = "NONE" 
    $hoverItemIdx = -1
    $flashItemIdx = -1
    $flashTick = 0

    function Local:Render-InstallPage($animate = $false) {
        $isVi = ($global:selectedLang -eq "Vietnamese")
        if ($curPage -ne $script:lastRenderedPage) {
            $script:lastRenderedPage = $curPage
            $pData = $pages[$curPage]
            if ($pData) {
                $pTitle = if ($isVi) { $pData.TitleVi } else { $pData.TitleEn }
                $cleanTitle = $pTitle -replace '^[\s\-]+', '' -replace '[\s\-]+$', ''
                Write-RightLog "$" (T "Chuyển sang: $cleanTitle" "Switched to: $cleanTitle") $cDim
            }
        }
        Get-TermSize
        $leftH = [math]::Max(5, $script:termH - 4)

        # 1. Back button at Y=3
        if (Test-IsAnyTaskRunning) {
            Hide-LeftBackButton
        } else {
            Show-LeftBackButton $(if ($hoverControl -eq "BACK_BTN") { "HOVER" } else { "NORMAL" })
        }

        $pageData = $pages[$curPage]
        $pageTitle = if ($isVi) { $pageData.TitleVi } else { $pageData.TitleEn }
        $items = $pageData.Items

        # Row 4: Page Subtitle (Centered, with '---' flush left and '---' flush right)
        Set-CursorPos 2 4
        $cleanTitle = $pageTitle -replace '^[\s\-]+', '' -replace '[\s\-]+$', ''
        $avail = 33 # 39 inside width minus 6 for "---" on left and "---" on right
        if ($cleanTitle.Length -ge $avail) {
            $headLine = "---" + $cleanTitle.Substring(0, $avail) + "---"
        } else {
            $padTotal = $avail - $cleanTitle.Length
            $padL = [int]($padTotal / 2)
            $padR = $padTotal - $padL
            $headLine = "---" + (" " * $padL) + $cleanTitle + (" " * $padR) + "---"
        }
        Write-Host "$cLightYellow$headLine$cReset" -NoNewline

        # Row 5: 1-line empty gap between Page Subtitle and first App row
        Set-CursorPos 2 5
        [Console]::Write((" " * 39))

        # Rows with 2 columns separated by a 1-space gap at col 21
        # Separated by 1 blank line between each row if space permits
        $numRows = [int][math]::Ceiling($items.Count / 2)
        $step = if ((6 + (($numRows - 1) * 2) + 2) -le ($leftH + 1)) { 2 } else { 1 }

        for ($r = 0; $r -lt $numRows; $r++) {
            $y = 6 + ($r * $step)
            Set-CursorPos 2 $y
            $i1 = $r * 2
            $i2 = $r * 2 + 1

            # Column 1 (cols 2..20, width 19)
            $it1 = $items[$i1]
            $str1 = ("[{0}] {1}" -f $it1.Id, $it1.Name).PadRight(19)
            if ($str1.Length -gt 19) { $str1 = $str1.Substring(0, 19) }
            $col1Style = if ($flashItemIdx -eq $i1) {
                "$ESC[48;2;30;85;45m$ESC[38;2;140;255;160m"
            } elseif ($hoverControl -eq "ITEM" -and $hoverItemIdx -eq $i1) {
                "$ESC[48;2;45;50;62m$ESC[38;2;255;255;255m"
            } else {
                "$cWhite"
            }

            # Column 2 (cols 22..40, width 19) with 1-space gap at col 21
            $col2Out = " " * 19
            if ($i2 -lt $items.Count) {
                $it2 = $items[$i2]
                $str2 = ("[{0}] {1}" -f $it2.Id, $it2.Name).PadRight(19)
                if ($str2.Length -gt 19) { $str2 = $str2.Substring(0, 19) }
                $col2Style = if ($flashItemIdx -eq $i2) {
                    "$ESC[48;2;30;85;45m$ESC[38;2;140;255;160m"
                } elseif ($hoverControl -eq "ITEM" -and $hoverItemIdx -eq $i2) {
                    "$ESC[48;2;45;50;62m$ESC[38;2;255;255;255m"
                } else {
                    "$cWhite"
                }
                $col2Out = "$col2Style$str2$cReset"
            }
            Write-Host "$col1Style$str1$cReset $col2Out" -NoNewline

            # Blank line between rows if step == 2
            if ($step -eq 2 -and ($y + 1) -le ($leftH + 1)) {
                Set-CursorPos 2 ($y + 1)
                [Console]::Write((" " * 39))
            }
            if ($animate) {
                Start-Sleep -Milliseconds 18
            }
        }

        $lastAppY = 6 + (($numRows - 1) * $step)
        $sepY = $lastAppY + 1
        $navY = $sepY + 1
        $script:installStep = $step
        $script:installLastAppY = $lastAppY
        $script:installNavY = $navY

        # Separator line at Row $sepY
        if ($sepY -le ($leftH + 1)) {
            Set-CursorPos 2 $sepY
            Write-Host ("$cDim" + ($chrLine * 39) + "$cReset") -NoNewline
        }

        # Navigation Bar at Row $navY: [P] Prev  [R] [1] [2] [3] [4]  [N] Next
        if ($navY -le ($leftH + 1)) {
            Set-CursorPos 2 $navY
            $prevTxt = if ($isVi) { "[P] Trước" } else { "[P] Prev" }
            $nextTxt = if ($isVi) { "[N] Tiếp" } else { "[N] Next" }

            $prevStyle = if ($hoverControl -eq "PREV_BTN") { "$ESC[48;2;45;50;62m$cWhite" } else { "$cLightCyan" }
            $nextStyle = if ($hoverControl -eq "NEXT_BTN") { "$ESC[48;2;45;50;62m$cWhite" } else { "$cLightCyan" }

            $tabs = @("REC", "P1", "P2", "P3", "P4")
            $tabLabels = @{
                "REC" = "[R]"
                "P1"  = "[1]"
                "P2"  = "[2]"
                "P3"  = "[3]"
                "P4"  = "[4]"
            }
            $tabOutList = @()
            foreach ($t in $tabs) {
                $lbl = $tabLabels[$t]
                $isActive = ($curPage -eq $t)
                $isHov = ($hoverControl -eq "TAB_$t")
                $style = if ($isActive) {
                    "$ESC[48;2;30;70;45m$ESC[38;2;120;255;160m"
                } elseif ($isHov) {
                    "$ESC[48;2;45;50;62m$ESC[38;2;255;255;255m"
                } else {
                    "$cDim"
                }
                $tabOutList += "$style$lbl$cReset"
            }
            $tabsStr = $tabOutList -join " "
            $sp1 = if ($isVi) { " " } else { "  " }
            $sp2 = "  "
            Write-Host "$prevStyle$prevTxt$cReset$sp1$tabsStr$sp2$nextStyle$nextTxt$cReset" -NoNewline
        }

        # Clear remaining inside lines below row $navY (strictly inside box, never overwriting bottom border at leftH + 2)
        $clearY = $navY + 1
        while ($clearY -le ($leftH + 1)) {
            Set-CursorPos 2 $clearY
            [Console]::Write((" " * 39))
            $clearY++
        }
    }

    $global:actionBreadcrumbs.Add(@{ Key = "INSTALL_PKG"; Vi = "Cài đặt phần mềm cần thiết"; En = "Install Essential Packages" })
    Start-ActionView "CÀI ĐẶT PHẦN MỀM CẦN THIẾT" $cCyan "INSTALL ESSENTIAL PACKAGES"
    Set-Activity "IDLE" (T "Sẵn sàng: Cài đặt phần mềm" "Ready: Install Essential Packages") $cLightCyan
    Draw-StatusPane
    Render-InstallPage $true

    # Event Loop
    $hInput = [ConsoleMouse]::GetStdHandle([ConsoleMouse]::STD_INPUT_HANDLE)
    if ($hInput) {
        try {
            $inMode = 0
            [ConsoleMouse]::GetConsoleMode($hInput, [ref]$inMode) | Out-Null
            $inMode = $inMode -band (-bnot [ConsoleMouse]::ENABLE_QUICK_EDIT_MODE)
            $inMode = $inMode -bor [ConsoleMouse]::ENABLE_MOUSE_INPUT -bor [ConsoleMouse]::ENABLE_EXTENDED_FLAGS
            [ConsoleMouse]::SetConsoleMode($hInput, $inMode) | Out-Null
            [ConsoleMouse]::FlushConsoleInputBuffer($hInput) | Out-Null
        } catch {}
    }
    $records = if ($hInput) { New-Object ConsoleMouse+INPUT_RECORD[] 64 } else { $null }

    $running = $true
    $wasLeft = $false
    try {
    while ($running) {
        Start-Sleep -Milliseconds 25
        $now = [Environment]::TickCount

        # Flash reset
        if ($flashItemIdx -ge 0 -and ($now - $flashTick) -gt 350) {
            $flashItemIdx = -1
            Render-InstallPage
        }

        if ($hInput) {
            [uint32]$eventsCount = 0
            [ConsoleMouse]::GetNumberOfConsoleInputEvents($hInput, [ref]$eventsCount) | Out-Null
            if ($eventsCount -le 0) { continue }

            [uint32]$toRead = [math]::Min([uint32]$records.Length, $eventsCount)
            [uint32]$read = 0
            [ConsoleMouse]::ReadConsoleInput($hInput, $records, $toRead, [ref]$read) | Out-Null

            for ($i = 0; $i -lt $read; $i++) {
                $rec = $records[$i]

                # Resize Event (EventType == 4)
                if ($rec.EventType -eq 4) {
                    $script:termSizeDirty = $true
                    Get-TermSize -force
                    Draw-FullLayout $false
                    Render-InstallPage
                    continue
                }

                # Keyboard Event (EventType == 1)
                if ($rec.EventType -eq 1 -and $rec.KeyEvent.bKeyDown -ne 0) {
                    $vk = $rec.KeyEvent.wVirtualKeyCode
                    $ch = [char]$rec.KeyEvent.UnicodeChar

                    if ($vk -eq 27) { # ESC
                        Write-RightLog "$" (T "Đã thoát Cài đặt Gói Phần mềm" "Exited Install Essential Packages") $cDim
                        $running = $false
                        break
                    }
                    if ($ch -eq 'r' -or $ch -eq 'R') {
                        $curPage = "REC"
                        Render-InstallPage
                    } elseif ($ch -eq '1') {
                        $curPage = "P1"
                        Render-InstallPage
                    } elseif ($ch -eq '2') {
                        $curPage = "P2"
                        Render-InstallPage
                    } elseif ($ch -eq '3') {
                        $curPage = "P3"
                        Render-InstallPage
                    } elseif ($ch -eq '4') {
                        $curPage = "P4"
                        Render-InstallPage
                    } elseif ($ch -eq 'n' -or $ch -eq 'N' -or $vk -eq 39) { # Next / Right Arrow
                        $curPage = switch ($curPage) {
                            "REC" { "P1" }
                            "P1"  { "P2" }
                            "P2"  { "P3" }
                            "P3"  { "P4" }
                            "P4"  { "REC" }
                            default { "REC" }
                        }
                        Render-InstallPage
                    } elseif ($ch -eq 'p' -or $ch -eq 'P' -or $vk -eq 37) { # Prev / Left Arrow
                        $curPage = switch ($curPage) {
                            "REC" { "P4" }
                            "P1"  { "REC" }
                            "P2"  { "P1" }
                            "P3"  { "P2" }
                            "P4"  { "P3" }
                            default { "REC" }
                        }
                        Render-InstallPage
                    }
                }

                # Mouse Event (EventType == 2)
                if ($rec.EventType -eq 2) {
                    $mEvent = $rec.MouseEvent
                    $posX = $mEvent.dwMousePosition.X
                    $posY = $mEvent.dwMousePosition.Y
                    $btnState = $mEvent.dwButtonState
                    $evtFlags = $mEvent.dwEventFlags
                    $isLeft = ($btnState -band 1) -ne 0
                    $isLeftClick = ($isLeft -and -not $wasLeft)
                    $wasLeft = $isLeft

                    # Wheel scroll for page switching
                    if (($evtFlags -band 4) -ne 0) {
                        $wheelDelta = [int16]($btnState -shr 16)
                        if ($wheelDelta -lt 0) {
                            # Wheel Down: Next Page
                            $curPage = switch ($curPage) {
                                "REC" { "P1" }
                                "P1"  { "P2" }
                                "P2"  { "P3" }
                                "P3"  { "P4" }
                                "P4"  { "REC" }
                                default { "REC" }
                            }
                            Render-InstallPage
                        } elseif ($wheelDelta -gt 0) {
                            # Wheel Up: Prev Page
                            $curPage = switch ($curPage) {
                                "REC" { "P4" }
                                "P1"  { "REC" }
                                "P2"  { "P1" }
                                "P3"  { "P2" }
                                "P4"  { "P3" }
                                default { "REC" }
                            }
                            Render-InstallPage
                        }
                        continue
                    }

                    # Determine target
                    $isVi = ($global:selectedLang -eq "Vietnamese")
                    $newControl = "NONE"
                    $newItemIdx = -1
                    $backStartX = if ($isVi) { 30 } else { 32 }
                    $backEndX   = 39

                    # 1. Back button at row 3
                    if ($posY -eq 3 -and $posX -ge $backStartX -and $posX -le $backEndX) {
                        if (-not (Test-IsAnyTaskRunning)) {
                            $newControl = "BACK_BTN"
                        }
                    }
                    # 2. Package items at rows 6..$script:installLastAppY
                    elseif ($posY -ge 6 -and $posY -le $script:installLastAppY) {
                        $relY = $posY - 6
                        if ($script:installStep -eq 1 -or ($relY % $script:installStep) -eq 0) {
                            $r = [int]($relY / $script:installStep)
                            $currItems = $pages[$curPage].Items
                            $numRows = [int][math]::Ceiling($currItems.Count / 2)
                            if ($r -ge 0 -and $r -lt $numRows) {
                                if ($posX -ge 1 -and $posX -le 20) {
                                    $newControl = "ITEM"
                                    $newItemIdx = $r * 2
                                } elseif ($posX -ge 22 -and $posX -le 41) {
                                    $idx2 = $r * 2 + 1
                                    if ($idx2 -lt $currItems.Count) {
                                        $newControl = "ITEM"
                                        $newItemIdx = $idx2
                                    }
                                }
                            }
                        }
                    }
                    # 3. Dynamic Navigation bar at row $script:installNavY: Prev, Tabs, Next
                    elseif ($posY -eq $script:installNavY) {
                        $prevEnd = if ($isVi) { 11 } else { 10 }
                        if ($posX -ge 1 -and $posX -le $prevEnd)   { $newControl = "PREV_BTN" }
                        elseif ($posX -ge 12 -and $posX -le 14)  { $newControl = "TAB_REC" }
                        elseif ($posX -ge 16 -and $posX -le 18)  { $newControl = "TAB_P1" }
                        elseif ($posX -ge 20 -and $posX -le 22)  { $newControl = "TAB_P2" }
                        elseif ($posX -ge 24 -and $posX -le 26)  { $newControl = "TAB_P3" }
                        elseif ($posX -ge 28 -and $posX -le 30)  { $newControl = "TAB_P4" }
                        elseif ($posX -ge 32 -and $posX -le 41)  { $newControl = "NEXT_BTN" }
                    }

                    # Global target hover detection (Breadcrumb, Top bar, Status pane)
                    $gTarget = Get-HoverTarget $posX $posY
                    if ($gTarget -ne $script:currentHoverTarget) {
                        $oldTarget = $script:currentHoverTarget
                        $script:currentHoverTarget = $gTarget
                        if ($gTarget.StartsWith("STATUS_") -or $oldTarget.StartsWith("STATUS_") -or $gTarget.StartsWith("BREADCRUMB_") -or $oldTarget.StartsWith("BREADCRUMB_")) {
                            Draw-StatusPane
                        }
                        if ($gTarget.StartsWith("TOP_") -or $oldTarget.StartsWith("TOP_") -or $gTarget.StartsWith("LANG_") -or $oldTarget.StartsWith("LANG_") -or $gTarget.StartsWith("LOG_") -or $oldTarget.StartsWith("LOG_")) {
                            Draw-TopMenuBar
                        }
                    }

                    # Update hover
                    if ($newControl -ne $hoverControl -or $newItemIdx -ne $hoverItemIdx) {
                        $isBackOnly = (($newControl -eq "BACK_BTN" -or $hoverControl -eq "BACK_BTN") -and $newItemIdx -eq $hoverItemIdx)
                        $hoverControl = $newControl
                        $hoverItemIdx = $newItemIdx
                        if ($isBackOnly) {
                            Show-LeftBackButton $(if ($hoverControl -eq "BACK_BTN") { "HOVER" } else { "NORMAL" })
                        } else {
                            Render-InstallPage
                        }
                    }

                    # Handle Click (on Left Down leading edge)
                    if ($isLeftClick) {
                        if ($newControl -eq "BACK_BTN") {
                            Lock-Input 300
                            Write-RightLog "$" (T "Đã thoát Cài đặt Gói Phần mềm" "Exited Install Essential Packages") $cDim
                            if ($hInput) { try { [ConsoleMouse]::FlushConsoleInputBuffer($hInput) | Out-Null } catch {} }
                            $running = $false
                            break
                        } elseif ($gTarget.StartsWith("BREADCRUMB_")) {
                            Lock-Input 300
                            if ($hInput) { try { [ConsoleMouse]::FlushConsoleInputBuffer($hInput) | Out-Null } catch {} }
                            $res = Handle-GlobalClick $posX $posY
                            if ($res -eq "BREADCRUMB_NAV") {
                                $running = $false
                                break
                            }
                        } elseif ($gTarget.StartsWith("TOP_") -or $gTarget.StartsWith("LANG_") -or $gTarget.StartsWith("LOG_") -or $gTarget.StartsWith("STATUS_")) {
                            $res = Handle-GlobalClick $posX $posY
                            if ($res -eq "LANG_CHANGED") {
                                Render-InstallPage
                            }
                        } elseif ($newControl -eq "PREV_BTN") {
                            $curPage = switch ($curPage) {
                                "REC" { "P4" }
                                "P1"  { "REC" }
                                "P2"  { "P1" }
                                "P3"  { "P2" }
                                "P4"  { "P3" }
                                default { "REC" }
                            }
                            Render-InstallPage
                        } elseif ($newControl -eq "NEXT_BTN") {
                            $curPage = switch ($curPage) {
                                "REC" { "P1" }
                                "P1"  { "P2" }
                                "P2"  { "P3" }
                                "P3"  { "P4" }
                                "P4"  { "REC" }
                                default { "REC" }
                            }
                            Render-InstallPage
                        } elseif ($newControl -eq "TAB_REC") {
                            $curPage = "REC"
                            Render-InstallPage
                        } elseif ($newControl -eq "TAB_P1") {
                            $curPage = "P1"
                            Render-InstallPage
                        } elseif ($newControl -eq "TAB_P2") {
                            $curPage = "P2"
                            Render-InstallPage
                        } elseif ($newControl -eq "TAB_P3") {
                            $curPage = "P3"
                            Render-InstallPage
                        } elseif ($newControl -eq "TAB_P4") {
                            $curPage = "P4"
                            Render-InstallPage
                        } elseif ($newControl -eq "ITEM" -and $newItemIdx -ge 0) {
                            $currItems = $pages[$curPage].Items
                            $targetItem = $currItems[$newItemIdx]
                            $flashItemIdx = $newItemIdx
                            $flashTick = [Environment]::TickCount
                            Render-InstallPage

                            $pkgList = $script:wingetPackages[$targetItem.Id]
                            if ($pkgList) {
                                if ($pkgList.Count -gt 1) {
                                    Write-RightLog "WARN" (T "Gói cài đặt $($targetItem.Name) bao gồm $($pkgList.Count) phần mềm/thành phần." "Bundle $($targetItem.Name) contains $($pkgList.Count) components.") $cYellow
                                    Start-ActionView "XÁC NHẬN CÀI ĐẶT GÓI" $cYellow "CONFIRM PACKAGE INSTALL"
                                    Write-LeftConsole (T " Gói '$($targetItem.Name)' bao gồm $($pkgList.Count) thành phần:" " Package '$($targetItem.Name)' contains $($pkgList.Count) components:") $cCyan
                                    foreach ($p in $pkgList) {
                                        Write-LeftConsole "  - $p" $cWhite
                                    }
                                    Write-LeftConsole ""
                                    $confirmPkg = Wait-SingleKey (T "Cài đặt tất cả $($pkgList.Count) thành phần?" "Install all $($pkgList.Count) components?") @('Y','N')
                                    if ($confirmPkg -ne 'Y') {
                                        Write-RightLog "DECLINED" (T "Đã hủy cài đặt $($targetItem.Name)" "Cancelled installation of $($targetItem.Name)") $cDim
                                        Render-InstallPage
                                        continue
                                    }
                                }
                                Set-Activity "RUN" (T "Đang cài đặt: $($targetItem.Name)" "Installing: $($targetItem.Name)") $cYellow
                                Draw-StatusPane
                                Write-RightLog "IN" (T "Bắt đầu cài đặt $($targetItem.Name)..." "Starting installation: $($targetItem.Name)...") $cYellow

                                $pkgCancelled = $false
                                foreach ($p in $pkgList) {
                                    Write-RightLog "IN" (T "Đang tải & cài đặt $p qua Winget..." "Downloading & installing $p via Winget...") $cLightCyan
                                    $pkgRes = Run-And-LogCommand "winget" "install --id=`"$p`" --exact --accept-source-agreements --accept-package-agreements --disable-interactivity"
                                    if ($pkgRes -eq -1 -or $script:stopRequested -or $script:lastTaskCancelled) {
                                        $pkgCancelled = $true
                                        Write-RightLog "WARN" (T "Đã hủy cài đặt: $p" "Cancelled install: $p") $cYellow
                                        break
                                    }
                                    Write-RightLog "OK" (T "Đã cài đặt xong $p" "Finished installing $p") $cGreen
                                }

                                if ($pkgCancelled) {
                                    Write-RightLog "WARN" (T "Đã dừng gói cài đặt: $($targetItem.Name)" "Stopped package install: $($targetItem.Name)") $cYellow
                                    Set-Activity "!" (T "Đã dừng: $($targetItem.Name)" "Stopped: $($targetItem.Name)") $cYellow
                                } else {
                                    Write-RightLog "OK" (T "Hoàn tất cài đặt: $($targetItem.Name)" "Completed install: $($targetItem.Name)") $cLightGreen
                                    Set-Activity "OK" (T "Hoàn tất: $($targetItem.Name)" "Done: $($targetItem.Name)") $cLightGreen
                                }
                                Draw-StatusPane
                            } else {
                                Write-RightLog "ERR" (T "Không tìm thấy gói phần mềm: $($targetItem.Id)" "Package ID not found: $($targetItem.Id)") $cRed
                            }

                            $flashItemIdx = -1
                            Start-ActionView "CÀI ĐẶT PHẦN MỀM CẦN THIẾT" $cCyan "INSTALL ESSENTIAL PACKAGES"
                            Render-InstallPage
                        } elseif ($posY -le 1 -or $posY -eq 4 -or $posY -eq 6) {
                            $res = Handle-GlobalClick $posX $posY
                            if ($res -eq "BREADCRUMB_NAV") {
                                $running = $false
                                break
                            }
                            Render-InstallPage
                        }
                    }
                }
            }
        }
    }
    } finally {
        if ($global:actionBreadcrumbs.Count -gt 1) {
            $global:actionBreadcrumbs.RemoveAt($global:actionBreadcrumbs.Count - 1)
        }
        $leftConsoleLines.Clear()
    }
}

# -------------------------------------------------------------------------------
#  SECTION 7.5: AUTO MAINTENANCE ROUTINE (MENU [6])
# -------------------------------------------------------------------------------
# --- [6.0] Auto Maintenance ---
function Invoke-AutoRun() {
    Write-DebugLog "&&" "[6.0] Invoking Auto Maintenance Routine..."
    if (-not (Require-AdminOrPrompt "TỰ ĐỘNG BẢO TRÌ HỆ THỐNG" "AUTO MAINTENANCE")) { return }
    Start-ActionView "TỰ ĐỘNG BẢO TRÌ HỆ THỐNG" $cDarkYellow "AUTO MAINTENANCE"
    Write-LeftConsole (T " [i] Các bước sẽ thực hiện tự động:" " [i] Tasks executed automatically:") $cCyan
    Write-LeftConsole (T "  1. Dọn dẹp nhanh (Tệp tạm, thùng rác, nhật ký)" "  1. Quick Clean (Temp files, Recycle Bin, logs)") $cWhite
    Write-LeftConsole (T "  2. Dọn dẹp sâu (Quét & sửa lỗi hệ thống DISM, SFC)" "  2. Deep Clean (DISM & SFC System Repair)") $cWhite
    Write-LeftConsole (T "  3. Xóa bộ đệm cập nhật Windows" "  3. Clear Windows Update Cache") $cWhite
    Write-LeftConsole ""
    $conf = Get-LeftInput (T "Gõ 'AUTO' để bắt đầu bảo trì toàn diện" "Type 'AUTO' to confirm")
    if ($conf -eq "AUTO") {
        Write-RightLog "SUMMARY" (T "Bắt đầu tự động bảo trì toàn diện..." "Starting Full Auto Maintenance...") $cYellow
        $script:lastTaskCancelled = $false
        $ok1 = Invoke-QuickClean $true
        if ($script:lastTaskCancelled -or -not $ok1) {
            Set-Activity "!" (T "Đã dừng: Tự động bảo trì" "Stopped: Auto Maintenance") $cYellow
            Wait-LeftReturn
            return
        }
        $ok2 = Invoke-DeepClean $true
        if ($script:lastTaskCancelled -or -not $ok2) {
            Set-Activity "!" (T "Đã dừng: Tự động bảo trì" "Stopped: Auto Maintenance") $cYellow
            Wait-LeftReturn
            return
        }
        $ok3 = Invoke-ClearWinUpdate $true
        if ($script:lastTaskCancelled -or -not $ok3) {
            Set-Activity "!" (T "Đã dừng: Tự động bảo trì" "Stopped: Auto Maintenance") $cYellow
            Wait-LeftReturn
            return
        }
        Write-RightLog "SUMMARY" (T "TỰ ĐỘNG BẢO TRÌ ĐÃ HOÀN TẤT TOÀN DIỆN." "FULL AUTO MAINTENANCE COMPLETED.") $cGreen
        Set-Activity "OK" (T "Hoàn thành: Tự động bảo trì" "Done: Auto Maintenance") $cGreen
        Write-LeftConsole ""
        $reb = Wait-SingleKey (T "Khởi động lại máy tính ngay?" "Reboot computer now?") @('Y', 'N')
        if ($reb -eq "Y") {
            Run-And-LogCommand "shutdown" "/r /t 10" | Out-Null
        }
        Wait-LeftReturn
    } else {
        $global:currentActionName = $null
        $global:currentActionBorderColor = $null
        Update-IdleActivity
        Draw-LeftMenu $false
        Draw-StatusPane
    }
}

# -------------------------------------------------------------------------------
#  SECTION 7.6: TOOLKIT OPTIONS (MENU [7])
# -------------------------------------------------------------------------------
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

    try { [Console]::Clear() } catch { [Console]::Write("$ESC[3J$ESC[2J$ESC[H") }
    $blockW = 43
    $blockH = 9
    $startX = [math]::Max(0, [int](($script:termW - $blockW) / 2))
    $startY = [math]::Max(2, [int](($script:termH - $blockH) / 2))

    while ($true) {
        $fData = Get-NextStartupFrame $frameIdx
        $lines = @($fData.FrameText -split "`r?\n" | Where-Object { $_.Length -gt 0 })
        $col = $fData.ColorCode

        for ($li = 0; $li -lt 9; $li++) {
            $rawLine = if ($li -lt $lines.Count) { $lines[$li] } else { "" }
            $line = if ($rawLine.Length -gt $blockW) { $rawLine.Substring(0, $blockW) } else { $rawLine.PadRight($blockW) }
            Set-CursorPos $startX ($startY + $li)
            [Console]::Write("$col$line$cReset")
        }

        $frameIdx++
        $renderedCount++

        $isDone = if ($asyncResult) { $asyncResult.IsCompleted } else { $true }
        if ([Console]::KeyAvailable) {
            $null = [Console]::ReadKey($true)
            if ($isDone) { break }
        }

        Start-Sleep -Milliseconds 150

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
try {
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
} finally {
    Terminate-AllChildProcesses
    if ($script:appMutex) {
        try { $script:appMutex.ReleaseMutex() } catch {}
        try { $script:appMutex.Dispose() } catch {}
        $script:appMutex = $null
    }
    try { [Console]::Clear() } catch {}
    try { [Console]::CursorVisible = $true } catch {}
    Write-Host "${cGreen}Thank you for using Windows Cleanup & Optimizer TUI!${cReset}"
}
