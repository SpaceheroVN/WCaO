@echo off
setlocal enabledelayedexpansion
title "Windows Cleanup & Optimizer v5.0.2 - Pro Toolkit (Auto & Expert)"

:: ==========================================
:: ===== CONFIGURATION - CUSTOMIZE HERE =====
:: ==========================================
set "VERSION=5.0.1"
set "TOOLNAME=Windows Cleanup and Optimizer"

:: Log Configuration
:: Base directory for logs within the user's local app data.
set "BASE_DIR=%LocalAppData%\WCaO_Toolkit"
:: How many days to keep old log files.
set "LOG_RETENTION_DAYS=7"

:: Default Expert Mode (0 = Off, 1 = On)
set "DEFAULT_EXPERT_MODE=0"

:: Color Configuration (Fixed trailing spaces)
set "COLOR_MENU=0B"       :: Light Aqua     - Main Menu
set "COLOR_QUICK=0A"      :: Light Green    - Quick Cleanup
set "COLOR_DEEP=09"       :: Light Blue     - Deep Cleanup
set "COLOR_OPTIMIZE=0D"   :: Light Purple   - Optimization
set "COLOR_ADVANCED=0C"   :: Light Red      - Advanced Tools
set "COLOR_FINISH=0E"     :: Light Yellow   - Finish and Report
set "COLOR_ERROR=4F"      :: Red BG, White Text - Error Messages
set "COLOR_WARNING=6F"    :: Yellow BG, White Text - Warning Messages

:: ===============================================================
:: ===== SCRIPT INITIALIZATION (Do not edit below this line) =====
:: ===============================================================

set "EXPERT_MODE=%DEFAULT_EXPERT_MODE%"
set "TMP_LOGFILE=%BASE_DIR%\Actions.tmp"
set "ERROR_LOGFILE=%BASE_DIR%\Errors.log"

:: Create base directory if it doesn't exist
if not exist "%BASE_DIR%" mkdir "%BASE_DIR%" >nul 2>&1

:: --- ROBUSTNESS CHECK: Verify that the working directory was created ---
if not exist "%BASE_DIR%\" (
    cls & color %COLOR_ERROR%
    call :DrawBox "CRITICAL ERROR"
    echo.
    echo  Could not create the working directory:
    echo  "%BASE_DIR%"
    echo.
    echo  Please check your user permissions or antivirus settings.
    echo  The script cannot continue without this directory.
    echo.
    pause
    exit /b
)

:: On start, clean up temp log from a previous improper exit
if exist "%TMP_LOGFILE%" del "%TMP_LOGFILE%" >nul 2>&1

:: Start a fresh temporary log for the current session
call :CreateNewTempLog

:: Clean up old permanent logs from the base directory
forfiles /p "%BASE_DIR%" /m "Log_*.txt" /d -%LOG_RETENTION_DAYS% /c "cmd /c del @path" >nul 2>&1

:: ===== ADMIN CHECK =====
>nul 2>&1 net session || (
    cls & color %COLOR_ERROR%
    call :DrawBox "ERROR: ADMINISTRATOR PRIVILEGES REQUIRED"
    echo.
    echo  This script must be run with administrative privileges to function correctly.
    echo.
    echo  To fix this:
    echo  1. Close this window.
    echo  2. Right-click the script file.
    echo  3. Select 'Run as administrator'.
    echo.
    pause >nul
    exit /b
)

:: ===== DETECT OS DRIVE (PERFORMANCE OPTIMIZATION) =====
:: Replaced slow WMIC call with the fast, built-in %SystemDrive% variable.
set "OS_DRIVE=%SystemDrive%"
if not defined OS_DRIVE set "OS_DRIVE=C:"


:: =====================
:: ===== MAIN MENU =====
:: =====================
:main_menu
cls & color %COLOR_MENU%
call :DrawBox "%TOOLNAME% - v%VERSION%"
set "expert_status=Off"
if "!EXPERT_MODE!"=="1" set "expert_status=On"
echo.
echo  System Drive: %OS_DRIVE%
echo.
echo  [1] Quick Cleanup
echo  [2] Deep Cleanup
echo  [3] System Optimization
echo  [4] Advanced Tools
echo  [5] Auto Run Full Maintenance
echo.
echo  --------------------------------------
echo  [6] Toggle Expert Mode (Current: !expert_status!)
echo  [7] Export Report
echo  [8] Exit
echo.
set /p "choice=  Please choose an option (1-8): "
if "%choice%"=="1" call :QuickClean & goto main_menu
if "%choice%"=="2" call :DeepClean & goto main_menu
if "%choice%"=="3" call :SystemOptimizeMenu & goto main_menu
if "%choice%"=="4" call :AdvancedMenu & goto main_menu
if "%choice%"=="5" call :AutoRun & goto main_menu
if "%choice%"=="6" (if "!EXPERT_MODE!"=="0" (set "EXPERT_MODE=1") else (set "EXPERT_MODE=0")) & goto main_menu
if "%choice%"=="7" call :ExportReport & goto main_menu
if "%choice%"=="8" (
    :: Delete temp log on clean exit
    if exist "%TMP_LOGFILE%" del "%TMP_LOGFILE%" >nul 2>&1
    exit /b
)
:: Loop back to main menu if invalid input
goto main_menu

:: ============================================
:: ===== CLEANUP & OPTIMIZATION FUNCTIONS =====
:: ============================================

:: ===== QUICK CLEANUP =====
:QuickClean
cls & color %COLOR_QUICK% & call :DrawBox "QUICK CLEANUP"
echo.
call :CleanDir "%temp%" "User Temp folder"
call :CleanDir "%SystemRoot%\Temp" "System Temp folder"
call :CleanDir "%SystemRoot%\Prefetch" "Prefetch folder"
call :CleanDir "%APPDATA%\Microsoft\Windows\Recent" "Recent shortcuts"
echo  [+] Emptying Recycle Bin...
:: (ROBUSTNESS FIX) Use PowerShell for a more reliable and silent Recycle Bin clear.
powershell.exe -NoProfile -Command "Clear-RecycleBin -Force -ErrorAction SilentlyContinue"
echo      [OK] Recycle Bin has been cleared.
call :LogAction "Recycle Bin cleared"
call :PauseToContinue
goto :EOF

:: ===== DEEP CLEANUP =====
:DeepClean
cls & color %COLOR_DEEP% & call :DrawBox "DEEP CLEANUP"
echo.
echo  [+] Running DISM RestoreHealth... This may take a long time. Please wait.
echo.
Dism /Online /Cleanup-Image /RestoreHealth
set "rc=!errorlevel!"
if !rc! equ 0 (
    echo. & echo      [OK] DISM completed successfully.
    call :LogAction "DISM OK"
) else (
    echo. & echo      [ERROR] DISM finished with error code !rc!. Check logs for details.
    call :LogAction "DISM ERR !rc!"
    call :LogError "DISM failed with error code !rc!"
)
echo.
echo  [+] Running SFC /scannow... This may also take some time.
echo.
sfc /scannow
set "rc=!errorlevel!"
if !rc! equ 0 (
    echo. & echo      [OK] SFC completed successfully.
    call :LogAction "SFC OK"
) else (
    echo. & echo      [ERROR] SFC finished with error code !rc!. Check logs for details.
    call :LogAction "SFC ERR !rc!"
    call :LogError "SFC failed with error code !rc!"
)
echo.
echo  [+] Running Disk Cleanup on essential items...
:: The /autoclean switch is more reliable than /sagerun as it cleans all default locations.
cleanmgr /autoclean >nul 2>&1
call :LogAction "cleanmgr /autoclean executed"
echo      [OK] Disk Cleanup has been executed.
call :BrowserCleanup
call :PauseToContinue
goto :EOF

:: ===== BROWSER CLEANUP =====
:BrowserCleanup
echo. & call :DrawBox "BROWSER CACHE CLEANUP"
echo.
echo  [+] Closing browser processes to release file locks...
taskkill /f /im chrome.exe >nul 2>&1
taskkill /f /im msedge.exe >nul 2>&1
taskkill /f /im firefox.exe >nul 2>&1
timeout /t 2 /nobreak >nul
echo  [+] Clearing browser caches for ALL user profiles...
:: (FUNCTIONAL FIX) Removed trailing '\*' from paths.
:: We pass the *directory* to :CleanDir, not a wildcard file path.
:: :CleanDir is designed to 'pushd' into the directory and clean its contents.
:: Passing 'Cache\*' would cause 'pushd' to fail.
for /d %%d in ("%LocalAppData%\Google\Chrome\User Data\*") do (
    if /i not "%%~nxd"=="System Profile" (
        call :CleanDir "%%d\Cache" "Google Chrome Cache (%%~nxd)"
    )
)
for /d %%d in ("%LocalAppData%\Microsoft\Edge\User Data\*") do (
    if /i not "%%~nxd"=="System Profile" (
        call :CleanDir "%%d\Cache" "Microsoft Edge Cache (%%~nxd)"
    )
)
:: (FUNCTIONAL FIX) Changed to clean the parent 'cache2' folder for a more thorough cleanup.
for /d %%p in ("%LocalAppData%\Mozilla\Firefox\Profiles\*") do (
    call :CleanDir "%%p\cache2" "Mozilla Firefox Cache (%%~nxp)"
)
echo  [+] Browser cache cleanup complete.
call :LogAction "Browser caches cleaned"
goto :EOF

:: ===================================
:: ===== MENUS and SUB-FUNCTIONS =====
:: ===================================

:: ===== SYSTEM OPTIMIZATION MENU =====
:SystemOptimizeMenu
:SubSystemOptimizeMenu
cls & color %COLOR_OPTIMIZE% & call :DrawBox "SYSTEM OPTIMIZATION"
echo.
echo  [1] Check Disk Integrity (Scan only)
echo  [2] Defrag / Trim Drive
echo  [3] Rebuild System Caches (Icons, Thumbnails)
echo  [4] Optimize Power Plan
echo  [5] Optimize Visual Effects
echo  [6] Back to Main Menu
echo.
set "opt="
set /p "opt=  Please choose an option (1-6): "
if "%opt%"=="1" (cls & call :DrawBox "CHECK DISK" & echo. & chkdsk %OS_DRIVE% /scan & call :LogAction "chkdsk /scan executed" & pause)
if "%opt%"=="2" (cls & call :DrawBox "DEFRAG / TRIM" & echo. & defrag %OS_DRIVE% /O /L & call :LogAction "defrag executed" & pause)
if "%opt%"=="3" (
    cls & call :DrawBox "REBUILD CACHES" & echo.
    echo  [+] Rebuilding icon & thumbnail caches...
    taskkill /f /im explorer.exe >nul 2>&1 & timeout /t 1 /nobreak >nul
    del /a /f /q "%localappdata%\IconCache.db" >nul 2>&1
    del /a /f /q "%localappdata%\Microsoft\Windows\Explorer\thumbcache_*.db" >nul 2>&1
    start "" explorer.exe & call :LogAction "Icon/Thumbnail cache rebuilt"
    echo  [+] Restarting Windows Search Service...
    sc query "WSearch" >nul 2>&1 && (net stop "WSearch" >nul 2>&1 & net start "WSearch" >nul 2>&1 & call :LogAction "WSearch restarted" & echo      [OK] WSearch service has been restarted.) || echo      [-] WSearch service not found or couldn't be restarted.
    echo. & echo  [+] Done. & pause
)
if "%opt%"=="4" (call :SetPowerPlan)
if "%opt%"=="5" (call :SetVisualEffects)
if "%opt%"=="6" (goto :EOF)
goto SubSystemOptimizeMenu

:: ===== ADVANCED TOOLS MENU =====
:AdvancedMenu
:SubAdvancedMenu
cls & color %COLOR_ADVANCED% & call :DrawBox "ADVANCED TOOLS"
echo.
echo  [1] Clear Windows Update Cache
echo  [2] Remove Windows.old folder (Expert)
echo  [3] Manage Pagefile / Hibernation (Expert)
echo  [4] Network Reset ^& Flush DNS
echo  [5] Create System Restore Point
echo  [6] Back to Main Menu
echo.
set "adv="
set /p "adv=  Please choose an option (1-6): "
if "%adv%"=="1" (call :ClearWinUpdate & pause)
if "%adv%"=="2" (if "!EXPERT_MODE!"=="1" (call :RemoveWindowsOld & pause) else (echo. & color %COLOR_WARNING% & echo  [WARNING] This function requires Expert Mode. & color %COLOR_ADVANCED% & pause))
if "%adv%"=="3" (if "!EXPERT_MODE!"=="1" (call :PagefileMenu) else (echo. & color %COLOR_WARNING% & echo  [WARNING] This function requires Expert Mode. & color %COLOR_ADVANCED% & pause))
if "%adv%"=="4" (call :NetReset & pause)
if "%adv%"=="5" (call :CreateRestorePoint & pause)
if "%adv%"=="6" (goto :EOF)
goto SubAdvancedMenu

:: ===== ADVANCED SUB-FUNCTIONS =====

:ClearWinUpdate
cls & call :DrawBox "CLEAR WINDOWS UPDATE CACHE" & echo.
echo  [+] Stopping required services...
net stop wuauserv >nul 2>&1
net stop bits >nul 2>&1
net stop cryptsvc >nul 2>&1
echo  [+] Deleting cache folders...
if exist "%windir%\SoftwareDistribution" (rd /s /q "%windir%\SoftwareDistribution" & echo      [OK] Removed SoftwareDistribution folder. & call :LogAction "SoftwareDistribution removed")
if exist "%windir%\System32\catroot2" (rd /s /q "%windir%\System32\catroot2" & echo      [OK] Removed catroot2 folder. & call :LogAction "catroot2 removed")
echo  [+] Restarting services...
net start cryptsvc >nul 2>&1
net start bits >nul 2>&1
net start wuauserv >nul 2>&1
echo  [+] Done.
goto :EOF

:RemoveWindowsOld
cls & color %COLOR_WARNING% & call :DrawBox "REMOVE WINDOWS.OLD FOLDER" & echo.
set "WINOLD=%OS_DRIVE%\Windows.old"
if exist "%WINOLD%" (
    echo  WARNING: This action is IRREVERSIBLE and will permanently delete the
    echo  Windows.old folder. You will NOT be able to revert to the previous
    echo  version of Windows after doing this.
    echo.
    set /p "confirm=  Type 'YES' to continue: "
    if /i "%confirm%"=="YES" (
        echo.
        echo  [*] Taking ownership of the folder...
        takeown /F "%WINOLD%" /R /D Y >nul
        icacls "%WINOLD%" /grant *S-1-5-32-544:F /T >nul
        echo  [*] Deleting the folder... This may take a moment.
        rd /s /q "%WINOLD%"
        if not exist "%WINOLD%" (
            echo  [+] Done. Folder removed successfully.
            call :LogAction "Windows.old removed"
        ) else (
            color %COLOR_ERROR%
            echo  [ERROR] Failed to remove the folder. It might be in use or permissions issue.
            call :LogError "Failed to remove Windows.old folder."
        )
    ) else ( echo. & echo  Cancelled by user. )
) else ( echo  Windows.old folder not found. )
color %COLOR_ADVANCED%
goto :EOF

:PagefileMenu
:SubPagefileMenu
cls & call :DrawBox "PAGEFILE & HIBERNATION MANAGEMENT" & echo.
echo  [1] Disable Automatic Pagefile Management
echo  [2] Disable Hibernation (removes hiberfil.sys)
echo  [3] Back
echo.
set "pf="
set /p "pf=  Please choose (1-3): "
if "%pf%"=="1" (
    wmic computersystem where name="%computername%" set AutomaticManagedPagefile=False >nul
    :: Ensure PagingFiles registry entry is cleared for proper disablement
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v PagingFiles /t REG_MULTI_SZ /d "" /f >nul
    echo. & echo  [+] Automatic pagefile management disabled (reboot required). & call :LogAction "Pagefile management disabled" & pause
)
if "%pf%"=="2" (
    powercfg -h off && (echo. & echo  [+] Hibernation has been disabled. & call :LogAction "Hibernation disabled") || (echo. & echo  [-] Could not disable Hibernation. Check admin rights.)
    pause
)
if "%pf%"=="3" (goto :EOF)
goto SubPagefileMenu

:NetReset
cls & call :DrawBox "NETWORK RESET AND FLUSH DNS" & echo.
ipconfig /flushdns >nul && echo  [+] Flushed DNS cache. & call :LogAction "DNS flushed"
netsh winsock reset >nul && echo  [+] Winsock has been reset. & call :LogAction "Winsock reset"
netsh int ip reset >nul && echo  [+] TCP/IP has been reset. & call :LogAction "TCP/IP reset"
echo  [+] Done. A reboot is recommended to apply all changes.
goto :EOF

:CreateRestorePoint
cls & call :DrawBox "CREATE SYSTEM RESTORE POINT" & echo.
echo  [+] Enabling System Restore and creating a point...
powershell -Command "Enable-ComputerRestore -Drive '%OS_DRIVE%'" >nul 2>&1
:: (PERFORMANCE OPTIMIZATION) Replaced slow WMIC call with fast PowerShell call
for /f "usebackq" %%i in (`powershell -Command "Get-Date -Format 'yyyyMMddHHmm'"`) do set "RP_TIME=%%i"
if not defined RP_TIME set "RP_TIME=backup"
set "RP_DESC=ProToolkit_Backup_%RP_TIME:~0,8%_%RP_TIME:~8,6%"
powershell -Command "Checkpoint-Computer -Description '%RP_DESC%' -RestorePointType 'MODIFY_SETTINGS'"
if %errorlevel% equ 0 (
    echo      [OK] Restore point '%RP_DESC%' created successfully.
    call :LogAction "Restore point created: %RP_DESC%"
) else (
    echo      [ERROR] Failed to create restore point.
    echo      Please check your System Protection settings in Control Panel.
    call :LogAction "Restore point creation failed"
    call :LogError "Restore point creation failed. User should check System Protection."
)
goto :EOF

:: ===== OPTIMIZATION SUB-FUNCTIONS =====

:SetPowerPlan
:SubSetPowerPlan
cls & color %COLOR_OPTIMIZE% & call :DrawBox "OPTIMIZE POWER PLAN" & echo.
echo  [+] Searching for available power plans...
echo.
set "HP_GUID=" & set "UP_GUID=" & set "BAL_GUID="
:: (SYNTAX & BUG FIX) Corrected the FOR loop logic to properly parse GUID and Name.
:: The old loop was capturing "GUID" as the GUID and the real GUID as part of the name.
for /f "tokens=4,*" %%g in ('powercfg /list ^| findstr /C:"("') do (
    set "guid=%%g"
    set "line=%%h"
    :: !line! is now " (Balanced) *" or " (High performance)"
    :: Need to extract text between ( and )
    :: This inner loop removes leading spaces and then extracts the text inside the parens
    for /f "tokens=1 delims=()" %%j in ("!line!") do (
        set "name=%%j"
        :: !name! is now "Balanced" or "High performance" (without spaces)
    )
    
    echo      GUID: !guid!
    echo      Name: !name!
    echo.

    if /i "!name!"=="High performance" set "HP_GUID=!guid!"
    :: (SYNTAX FIX) Added missing '==' comparison operator
    if /i "!name!"=="Ultimate Performance" set "UP_GUID=!guid!"
    if /i "!name!"=="Balanced" set "BAL_GUID=!guid!"
)

if not defined UP_GUID (
    echo  [*] Ultimate Performance plan not found. Trying to import it...
    :: GUID for Ultimate Performance
    powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 >nul 2>&1
    if !errorlevel! equ 0 (
        echo      [OK] Successfully imported Ultimate Performance. Reopening menu to select.
        call :LogAction "Imported Ultimate Performance power plan"
        pause
        goto SubSetPowerPlan :: Re-scan plans to show new option
    ) else (
        echo      [-] Failed to import Ultimate Performance. Your Windows version may not support it.
    )
    echo.
)

echo  --------------------------------------
echo  [1] High Performance
if defined UP_GUID echo  [2] Ultimate Performance
echo  [3] Balanced (Default)
echo  [4] Back
echo.
set "pp="
set /p "pp=  Choose a plan to activate: "
if "%pp%"=="1" if defined HP_GUID (powercfg /s %HP_GUID% & echo. & echo  [+] High Performance activated. & call :LogAction "Power plan set to High Performance")
if "%pp%"=="2" if defined UP_GUID (powercfg /s %UP_GUID% & echo. & echo  [+] Ultimate Performance activated. & call :LogAction "Power plan set to Ultimate Performance")
if "%pp%"=="3" (
    :: Ensure Balanced plan is available, then activate it.
    if not defined BAL_GUID powercfg -duplicatescheme 381b4222-f694-41f0-9685-ff5bb260df2e >nul 2>&1
    powercfg /s 381b4222-f694-41f0-9685-ff5bb260df2e & echo. & echo  [+] Balanced activated. & call :LogAction "Power plan set to Balanced"
)
if "%pp%"=="4D" (goto :EOF)
pause
goto SubSetPowerPlan

:SetVisualEffects
:SubSetVisualEffects
cls & call :DrawBox "OPTIMIZE VISUAL EFFECTS" & echo.
echo  [1] Adjust for best performance (disables most animations)
echo  [2] Let Windows choose what's best (Default)
echo  [3] Back
echo.
set "ve="
set /p "ve=  Please choose an option (1-3): "
if "%ve%"=="1" (
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v "VisualFxSetting" /t REG_DWORD /d 2 /f >nul
    reg add "HKCU\Control Panel\Desktop" /v "UserPreferencesMask" /t REG_BINARY /d 9012038010000000 /f >nul
    echo. & echo  [+] Visual effects set for best performance.
    echo      A log off or reboot is required to apply changes.
    call :LogAction "Visual effects set for best performance"
    pause
)
if "%ve%"=="2" (
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v "VisualFxSetting" /t REG_DWORD /d 0 /f >nul
    :: Reset UserPreferencesMask to default
    reg add "HKCU\Control Panel\Desktop" /v "UserPreferencesMask" /t REG_BINARY /d 9012018010000000 /f >nul 2>&1
    echo. & echo  [+] Restored default visual effects settings.
    call :LogAction "Visual effects set to default"
    pause
)
if "%ve%"=="3" (goto :EOF)
goto SubSetVisualEffects

:: ===== AUTO RUN FULL MAINTENANCE =====
:AutoRun
cls & color %COLOR_DEEP% & call :DrawBox "AUTO RUN - FULL MAINTENANCE"
echo.
echo  This will automatically run the following sequence:
echo  Quick Cleanup -> Deep Cleanup -> Key Optimizations -> Clear Update Cache
echo.
color %COLOR_WARNING%
set /p "confirm=  Type 'AUTO' to start, or anything else to cancel: "
color %COLOR_DEEP%
if /i not "%confirm%"=="AUTO" (echo. & echo  Cancelled by user. & pause & goto :EOF)
echo.
call :LogAction "AutoRun started"
call :QuickClean
call :DeepClean
echo.
echo  [+] Running automated optimizations...
defrag %OS_DRIVE% /O /L >nul 2>&1
call :LogAction "AutoRun defrag executed"
taskkill /f /im explorer.exe >nul 2>&1 & timeout /t 2 >nul
del /a /f /q "%localappdata%\IconCache.db" >nul 2>&1
del /a /f /q "%localappdata%\Microsoft\Windows\Explorer\thumbcache_*.db" >nul 2>&1
start "" explorer.exe & call :LogAction "AutoRun Icon/Thumbnail cache rebuilt"
call :ClearWinUpdate
call :LogAction "AutoRun completed"
echo.
echo  [+] FULL MAINTENANCE COMPLETE.
echo.
set /p "rebootq=  A reboot is recommended. Would you like to reboot now? (Y/N): "
if /i "%rebootq%"=="Y" shutdown /r /t 10 /c "Rebooting after Pro Toolkit maintenance."
call :PauseToContinue
goto :EOF

:: ===== EXPORT REPORT =====
:ExportReport
cls & color %COLOR_FINISH% & call :DrawBox "EXPORT REPORT" & echo.

:: Ensure the temporary log file exists before proceeding
if not exist "%TMP_LOGFILE%" (
    echo  [-] No actions have been performed in this session. Nothing to export.
    pause
    goto :EOF
)

set "NOW="
:: Use powershell for a more reliable timestamp, especially for filenames
for /f "usebackq" %%i in (`powershell -Command "Get-Date -Format 'yyyyMMddHHmm'"`) do set "NOW=%%i"

if not defined NOW (
    echo  [ERROR] Could not get system timestamp to create the log file. Export cancelled.
    call :LogError "Failed to get system timestamp for log export."
    pause
    goto :EOF
)

set "EXPORT_FILENAME=Log_%NOW%.txt"
set "EXPORT_PATH=%BASE_DIR%\%EXPORT_FILENAME%"

:: Create a unique log file
set "counter=0"
:check_filename
if exist "%EXPORT_PATH%" (
    set /a counter+=1
    set "EXPORT_FILENAME=Log_%NOW%_%counter%.txt"
    set "EXPORT_PATH=%BASE_DIR%\%EXPORT_FILENAME%"
    goto check_filename
)

:: Copy the temporary log to the permanent, uniquely named file
copy "%TMP_LOGFILE%" "%EXPORT_PATH%" >nul

if exist "%EXPORT_PATH%" (
    echo  [+] Report saved successfully to:
    echo      %EXPORT_PATH%
    start "" "%BASE_DIR%"
) else (
    echo  [ERROR] Failed to write the report file. Please check permissions.
    call :LogError "Failed to write export file to %EXPORT_PATH%"
)
call :LogAction "Log exported to %EXPORT_FILENAME%"
pause
goto :EOF

:: ==========================================
:: ===== HELPER FUNCTIONS (Do not edit) =====
:: ==========================================

:CreateNewTempLog
>> "%TMP_LOGFILE%" echo.
>> "%TMP_LOGFILE%" echo --- Actions log for session started: %date% %time% ---
goto :EOF

:CleanDir
setlocal
set "DIR_PATH=%~1"
set "DESC=%~2"
if exist "%DIR_PATH%" (
    echo  [*] Cleaning %DESC%...
    pushd "%DIR_PATH%" >nul 2>&1 && (
        :: Delete files first
        del /f /s /q * >nul 2>&1
        :: Then remove subdirectories
        for /d %%D in (*) do rd /s /q "%%D" >nul 2>&1
        popd
        echo      [OK] Cleaned.
        call :LogAction "%DESC% cleaned (%DIR_PATH%)"
    ) || (
        echo      [ERROR] Could not access or clean directory. It may be in use.
        call :LogAction "Failed to access %DESC% dir (%DIR_PATH%)"
        call :LogError "Could not access or clean directory: %DESC% (%DIR_PATH%)"
    )
) else (
    echo  [-] %DESC% not found. Skipping.
)
endlocal
goto :EOF

:LogAction
>> "%TMP_LOGFILE%" echo [%time%] %~1
goto :EOF

:LogError
>> "%ERROR_LOGFILE%" echo [%date% %time%] %~1
goto :EOF

:DrawBox
setlocal
:: (PERFORMANCE OPTIMIZATION) Replaced slow 256-iteration loop with a fast, efficient loop.
:: This loop runs only N times (N=string length) instead of always 256 times.
set "text=%~1"
set "len=0"
:len_loop
if defined text (
    set "text=!text:~1!"
    set /a len+=1
    goto :len_loop
)
set "padding="
for /l %%A in (1,1,%len%) do set "padding=!padding!="
echo.
echo  +-%padding%-+
echo  ^| %~1 ^|
echo  +-%padding%-+
endlocal
goto :EOF

:PauseToContinue
echo.
color %COLOR_FINISH%
echo  =============================================================
echo   DONE! Operation finished.
echo   Press any key to return to the Main Menu...
echo  =============================================================
pause >nul
goto :EOF
