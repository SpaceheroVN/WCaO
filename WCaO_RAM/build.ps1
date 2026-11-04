$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

# Ensure PATH includes Machine and User PATH (e.g. LLVM-MinGW)
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

Write-Host "[1/2] Compiling Win32 Resource (WCaO_RAM.rc)..." -ForegroundColor Cyan
windres WCaO_RAM.rc -O coff -o WCaO_RAM.res
if ($LASTEXITCODE -ne 0) { throw "windres failed with exit code $LASTEXITCODE" }

Write-Host "[2/2] Compiling C++ Source (main.cpp -> WCaO_RAM.exe)..." -ForegroundColor Cyan
g++ -std=c++17 -O3 -flto -march=x86-64-v2 -s -mwindows -municode -static `
    -fno-exceptions -fno-rtti -ffunction-sections -fdata-sections "-Wl,--gc-sections" `
    main.cpp WCaO_RAM.res -o WCaO_RAM.exe `
    -lgdiplus -ldwmapi -lshell32 -lole32 -luuid -lcomdlg32 -ladvapi32 -luser32 -lgdi32 -lpsapi -lpropsys

if ($LASTEXITCODE -ne 0) { throw "g++ failed with exit code $LASTEXITCODE" }

if (Test-Path "WCaO_RAM.res") { Remove-Item "WCaO_RAM.res" -Force }
$exeInfo = Get-Item "WCaO_RAM.exe"
Write-Host ("SUCCESS! Built WCaO_RAM.exe ({0:N1} KB)" -f ($exeInfo.Length / 1KB)) -ForegroundColor Green
