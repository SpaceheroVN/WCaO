@echo off
setlocal enabledelayedexpansion
title Windows Cleanup ^& Optimizer v4.1.1 - Pro Toolkit (Auto ^& Expert)

:: ===== CONFIG / LOG SETUP =====
set "VERSION=4.1.1"
set "TOOLNAME=Windows Cleanup & Optimizer"
set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

:: Unified timestamp
for /f "tokens=2 delims==" %%i in ('wmic os get localdatetime /value 2^>nul') do set "NOW=%%i"
set "YYYY=%NOW:~0,4%" & set "MM=%NOW:~4,2%" & set "DD=%NOW:~6,2%" & set "HH=%NOW:~8,2%" & set "MN=%NOW:~10,2%"
set "TIME_TAG=%DD%-%MM%_%HH%-%MN%"

set "BASE_LOG_DIR=%LocalAppData%\Windows_CaO\Logs"
if not exist "%BASE_LOG_DIR%" mkdir "%BASE_LOG_DIR%" >nul 2>&1
forfiles /p "%BASE_LOG_DIR%" /m "log_*.txt" /d -3 /c "cmd /c del @path" >nul 2>&1

set "ACTIONS_LOGFILE=%BASE_LOG_DIR%\Actions.log"
> "%ACTIONS_LOGFILE%" echo Actions log started: %date% %time%

set "OS_DRIVE=" & set "EXPERT_MODE=0"

:: ===== ADMIN CHECK =====
>nul 2>&1 net session || (
  cls & color 04
  echo =========================================
  echo  ERROR: Run this script AS ADMINISTRATOR
  echo =========================================
  echo. & pause & exit /b
)

:: ===== DETECT OS DRIVE =====
for /f "tokens=2 delims==" %%A in ('wmic os get systemdrive /value 2^>nul') do (
    set "OS_DRIVE=%%A"
)
if not defined OS_DRIVE set "OS_DRIVE=C:"
if "%OS_DRIVE:~-1%"==":" (
    rem valid
) else set "OS_DRIVE=%OS_DRIVE%:"

:: ===== MAIN MENU =====
:main_menu
cls & color 0E
call :DrawBox "%TOOLNAME% - v%VERSION%"
echo.
echo OS Drive detected: %OS_DRIVE%
echo.
echo [1] Quick Cleanup
echo [2] Deep Cleanup
echo [3] System Optimization
echo [4] Advanced Tools
echo [5] Auto Run Full Maintenance (Safe)
echo [6] Toggle Expert Mode (Current: %EXPERT_MODE%)
echo [7] Export Report
echo [8] Exit
echo.
set /p "choice=Choose (1-8): "
if "%choice%"=="1" call :QuickClean & goto finish
if "%choice%"=="2" call :DeepClean & goto finish
if "%choice%"=="3" call :SystemOptimize & goto finish
if "%choice%"=="4" call :AdvancedMenu & goto finish
if "%choice%"=="5" call :AutoRun & goto finish
if "%choice%"=="6" (if "%EXPERT_MODE%"=="0" (set "EXPERT_MODE=1") else (set "EXPERT_MODE=0")) & goto main_menu
if "%choice%"=="7" call :ExportReport & goto finish
if "%choice%"=="8" exit /b
goto main_menu

:: ===== QUICK CLEAN =====
:QuickClean
cls & color 06 & call :DrawBox "QUICK CLEANUP"
echo.
call :CleanDir "%temp%" "User Temp"
call :CleanDir "%SystemRoot%\Temp" "System Temp"
call :CleanDir "%SystemRoot%\Prefetch" "Prefetch"
call :CleanDir "%APPDATA%\Microsoft\Windows\Recent" "Recent Shortcuts"
echo [+] Emptying Recycle Bin...
rd /s /q "%OS_DRIVE%\$Recycle.Bin" 2>nul && (
  echo [+] Recycle Bin cleared
  call :LogAction "Recycle Bin cleared"
) || echo [-] Recycle Bin not found/skipped
goto :EOF

:: ===== DEEP CLEAN =====
:DeepClean
cls & call :DrawBox "DEEP CLEANUP"
echo [+] Running DISM RestoreHealth...
Dism /Online /Cleanup-Image /RestoreHealth >nul
set "rc=%errorlevel%"
if %rc% equ 0 (call :LogAction "DISM OK") else call :LogAction "DISM ERR %rc%"
echo [+] Running SFC /scannow...
sfc /scannow
set "rc=%errorlevel%"
if %rc% equ 0 (call :LogAction "SFC OK") else call :LogAction "SFC ERR %rc%"
echo [+] Running Disk Cleanup...
cleanmgr /sagerun:65535 >nul 2>&1
call :LogAction "cleanmgr executed"
goto :EOF

:: ===== SYSTEM OPTIMIZATION =====
:SystemOptimize
cls & call :DrawBox "SYSTEM OPTIMIZATION"
echo [+] Checking disk integrity...
chkdsk %OS_DRIVE% /scan
call :LogAction "chkdsk /scan executed"
echo [+] Running defrag/trim...
defrag %OS_DRIVE% /O /L /V >nul 2>&1
call :LogAction "defrag executed"
echo [+] Rebuilding icon & thumbnail caches...
taskkill /f /im explorer.exe >nul 2>&1
timeout /t 2 >nul
del /a /f /q "%localappdata%\IconCache.db" >nul 2>&1
del /a /f /q "%localappdata%\Microsoft\Windows\Explorer\thumbcache_*.db" >nul 2>&1
start explorer.exe
call :LogAction "Icon cache rebuilt"
echo [+] Restarting Windows Search...
sc query "WSearch" >nul 2>&1 && (
  net stop "WSearch" >nul 2>&1
  net start "WSearch" >nul 2>&1
  call :LogAction "WSearch restarted"
) || echo [-] WSearch not present
goto :EOF

:: ===== ADVANCED MENU =====
:AdvancedMenu
cls & call :DrawBox "ADVANCED TOOLS"
echo.
echo [1] Clear Windows Update Cache
echo [2] Remove Windows.old (Expert)
echo [3] Pagefile / Hibernation (Expert)
echo [4] Network Reset ^& Flush DNS
echo [5] Create System Restore Point
echo [6] Back
echo.
set /p "adv=Choose (1-6): "
if "%adv%"=="1" call :ClearWinUpdate & goto AdvancedMenu
if "%adv%"=="2" if "%EXPERT_MODE%"=="1" (call :RemoveWindowsOld) else (echo [-] Expert mode required & pause)
if "%adv%"=="3" if "%EXPERT_MODE%"=="1" (call :PagefileMenu) else (echo [-] Expert mode required & pause)
if "%adv%"=="4" call :NetReset
if "%adv%"=="5" call :CreateRestorePoint
if "%adv%"=="6" goto main_menu
goto AdvancedMenu

:: ===== CLEAR WINDOWS UPDATE CACHE =====
:ClearWinUpdate
cls & call :DrawBox "CLEAR WINDOWS UPDATE CACHE"
net stop wuauserv >nul 2>&1
net stop bits >nul 2>&1
net stop cryptsvc >nul 2>&1
if exist "%windir%\SoftwareDistribution" (
  rd /s /q "%windir%\SoftwareDistribution"
  call :LogAction "SoftwareDistribution removed"
)
if exist "%windir%\System32\catroot2" (
  rd /s /q "%windir%\System32\catroot2"
  call :LogAction "catroot2 removed"
)
net start cryptsvc >nul 2>&1
net start bits >nul 2>&1
net start wuauserv >nul 2>&1
pause
goto :EOF

:: ===== REMOVE WINDOWS.OLD =====
:RemoveWindowsOld
cls & call :DrawBox "REMOVE WINDOWS.OLD"
set "WINOLD=%OS_DRIVE%\Windows.old"
if exist "%WINOLD%" (
  echo WARNING: Permanent removal.
  set /p "confirm=Type YES to continue: "
  if /i "%confirm%"=="YES" (
    takeown /F "%WINOLD%" /R /D Y >nul
    icacls "%WINOLD%" /grant Administrators:F /T >nul
    rd /s /q "%WINOLD%"
    call :LogAction "Windows.old removed"
  ) else echo Cancelled.
) else echo No Windows.old found.
pause
goto :EOF

:: ===== PAGEFILE / HIBERNATION =====
:PagefileMenu
cls & call :DrawBox "PAGEFILE & HIBERNATION"
echo [1] Disable automatic pagefile
echo [2] Delete pagefile.sys
echo [3] Disable Hibernation
echo [4] Back
echo.
set /p "pf=Choose (1-4): "
if "%pf%"=="1" (
  wmic computersystem where name="%computername%" set AutomaticManagedPagefile=False >nul
  reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v PagingFiles /t REG_MULTI_SZ /d "" /f >nul
  call :LogAction "Pagefile disabled (reboot required)"
)
if "%pf%"=="2" (
  del /f /q "%OS_DRIVE%\pagefile.sys" >nul 2>&1 && call :LogAction "pagefile.sys deleted"
)
if "%pf%"=="3" (
  powercfg -h off && call :LogAction "Hibernation disabled"
)
if "%pf%"=="4" goto AdvancedMenu
pause
goto PagefileMenu

:: ===== NETWORK RESET & DNS FLUSH =====
:NetReset
cls & call :DrawBox "NETWORK RESET"
ipconfig /flushdns >nul && call :LogAction "DNS flushed"
netsh winsock reset >nul && call :LogAction "Winsock reset"
netsh int ip reset >nul && call :LogAction "TCP/IP reset"
netsh interface ip delete arpcache >nul && call :LogAction "ARP cache cleared"
pause
goto :EOF

:: ===== CREATE RESTORE POINT =====
:CreateRestorePoint
cls & call :DrawBox "CREATE RESTORE POINT"
powershell -Command "Try { Checkpoint-Computer -Description 'ProToolkit_Backup' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop; Write-Host 'OK' } Catch { Write-Host 'ERR' }" > "%temp%\rp_result.txt"
set /p rpresult=<"%temp%\rp_result.txt"
del "%temp%\rp_result.txt" >nul
if /i "%rpresult%"=="OK" (call :LogAction "Restore point created") else call :LogAction "Restore point failed"
pause
goto :EOF

:: ===== AUTO RUN =====
:AutoRun
cls & call :DrawBox "AUTO RUN - FULL MAINTENANCE"
echo This will run Quick -> Deep -> System Optimize -> Clear Update Cache.
set /p "confirm=Type A to start: "
if /i not "%confirm%"=="A" (echo Cancelled & pause & goto main_menu)
call :LogAction "AutoRun started"
call :QuickClean
call :DeepClean
call :SystemOptimize
call :ClearWinUpdate
call :LogAction "AutoRun completed"
set /p "rebootq=Reboot now? (Y/N): "
if /i "%rebootq%"=="Y" shutdown /r /t 5
pause
goto :EOF

:: ===== EXPORT REPORT =====
:ExportReport
cls & call :DrawBox "EXPORT REPORT"
set "EXPORT_LOG=%BASE_LOG_DIR%\log_%TIME_TAG%.txt"
if exist "%ACTIONS_LOGFILE%" (
  ren "%ACTIONS_LOGFILE%" "log_%TIME_TAG%.txt"
  echo [+] Report saved: %EXPORT_LOG%
) else echo [-] No Actions.log found.
> "%ACTIONS_LOGFILE%" echo Actions log restarted: %date% %time%
call :LogAction "Log exported: %EXPORT_LOG%"
start "" "%BASE_LOG_DIR%"
pause
goto :EOF

:: ===== CLEAN DIR HELPER =====
:CleanDir
setlocal
set "DIR=%~1"
set "DESC=%~2"
if exist "%DIR%" (
  echo [+] Cleaning %DESC%...
  attrib -s -h "%DIR%\*" /S >nul 2>&1
  for /d %%D in ("%DIR%\*") do rd /s /q "%%D" >nul 2>&1
  del /f /q "%DIR%\*.*" >nul 2>&1
  endlocal & call :LogAction "%DESC% cleaned (%DIR%)"
) else endlocal
exit /b

:: ===== LOG ACTION =====
:LogAction
>> "%ACTIONS_LOGFILE%" echo [%date% %time%] %~1
exit /b

:: ===== DRAW BOX =====
:DrawBox
setlocal enabledelayedexpansion
set "text= %~1 "
set /a len=0
for /l %%i in (0,1,255) do (
  set "c=!text:~%%i,1!"
  if "!c!"=="" goto :draw
  set /a len+=1
)
:draw
set "b=" & for /l %%i in (1,1,%len%) do set "b=!b!=="
echo. & echo +!b!+ & echo ^|!text!^| & echo +!b!+
endlocal & exit /b

:: ===== FINISH =====
:finish
color 07
echo.
echo Operation finished. Use Export Report to save log.
pause
goto main_menu
