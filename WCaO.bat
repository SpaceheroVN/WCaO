@echo off
setlocal enabledelayedexpansion
title Windows Cleanup ^& Optimizer v6.1.9 - Ultimate Toolkit

reg add "HKCU\Console" /v VirtualTerminalLevel /t REG_DWORD /d 1 /f >nul 2>&1
cd /d "%~dp0"

:: =====================================================================
::                            CONFIGURATION
:: =====================================================================
set "VERSION=6.1.9"
set "TOOLNAME=Windows Cleanup & Optimizer"
set "BASE_DIR=%LocalAppData%\WCaO_Toolkit"
set "LOG_RETENTION_DAYS=7"
set "DEFAULT_EXPERT_MODE=0"

for /F "tokens=1,2 delims=#" %%a in ('"prompt #$H#$E# & echo on & for %%b in (1) do rem"') do set ESC=%%b
set "cBLU=%ESC%[94m"
set "cGRE=%ESC%[92m"
set "cYEL=%ESC%[93m"
set "cRED=%ESC%[91m"
set "cCYA=%ESC%[96m"
set "cMAG=%ESC%[95m"
set "cWHI=%ESC%[97m"
set "cRES=%ESC%[0m"

:: =====================================================================
::                            INITIALIZATION
:: =====================================================================
set "EXPERT_MODE=%DEFAULT_EXPERT_MODE%"
set "TMP_LOGFILE=%BASE_DIR%\Actions.tmp"
set "ERROR_LOGFILE=%BASE_DIR%\Errors.log"
set "UNDO_LOG=%BASE_DIR%\RenameUndo.txt"

if not exist "%BASE_DIR%" mkdir "%BASE_DIR%" >nul 2>&1
if not exist "%BASE_DIR%\" (
    echo %cRED%[!] CRITICAL: Cannot create working dir.%cRES% & pause & exit /b
)

if exist "%TMP_LOGFILE%" del "%TMP_LOGFILE%" >nul 2>&1
call :CreateNewTempLog
forfiles /p "%BASE_DIR%" /m "Log_*.txt" /d -%LOG_RETENTION_DAYS% /c "cmd /c del @path" >nul 2>&1

set "IS_ADMIN=0"
>nul 2>&1 net session && set "IS_ADMIN=1"
set "OS_DRIVE=%SystemDrive%"
if not defined OS_DRIVE set "OS_DRIVE=C:"

:: =====================================================================
::                               MAIN MENU
:: =====================================================================
:main_menu
call :LogNav "Main Menu"
cls
call :DrawBox "%TOOLNAME% - v%VERSION%" "%cCYA%"

set "exp_stat=%cRES%Off" & if "!EXPERT_MODE!"=="1" set "exp_stat=%cRED%On%cRES%"
set "adm_stat=%cRED%NO (Limited)%cRES%" & if "!IS_ADMIN!"=="1" set "adm_stat=%cGRE%YES (Full)%cRES%"

echo.
echo  %cWHI%System: %cYEL%%OS_DRIVE%%cWHI%  ^|  Admin: !adm_stat!%cWHI%  ^|  Expert: !exp_stat!
echo.
echo  %cGRE%[1]%cWHI% Quick Cleanup%cRES%
echo  %cRED%[2]%cWHI% Deep Cleanup %cRED%(Admin)%cRES%
echo  %cCYA%[3]%cWHI% System Optimization%cRES%
echo  %cMAG%[4]%cWHI% Advanced Tools%cRES%
echo  %cBLU%[5]%cWHI% System Utilities%cRES% 
echo  %cYEL%[6]%cWHI% Screen ^& Power Tools%cRES%
echo  %cGRE%[7]%cWHI% Quick Rename Pro%cRES%
echo  %cRED%[8]%cWHI% Auto Maintenance %cRED%(Admin)%cRES%
echo  --------------------------------------
echo  %cYEL%[9]%cWHI% Toolkit Options %cMAG%(Expert / Logs)%cRES%
echo  %cWHI%[0] Exit Toolkit%cRES%
echo.
set "choice="
set /p "choice= %cCYA%Choose an option (0-9): %cRES%"
call :LogInput "Main Menu Choice" "!choice!"

if "!choice!"=="1" call :QuickClean & goto main_menu
if "!choice!"=="2" call :DeepClean & goto main_menu
if "!choice!"=="3" goto SystemOptimizeMenu
if "!choice!"=="4" goto AdvancedMenu
if "!choice!"=="5" goto SystemUtilitiesMenu
if "!choice!"=="6" goto ScreenToolsMenu
if "!choice!"=="7" goto QuickRename
if "!choice!"=="8" call :AutoRun & goto main_menu
if "!choice!"=="9" call :Options & goto main_menu
if "!choice!"=="0" (
    call :SummarizeLog
    if exist "%TMP_LOGFILE%" del "%TMP_LOGFILE%" >nul 2>&1 
    exit
)
goto main_menu

:: =====================================================================
::                           1. QUICK CLEANUP
:: =====================================================================
:QuickClean
call :LogNav "Quick Cleanup"
cls & call :DrawBox "QUICK CLEANUP" "%cGRE%" & echo.
call :CleanDir "%temp%" "User Temp folder"
call :CleanDir "%APPDATA%\Microsoft\Windows\Recent" "Recent shortcuts"

if "!IS_ADMIN!"=="1" (
    call :CleanDir "%SystemRoot%\Temp" "System Temp folder"
    call :CleanDir "%SystemRoot%\Prefetch" "Prefetch folder"
    echo  %cBLU%[+] Flushing DNS Cache...%cRES%
    call :RunAndLog ipconfig /flushdns
)

echo  %cBLU%[+] Emptying Recycle Bin...%cRES%
call :RunAndLog powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Clear-RecycleBin -Force -ErrorAction SilentlyContinue"
echo      %cGRE%[OK] Recycle Bin cleared.%cRES%
call :PauseToContinue
goto :EOF

:: =====================================================================
::                           2. DEEP CLEANUP
:: =====================================================================
:DeepClean
call :CheckAdmin || goto :EOF
call :LogNav "Deep Cleanup"
cls & call :DrawBox "DEEP CLEANUP" "%cRED%" & echo.

echo  %cBLU%[+] Running DISM RestoreHealth... (Please wait)%cRES%
call :RunAndLog Dism /Online /Cleanup-Image /RestoreHealth
set "rc=!errorlevel!"
if !rc! equ 0 (echo      %cGRE%[OK] DISM successful.%cRES%) else (echo      %cRED%[ERROR] DISM Code !rc!%cRES%)

echo. & echo  %cBLU%[+] Running SFC /scannow...%cRES%
call :RunAndLog sfc /scannow
set "rc=!errorlevel!"
if !rc! equ 0 (echo      %cGRE%[OK] SFC successful.%cRES%) else (echo      %cRED%[ERROR] SFC Code !rc!%cRES%)

echo. & echo  %cBLU%[+] Running Disk Cleanup...%cRES%
call :RunAndLog cleanmgr /autoclean
echo      %cGRE%[OK] Disk Cleanup executed.%cRES%
call :PauseToContinue
goto :EOF

:: =====================================================================
::                       3. SYSTEM OPTIMIZATION
:: =====================================================================
:SystemOptimizeMenu
call :LogNav "System Optimization Menu"
cls & call :DrawBox "SYSTEM OPTIMIZATION" "%cCYA%" & echo.
echo  %cYEL%[1]%cWHI% Check Disk Integrity %cRED%(Admin)%cRES%
echo  %cYEL%[2]%cWHI% Defrag / Trim Drive %cRED%(Admin)%cRES%
echo  %cYEL%[3]%cWHI% Rebuild System Caches%cRES%
echo  %cYEL%[4]%cWHI% Optimize Power Plan %cRED%(Admin)%cRES%
echo  %cYEL%[5]%cWHI% Optimize Visual Effects%cRES%
echo  %cYEL%[6]%cWHI% Windows 11 Classic Context Menu %cGRE%(Toggle)%cRES%
echo  %cYEL%[7]%cWHI% Edge Rounded Corners Fix %cGRE%(Toggle)%cRES%
echo  %cYEL%[0]%cWHI% Back to Main Menu%cRES%
echo.
set "opt="
set /p "opt= %cCYA%Choose option: %cRES%"
call :LogInput "System Opt Choice" "!opt!"

if "!opt!"=="" goto SystemOptimizeMenu
if "!opt!"=="1" call :CheckDisk
if "!opt!"=="2" call :DefragDrive
if "!opt!"=="3" call :RebuildCaches
if "!opt!"=="4" (call :CheckAdmin && call :SetPowerPlan)
if "!opt!"=="5" call :SetVisualEffects
if "!opt!"=="6" goto ToggleContextMenu
if "!opt!"=="7" goto EdgeRoundedMenu
if "!opt!"=="0" goto main_menu
goto SystemOptimizeMenu

:: 3.1 Check Disk Integrity
:CheckDisk
call :CheckAdmin || goto :EOF
cls & echo %cCYA%[+] Running Check Disk...%cRES%
call :RunAndLog chkdsk %OS_DRIVE% /scan
echo %cGRE%[+] Done.%cRES%
call :PauseToContinue
goto :EOF

:: 3.2 Defrag / Trim Drive
:DefragDrive
call :CheckAdmin || goto :EOF
cls & echo %cCYA%[+] Running Defrag/Trim...%cRES%
call :RunAndLog defrag %OS_DRIVE% /O /L
echo %cGRE%[+] Done.%cRES%
call :PauseToContinue
goto :EOF

:: 3.3 Rebuild System Caches
:RebuildCaches
cls & echo %cCYA%[+] Rebuilding icon ^& thumbnail caches...%cRES%
    call :RunAndLog taskkill /f /im explorer.exe
    timeout /t 2 /nobreak >nul
    call :RunAndLog del /a /f /q "%localappdata%\IconCache.db"
    call :RunAndLog del /a /f /q "%localappdata%\Microsoft\Windows\Explorer\thumbcache_*.db"
    tasklist /FI "IMAGENAME eq explorer.exe" 2>nul | find /I "explorer.exe" >nul || start explorer.exe
if "!IS_ADMIN!"=="1" (sc query "WSearch" >nul 2>&1 && (call :RunAndLog net stop "WSearch" & call :RunAndLog net start "WSearch"))
echo  %cGRE%[+] Done.%cRES%
call :PauseToContinue
goto :EOF

:: 3.4 Optimize Power Plan
:SetPowerPlan
cls & call :DrawBox "OPTIMIZE POWER PLAN" "%cCYA%" & echo.
powercfg /list & echo -----------------------------------
echo  %cYEL%[1]%cWHI% Add Ultimate Plan   %cYEL%[2]%cWHI% Remove Plan   %cYEL%[3]%cWHI% Set Active Plan%cRES%
echo  %cYEL%[4]%cWHI% Restore Default     %cYEL%[0]%cWHI% Back to Optimization Menu%cRES%
echo.
set "pp=" & set /p "pp= Choose: "
if "!pp!"=="" goto SetPowerPlan
if "!pp!"=="1" (call :RunAndLog powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 & echo %cGRE%[+] Plan Added.%cRES% & call :PauseToContinue)
if "!pp!"=="2" (set "del_guid=" & set /p "del_guid= Enter GUID to remove: " & call :RunAndLog powercfg /delete !del_guid! & call :PauseToContinue)
if "!pp!"=="3" (set "set_guid=" & set /p "set_guid= Enter GUID to set: " & call :RunAndLog powercfg /s !set_guid! & call :PauseToContinue)
if "!pp!"=="4" (call :RunAndLog powercfg /restoredefaultschemes & echo %cGRE%[+] Restored.%cRES% & call :PauseToContinue)
if "!pp!"=="0" goto :EOF
goto SetPowerPlan

:: 3.5 Optimize Visual Effects
:SetVisualEffects
cls & call :DrawBox "VISUAL EFFECTS" "%cCYA%" & echo.
echo  %cYEL%[1]%cWHI% Best Performance  %cYEL%[2]%cWHI% Custom (Peek+Smooth Fonts)  %cYEL%[3]%cWHI% Default  %cYEL%[0]%cWHI% Back%cRES%
echo.
set "ve=" & set /p "ve= Choose: "
if "!ve!"=="1" (call :RunAndLog reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v "VisualFxSetting" /t REG_DWORD /d 2 /f & echo %cGRE%[+] Applied.%cRES% & call :PauseToContinue)
if "!ve!"=="2" (call :RunAndLog reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v "VisualFxSetting" /t REG_DWORD /d 3 /f & echo %cGRE%[+] Applied.%cRES% & call :PauseToContinue)
if "!ve!"=="3" (call :RunAndLog reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v "VisualFxSetting" /t REG_DWORD /d 0 /f & echo %cGRE%[+] Restored.%cRES% & call :PauseToContinue)
if "!ve!"=="0" goto :EOF
goto SetVisualEffects

:: 3.6 Windows 11 Classic Context Menu
:ToggleContextMenu
cls & call :DrawBox "WIN 11 CONTEXT MENU" "%cCYA%" & echo.
echo  %cYEL%[1]%cWHI% Enable Classic Menu %cGRE%(Win 10 Style)%cRES%
echo  %cYEL%[2]%cWHI% Restore Default Menu %cCYA%(Win 11 Style)%cRES%
echo  %cYEL%[0]%cWHI% Back%cRES%
echo.
set "cm=" & set /p "cm= Choose: "
if "!cm!"=="1" goto EnableClassicMenu
if "!cm!"=="2" goto RestoreDefaultMenu
if "!cm!"=="0" goto SystemOptimizeMenu
goto ToggleContextMenu

:EnableClassicMenu
call :RunAndLog reg add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /f /ve
echo %cGRE%[+] Classic Menu Enabled.%cRES%
goto AskRestartExplorer

:RestoreDefaultMenu
call :RunAndLog reg delete "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" /f
echo %cGRE%[+] Default Menu Restored.%cRES%
goto AskRestartExplorer

:AskRestartExplorer
echo.
set "res_exp="
set /p "res_exp= %cYEL%Restart Windows Explorer to apply immediately? (Y/N): %cRES%"
if /i "!res_exp!"=="Y" (
    echo %cBLU%[+] Restarting Explorer...%cRES%
    call :RunAndLog taskkill /f /im explorer.exe
    timeout /t 2 /nobreak >nul
    tasklist /FI "IMAGENAME eq explorer.exe" 2>nul | find /I "explorer.exe" >nul || start explorer.exe
    echo %cGRE%[+] Done.%cRES%
) else (
    echo %cGRE%[+] Done.%cRES%
)
call :PauseToContinue
goto ToggleContextMenu

:: 3.7 Edge Rounded Corners Fix
:EdgeRoundedMenu
cls & call :DrawBox "EDGE ROUNDED CORNERS FIX" "%cCYA%" & echo.
echo  %cWHI%Patches all Edge shortcuts to disable the forced rounded corners%cRES%
echo  %cWHI%introduced in Edge v149+.%cRES%
echo.

set "edge_patched=0"
powershell -NoProfile -Command "$paths=@(\"$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk\", \"$env:Public\Desktop\Microsoft Edge.lnk\", \"$([Environment]::GetFolderPath('Desktop'))\Microsoft Edge.lnk\", \"$env:AppData\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Microsoft Edge.lnk\"); $patched=0; $sh=New-Object -Com WScript.Shell; foreach($p in $paths){ if(Test-Path $p){ $s=$sh.CreateShortcut($p); if($s.Arguments -match 'msFeatureGroupNewLookAndFeelHoldout'){ $patched=1; break } } }; if($patched){exit 0}else{exit 1}" >nul 2>&1
if !errorlevel! equ 0 set "edge_patched=1"

set "patch_stat=%cRED%Not Applied%cRES%"
if "!edge_patched!"=="1" set "patch_stat=%cGRE%Applied%cRES%"

echo  %cWHI%Current Status: !patch_stat!
echo.
echo  %cYEL%[1]%cWHI% Apply Fix   %cGRE%(Disable rounded corners)%cRES%
echo  %cYEL%[2]%cWHI% Remove Fix  %cYEL%(Restore Edge default shortcuts)%cRES%
echo  %cYEL%[0]%cWHI% Back%cRES%
echo.
set "er_opt="
set /p "er_opt= %cCYA%Choose option: %cRES%"
call :LogInput "Edge Rounded Choice" "!er_opt!"

if "!er_opt!"=="1" goto ApplyEdgeFix
if "!er_opt!"=="2" goto RemoveEdgeFix
if "!er_opt!"=="0" goto SystemOptimizeMenu
goto EdgeRoundedMenu

:ApplyEdgeFix
cls & echo  %cBLU%[+] Applying Edge rounded corners fix...%cRES%
set "PS_SCRIPT=%TEMP%\edge_fix.ps1"
(
echo $x86=[System.Environment]::GetEnvironmentVariable('ProgramFiles(x86^)'^)
echo $cands=@(($x86+'\Microsoft\Edge\Application\msedge.exe'^),($env:ProgramFiles+'\Microsoft\Edge\Application\msedge.exe'^),($env:LocalAppData+'\Microsoft\Edge\Application\msedge.exe'^)^)
echo $ep=$null
echo foreach($c in $cands^){if(Test-Path $c^){$ep=$c;break}}
echo if(-not $ep^){Write-Host '  [-] Edge not found.' -F Red;exit 1}
echo Write-Host ('  [i] Edge: '+$ep^) -F Cyan
echo $opts='--disable-features=msShowSignInIndicator,msFeatureGroupNewLookAndFeelHoldout'
echo $sh=New-Object -ComObject WScript.Shell
echo $dirs=@(
echo "$env:Public\Desktop",
echo [Environment]::GetFolderPath('Desktop'^),
echo "$env:ProgramData\Microsoft\Windows\Start Menu\Programs",
echo "$env:AppData\Microsoft\Windows\Start Menu\Programs",
echo "$env:AppData\Microsoft\Internet Explorer\Quick Launch",
echo "$env:AppData\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
echo ^)
echo $found=0
echo foreach($d in $dirs^){
echo   if(-not(Test-Path $d^)^){continue}
echo   Get-ChildItem -Path $d -Filter '*Edge*.lnk' -EA SilentlyContinue ^| ForEach-Object {
echo     $f = $_.FullName
echo     try{
echo       $s=$sh.CreateShortcut($f^); $s.TargetPath=$ep; $s.Arguments=$opts; $s.WorkingDirectory=Split-Path $ep -Parent; $s.IconLocation=$ep+',0'; $s.Save(^)
echo       Write-Host('  [OK] Patched: '+$f^) -F Green; $found++
echo     }catch{ Write-Host('  [-] Failed: '+$f^) -F Red }
echo   }
echo }
echo if($found -eq 0^){
echo   Write-Host '  [*] No shortcuts found. Creating on Desktop...' -F Yellow
echo   $lnk=$sh.CreateShortcut([Environment]::GetFolderPath('Desktop'^)+'\Microsoft Edge.lnk'^)
echo   $lnk.TargetPath=$ep; $lnk.Arguments=$opts; $lnk.WorkingDirectory=Split-Path $ep -Parent; $lnk.IconLocation=$ep+',0'; $lnk.Save(^)
echo   Write-Host '  [OK] Shortcut created on Desktop.' -F Green; $found++
echo }
echo Write-Host ('  [+] Total patched: '+$found^) -F Cyan
) > "!PS_SCRIPT!"
call :RunAndLog powershell -NoProfile -ExecutionPolicy Bypass -File "!PS_SCRIPT!"
del "!PS_SCRIPT!" >nul 2>&1
call :RestartEdge
echo.
echo  %cGRE%[+] Done!%cRES%
call :PauseToContinue & goto EdgeRoundedMenu

:RemoveEdgeFix
cls & echo  %cBLU%[+] Restoring Edge shortcuts to default...%cRES%
set "PS_SCRIPT=%TEMP%\edge_unfix.ps1"
(
echo $x86=[System.Environment]::GetEnvironmentVariable('ProgramFiles(x86^)'^)
echo $cands=@(($x86+'\Microsoft\Edge\Application\msedge.exe'^),($env:ProgramFiles+'\Microsoft\Edge\Application\msedge.exe'^),($env:LocalAppData+'\Microsoft\Edge\Application\msedge.exe'^)^)
echo $ep=$null
echo foreach($c in $cands^){if(Test-Path $c^){$ep=$c;break}}
echo if(-not $ep^){Write-Host '  [-] Edge not found.' -F Red;exit 1}
echo Write-Host ('  [i] Edge: '+$ep^) -F Cyan
echo $sh=New-Object -ComObject WScript.Shell
echo $dirs=@(
echo "$env:Public\Desktop",
echo [Environment]::GetFolderPath('Desktop'^),
echo "$env:ProgramData\Microsoft\Windows\Start Menu\Programs",
echo "$env:AppData\Microsoft\Windows\Start Menu\Programs",
echo "$env:AppData\Microsoft\Internet Explorer\Quick Launch",
echo "$env:AppData\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
echo ^)
echo foreach($d in $dirs^){
echo   if(-not(Test-Path $d^)^){continue}
echo   Get-ChildItem -Path $d -Filter '*Edge*.lnk' -EA SilentlyContinue ^| ForEach-Object {
echo     $f = $_.FullName
echo     try{
echo       $s=$sh.CreateShortcut($f^); $s.TargetPath=$ep; $s.Arguments=''; $s.WorkingDirectory=Split-Path $ep -Parent; $s.IconLocation=$ep+',0'; $s.Save(^)
echo       Write-Host('  [OK] Restored: '+$f^) -F Green
echo     }catch{ Write-Host('  [-] Failed: '+$f^) -F Red }
echo   }
echo }
echo # Update icon cache without restarting explorer
echo ie4uinit.exe -show
echo Write-Host '  [OK] Shortcut cache cleared.' -F Green
) > "!PS_SCRIPT!"
call :RunAndLog powershell -NoProfile -ExecutionPolicy Bypass -File "!PS_SCRIPT!"
del "!PS_SCRIPT!" >nul 2>&1
call :RestartEdge
echo.
echo  %cGRE%[+] Done!%cRES%
call :PauseToContinue & goto EdgeRoundedMenu

:RestartEdge
set "edge_was_running=0"
tasklist /FI "IMAGENAME eq msedge.exe" 2>nul | find /I "msedge.exe" >nul && set "edge_was_running=1"
if "!edge_was_running!"=="0" goto :EOF
echo.
echo  %cYEL%[i] Edge is running. Closing and reopening via shortcut...%cRES%
echo  %cWHI%    (Your tabs will be restored automatically)%cRES%
set "PS_SCRIPT=%TEMP%\edge_restart.ps1"
(
echo Get-Process msedge -EA SilentlyContinue ^| ForEach-Object { [void]$_.CloseMainWindow(^) }
echo $deadline=[DateTime]::Now.AddSeconds(4^)
echo while((Get-Process msedge -EA SilentlyContinue^) -and [DateTime]::Now -lt $deadline^){ Start-Sleep -Milliseconds 300 }
echo Stop-Process -Name msedge -Force -ErrorAction SilentlyContinue
echo $deadline=[DateTime]::Now.AddSeconds(10^)
echo while((Get-Process msedge -EA SilentlyContinue^) -and [DateTime]::Now -lt $deadline^){ Start-Sleep -Milliseconds 300 }
echo Start-Sleep -Milliseconds 500
echo $desk=[Environment]::GetFolderPath('Desktop'^)
echo $paths=@(
echo   "$env:AppData\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Microsoft Edge.lnk",
echo   "$desk\Microsoft Edge.lnk",
echo   "$env:Public\Desktop\Microsoft Edge.lnk",
echo   "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk"
echo ^)
echo $edgeLnk=$null
echo foreach($p in $paths^){if(Test-Path $p^){$edgeLnk=$p;break}}
echo if ($edgeLnk^) {
echo     $sh=New-Object -ComObject WScript.Shell
echo     $s=$sh.CreateShortcut($edgeLnk^)
echo     Start-Process $s.TargetPath -ArgumentList ($s.Arguments + ' --restore-last-session'^)
echo } else {
echo     $x86=[System.Environment]::GetEnvironmentVariable('ProgramFiles(x86^)'^)
echo     $cands=@(($x86+'\Microsoft\Edge\Application\msedge.exe'^),($env:ProgramFiles+'\Microsoft\Edge\Application\msedge.exe'^)^)
echo     foreach($c in $cands^){if(Test-Path $c^){Start-Process $c -ArgumentList '--restore-last-session';break}}
echo }
) > "!PS_SCRIPT!"
call :RunAndLog powershell -NoProfile -ExecutionPolicy Bypass -File "!PS_SCRIPT!"
del "!PS_SCRIPT!" >nul 2>&1
goto :EOF

:: =====================================================================
::                          4. ADVANCED TOOLS
:: =====================================================================
:AdvancedMenu
call :LogNav "Advanced Tools Menu"
cls & call :DrawBox "ADVANCED TOOLS" "%cMAG%" & echo.
echo  %cYEL%[1]%cWHI% Clear Update Cache %cRED%(Admin)%cRES%
echo  %cYEL%[2]%cWHI% Uninstall Office Key %cRED%(Admin)%cRES%
echo  %cYEL%[3]%cWHI% Remove Windows.old %cRED%(Admin+Expert)%cRES%
echo  %cYEL%[4]%cWHI% Manage Pagefile/Hibernation %cRED%(Admin+Expert)%cRES%
echo  %cYEL%[5]%cWHI% Network Reset ^& Flush DNS %cRED%(Admin)%cRES%
echo  %cYEL%[6]%cWHI% Create Restore Point %cRED%(Admin)%cRES%
echo  %cYEL%[7]%cWHI% Wipe Free Space %cMAG%(Anti-Recovery)%cRES% %cRED%(Admin+Expert)%cRES%
echo  %cYEL%[0]%cWHI% Back to Main Menu%cRES%
echo.
set "adv="
set /p "adv= %cMAG%Choose option: %cRES%"

if "!adv!"=="" goto AdvancedMenu
if "!adv!"=="1" (call :CheckAdmin && call :ClearWinUpdate)
if "!adv!"=="2" (call :CheckAdmin && call :UninstallOfficeKey)
if "!adv!"=="3" (call :CheckAdmin && if "!EXPERT_MODE!"=="1" (call :RemoveWindowsOld) else (echo %cRED%[-] Expert Mode required.%cRES% & call :PauseToContinue))
if "!adv!"=="4" (call :CheckAdmin && if "!EXPERT_MODE!"=="1" (call :PagefileMenu) else (echo %cRED%[-] Expert Mode required.%cRES% & call :PauseToContinue))
if "!adv!"=="5" (call :CheckAdmin && call :NetReset)
if "!adv!"=="6" (call :CheckAdmin && call :CreateRestorePoint)
if "!adv!"=="7" (call :CheckAdmin && if "!EXPERT_MODE!"=="1" (call :WipeFreeSpace) else (echo %cRED%[-] Expert Mode required.%cRES% & call :PauseToContinue))
if "!adv!"=="0" goto main_menu
goto AdvancedMenu

:: 4.1 Clear Update Cache
:ClearWinUpdate
cls & echo %cBLU%[+] Stopping services...%cRES%
call :RunAndLog sc stop wuauserv
call :RunAndLog sc stop bits
call :RunAndLog sc stop cryptsvc
if exist "%windir%\SoftwareDistribution" call :RunAndLog rd /s /q "%windir%\SoftwareDistribution"
if exist "%windir%\System32\catroot2" call :RunAndLog rd /s /q "%windir%\System32\catroot2"
echo %cBLU%[+] Restarting services...%cRES%
call :RunAndLog net start cryptsvc
call :RunAndLog net start bits
call :RunAndLog net start wuauserv
echo %cGRE%[+] Update Cache Cleared.%cRES% & call :PauseToContinue & goto :EOF

:: 4.2 Uninstall Office Key
:UninstallOfficeKey
cls & if exist "C:\Program Files\Microsoft Office\Office16\ospp.vbs" (cd /d "C:\Program Files\Microsoft Office\Office16") else (if exist "C:\Program Files (x86)\Microsoft Office\Office16\ospp.vbs" (cd /d "C:\Program Files (x86)\Microsoft Office\Office16") else (echo %cRED%[-] Office 2016 ospp.vbs not found.%cRES% & call :PauseToContinue & cd /d "%~dp0" & goto :EOF))
call :RunAndLog cscript ospp.vbs /dstatus
call :PauseToContinue & cd /d "%~dp0" & goto :EOF

:: 4.3 Remove Windows.old
:RemoveWindowsOld
cls & set "WINOLD=%OS_DRIVE%\Windows.old"
if exist "%WINOLD%" (
    echo %cYEL%WARNING: Irreversible deletion of Windows.old.%cRES% 
    set "confirm=" & set /p "confirm=Type 'YES' to proceed: "
    if /i "!confirm!"=="YES" (
        call :RunAndLog takeown /F "%WINOLD%" /R /D Y
        call :RunAndLog icacls "%WINOLD%" /grant *S-1-5-32-544:F /T
        call :RunAndLog rd /s /q "%WINOLD%" & echo %cGRE%[+] Done.%cRES%
    )
) else (echo %cYEL%[-] Windows.old not found.%cRES%)
call :PauseToContinue & goto :EOF

:: 4.4 Manage Pagefile/Hibernation
:PagefileMenu
cls & call :DrawBox "PAGEFILE & HIBERNATION" "%cMAG%" & echo.
echo  %cYEL%[1]%cWHI% Disable Auto Pagefile  %cYEL%[2]%cWHI% Disable Hibernation  %cYEL%[0]%cWHI% Back%cRES%
echo.
set "pf=" & set /p "pf=Choose: "
if "!pf!"=="1" (call :RunAndLog wmic computersystem where name="%computername%" set AutomaticManagedPagefile=False & echo %cGRE%[+] Disabled. Reboot needed.%cRES% & call :PauseToContinue)
if "!pf!"=="2" (call :RunAndLog powercfg -h off & echo %cGRE%[+] Hibernation disabled.%cRES% & call :PauseToContinue)
if "!pf!"=="0" goto :EOF
goto PagefileMenu

:: 4.5 Network Reset & Flush DNS
:NetReset
cls & echo %cBLU%[+] Resetting Network...%cRES%
call :RunAndLog ipconfig /flushdns
call :RunAndLog netsh winsock reset
call :RunAndLog netsh int ip reset
echo %cGRE%[+] Complete. Reboot recommended.%cRES% & call :PauseToContinue & goto :EOF

:: 4.6 Create Restore Point
:CreateRestorePoint
cls & echo %cBLU%[+] Creating Restore Point...%cRES%
call :RunAndLog powershell -NoProfile -ExecutionPolicy Bypass -Command "Enable-ComputerRestore -Drive '%OS_DRIVE%'"
call :RunAndLog powershell -NoProfile -ExecutionPolicy Bypass -Command "Checkpoint-Computer -Description 'ProToolkit_Backup' -RestorePointType 'MODIFY_SETTINGS'"
if %errorlevel% equ 0 (echo %cGRE%[OK] Created.%cRES%) else (echo %cRED%[ERROR] Failed.%cRES%)
call :PauseToContinue & goto :EOF

:: 4.7 Wipe Free Space (Anti-Recovery)
:WipeFreeSpace
cls & call :DrawBox "WIPE FREE SPACE (SECURITY WIPE)" "%cRED%" & echo.
echo  %cRED%[!] WARNING: This will permanently overwrite all free space on %OS_DRIVE%.%cRES%
echo  %cYEL% - It prevents recovery of deleted files.%cRES%
echo  %cYEL% - It takes a VERY LONG TIME (hours).%cRES%
echo  %cYEL% - It causes severe wear and tear on SSDs. DO NOT use on SSDs frequently.%cRES%
echo.
set "confirm_wipe=" & set /p "confirm_wipe=Type 'WIPE' to proceed or anything else to cancel: "
if /i "!confirm_wipe!"=="WIPE" (
    echo.
    echo  %cBLU%[+] Starting free space wipe on %OS_DRIVE%\... DO NOT CLOSE THIS WINDOW.%cRES%
    call :RunAndLog cipher /w:%OS_DRIVE%\
    echo  %cGRE%[+] Wipe complete.%cRES%
) else (
    echo  %cYEL%[-] Operation cancelled.%cRES%
)
call :PauseToContinue & goto :EOF

:: =====================================================================
::                         5. SYSTEM UTILITIES
:: =====================================================================
:SystemUtilitiesMenu
call :LogNav "System Utilities Menu"
cls & call :DrawBox "SYSTEM UTILITIES" "%cBLU%" & echo.
echo  %cYEL%[1]%cWHI% Show Advanced System Info%cRES%
echo  %cYEL%[2]%cWHI% Restart Windows Explorer %cGRE%(Fix UI Glitches)%cRES%
echo  %cYEL%[3]%cWHI% Kill 'Not Responding' Tasks%cRES%
echo  %cYEL%[4]%cWHI% Winget Power Tools %cGRE%(Update, Install, Fix)%cRES%
echo  %cYEL%[5]%cWHI% Check Windows License Key ^& Status%cRES%
echo  %cYEL%[6]%cWHI% Generate Battery Health Report%cRES%
echo  %cYEL%[7]%cWHI% Show Current Wi-Fi Password%cRES%
echo  %cYEL%[0]%cWHI% Back to Main Menu%cRES%
echo.
set "util="
set /p "util= %cBLU%Choose option: %cRES%"

if "!util!"=="" goto SystemUtilitiesMenu
if "!util!"=="1" goto ShowAdvancedSysInfo
if "!util!"=="2" goto RestartExplorer
if "!util!"=="3" goto KillNotRespondingTasks
if "!util!"=="4" goto WingetMenu
if "!util!"=="5" goto CheckWinKey
if "!util!"=="6" goto CheckBattery
if "!util!"=="7" goto ShowWifiPass
if "!util!"=="0" goto main_menu
goto SystemUtilitiesMenu

:: 5.1 Show Advanced System Info
:ShowAdvancedSysInfo
cls & call :DrawBox "ADVANCED SYSTEM INFO" "%cBLU%" & echo.
echo  %cCYA%[+] Fetching detailed hardware information... (Please wait)%cRES%
echo.
call :RunAndLog powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$c='Cyan'; $w='White'; " ^
    "Write-Host ' [SYSTEM AND OS]' -F $c; " ^
    "$os=Get-CimInstance Win32_OperatingSystem; $cs=Get-CimInstance Win32_ComputerSystem; $bios=Get-CimInstance Win32_BIOS; " ^
    "Write-Host ('   OS Name      : '+$os.Caption) -F $w; " ^
    "Write-Host ('   OS Version   : '+$os.Version+' ('+$os.OSArchitecture+')') -F $w; " ^
    "Write-Host ('   System Name  : '+$cs.Name) -F $w; " ^
    "Write-Host ('   BIOS Version : '+$bios.Name) -F $w; Write-Host ''; " ^
    "Write-Host ' [PROCESSOR AND BOARD]' -F $c; " ^
    "$cpu=Get-CimInstance Win32_Processor; " ^
    "Write-Host ('   CPU          : '+$cpu.Name.Trim()) -F $w; " ^
    "Write-Host ('   Cores/Threads: '+$cpu.NumberOfCores+' Cores, '+$cpu.NumberOfLogicalProcessors+' Threads') -F $w; " ^
    "$mb=Get-CimInstance Win32_BaseBoard; Write-Host ('   Motherboard  : '+$mb.Manufacturer+' '+$mb.Product) -F $w; Write-Host ''; " ^
    "Write-Host ' [MEMORY AND GRAPHICS]' -F $c; " ^
    "$rT=[math]::Round((Get-CimInstance Win32_PhysicalMemory | Measure-Object Capacity -Sum).Sum/1GB, 2); " ^
    "$rA=[math]::Round($os.FreePhysicalMemory/1048576, 2); " ^
    "Write-Host ('   RAM Total    : '+$rT+' GB') -F $w; " ^
    "Write-Host ('   RAM Available: '+$rA+' GB') -F $w; " ^
    "foreach($g in @(Get-CimInstance Win32_VideoController)){Write-Host ('   GPU          : '+$g.Caption) -F $w}; Write-Host ''; " ^
    "Write-Host ' [HARDWARE ID]' -F $c; " ^
    "$pnpGPU = Get-PnpDevice -PresentOnly | Where-Object Class -eq 'Display'; " ^
    "foreach($g in $pnpGPU) { " ^
        "Write-Host ('   GPU ID       : ' + $g.InstanceId) -F $w; " ^
    "}; " ^
    "$pnpCPU = Get-PnpDevice -PresentOnly | Where-Object Class -eq 'Processor' | Select-Object -First 1; " ^
    "if($pnpCPU) { " ^
        "Write-Host ('   CPU ID       : ' + $pnpCPU.InstanceId) -F $w; " ^
    "}"
call :PauseToContinue & goto SystemUtilitiesMenu

:: 5.2 Restart Windows Explorer (Fix UI Glitches)
:RestartExplorer
echo. & echo %cBLU%[+] Restarting Explorer safely...%cRES%
call :RunAndLog taskkill /f /im explorer.exe
timeout /t 2 /nobreak >nul
tasklist /FI "IMAGENAME eq explorer.exe" 2>nul | find /I "explorer.exe" >nul || start explorer.exe
echo %cGRE%[+] Done.%cRES% & call :PauseToContinue & goto SystemUtilitiesMenu

:: 5.3 Kill 'Not Responding' Tasks
:KillNotRespondingTasks
echo. & echo %cBLU%[+] Terminating frozen applications...%cRES%
call :RunAndLog taskkill.exe /F /FI "status eq NOT RESPONDING"
echo %cGRE%[+] Done.%cRES% & call :PauseToContinue & goto SystemUtilitiesMenu

:: 5.4 Winget Power Tools
:WingetMenu
cls & call :DrawBox "WINGET POWER TOOLS" "%cBLU%" & echo.
echo  %cCYA%[+] Checking for available updates... (Please wait)%cRES%
echo.
winget upgrade --include-unknown
echo.
echo  -------------------------------------------------------------
echo  %cYEL%[1]%cWHI% Update ALL Apps %cGRE%(Silent ^& Auto)%cRES%
echo  %cYEL%[2]%cWHI% Choose Specific Applications to Update %cCYA%(By ID)%cRES%
echo  %cYEL%[3]%cWHI% Recheck ^& Clear Output Screen%cRES%
echo  %cYEL%[4]%cWHI% Fix ^& Reset Winget Cache%cRES%
echo  %cYEL%[5]%cWHI% Install Essential Software%cRES%
echo  %cYEL%[0]%cWHI% Back to Utilities Menu%cRES%
echo  -------------------------------------------------------------
echo.
set "w_opt="
set /p "w_opt= %cBLU%Choose option: %cRES%"

if "!w_opt!"=="" goto WingetMenu
if "!w_opt!"=="1" goto WingetUpdateAll
if "!w_opt!"=="2" goto WingetSelectUpdate
if "!w_opt!"=="3" goto WingetMenu
if "!w_opt!"=="4" (call :RunAndLog winget source reset --force & echo %cGRE%[+] Cache reset complete.%cRES% & call :PauseToContinue & goto WingetMenu)
if "!w_opt!"=="5" goto WingetInstall
if "!w_opt!"=="0" goto SystemUtilitiesMenu
goto WingetMenu

:WingetUpdateAll
echo.
echo  %cCYA%[+] Upgrading ALL applications in background...%cRES%
call :RunAndLog winget upgrade --all --include-unknown --accept-source-agreements --accept-package-agreements --disable-interactivity
echo. & echo  %cGRE%[+] Finished updating.%cRES%
call :PauseToContinue & goto WingetMenu

:WingetSelectUpdate
echo.
echo  %cYEL%Tip: Copy or highlight the ID on the screen, then Right-Click to paste it here quickly.%cRES%
echo.
set "spec_ids="
set /p "spec_ids= %cCYA%Enter App IDs to update: %cRES%"

if "!spec_ids!"=="" goto WingetMenu
echo.
for %%I in (!spec_ids!) do (
    echo  %cBLU%[+] Updating %%I...%cRES%
    call :RunAndLog winget upgrade --id="%%I" --exact --include-unknown --accept-source-agreements --accept-package-agreements --disable-interactivity
    echo.
)
echo  %cGRE%[+] Finished selected updates.%cRES%
call :PauseToContinue & goto WingetMenu

:WingetInstall
set "pkg[10]=Microsoft.VCRedist.2005.x64 Microsoft.VCRedist.2005.x86 Microsoft.VCRedist.2008.x64 Microsoft.VCRedist.2008.x86 Microsoft.VCRedist.2010.x64 Microsoft.VCRedist.2010.x86 Microsoft.VCRedist.2012.x64 Microsoft.VCRedist.2012.x86 Microsoft.VCRedist.2013.x64 Microsoft.VCRedist.2013.x86 Microsoft.VCRedist.2015+.x64 Microsoft.VCRedist.2015+.x86"
set "pkg[11]=Microsoft.VCRedist.2005.x64 Microsoft.VCRedist.2005.x86"
set "pkg[13]=Microsoft.VCRedist.2008.x64 Microsoft.VCRedist.2008.x86"
set "pkg[15]=Microsoft.VCRedist.2010.x64 Microsoft.VCRedist.2010.x86"
set "pkg[17]=Microsoft.VCRedist.2012.x64 Microsoft.VCRedist.2012.x86"
set "pkg[19]=Microsoft.VCRedist.2013.x64 Microsoft.VCRedist.2013.x86"
set "pkg[21]=Microsoft.VCRedist.2015+.x64 Microsoft.VCRedist.2015+.x86"
set "pkg[12]=Microsoft.DotNet.DesktopRuntime.8"
set "pkg[14]=Amazon.Corretto.21"
set "pkg[31]=Google.Chrome" & set "pkg[32]=Mozilla.Firefox" & set "pkg[33]=Microsoft.Edge"
set "pkg[34]=Brave.Brave" & set "pkg[35]=Opera.Opera" & set "pkg[36]=VivaldiTechnologies.Vivaldi"
set "pkg[37]=CocCoc.CocCoc"
set "pkg[41]=Zoom.Zoom" & set "pkg[42]=Discord.Discord" & set "pkg[43]=Microsoft.Teams"
set "pkg[44]=Pidgin.Pidgin" & set "pkg[45]=Mozilla.Thunderbird" & set "pkg[46]=CeruleanStudios.Trillian"
set "pkg[61]=Apple.iTunes" & set "pkg[62]=VideoLAN.VLC" & set "pkg[63]=AIMP.AIMP"
set "pkg[64]=PeterPawlowski.foobar2000" & set "pkg[65]=StevenMayall.MusicBee" & set "pkg[66]=Audacity.Audacity"
set "pkg[67]=CodecGuide.K-LiteCodecPack.Mega" & set "pkg[68]=Spotify.Spotify" & set "pkg[69]=HandBrake.HandBrake"
set "pkg[60]=Radionomy.Winamp" & set "pkg[601]=GRETECH.GOMPlayer" & set "pkg[602]=MediaMonkey.MediaMonkey"
set "pkg[71]=KDE.Krita" & set "pkg[72]=BlenderFoundation.Blender" & set "pkg[73]=dotPDNLLC.paint.net"
set "pkg[74]=GIMP.GIMP" & set "pkg[75]=IrfanSkiljan.IrfanView" & set "pkg[76]=XnSoft.XnViewMP"
set "pkg[77]=Inkscape.Inkscape" & set "pkg[78]=Greenshot.Greenshot" & set "pkg[79]=ShareX.ShareX"
set "pkg[70]=FastStone.ImageViewer"
set "pkg[81]=Foxit.FoxitReader" & set "pkg[82]=TheDocumentFoundation.LibreOffice" & set "pkg[83]=SumatraPDF.SumatraPDF"
set "pkg[84]=7zip.7zip" & set "pkg[85]=GiorgioTani.PeaZip" & set "pkg[86]=RARLab.WinRAR"
set "pkg[87]=AcroSoftware.CutePDFWriter" & set "pkg[88]=Apache.OpenOffice"
set "pkg[91]=Dropbox.Dropbox" & set "pkg[92]=Google.Drive" & set "pkg[93]=Microsoft.OneDrive" & set "pkg[94]=qBittorrent.qBittorrent"
set "pkg[101]=Malwarebytes.Malwarebytes" & set "pkg[102]=Avast.Antivirus.Free" & set "pkg[103]=AVG.AntivirusFree"
set "pkg[104]=Avira.FreeSecurity" & set "pkg[105]=SUPERAntiSpyware.SUPERAntiSpyware"
set "pkg[111]=Python.Python.3.12" & set "pkg[112]=Git.Git" & set "pkg[113]=Notepad++.Notepad++"
set "pkg[114]=Microsoft.VisualStudioCode" & set "pkg[115]=TimKosse.FileZillaClient" & set "pkg[116]=MartinPrikryl.WinSCP"
set "pkg[117]=SimonTatham.PuTTY" & set "pkg[118]=WinMerge.WinMerge" & set "pkg[119]=Cursor.Cursor"
set "pkg[110]=EclipseFoundation.EclipseJava"
set "pkg[121]=AnyDeskSoftwareGmbH.AnyDesk" & set "pkg[122]=TeamViewer.TeamViewer" & set "pkg[123]=VSRevoGroup.RevoUninstallerFree"
set "pkg[124]=AntibodySoftware.WizTree" & set "pkg[125]=WinDirStat.WinDirStat" & set "pkg[126]=Glarysoft.GlaryUtilities"
set "pkg[127]=Piriform.CCleaner" & set "pkg[128]=CodeSector.TeraCopy" & set "pkg[129]=OpenShell.OpenShell"
set "pkg[120]=LIGHTNINGUK.ImgBurn" & set "pkg[1201]=RealVNC.VNCViewer" & set "pkg[1202]=TightVNC.TightVNC"
set "pkg[131]=Valve.Steam" & set "pkg[132]=EpicGames.EpicGamesLauncher" & set "pkg[133]=voidtools.Everything"
set "pkg[134]=DominikReichl.KeePass" & set "pkg[135]=Google.EarthPro" & set "pkg[136]=Evernote.Evernote"
set "pkg[137]=NVAccess.NVDA"

goto WingetInstall_Rec

:WingetInstall_Rec
cls & call :DrawBox "INSTALL ESSENTIALS - RECOMMENDED" "%cGRE%" & echo.
echo  %cWHI%--- Runtimes ^& Environment ---%cRES%
echo  %cYEL%[10]%cWHI% ALL VCRedist (x86+x64)    %cYEL%[12]%cWHI% .NET Desktop Runtime 8%cRES%
echo  %cYEL%[14]%cWHI% Java (Amazon Corretto)%cRES%
echo.
echo  %cWHI%--- Web Browsers ^& Messaging ---%cRES%
echo  %cYEL%[37]%cWHI% Coc Coc                   %cYEL%[42]%cWHI% Discord%cRES%
echo.
echo  %cWHI%--- Media, 3D ^& Imaging ---%cRES%
echo  %cYEL%[62]%cWHI% VLC Media Player          %cYEL%[72]%cWHI% Blender%cRES%
echo.
echo  %cWHI%--- Compression ^& Security ---%cRES%
echo  %cYEL%[86]%cWHI% WinRAR                    %cYEL%[84]%cWHI% 7-Zip%cRES%
echo  %cYEL%[102]%cWHI% Avast Free Antivirus%cRES%
echo.
echo  %cWHI%--- Developer Tools ---%cRES%
echo  %cYEL%[111]%cWHI% Python 3                 %cYEL%[112]%cWHI% Git%cRES%
echo  %cYEL%[114]%cWHI% VS Code                  %cYEL%[113]%cWHI% Notepad++%cRES%
echo.
echo  %cWHI%--- Utilities ^& Gaming ---%cRES%
echo  %cYEL%[121]%cWHI% AnyDesk                  %cYEL%[122]%cWHI% TeamViewer%cRES%
echo  %cYEL%[133]%cWHI% Everything Search        %cYEL%[131]%cWHI% Steam%cRES%
echo  %cYEL%[132]%cWHI% Epic Games Launcher%cRES%
echo  -------------------------------------------------------------
echo  %cYEL%[N]%cWHI% View ALL Apps %cMAG%(Pages 1-3)%cRES%    %cYEL%[0]%cWHI% Back to Winget Menu%cRES%
echo.
set "wi_opt="
set /p "wi_opt= %cCYA%Select software (Ex: 10 37 86) or N for more: %cRES%"

if /i "!wi_opt!"=="N" goto WingetInstall_P1
if /i "!wi_opt!"=="0" goto WingetMenu
if not "!wi_opt!"=="" (set "RETURN_PAGE=WingetInstall_Rec" & goto ProcessInstall)
goto WingetInstall_Rec

:WingetInstall_P1
cls & call :DrawBox "ALL APPS - P1 (Runtimes, Web, Media)" "%cBLU%" & echo.
echo  %cWHI%--- VC++ Redistributables (Individual) ---%cRES%
echo  %cYEL%[11]%cWHI% VCRedist 2005   %cYEL%[13]%cWHI% VCRedist 2008   %cYEL%[15]%cWHI% VCRedist 2010%cRES%
echo  %cYEL%[17]%cWHI% VCRedist 2012   %cYEL%[19]%cWHI% VCRedist 2013   %cYEL%[21]%cWHI% VCRedist 2015-2022%cRES%
echo.
echo  %cWHI%--- Web Browsers ---%cRES%
echo  %cYEL%[31]%cWHI% Chrome          %cYEL%[32]%cWHI% Firefox         %cYEL%[33]%cWHI% Edge%cRES%
echo  %cYEL%[34]%cWHI% Brave           %cYEL%[35]%cWHI% Opera           %cYEL%[36]%cWHI% Vivaldi%cRES%
echo.
echo  %cWHI%--- Messaging ---%cRES%
echo  %cYEL%[41]%cWHI% Zoom            %cYEL%[43]%cWHI% MS Teams        %cYEL%[44]%cWHI% Pidgin%cRES%
echo  %cYEL%[45]%cWHI% Thunderbird     %cYEL%[46]%cWHI% Trillian%cRES%
echo.
echo  %cWHI%--- Media ---%cRES%
echo  %cYEL%[61]%cWHI% iTunes          %cYEL%[63]%cWHI% AIMP            %cYEL%[64]%cWHI% foobar2000%cRES%
echo  %cYEL%[65]%cWHI% MusicBee        %cYEL%[66]%cWHI% Audacity        %cYEL%[67]%cWHI% K-Lite Codecs%cRES%
echo  %cYEL%[68]%cWHI% Spotify         %cYEL%[69]%cWHI% HandBrake       %cYEL%[60]%cWHI% Winamp%cRES%
echo  %cYEL%[601]%cWHI% GOM Player     %cYEL%[602]%cWHI% MediaMonkey%cRES%
echo  -------------------------------------------------------------
echo  %cYEL%[R]%cWHI% Recommended Page   %cYEL%[N]%cWHI% Next Page (P2)   %cYEL%[0]%cWHI% Back%cRES%
echo.
set "wi_opt="
set /p "wi_opt= %cCYA%Select software (Ex: 11 31) or N to next: %cRES%"

if /i "!wi_opt!"=="R" goto WingetInstall_Rec
if /i "!wi_opt!"=="N" goto WingetInstall_P2
if /i "!wi_opt!"=="0" goto WingetMenu
if not "!wi_opt!"=="" (set "RETURN_PAGE=WingetInstall_P1" & goto ProcessInstall)
goto WingetInstall_P1

:WingetInstall_P2
cls & call :DrawBox "ALL APPS - P2 (Imaging, Docs, Sec)" "%cBLU%" & echo.
echo  %cWHI%--- Imaging ---%cRES%
echo  %cYEL%[71]%cWHI% Krita           %cYEL%[73]%cWHI% Paint.NET       %cYEL%[74]%cWHI% GIMP%cRES%
echo  %cYEL%[75]%cWHI% IrfanView       %cYEL%[76]%cWHI% XnView          %cYEL%[77]%cWHI% Inkscape%cRES%
echo  %cYEL%[78]%cWHI% Greenshot       %cYEL%[79]%cWHI% ShareX          %cYEL%[70]%cWHI% FastStone%cRES%
echo.
echo  %cWHI%--- Documents ^& Compression ---%cRES%
echo  %cYEL%[81]%cWHI% Foxit Reader    %cYEL%[82]%cWHI% LibreOffice     %cYEL%[83]%cWHI% SumatraPDF%cRES%
echo  %cYEL%[85]%cWHI% PeaZip          %cYEL%[87]%cWHI% CutePDF         %cYEL%[88]%cWHI% OpenOffice%cRES%
echo.
echo  %cWHI%--- Storage ^& Sharing ---%cRES%
echo  %cYEL%[91]%cWHI% Dropbox         %cYEL%[92]%cWHI% Google Drive    %cYEL%[93]%cWHI% OneDrive%cRES%
echo  %cYEL%[94]%cWHI% qBittorrent%cRES%
echo.
echo  %cWHI%--- Security ---%cRES%
echo  %cYEL%[101]%cWHI% Malwarebytes   %cYEL%[103]%cWHI% AVG Free       %cYEL%[104]%cWHI% Avira Security%cRES%
echo  %cYEL%[105]%cWHI% SUPERAntiSpyware%cRES%
echo  -------------------------------------------------------------
echo  %cYEL%[P]%cWHI% Prev Page (P1)     %cYEL%[N]%cWHI% Next Page (P3)   %cYEL%[0]%cWHI% Back%cRES%
echo.
set "wi_opt="
set /p "wi_opt= %cCYA%Select software (Ex: 71 91) or P/N to switch: %cRES%"

if /i "!wi_opt!"=="P" goto WingetInstall_P1
if /i "!wi_opt!"=="N" goto WingetInstall_P3
if /i "!wi_opt!"=="0" goto WingetMenu
if not "!wi_opt!"=="" (set "RETURN_PAGE=WingetInstall_P2" & goto ProcessInstall)
goto WingetInstall_P2

:WingetInstall_P3
cls & call :DrawBox "ALL APPS - P3 (Dev, Utils, Other)" "%cBLU%" & echo.
echo  %cWHI%--- Developer Tools ---%cRES%
echo  %cYEL%[115]%cWHI% FileZilla      %cYEL%[116]%cWHI% WinSCP         %cYEL%[117]%cWHI% PuTTY%cRES%
echo  %cYEL%[118]%cWHI% WinMerge       %cYEL%[119]%cWHI% Cursor         %cYEL%[110]%cWHI% Eclipse Java%cRES%
echo.
echo  %cWHI%--- Utilities ---%cRES%
echo  %cYEL%[123]%cWHI% Revo Uninstaller %cYEL%[124]%cWHI% WizTree      %cYEL%[125]%cWHI% WinDirStat%cRES%
echo  %cYEL%[126]%cWHI% Glary Utilities  %cYEL%[127]%cWHI% CCleaner     %cYEL%[128]%cWHI% TeraCopy%cRES%
echo  %cYEL%[129]%cWHI% Open-Shell       %cYEL%[120]%cWHI% ImgBurn      %cYEL%[1201]%cWHI% VNC Viewer%cRES%
echo  %cYEL%[1202]%cWHI% TightVNC%cRES%
echo.
echo  %cWHI%--- Other ---%cRES%
echo  %cYEL%[134]%cWHI% KeePass 2      %cYEL%[135]%cWHI% Google Earth   %cYEL%[136]%cWHI% Evernote%cRES%
echo  %cYEL%[137]%cWHI% NV Access%cRES%
echo  -------------------------------------------------------------
echo  %cYEL%[P]%cWHI% Prev Page (P2)                       %cYEL%[0]%cWHI% Back%cRES%
echo.
set "wi_opt="
set /p "wi_opt= %cCYA%Select software (Ex: 115 124) or P to prev: %cRES%"

if /i "!wi_opt!"=="P" goto WingetInstall_P2
if /i "!wi_opt!"=="0" goto WingetMenu
if not "!wi_opt!"=="" (set "RETURN_PAGE=WingetInstall_P3" & goto ProcessInstall)
goto WingetInstall_P3

:ProcessInstall
echo.
for %%N in (!wi_opt!) do (
    call set "current_pkg=%%pkg[%%N]%%"
    if defined current_pkg (
        for %%P in (!current_pkg!) do (
            echo  %cBLU%[+] Installing %%P...%cRES%
            call :RunAndLog winget install --id="%%P" --exact --accept-source-agreements --accept-package-agreements --disable-interactivity
        )
    ) else (
        echo  %cRED%[-] Invalid option: %%N%cRES%
    )
)
echo. & echo  %cGRE%[+] Installation process complete.%cRES%
call :PauseToContinue
goto !RETURN_PAGE!

:: 5.5 Check Windows License Key & Status
:CheckWinKey
cls & call :DrawBox "WINDOWS LICENSE & STATUS" "%cBLU%" & echo.
echo  %cCYA%[+] Checking Windows Activation Status ^& Channel...%cRES%

set "channel=Unknown"
set "is_kms=0"
set "lic_status=Unknown"
for /f "tokens=* delims=" %%A in ('cscript //nologo "%windir%\System32\slmgr.vbs" /dli 2^>nul') do (
    set "line=%%A"
    if "!line:Description:=!" neq "!line!" set "channel=!line!"
    if "!line:VOLUME_KMSCLIENT=!" neq "!line!" set "is_kms=1"
    if "!line:License Status:=!" neq "!line!" set "lic_status=!line!"
)

echo  %cWHI%Status: %cRES%!lic_status!
echo  %cWHI%License Channel: %cRES%!channel!

if "!is_kms!"=="1" (
    echo  %cRED%[!] WARNING: System is using a Volume/KMS Key.%cRES%
    echo  %cRED%[!] ^(For personal PCs, this often indicates an unofficial/cracked key^).%cRES%
) else (
    echo  %cGRE%[+] System is using a legitimate license ^(Retail/OEM^).%cRES%
)

echo.
echo  %cCYA%[+] Expiration Status (slmgr /xpr):%cRES%
for /f "delims=" %%A in ('cscript //nologo "%windir%\System32\slmgr.vbs" /xpr 2^>nul') do (
    set "xpr_out=%%A"
    echo  %cWHI%!xpr_out!%cRES%
)

echo.
echo  %cCYA%[+] Detailed Information (slmgr /dlv):%cRES%
for /f "delims=" %%A in ('cscript //nologo "%windir%\System32\slmgr.vbs" /dlv 2^>nul') do (
    set "dlv_out=%%A"
    echo  %cWHI%!dlv_out!%cRES%
)

echo.
echo  %cCYA%[+] Extracting Original Key from BIOS/UEFI...%cRES%
for /f "tokens=2 delims==" %%A in ('wmic path softwarelicensingservice get OA3xOriginalProductKey /value 2^>nul') do set "bios_key=%%A"
if not "!bios_key!"=="" (
    echo  %cGRE%Original OEM Key: !bios_key!%cRES%
) else (
    echo  %cYEL%No original key found in BIOS/UEFI.%cRES%
)

call :PauseToContinue & goto SystemUtilitiesMenu

:: 5.6 Generate Battery Health Report
:CheckBattery
cls & call :DrawBox "BATTERY HEALTH REPORT" "%cBLU%" & echo.
echo  %cCYA%[+] Generating battery report...%cRES%
set "bat_report=%temp%\battery_report.html"
call :RunAndLog powercfg /batteryreport /output "!bat_report!" >nul 2>&1
if exist "!bat_report!" (
    echo  %cGRE%[+] Report generated successfully! Opening file...%cRES%
    start "" "!bat_report!"
) else (
    echo  %cRED%[-] Failed to generate report. This device might not have a battery.%cRES%
)
call :PauseToContinue & goto SystemUtilitiesMenu

:: 5.7 Show Current Wi-Fi Password
:ShowWifiPass
cls & call :DrawBox "CURRENT WI-FI PASSWORD" "%cBLU%" & echo.
echo  %cCYA%[+] Checking network connection type...%cRES%
echo.
call :RunAndLog powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$iface = netsh wlan show interfaces 2>$null; " ^
    "$prof = $iface | Select-String -Pattern '^\s*Profile\s*:\s*(.+)$'; " ^
    "if ($prof) { " ^
        "$ssid = $prof.Matches[0].Groups[1].Value.Trim(); " ^
        "Write-Host ('   Connection Type     : Wi-Fi') -F Cyan; " ^
        "Write-Host ('   Network Name (SSID) : ' + $ssid) -F White; " ^
        "$cmd = 'netsh wlan show profile name=\"{0}\" key=clear' -f $ssid; " ^
        "$keyInfo = Invoke-Expression $cmd; " ^
        "$key = $keyInfo | Select-String -Pattern '^\s*Key Content\s*:\s*(.+)$'; " ^
        "if ($key) { " ^
            "$pass = $key.Matches[0].Groups[1].Value.Trim(); " ^
            "Write-Host ('   Password (Key)      : ' + $pass) -F Green; " ^
        "} else { " ^
            "Write-Host '   Password (Key)      : [Not Found or Open Network]' -F Yellow; " ^
        "} " ^
    "} else { " ^
        "$eth = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' -and $_.InterfaceAlias -match 'Ethernet|LAN' }; " ^
        "if ($eth) { " ^
            "Write-Host '   Connection Type     : Ethernet (LAN Cable)' -F Cyan; " ^
            "Write-Host '   [-] Cannot retrieve Wi-Fi password over a wired connection.' -F Yellow; " ^
            "Write-Host '       (Or this system does not have an active Wi-Fi adapter).' -F DarkGray; " ^
        "} else { " ^
            "Write-Host '   [-] Not connected to any active Wi-Fi or Ethernet network.' -F Red; " ^
        "} " ^
    "}"
echo.
call :PauseToContinue & goto SystemUtilitiesMenu

:: =====================================================================
::                        6. SCREEN & POWER TOOLS
:: =====================================================================
:ScreenToolsMenu
cls & call :DrawBox "SCREEN AND POWER TOOLS" "%cYEL%" & echo.
echo  %cYEL%[1]%cWHI% Turn Off Screen Immediately%cRES%
echo  %cYEL%[2]%cWHI% Create "Turn Off Screen.bat" on Desktop%cRES%
echo  %cYEL%[0]%cWHI% Back to Main Menu%cRES%
echo.
set "scr_choice="
set /p "scr_choice= %cYEL%Choose option: %cRES%"

if "!scr_choice!"=="" goto ScreenToolsMenu
if "!scr_choice!"=="1" goto ScrOffNow
if "!scr_choice!"=="2" goto ScrOffBat
if "!scr_choice!"=="0" goto main_menu
goto ScreenToolsMenu

:: 6.1 Turn Off Screen Immediately
:ScrOffNow
powershell -Command "(Add-Type '[DllImport(\"user32.dll\")]public static extern int SendMessage(int hWnd, int hMsg, int wParam, int lParam);' -Name a -Pas)::SendMessage(-1,0x0112,0xF170,2)"
goto ScreenToolsMenu

:: 6.2 Create "Turn Off Screen.bat" on Desktop
:ScrOffBat
for /f "delims=" %%I in ('powershell -NoProfile -Command "[Environment]::GetFolderPath('Desktop')"') do set "real_desktop=%%I"
set "bat_path=!real_desktop!\Turn Off Screen.bat"

echo @echo off> "!bat_path!"
echo title Turn Off Screen>> "!bat_path!"
echo cls ^& color 0B>> "!bat_path!"
echo setlocal enabledelayedexpansion>> "!bat_path!"
echo for /l %%%%i in (3,-1,1) do (>> "!bat_path!"
echo      cls ^& echo Turning off in %%%%i seconds...>> "!bat_path!"
echo      timeout /t 1 ^>nul>> "!bat_path!"
echo )>> "!bat_path!"
echo echo Turning off now...>> "!bat_path!"
echo powershell -Command "(Add-Type '[DllImport(\"user32.dll\")]public static extern int SendMessage(int hWnd, int hMsg, int wParam, int lParam);' -Name a -Pas)::SendMessage(-1,0x0112,0xF170,2)" ^>nul>> "!bat_path!"
echo exit /b>> "!bat_path!"

if exist "!bat_path!" (echo  %cGRE%[+] Created: "!bat_path!"%cRES%) else (echo  %cRED%[-] Error: Could not create file at "!bat_path!"%cRES%)
call :PauseToContinue & goto ScreenToolsMenu

:: =====================================================================
::                         7. QUICK RENAME PRO
:: =====================================================================
:QuickRename
if not defined mode1 set "mode1=File"
if not defined mode2_code set "mode2_code=1.1"
if not defined mode2_desc set "mode2_desc=Extract: K(x).re -> x.re"
set "remove_x=" & set "rep_a=" & set "rep_b="

:QuickRenameUI
cls & call :DrawBox "QUICK RENAME PRO" "%cGRE%" & echo.
echo  %cBLU%[+] Target Type: %mode1%%cRES%
echo  %cBLU%[+] Active Mode: %mode2_code% - !mode2_desc!%cRES%
if defined remove_x echo  %cBLU%[+] Param [x]: !remove_x!%cRES%
if defined rep_a echo  %cBLU%[+] Replace: '!rep_a!' with '!rep_b!'%cRES%
echo.
echo  %cGRE%--- CONFIGURATION ---%cRES%
echo  %cYEL%[0]%cWHI% Back to Main Menu%cRES%
echo  %cMAG%[1] FILE Modes:%cRES%
echo      %cYEL%[1.1]%cWHI% Extract Brackets   %cGRE%Ex: Report(2023).txt -^> 2023.txt%cRES%
echo      %cYEL%[1.2]%cWHI% Sequential Series  %cGRE%Ex: Folder -^> Folder - 1.jpg%cRES%
echo      %cYEL%[1.3]%cWHI% Remove Suffix (x)  %cGRE%Ex: Image_copy.png -^> Image.png%cRES%
echo      %cYEL%[1.4]%cWHI% Replace String     %cGRE%Ex: A -^> B%cRES%
echo      %cYEL%[1.5]%cWHI% Fast Rename        %cGRE%Scan and rename file-by-file or via list%cRES%
echo  %cMAG%[2] FOLDER Modes:%cRES%
echo      %cYEL%[2.1]%cWHI% Extract Brackets   %cGRE%Ex: Docs(Secret) -^> Secret%cRES%
echo      %cYEL%[2.2]%cWHI% Remove Suffix (x)  %cGRE%Ex: Backup_old -^> Backup%cRES%
echo      %cYEL%[2.3]%cWHI% Fast Rename        %cGRE%Scan and rename folder-by-folder or via list%cRES%
echo  %cMAG%[3] ACTIONS:%cRES%
echo      %cYEL%[3.1]%cWHI% Clear Output Screen%cRES%
echo      %cYEL%[3.2]%cWHI% %cRED%Undo Last Rename Batch%cRES%
echo.

:SubQuickRenameLoop
set "target_input="
set /p "target_input=%cYEL% Drag folder here, or type mode (ex: 1.2): %cRES%"

if "!target_input!"=="" goto SubQuickRenameLoop
if "!target_input!"=="0" goto main_menu
if "!target_input!"=="1" (set "mode1=File" & set "mode2_code=1.1" & set "mode2_desc=Extract: K(x).re -> x.re" & goto QuickRenameUI)
if "!target_input!"=="1.1" (set "mode1=File" & set "mode2_code=1.1" & set "mode2_desc=Extract: K(x).re -> x.re" & goto QuickRenameUI)
if "!target_input!"=="1.2" (set "mode1=File" & set "mode2_code=1.2" & set "mode2_desc=Sequential: Folder x -> x - 1.re" & goto QuickRenameUI)
if "!target_input!"=="1.3" (set "mode1=File" & set "mode2_code=1.3" & set "mode2_desc=Remove Suffix: K[x].re -> K.re" & set "remove_x=" & set /p "remove_x= Enter exact suffix to remove [x]: " & goto QuickRenameUI)
if "!target_input!"=="1.4" (set "mode1=File" & set "mode2_code=1.4" & set "mode2_desc=Replace String A with B" & set "rep_a=" & set /p "rep_a= String to find [A]: " & set "rep_b=" & set /p "rep_b= Replace with [B]: " & goto QuickRenameUI)
if "!target_input!"=="1.5" (set "mode1=File" & set "mode2_code=1.5" & set "mode2_desc=Fast Rename: Interactive or txt list" & goto QuickRenameUI)
if "!target_input!"=="2" (set "mode1=Folder" & set "mode2_code=2.1" & set "mode2_desc=Extract: K(x) -> x" & goto QuickRenameUI)
if "!target_input!"=="2.1" (set "mode1=Folder" & set "mode2_code=2.1" & set "mode2_desc=Extract: K(x) -> x" & goto QuickRenameUI)
if "!target_input!"=="2.2" (set "mode1=Folder" & set "mode2_code=2.2" & set "mode2_desc=Remove Suffix: K[x] -> K" & set "remove_x=" & set /p "remove_x= Enter exact suffix to remove [x]: " & goto QuickRenameUI)
if "!target_input!"=="2.3" (set "mode1=Folder" & set "mode2_code=2.3" & set "mode2_desc=Fast Rename: Interactive or txt list" & goto QuickRenameUI)
if "!target_input!"=="3" goto QuickRenameUI
if "!target_input!"=="3.1" goto QuickRenameUI

if "!target_input!"=="3.2" (
    if not exist "!UNDO_LOG!" (echo  %cRED%[-] Nothing to undo.%cRES% & goto SubQuickRenameLoop)
    echo  %cBLU%[+] Undoing last rename batch...%cRES%
    call :RunAndLog powershell -NoProfile -ExecutionPolicy Bypass -Command ^
        "$log = $env:UNDO_LOG; if (Test-Path $log) { $lines = @(Get-Content $log); $idx = -1; " ^
        "for ($i = $lines.Count - 1; $i -ge 0; $i--) { if ($lines[$i] -eq '---BATCH_START---') { $idx = $i; break } }; " ^
        "if ($idx -ne -1) { $b = @(); if ($idx -lt $lines.Count - 1) { $b = @($lines[($idx + 1)..($lines.Count - 1)]) }; " ^
        "[array]::Reverse($b); foreach ($l in $b) { $p = $l -split '\|'; if ($p.Length -eq 3) { " ^
        "$fp = Join-Path $p[0] $p[1]; if (Test-Path -LiteralPath $fp) { " ^
        "try { Rename-Item -LiteralPath $fp -NewName $p[2] -Force -ErrorAction Stop; Write-Host ('  [UNDO OK] ' + $p[1] + ' -> ' + $p[2]) -ForegroundColor Yellow } " ^
        "catch { Write-Host ('  [-] UNDO FAILED: ' + $p[1]) -ForegroundColor Red } " ^
        "} } }; if ($idx -gt 0) { Set-Content -Path $log -Value $lines[0..($idx - 1)] -Force } " ^
        "else { Remove-Item $log -Force } } else { Write-Host '[-] No recent actions.' -ForegroundColor Yellow; Remove-Item $log -Force } }"
    echo  %cGRE%[+] Undo complete^^!%cRES%
    goto SubQuickRenameLoop
)

set "target_dir=!target_input:"=!"
if not exist "!target_dir!\" (echo  %cRED%[-] Path does not exist. Please drag a valid folder.%cRES% & goto SubQuickRenameLoop)

echo  %cBLU%[+] Processing mode %mode2_code% in: !target_dir!...%cRES%
>> "%UNDO_LOG%" echo ---BATCH_START---

if "%mode2_code%"=="1.1" call :RunAndLog powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Get-ChildItem -LiteralPath $env:target_dir -File | Where-Object { $_.BaseName -match '^.*\((.*?)\)$' } | ForEach-Object { " ^
    "  $nn = ($_.BaseName -replace '^.*\((.*?)\)$', '$1') + $_.Extension; $old = $_.Name; " ^
    "  try { Rename-Item -LiteralPath $_.FullName -NewName $nn -Force -ErrorAction Stop; " ^
    "  Write-Host ('  [OK] ' + $old + ' -> ' + $nn) -ForegroundColor Green; " ^
    "  Add-Content -Path $env:UNDO_LOG -Value ($_.DirectoryName + '|' + $nn + '|' + $old); " ^
    "  } catch { Write-Host ('  [-] SKIPPED: ' + $old) -ForegroundColor Red } }"

if "%mode2_code%"=="1.2" call :RunAndLog powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$folder = Get-Item -LiteralPath $env:target_dir; $fName = $folder.Name; " ^
    "$files = Get-ChildItem -LiteralPath $folder.FullName -File | Sort-Object @{e={[regex]::Replace($_.BaseName, '\d+', [System.Text.RegularExpressions.MatchEvaluator]{param($m) $m.Value.PadLeft(10, '0')})}}; " ^
    "$temp = @(); foreach ($f in $files) { $tmp = $f.Name + '.tmp_ren'; try { Rename-Item -LiteralPath $f.FullName -NewName $tmp -Force -ErrorAction Stop; $temp += [PSCustomObject]@{ Old = $f.Name; Tmp = $tmp; Ext = $f.Extension } } catch {} }; " ^
    "$i = 1; foreach ($t in $temp) { $nn = $fName + ' - ' + $i + $t.Ext; try { Rename-Item -LiteralPath (Join-Path $folder.FullName $t.Tmp) -NewName $nn -Force -ErrorAction Stop; Write-Host ('  [OK] ' + $t.Old + ' -> ' + $nn) -ForegroundColor Green; Add-Content -Path $env:UNDO_LOG -Value ($folder.FullName + '|' + $nn + '|' + $t.Old) } catch {}; $i++ }"

if "%mode2_code%"=="1.3" call :RunAndLog powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$rx = [regex]::Escape($env:remove_x); Get-ChildItem -LiteralPath $env:target_dir -File | Where-Object { $_.BaseName -match ($rx + '$') } | ForEach-Object { " ^
    "  $nn = ($_.BaseName -replace ($rx + '$'), '') + $_.Extension; $old = $_.Name; " ^
    "  try { Rename-Item -LiteralPath $_.FullName -NewName $nn -Force -ErrorAction Stop; Write-Host ('  [OK] ' + $old + ' -> ' + $nn) -ForegroundColor Green; Add-Content -Path $env:UNDO_LOG -Value ($_.DirectoryName + '|' + $nn + '|' + $old) } catch {} }"

if "%mode2_code%"=="1.4" call :RunAndLog powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ra = [regex]::Escape($env:rep_a); $rb = $env:rep_b; Get-ChildItem -LiteralPath $env:target_dir -File | Where-Object { $_.Name -match $ra } | ForEach-Object { " ^
    "  $nn = $_.Name -replace $ra, $rb; $old = $_.Name; " ^
    "  try { Rename-Item -LiteralPath $_.FullName -NewName $nn -Force -ErrorAction Stop; Write-Host ('  [OK] ' + $old + ' -> ' + $nn) -ForegroundColor Green; Add-Content -Path $env:UNDO_LOG -Value ($_.DirectoryName + '|' + $nn + '|' + $old) } catch {} }"

if "%mode2_code%"=="2.1" call :RunAndLog powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Get-ChildItem -LiteralPath $env:target_dir -Directory | Where-Object { $_.Name -match '^.*\((.*?)\)$' } | ForEach-Object { " ^
    "  $nn = $_.Name -replace '^.*\((.*?)\)$', '$1'; $old = $_.Name; " ^
    "  try { Rename-Item -LiteralPath $_.FullName -NewName $nn -Force -ErrorAction Stop; Write-Host ('  [OK] ' + $old + ' -> ' + $nn) -ForegroundColor Green; Add-Content -Path $env:UNDO_LOG -Value ($_.Parent.FullName + '|' + $nn + '|' + $old) } catch {} }"

if "%mode2_code%"=="2.2" call :RunAndLog powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$rx = [regex]::Escape($env:remove_x); Get-ChildItem -LiteralPath $env:target_dir -Directory | Where-Object { $_.Name -match ($rx + '$') } | ForEach-Object { " ^
    "  $nn = $_.Name -replace ($rx + '$'), ''; $old = $_.Name; " ^
    "  try { Rename-Item -LiteralPath $_.FullName -NewName $nn -Force -ErrorAction Stop; Write-Host ('  [OK] ' + $old + ' -> ' + $nn) -ForegroundColor Green; Add-Content -Path $env:UNDO_LOG -Value ($_.Parent.FullName + '|' + $nn + '|' + $old) } catch {} }"

if "%mode2_code%"=="1.5" set "FAST_MODE=File" & goto RunFastRename
if "%mode2_code%"=="2.3" set "FAST_MODE=Folder" & goto RunFastRename

echo  %cGRE%[+] Done^^!%cRES%
goto SubQuickRenameLoop

:: 7.1 Fast Rename Core
:RunFastRename
echo.
echo  %cCYA%--- FAST RENAME (%FAST_MODE%) ---%cRES%
echo  %cYEL%[1]%cWHI% Manual Step-by-Step %cGRE%(s/skip, u/up)%cRES%
echo  %cYEL%[2]%cWHI% Rename from a .txt list%cRES%
set "fast_opt="
set /p fast_opt=" %cYEL%Choose option (1/2): %cRES%"

if "!fast_opt!"=="1" goto FastRenameManual
if "!fast_opt!"=="2" goto FastRenameList
echo %cRED%[-] Invalid option.%cRES%
goto SubQuickRenameLoop

:FastRenameManual
powershell -NoProfile -ExecutionPolicy Bypass -Command "$t = $env:target_dir; $mode = $env:FAST_MODE; $se = @{e={[regex]::Replace($_.Name, '\d+', [System.Text.RegularExpressions.MatchEvaluator]{param($m) $m.Value.PadLeft(10, '0')})}}; if($mode -eq 'File') { $items = @(Get-ChildItem -LiteralPath $t -File | Sort-Object $se) } else { $items = @(Get-ChildItem -LiteralPath $t -Directory | Sort-Object $se) }; if($items.Count -eq 0) { Write-Host 'No items found.' -F Yellow; exit }; $list = @(); foreach($i in $items) { $list += [PSCustomObject]@{Orig=$i.Name; Curr=$i.Name; Dir=$i.Parent.FullName; Ext=$i.Extension} }; $idx=0; while($idx -lt $list.Count) { if($idx -lt 0) { $idx=0 }; $c = $list[$idx]; Write-Host ''; Write-Host ('[' + ($idx+1) + '/' + $list.Count + '] Item: ' + $c.Curr) -F Cyan; $inp = Read-Host '  >> Enter new name (or s/skip [n], u/up [n], exit)'; if($inp -match '^(exit|quit)$') { break }; if($inp -match '^(?:-s|s|skip)(?:\s+(\d+))?$') { $n=1; if($matches[1]) { $n=[int]$matches[1] }; Write-Host ('  >> Skipped ' + $n + ' items') -F DarkGray; $idx+=$n; continue }; if($inp -match '^(?:-u|u|up)(?:\s+(\d+))?$') { $n=1; if($matches[1]) { $n=[int]$matches[1] }; Write-Host ('  >> Undid ' + $n + ' items') -F DarkYellow; $idx-=$n; if($idx -lt 0) { $idx=0 }; continue }; if([string]::IsNullOrWhiteSpace($inp)) { Write-Host '  >> Skipped' -F DarkGray; $idx++; continue }; $nn = $inp; if($mode -eq 'File' -and -not $nn.EndsWith($c.Ext)) { $nn += $c.Ext }; $oldP = Join-Path $c.Dir $c.Curr; $newP = Join-Path $c.Dir $nn; if(Test-Path -LiteralPath $newP) { Write-Host '  [-] Name already exists!' -F Red; continue }; try { Rename-Item -LiteralPath $oldP -NewName $nn -ErrorAction Stop; Write-Host ('  [OK] ' + $c.Curr + ' -> ' + $nn) -F Green; Add-Content -Path $env:UNDO_LOG -Value ($c.Dir + '|' + $nn + '|' + $c.Curr); $c.Curr=$nn; $idx++ } catch { Write-Host ('  [-] Error: ' + $_) -F Red } }"
echo  %cGRE%[+] Done^^!%cRES%
goto SubQuickRenameLoop

:FastRenameList
echo.
echo %cRED%Please ensure the provided list is a .txt format file.%cRES%
set /p txt_path=" %cYEL%Enter path to .txt file: %cRES%"
set "txt_path=!txt_path:"=!"
if not exist "!txt_path!" (echo %cRED%[-] File not found.%cRES% & goto SubQuickRenameLoop)

powershell -NoProfile -ExecutionPolicy Bypass -Command "$t = $env:target_dir; $mode = $env:FAST_MODE; $txt = $env:txt_path; $se = @{e={[regex]::Replace($_.Name, '\d+', [System.Text.RegularExpressions.MatchEvaluator]{param($m) $m.Value.PadLeft(10, '0')})}}; if($mode -eq 'File') { $items = @(Get-ChildItem -LiteralPath $t -File | Sort-Object $se) } else { $items = @(Get-ChildItem -LiteralPath $t -Directory | Sort-Object $se) }; if($items.Count -eq 0) { Write-Host 'No items found.' -F Yellow; exit }; try { $names = @(Get-Content -LiteralPath $txt -ErrorAction Stop) } catch { Write-Host '[-] Failed to read txt file.' -F Red; exit }; if($names.Count -eq 0) { Write-Host '[-] Text file is empty.' -F Red; exit }; $count = [math]::Min($items.Count, $names.Count); $preview = @(); for($i=0; $i -lt $count; $i++) { $old = $items[$i].Name; $new = $names[$i].Trim(); if($mode -eq 'File') { $ext = $items[$i].Extension; if(-not $new.EndsWith($ext)) { $new += $ext } }; $preview += [PSCustomObject]@{ Old = $old; New = $new; Item = $items[$i] } }; Write-Host ''; Write-Host '--- RENAME PREVIEW ---' -F Cyan; foreach($p in $preview) { Write-Host ('  {0} -> {1}' -f $p.Old, $p.New) -F White }; Write-Host ''; Write-Host ('Total items to rename: ' + $count) -F Yellow; $ans = Read-Host 'Proceed with renaming? (Y/N)'; if($ans -match '^Y') { foreach($p in $preview) { try { Rename-Item -LiteralPath $p.Item.FullName -NewName $p.New -ErrorAction Stop; Write-Host ('  [OK] ' + $p.Old + ' -> ' + $p.New) -F Green; Add-Content -Path $env:UNDO_LOG -Value ($p.Item.DirectoryName + '|' + $p.New + '|' + $p.Old) } catch { Write-Host ('  [-] FAILED: ' + $p.Old + ' -> ' + $p.New + ' (Invalid name format, length, or forbidden characters)') -F Red } } } else { Write-Host 'Cancelled.' -F DarkGray }"
echo  %cGRE%[+] Done^^!%cRES%
goto SubQuickRenameLoop

:: =====================================================================
::                    8. AUTO MAINTENANCE (ADMIN)
:: =====================================================================
:AutoRun
call :CheckAdmin || goto :EOF
cls & call :DrawBox "AUTO MAINTENANCE" "%cRED%"
set "confirm=" & set /p "confirm=%cYEL%Type 'AUTO' to start: %cRES%"
if /i not "!confirm!"=="AUTO" goto :EOF
call :QuickClean & call :DeepClean & call :ClearWinUpdate
echo %cGRE%[+] FULL MAINTENANCE COMPLETE.%cRES%
set "rebootq=" & set /p "rebootq=Reboot now? (Y/N): "
if /i "!rebootq!"=="Y" shutdown /r /t 10
goto :EOF

:: =====================================================================
::                      9. TOOLKIT OPTIONS & LOGS
:: =====================================================================
:Options
cls & call :DrawBox "OPTIONS & LOGS" "%cYEL%" & echo.
echo  %cYEL%[1]%cWHI% Toggle Expert Mode %cMAG%(Show hidden/dangerous options)%cRES%
echo  %cYEL%[2]%cWHI% Export Action Report%cRES%
echo  %cYEL%[0]%cWHI% Back to Main Menu%cRES%
echo.
set "opt_c="
set /p "opt_c= %cYEL%Choose option: %cRES%"

if "!opt_c!"=="" goto Options
if "!opt_c!"=="1" (if "!EXPERT_MODE!"=="0" (set "EXPERT_MODE=1") else (set "EXPERT_MODE=0"))
if "!opt_c!"=="2" (
    if not exist "%TMP_LOGFILE%" (echo %cRED%[-] No actions to export.%cRES% & call :PauseToContinue & goto :EOF)
    for /f "usebackq" %%i in (`powershell -Command "Get-Date -Format 'yyyyMMddHHmm'"`) do set "NOW=%%i"
    set "EXP=%BASE_DIR%\Log_!NOW!.txt"
    copy "%TMP_LOGFILE%" "!EXP!" >nul
    echo %cGRE%[+] Exported: !EXP!%cRES% & start "" "%BASE_DIR%" & call :PauseToContinue
)
goto :EOF

:: =====================================================================
::                         HELPER FUNCTIONS
:: =====================================================================

:CheckAdmin
if "!IS_ADMIN!"=="0" (
    echo.
    echo  %cRED%[!] This feature requires Administrator privileges.%cRES%
    set /p "elevate=%cYEL%Relaunch toolkit as Administrator now? (Y/N): %cRES%"
    if /i "!elevate!"=="Y" (
        powershell -Command "Start-Process cmd -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
        exit
    )
    exit /b 1
)
exit /b 0

:CreateNewTempLog
>> "%TMP_LOGFILE%" echo ========================================
>> "%TMP_LOGFILE%" echo SESSION STARTED: %date% %time%
>> "%TMP_LOGFILE%" echo ========================================
goto :EOF

:LogNav
>> "%TMP_LOGFILE%" echo [%time%] [NAVIGATION] Entered: %~1
goto :EOF

:LogInput
>> "%TMP_LOGFILE%" echo [%time%] [USER INPUT] %~1 = %~2
goto :EOF

:LogAction
>> "%TMP_LOGFILE%" echo [%time%] [ACTION EXE] %~1
goto :EOF

:LogError
>> "%ERROR_LOGFILE%" echo [%date% %time%] [CRIT_ERR] %~1
goto :EOF

:CleanDir
if exist "%~1" (
    echo %cBLU%[+] Cleaning %~2...%cRES%
    >> "%TMP_LOGFILE%" echo [%time%] [CLEANUP_ACT] Target: %~2
    pushd "%~1" 2>nul && (
        del /f /s /q * >nul 2>&1
        for /d %%D in (*) do rd /s /q "%%D" >nul 2>&1
        popd
        echo      %cGRE%[OK] %~2 cleaned.%cRES%
    ) || call :LogError "Failed to access %~2"
)
goto :EOF

:RunAndLog
>> "%TMP_LOGFILE%" echo [%time%] [CMD_INVOKE] %*
%*
set "RET=!errorlevel!"
if !RET! equ 0 (
    >> "%TMP_LOGFILE%" echo [%time%] [CMD_STATUS] SUCCESS
) else (
    >> "%TMP_LOGFILE%" echo [%time%] [CMD_STATUS] ERROR CODE: !RET!
)
>> "%TMP_LOGFILE%" echo ----------------------------------------
exit /b !RET!

:SummarizeLog
cls & call :DrawBox "SESSION SUMMARY" "%cMAG%"
echo.
echo  %cCYA%[+] Here is a brief summary of what happened this session:%cRES%
echo  --------------------------------------------------------------
if exist "%TMP_LOGFILE%" (
    findstr /C:"[NAVIGATION]" /C:"[USER INPUT]" /C:"[CMD_STATUS]" "%TMP_LOGFILE%"
) else (
    echo    No actions recorded.
)
echo  --------------------------------------------------------------
echo  %cGRE%Full log is available in memory until you exit.%cRES%
pause
goto :EOF

:DrawBox
setlocal
set "fullText=%~1"
set "text=!fullText!"
set "color=%~2"
set "len=0"
:len_loop
if defined text (set "text=!text:~1!" & set /a len+=1 & goto len_loop)
set "padding=" & for /l %%A in (1,1,%len%) do set "padding=!padding!="
echo.
echo  !color! +-%padding%-+!cRES!
echo  !color! ^| !fullText! ^|!cRES!
echo  !color! +-%padding%-+!cRES!
endlocal & goto :EOF

:PauseToContinue
echo. & echo  %cYEL%==========================================%cRES%
echo  %cWHI%DONE^^! Press any key to return...%cRES%
echo  %cYEL%==========================================%cRES% & pause >nul & goto :EOF