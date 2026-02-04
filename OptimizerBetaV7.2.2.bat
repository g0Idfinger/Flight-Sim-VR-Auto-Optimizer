@echo off
setlocal EnableExtensions EnableDelayedExpansion

:: ============================================================
:: UNIVERSAL SIM VR OPTIMIZER - V7.2.2 BETA Stable
:: ============================================================

:MENU
cls
echo ============================================================
echo        VR AUTO-OPTIMIZER - SELECT YOUR SIMULATOR
echo ============================================================
echo.
echo [1] MSFS 2024 (Steam)          [5] MSFS 2024 (Store/GamePass)
echo [2] MSFS 2020 (Steam)          [6] MSFS 2020 (Store/GamePass)
echo [3] DCS World (Steam)          [7] DCS World (Standalone)
echo.
echo [X] EXIT
echo.
set /p choice="Selection (1-7/X): "

if /i "%choice%"=="X" exit

set "LAUNCH_METHOD=STEAM"
if "%choice%"=="1" (
    set "STEAM_APPID=2537590" & set "GAME_EXE=FlightSimulator2024.exe" & set "VERSION_NAME=MSFS 2024 (Steam)"
) else if "%choice%"=="2" (
    set "STEAM_APPID=1250410" & set "GAME_EXE=FlightSimulator.exe" & set "VERSION_NAME=MSFS 2020 (Steam)"
) else if "%choice%"=="3" (
    set "STEAM_APPID=223750" & set "GAME_EXE=DCS.exe" & set "VERSION_NAME=DCS World (Steam)"
) else if "%choice%"=="5" (
    set "LAUNCH_METHOD=STORE" & set "GAME_EXE=FlightSimulator2024.exe" & set "VERSION_NAME=MSFS 2024 Store"
    set "STORE_URI=shell:AppsFolder\Microsoft.Limitless_8wekyb3d8bbwe^!App"
) else if "%choice%"=="6" (
    set "LAUNCH_METHOD=STORE" & set "STORE_URI=shell:AppsFolder\Microsoft.FlightSimulator_8wekyb3d8bbwe^!App"
    set "GAME_EXE=FlightSimulator.exe" & set "VERSION_NAME=MSFS 2020 (Store)"
) else if "%choice%"=="7" (
    set "LAUNCH_METHOD=DCS_STORE" & set "GAME_EXE=DCS.exe" & set "VERSION_NAME=DCS World (Standalone)"
) else ( goto MENU )

:: CONFIG
set "LOGFILE=%~dp0sim_launcher.log"
set "RESTART_DISCORD=YES"
set "RESTART_ONEDRIVE=YES"
set "RESTART_EDGE=YES"
set "RESTART_CCLEANER=YES"
set "RESTART_ICLOUD=YES"

:: --- LOG ROTATION ---
if exist "%LOGFILE%" (
    set "count=0"
    for /f "usebackq" %%A in (`find /c /i "[SESSION START]" "%LOGFILE%"`) do set "count=%%A"
    for %%I in ("%LOGFILE%") do set "fsize=%%~zI"
    if !count! GEQ 10 ( move /y "%LOGFILE%" "%LOGFILE%.old" >nul & echo [%DATE% %TIME%] [LOG] Rotation triggered >> "%LOGFILE%" )
    if !fsize! GTR 2097152 ( move /y "%LOGFILE%" "%LOGFILE%.old" >nul )
)
echo ============================================================ >> "%LOGFILE%"
echo [%DATE% %TIME%] [SESSION START] Target: %VERSION_NAME% >> "%LOGFILE%"

:: ADMIN CHECK
net session >nul 2>&1 || ( powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -ArgumentList '%choice%' -Verb RunAs" & exit /b )
if not "%~1"=="" set "choice=%~1"
cd /d "%~dp0"

:: [1/4] PREP
echo [1/4] Preparing system...
powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c >nul 2>&1
echo [%TIME%] [PREP] Power Plan active: %VERSION_NAME% >> "%LOGFILE%"

taskkill /f /im OneDrive.exe /t >nul 2>&1 && echo [%TIME%] [PREP] OneDrive killed >> "%LOGFILE%"
taskkill /f /im Discord.exe /t >nul 2>&1 && echo [%TIME%] [PREP] Discord killed >> "%LOGFILE%"
taskkill /f /im chrome.exe /t >nul 2>&1 && echo [%TIME%] [PREP] Chrome killed >> "%LOGFILE%"
taskkill /f /im msedge.exe /t >nul 2>&1 && echo [%TIME%] [PREP] Edge killed >> "%LOGFILE%"
taskkill /f /im CCleaner64.exe /t >nul 2>&1 && echo [%TIME%] [PREP] CCleaner killed >> "%LOGFILE%"
taskkill /f /im iCloudServices.exe /t >nul 2>&1 && echo [%TIME%] [PREP] iCloudServices killed >> "%LOGFILE%"
taskkill /f /im iCloudDrive.exe /t >nul 2>&1 && echo [%TIME%] [PREP] iCloudDrive killed >> "%LOGFILE%"

net stop SysMain /y >nul 2>&1
net stop Spooler /y >nul 2>&1
nvidia-smi -pm 1 >nul 2>&1
ipconfig /flushdns >nul

:: [2/4] VR
if exist "C:\Program Files\Virtual Desktop Streamer\VirtualDesktop.Streamer.exe" (
    echo [2/4] Launching VR...
    echo [%TIME%] [VR] Streamer started >> "%LOGFILE%"
    start "" "C:\Program Files\Virtual Desktop Streamer\VirtualDesktop.Streamer.exe"
    timeout /t 8 >nul
)

:: [3/4] LAUNCH
echo [3/4] Launching %VERSION_NAME%...
echo [%TIME%] [LAUNCH] Method: %LAUNCH_METHOD% - Target: %GAME_EXE% >> "%LOGFILE%"

if "%LAUNCH_METHOD%"=="STEAM" (
    start "" "steam://run/%STEAM_APPID%"
) else if "%LAUNCH_METHOD%"=="STORE" (
    echo [%TIME%] [LAUNCH] Store-URI: !STORE_URI! >> "%LOGFILE%"
    powershell -NoProfile -Command "Start-Process $env:STORE_URI -ArgumentList ' -FastLaunch'"
) else if "%LAUNCH_METHOD%"=="DCS_STORE" (
    set "DCS_BIN="
    for %%D in (C D E F G H I J) do (
        if exist "%%D:\Eagle Dynamics\DCS World\bin-mt\DCS.exe" set "DCS_BIN=%%D:\Eagle Dynamics\DCS World\bin-mt\DCS.exe"
        if exist "%%D:\DCS World\bin-mt\DCS.exe" set "DCS_BIN=%%D:\DCS World\bin-mt\DCS.exe"
    )
    if defined DCS_BIN ( pushd "!DCS_BIN:\DCS.exe=!" & start "" "DCS.exe" & popd )
)

:: DETECTION
set /a retry_count=0
:WAIT_GAME
set "ACTIVE_EXE="
for %%E in ("%GAME_EXE%" "DCS_mt.exe" "FlightSimulator.exe") do (
    tasklist /NH /FI "IMAGENAME eq %%~E" | find /i "%%~E" >nul
    if not errorlevel 1 set "ACTIVE_EXE=%%~E"
)
if defined ACTIVE_EXE (
    set "GAME_EXE=%ACTIVE_EXE%"
    echo [%TIME%] [DETECT] Process active: !GAME_EXE! >> "%LOGFILE%"
    goto GAME_DETECTED
)
set /a retry_count+=1
echo [!] Waiting... (!retry_count!/7)
if !retry_count! GEQ 7 (
    echo [%TIME%] [TIMEOUT] Game not found >> "%LOGFILE%"
    goto RESTORE
)
timeout /t 5 >nul
goto WAIT_GAME

:GAME_DETECTED
echo [!] %GAME_EXE% detected. Optimizing Performance...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$n='%GAME_EXE%'.Replace('.exe',''); $p=Get-Process $n -ErrorAction SilentlyContinue; if($p){ " ^
    "try { $p.PriorityClass='High'; " ^
    "$cpu=Get-CimInstance Win32_Processor; $cores=$cpu.NumberOfCores; $logical=$cpu.NumberOfLogicalProcessors; " ^
    "$mask=[int64]0; if($logical -gt $cores){ for($i=0; $i -lt $cores; $i++){ $mask+=[int64][math]::Pow(2,$i*2) } } " ^
    "else { for($i=0; $i -lt $cores; $i++){ $mask+=[int64][math]::Pow(2,$i) } }; " ^
    "$p.ProcessorAffinity=[IntPtr]$mask; Write-Host 'Optimized Performance' -ForegroundColor Cyan " ^
    "} catch { Write-Host 'Affinity partially applied' -ForegroundColor Yellow } }"
	
echo ============================================================
echo %VERSION_NAME% RUNNING - DO NOT CLOSE THIS WINDOW
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Write-Host 'Enjoy your flight! Greetings from ' -NoNewline; Write-Host ' VRFLIGHTSIM GUY ' -ForegroundColor Yellow -BackgroundColor Red -NoNewline; Write-Host ' and ' -NoNewline; Write-Host ' SHARK ' -ForegroundColor Yellow -BackgroundColor Red;"
echo ============================================================

:WAIT_EXIT
timeout /t 15 >nul
tasklist /NH /FI "IMAGENAME eq %GAME_EXE%" | find /i "%GAME_EXE%" >nul
if not errorlevel 1 goto WAIT_EXIT

:: [4/4] RESTORE
:RESTORE
echo [4/4] Restoring system...
echo [%TIME%] [RESTORE] Starting Cleanup >> "%LOGFILE%"
taskkill /f /im VirtualDesktop.Streamer.exe >nul 2>&1
net start SysMain /y >nul 2>&1
net start Spooler /y >nul 2>&1
nvidia-smi -pm 0 >nul 2>&1
powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e
echo [%TIME%] [RESTORE] System reverted >> "%LOGFILE%"

if /i "%RESTART_EDGE%"=="YES" (
    if exist "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" (
        echo Restoring Microsoft Edge...
        start "" "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
        echo [%TIME%] [RESTORE] Edge restart triggered >> "%LOGFILE%"
    ) else (
        echo [%TIME%] [RESTORE] Edge not found, skipping >> "%LOGFILE%"
    )
)


if /i "%RESTART_DISCORD%"=="YES" (
    if exist "%LocalAppData%\Discord\Update.exe" (
        echo Restoring Discord...
        start "" "%LocalAppData%\Discord\Update.exe" --processStart Discord.exe
		echo [%TIME%] [RESTORE] Discord restart triggered >> "%LOGFILE%"
    )
)

if /i "%RESTART_ONEDRIVE%"=="YES" (
    set "OD_P="
    if exist "%LocalAppData%\Microsoft\OneDrive\OneDrive.exe" set "OD_P=%LocalAppData%\Microsoft\OneDrive\OneDrive.exe"
    if exist "C:\Program Files\Microsoft OneDrive\OneDrive.exe" set "OD_P=C:\Program Files\Microsoft OneDrive\OneDrive.exe"
    if defined OD_P (
        echo [%TIME%] [RESTORE] OneDrive task start >> "%LOGFILE%"
        schtasks /create /tn "OD_Restarter" /tr "\"!OD_P!\" /background" /sc once /st 00:00 /it /f >nul 2>&1
        schtasks /run /tn "OD_Restarter" >nul 2>&1
        timeout /t 2 >nul
        schtasks /delete /tn "OD_Restarter" /f >nul 2>&1
        echo [%TIME%] [RESTORE] OneDrive task finished >> "%LOGFILE%"
    )
)
if /i "%RESTART_CCLEANER%"=="YES" (
    if exist "C:\Program Files\CCleaner\CCleaner64.exe" (
        echo Restoring CCleaner...
        start "" "C:\Program Files\CCleaner\CCleaner64.exe" /MONITOR
    )
)

if /i "%RESTART_ICLOUD%"=="YES" (
    if exist "C:\Program Files\WindowsApps\AppleInc.iCloud_*" (
        echo Restoring iCloud (Store Version)...
        start explorer.exe shell:AppsFolder\AppleInc.iCloud_skh98v6769f6t^!iCloud
    ) else if exist "C:\Program Files (x86)\Common Files\Apple\Internet Services\iCloud.exe" (
        echo Restoring iCloud (Desktop Version)...
        start "" "C:\Program Files\x86\Common Files\Apple\Internet Services\iCloud.exe"
    )
)
echo [SESSION END] %DATE% %TIME% >> "%LOGFILE%"
echo.
echo Operation complete. Returning to main menu...
timeout /t 5 >nul
goto MENU




