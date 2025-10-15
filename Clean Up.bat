@echo off
setlocal enabledelayedexpansion
title Windows Cleanup & Optimizer v4.0.1 - Pro Toolkit (Auto & Expert)

:: =========================================
:: CONFIG / LOG SETUP (main comments only)
:: =========================================
set "VERSION=4.0.1"
set "TOOLNAME=Windows Cleanup & Optimizer"
set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

:: Log directory and retention (3 days)
set "BASE_LOG_DIR=%LocalAppData%\Windows_CaO"
if not exist "%BASE_LOG_DIR%" mkdir "%BASE_LOG_DIR%" >nul 2>&1
forfiles /p "%BASE_LOG_DIR%" /m "log_*.txt" /d -3 /c "cmd /c del @path" >nul 2>&1

:: Active Actions log (reset each script start)
set "ACTIONS_LOGFILE=%BASE_LOG_DIR%\Actions.log"
del "%ACTIONS_LOGFILE%" >nul 2>&1
> "%ACTIONS_LOGFILE%" echo Actions log started: %date% %time%

:: default flags
set "OS_DRIVE="
set "EXPERT_MODE=0"

:: =========================================
:: ADMIN CHECK
:: =========================================
>nul 2>&1 net session || (
  cls
  color 0C
  echo.
  echo =========================================
  echo ERROR: Run this script AS ADMINISTRATOR
  echo =========================================
  pause
  exit /b
)

:: =========================================
:: DETECT OS DRIVE
:: =========================================
for /f "tokens=2 delims==" %%A in ('wmic os get systemdrive /value 2^>nul') do set "OS_DRIVE=%%A"
set "OS_DRIVE=%OS_DRIVE::=%"
if not defined OS_DRIVE set "OS_DRIVE=C"

:: =========================================
:: MAIN MENU
:: =========================================
:main_menu
cls
color 0A
call :DrawBox "%TOOLNAME% - v%VERSION%"
echo.
echo OS Drive detected: %OS_DRIVE%:
echo.
echo [1] Quick Cleanup
echo [2] Deep Cleanup
echo [3] System Optimization
echo [4] Advanced Tools
echo [5] Auto Run Full Maintenance (Safe)
echo [6] Toggle Expert Mode (Current: %EXPERT_MODE%)
echo [7] Export Report (rotate Actions.log -> timestamped)
echo [8] Exit
echo.
set /p "choice=Choose (1-8): "
if "%choice%"=="1" call :QuickClean & goto finish
if "%choice%"=="2" call :DeepClean & goto finish
if "%choice%"=="3" call :SystemOptimize & goto finish
if "%choice%"=="4" call :AdvancedMenu & goto finish
if "%choice%"=="5" call :AutoRun & goto finish
if "%choice%"=="6" (
    if "%EXPERT_MODE%"=="0" (set "EXPERT_MODE=1") else (set "EXPERT_MODE=0")
    goto main_menu
)
if "%choice%"=="7" call :ExportReport & goto finish
if "%choice%"=="8" exit /b
goto main_menu

:: =========================================
:: QUICK CLEAN
:: =========================================
:QuickClean
cls
call :DrawBox "QUICK CLEANUP"
echo.
call :CleanDir "%temp%" "User Temp"
call :CleanDir "%SystemRoot%\Temp" "System Temp"
call :CleanDir "%SystemRoot%\Prefetch" "Prefetch"
call :CleanDir "%APPDATA%\Microsoft\Windows\Recent" "Recent Shortcuts"
echo [+] Emptying Recycle Bin...
rd /s /q "%OS_DRIVE%\$Recycle.Bin" 2>nul && (
  echo [+] Recycle Bin cleared
  call :LogAction "Recycle Bin cleared"
) || (
  echo [-] Recycle Bin not found/skipped
)
echo.
goto :EOF

:: =========================================
:: DEEP CLEAN
:: =========================================
:DeepClean
cls
call :DrawBox "DEEP CLEANUP"
echo.
echo [+] Running DISM RestoreHealth...
Dism /Online /Cleanup-Image /RestoreHealth
set "rc=%errorlevel%"
if %rc% equ 0 (call :LogAction "DISM RestoreHealth OK") else call :LogAction "DISM RestoreHealth ERR %rc%"

echo [+] Running SFC /scannow...
sfc /scannow
set "rc=%errorlevel%"
if %rc% equ 0 (call :LogAction "SFC OK") else call :LogAction "SFC ERR %rc%"

echo [+] Running Disk Cleanup (cleanmgr)...
cleanmgr /sagerun:65535 >nul 2>&1
call :LogAction "cleanmgr sagerun executed"
echo.
goto :EOF

:: =========================================
:: SYSTEM OPTIMIZE
:: =========================================
:SystemOptimize
cls
call :DrawBox "SYSTEM OPTIMIZATION"
echo.
echo [+] Running chkdsk scan...
chkdsk %OS_DRIVE%: /scan
call :LogAction "chkdsk /scan executed on %OS_DRIVE%:"

echo [+] Running defrag/trim optimization...
defrag %OS_DRIVE%: /O /L /V >nul 2>&1
call :LogAction "defrag/trim executed on %OS_DRIVE%:"

echo [+] Rebuilding icon & thumbnail caches...
taskkill /f /im explorer.exe >nul 2>&1
timeout /t 2 >nul
del /a /f /q "%localappdata%\IconCache.db" >nul 2>&1
del /a /f /q "%localappdata%\Microsoft\Windows\Explorer\thumbcache_*.db" >nul 2>&1
start explorer.exe
call :LogAction "Icon/thumbcache rebuild attempted"

echo [+] Restarting Windows Search (if present)...
sc query "WSearch" >nul 2>&1 && (
  net stop "WSearch" >nul 2>&1
  net start "WSearch" >nul 2>&1
  call :LogAction "WSearch restarted"
) || (
  echo [-] WSearch not present
)
echo.
goto :EOF

:: =========================================
:: ADVANCED TOOLS
:: =========================================
:AdvancedMenu
cls
call :DrawBox "ADVANCED TOOLS"
echo.
echo [1] Clear Windows Update Cache
echo [2] Remove Windows.old (Expert)
echo [3] Pagefile / Hibernation (Expert)
echo [4] Network Reset & Flush DNS
echo [5] Create System Restore Point
echo [6] Back
echo.
set /p "adv=Choose (1-6): "
if "%adv%"=="1" call :ClearWinUpdate & goto AdvancedMenu
if "%adv%"=="2" (
    if "%EXPERT_MODE%"=="1" (call :RemoveWindowsOld) else (echo [-] Expert mode required & pause)
    goto AdvancedMenu
)
if "%adv%"=="3" (
    if "%EXPERT_MODE%"=="1" (call :PagefileMenu) else (echo [-] Expert mode required & pause)
    goto AdvancedMenu
)
if "%adv%"=="4" call :NetReset & goto AdvancedMenu
if "%adv%"=="5" call :CreateRestorePoint & goto AdvancedMenu
if "%adv%"=="6" goto main_menu
goto AdvancedMenu

:: =========================================
:: CLEAR WINDOWS UPDATE CACHE
:: =========================================
:ClearWinUpdate
cls
call :DrawBox "CLEAR WINDOWS UPDATE CACHE"
echo.
echo Stopping update services...
net stop wuauserv >nul 2>&1
net stop bits >nul 2>&1
net stop cryptsvc >nul 2>&1

echo Deleting SoftwareDistribution...
if exist "%windir%\SoftwareDistribution" (
  rd /s /q "%windir%\SoftwareDistribution" && (
    echo [+] SoftwareDistribution removed
    call :LogAction "SoftwareDistribution removed"
  ) || (
    echo [-] Failed to remove SoftwareDistribution
    call :LogAction "SoftwareDistribution removal FAILED"
  )
) else echo [-] SoftwareDistribution not found

echo Deleting Catroot2...
if exist "%windir%\System32\catroot2" (
  rd /s /q "%windir%\System32\catroot2" && (
    echo [+] catroot2 removed
    call :LogAction "catroot2 removed"
  ) || (
    echo [-] Failed to remove catroot2
    call :LogAction "catroot2 removal FAILED"
  )
) else echo [-] catroot2 not found

echo Restarting services...
net start cryptsvc >nul 2>&1
net start bits >nul 2>&1
net start wuauserv >nul 2>&1
echo.
pause
goto :EOF

:: =========================================
:: REMOVE WINDOWS.OLD (Expert)
:: =========================================
:RemoveWindowsOld
cls
call :DrawBox "REMOVE WINDOWS.OLD (Expert)"
echo.
set "WINOLD=%OS_DRIVE%\Windows.old"
if exist "%WINOLD%" (
  echo WARNING: Permanent. This removes rollback ability.
  set /p "confirm=Type YES to permanently delete Windows.old: "
  if /i "%confirm%"=="YES" (
    takeown /F "%WINOLD%" /R /D Y >nul 2>&1
    icacls "%WINOLD%" /grant Administrators:F /T >nul 2>&1
    rd /s /q "%WINOLD%" && (
      echo [+] Windows.old removed
      call :LogAction "Windows.old removed"
    ) || (
      echo [-] Failed to remove Windows.old
      call :LogAction "Windows.old removal FAILED"
    )
  ) else echo Cancelled.
) else echo No Windows.old found.
pause
goto :EOF

:: =========================================
:: PAGEFILE / HIBERNATION (Expert)
:: =========================================
:PagefileMenu
cls
call :DrawBox "PAGEFILE & HIBERNATION (Expert)"
echo.
echo [1] Disable automatic pagefile (requires reboot)
echo [2] Attempt delete pagefile.sys (after disable + reboot)
echo [3] Disable Hibernation (remove hiberfil.sys)
echo [4] Back
echo.
set /p "pf=Choose (1-4): "
if "%pf%"=="1" (
  wmic computersystem where name="%computername%" set AutomaticManagedPagefile=False >nul 2>&1
  reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v PagingFiles /t REG_MULTI_SZ /d "" /f >nul 2>&1
  echo [+] Pagefile set to manual (reboot required)
  call :LogAction "Pagefile disabled (reboot required)"
  pause
  goto PagefileMenu
)
if "%pf%"=="2" (
  echo Attempting to delete %OS_DRIVE%\pagefile.sys ...
  del /f /q "%OS_DRIVE%\pagefile.sys" >nul 2>&1 && (
    echo [+] pagefile.sys deleted
    call :LogAction "pagefile.sys deleted"
  ) || (
    echo [-] Could not delete (in use). Disable first and reboot
    call :LogAction "pagefile.sys delete FAILED"
  )
  pause
  goto PagefileMenu
)
if "%pf%"=="3" (
  powercfg -h off
  set "rc=%errorlevel%"
  if %rc% equ 0 (
    echo [+] Hibernation disabled
    call :LogAction "Hibernation disabled"
  ) else (
    echo [-] Failed to disable hibernation
    call :LogAction "Hibernation disable FAILED %rc%"
  )
  pause
  goto PagefileMenu
)
goto PagefileMenu

:: =========================================
:: NETWORK RESET & DNS FLUSH
:: =========================================
:NetReset
cls
call :DrawBox "NETWORK RESET & DNS FLUSH"
echo.
ipconfig /flushdns >nul 2>&1 && (echo [+] DNS flushed & call :LogAction "DNS flushed") || (echo [-] DNS flush failed & call :LogAction "DNS flush FAILED")
netsh winsock reset >nul 2>&1 && (echo [+] Winsock reset (reboot required) & call :LogAction "Winsock reset") || (echo [-] Winsock reset failed & call :LogAction "Winsock reset FAILED")
netsh int ip reset >nul 2>&1 && (echo [+] TCP/IP reset (reboot recommended) & call :LogAction "TCP/IP reset") || (echo [-] TCP/IP reset failed & call :LogAction "TCP/IP reset FAILED")
netsh interface ip delete arpcache >nul 2>&1 && (echo [+] ARP cache cleared & call :LogAction "ARP cache cleared") || (echo [-] ARP clear failed & call :LogAction "ARP clear FAILED")
pause
goto :EOF

:: =========================================
:: CREATE RESTORE POINT
:: =========================================
:CreateRestorePoint
cls
call :DrawBox "CREATE SYSTEM RESTORE POINT"
echo.
powershell -Command "Try { Checkpoint-Computer -Description 'ProToolkit_Backup' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop; Write-Host 'OK' } Catch { Write-Host 'ERR' }" > "%temp%\rp_result.txt" 2>&1
set /p rpresult=<"%temp%\rp_result.txt"
del "%temp%\rp_result.txt" >nul 2>&1
if /i "%rpresult%"=="OK" (
  echo [+] Restore point created
  call :LogAction "Restore point created"
) else (
  echo [-] Could not create restore point (ensure System Protection ON)
  call :LogAction "Restore point attempt failed"
)
pause
goto :EOF

:: =========================================
:: AUTO RUN (Safe Full Maintenance)
:: =========================================
:AutoRun
cls
call :DrawBox "AUTO RUN - FULL MAINTENANCE (Safe)"
echo This will run Quick -> Deep -> System Optimize -> Clear Update Cache (safe subset).
echo Expert-only destructive steps not included unless Expert Mode enabled.
echo.
set /p "confirm=Type A to start Auto Run (or any other key to cancel): "
if /i not "%confirm%"=="A" (echo Cancelled & pause & goto main_menu)

echo [+] Starting Auto Run...
call :LogAction "AutoRun started by user"
call :QuickClean
call :DeepClean
call :SystemOptimize
call :ClearWinUpdate
echo [+] Auto Run completed.
call :LogAction "AutoRun completed"
echo.
set /p "rebootq=Reboot now? (Y/N): "
if /i "%rebootq%"=="Y" (
  echo Rebooting...
  shutdown /r /t 5
) else echo Remember to reboot later if needed.
pause
goto :EOF

:: =========================================
:: EXPORT REPORT (rotate Actions.log -> log_DD-MM_HH-MM.txt)
:: =========================================
:ExportReport
cls
call :DrawBox "EXPORT REPORT"
echo.

:: Build timestamp tag: DD-MM_HH-MM (handles single-digit hour)
set "TIME_TAG=%date:~0,2%-%date:~3,2%_%time:~0,2%-%time:~3,2%"
set "TIME_TAG=%TIME_TAG: =0%"
set "EXPORT_LOG=%BASE_LOG_DIR%\log_%TIME_TAG%.txt"

if exist "%ACTIONS_LOGFILE%" (
    ren "%ACTIONS_LOGFILE%" "log_%TIME_TAG%.txt"
    echo [+] Report saved: %EXPORT_LOG%
    echo [+] Naming format:
    echo     Example: log_15-10_09-35.txt -> means created on day 15, month 10, hour 09, minute 35
) else (
    echo [-] No Actions.log found.
)

:: Recreate new Actions.log to continue logging
> "%ACTIONS_LOGFILE%" echo Actions log restarted: %date% %time%
call :LogAction "Exported and rotated log file: %EXPORT_LOG%"

:: Open log folder for convenience
start "" "%BASE_LOG_DIR%"

pause
goto :EOF

:: =========================================
:: CLEAN DIR helper (removes files/dirs inside target)
:: =========================================
:CleanDir
setlocal
set "DIR=%~1"
set "DESC=%~2"
if exist "%DIR%" (
  echo [+] Cleaning %DESC%...
  attrib -s -h "%DIR%\*" /S >nul 2>&1
  for /d %%D in ("%DIR%\*") do rd /s /q "%%D" >nul 2>&1
  del /f /q "%DIR%\*.*" >nul 2>&1
  echo [+] %DESC% cleaned.
  endlocal & call :LogAction "%DESC% cleaned (%DIR%)"
) else (
  echo [-] %DESC% not found: %DIR%
  endlocal
)
exit /b

:: =========================================
:: LOG ACTION (append entry)
:: =========================================
:LogAction
:: Append timestamped entry to Actions.log
set "entry=%~1"
>> "%ACTIONS_LOGFILE%" echo [%date% %time%] %entry%
exit /b

:: =========================================
:: DRAW BOX (UI helper)
:: =========================================
:DrawBox
setlocal enabledelayedexpansion
set "text= %~1 "
set /a len=0
for /l %%i in (0,1,255) do (
  set "char=!text:~%%i,1!"
  if "!char!"=="" goto :drawbox2
  set /a len+=1
)
:drawbox2
set "border="
for /l %%i in (1,1,%len%) do set "border=!border!=="
echo.
echo +!border!+
echo ^|!text!^|
echo +!border!+
endlocal
exit /b

:: =========================================
:: FINISH / LOOP BACK
:: =========================================
:finish
color 07
echo.
echo Operation finished. Use Export Report to save log.
pause
goto main_menu
