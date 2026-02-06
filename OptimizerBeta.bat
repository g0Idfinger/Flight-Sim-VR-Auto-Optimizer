@echo off
setlocal EnableExtensions EnableDelayedExpansion
:: ============================================================
:: UNIVERSAL SIM VR OPTIMIZER - V7.2.2.2.2 BETA Stable
:: ============================================================

:PREMENU
cls
rem === Prepare ESC (ANSI) ===
for /F %%A in ('echo prompt $E ^| cmd') do set "ESC=%%A"

rem === Header ===
echo ============================================================
echo %ESC%[36m        SELECT PROFILE%ESC%[0m
echo ============================================================
echo.

rem === Options ===
echo %ESC%[32m[1] DEFAULT MODE AUTO%ESC%[0m
echo %ESC%[33m[2] NO RESTART OF APPLICATIONS%ESC%[0m
echo %ESC%[35m[3] DEBUG%ESC%[0m
echo.
echo %ESC%[37m[X] CONTINUE TO SIM SELECTION%ESC%[0m
echo.


set /p premenu="Selection: "

if /i "%premenu%"=="X" goto MENU

if "%premenu%"=="1" (
    set "VR_PROFILE=DEFAULT"
) else if "%premenu%"=="2" (
    set "VR_PROFILE=NO_RESTART"
) else if "%premenu%"=="3" (
    set "VR_PROFILE=DEBUG"
) else (
    goto PREMENU
)

echo.
powershell -NoProfile -Command "Write-Host 'Selected Profile: %VR_PROFILE%' -ForegroundColor Cyan"
timeout /t 1 >nul
goto MENU

:MENU
cls
rem === Prepare ESC (ANSI escape) ===
for /F %%A in ('echo prompt $E ^| cmd') do set "ESC=%%A"

rem === Header ===
echo ============================================================
echo %ESC%[36m       VR AUTO-OPTIMIZER - SELECT YOUR SIMULATOR%ESC%[0m
echo ============================================================
echo.

rem === Options ===
echo %ESC%[32m[1] MSFS 2024 (Steam)%ESC%[0m
echo %ESC%[32m[2] MSFS 2020 (Steam)%ESC%[0m
echo %ESC%[32m[3] DCS World (Steam)%ESC%[0m
echo %ESC%[33m[5] MSFS 2024 (Store/GamePass)%ESC%[0m
echo %ESC%[33m[6] MSFS 2020 (Store/GamePass)%ESC%[0m
echo %ESC%[33m[7] DCS World (Standalone)%ESC%[0m
echo.
echo %ESC%[37m[X] EXIT%ESC%[0m
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
    set "LAUNCH_METHOD=STORE" & set "STORE_URI=shell:AppsFolder\Microsoft.Limitless_8wekyb3d8bbwe^!App"
	set "STORE_URI=FlightSimulator2024.exe" & set "VERSION_NAME=MSFS 2024 (Store)"
) else if "%choice%"=="6" (
    set "LAUNCH_METHOD=STORE" & set "STORE_URI=shell:AppsFolder\Microsoft.FlightSimulator_8wekyb3d8bbwe^!App"
    set "GAME_EXE=FlightSimulator.exe" & set "VERSION_NAME=MSFS 2020 (Store)"
) else if "%choice%"=="7" (
    set "LAUNCH_METHOD=DCS_STORE" & set "GAME_EXE=DCS.exe" & set "VERSION_NAME=DCS World (Standalone)"
) else ( goto MENU )


:: CONFIG
set "LOGFILE=%~dp0sim_launcher.log"

:: ---------- DEFAULTS ----------
set "RESTART_DISCORD=YES"
set "RESTART_ONEDRIVE=YES"
set "RESTART_EDGE=YES"
set "RESTART_CCLEANER=YES"
set "RESTART_ICLOUD=YES"

:: ---------- PROFILE OVERRIDE ----------
if /i "%VR_PROFILE%"=="NO_RESTART" (
    set "RESTART_DISCORD=NO"
    set "RESTART_ONEDRIVE=NO"
    set "RESTART_EDGE=NO"
    set "RESTART_CCLEANER=NO"
    set "RESTART_ICLOUD=NO"
)

if /i "%VR_PROFILE%"=="DEBUG" (
    echo [DEBUG] Profile active
)

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
		rem Standard locations without Program Files
		if exist "%%D:\Eagle Dynamics\DCS World\bin\DCS.exe" set "DCS_BIN=%%D:\Eagle Dynamics\DCS World\bin\DCS.exe"
		if exist "%%D:\DCS World\bin\DCS.exe" set "DCS_BIN=%%D:\DCS World\bin\DCS.exe"
	
		rem Add Program Files variants (x64 and x86)
		if exist "%%D:\Program Files\Eagle Dynamics\DCS World\bin\DCS.exe" set "DCS_BIN=%%D:\Program Files\Eagle Dynamics\DCS World\bin\DCS.exe"
		if exist "%%D:\Program Files (x86)\Eagle Dynamics\DCS World\bin\DCS.exe" set "DCS_BIN=%%D:\Program Files (x86)\Eagle Dynamics\DCS World\bin\DCS.exe"
	
		rem (Optional) OpenBeta variants
		if exist "%%D:\Eagle Dynamics\DCS World OpenBeta\bin\DCS.exe" set "DCS_BIN=%%D:\Eagle Dynamics\DCS World OpenBeta\bin\DCS.exe"
		if exist "%%D:\Program Files\Eagle Dynamics\DCS World OpenBeta\bin\DCS.exe" set "DCS_BIN=%%D:\Program Files\Eagle Dynamics\DCS World OpenBeta\bin\DCS.exe"
		if exist "%%D:\Program Files (x86)\Eagle Dynamics\DCS World OpenBeta\bin\DCS.exe" set "DCS_BIN=%%D:\Program Files (x86)\Eagle Dynamics\DCS World OpenBeta\bin\DCS.exe"
	)
	
	if defined DCS_BIN (
		pushd "!DCS_BIN:\DCS.exe=!"
		start "" "DCS.exe"
		popd
	) else (
		echo DCS.exe not found on scanned drives.
	)

)

:: DETECTION
set /a retry_count=0
:WAIT_GAME
set "ACTIVE_EXE="

rem ---- scan processes ----
for %%E in ("%GAME_EXE%" "DCS_mt.exe" "FlightSimulator.exe") do (
    tasklist /NH /FI "IMAGENAME eq %%~E" | find /i "%%~E" >nul
    if not errorlevel 1 set "ACTIVE_EXE=%%~E"
)

rem ---- found game ----
if defined ACTIVE_EXE (
    set "GAME_EXE=%ACTIVE_EXE%"
    echo [%TIME%] [DETECT] Process active: !GAME_EXE! >> "%LOGFILE%"
    goto GAME_DETECTED
)

rem ---- increment retry counter OUTSIDE the () block ----
set /a retry_count+=1

rem ---- echo retry using percent expansion (no delayed expansion needed) ----
echo [!] Waiting... (%retry_count%/7)

rem ---- max retries reached ----
if %retry_count% GEQ 7 (
    echo [%TIME%] [TIMEOUT] Game not found >> "%LOGFILE%"
    goto RESTORE
)

rem ---- wait and repeat ----
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

rem === Prepare ESC (ANSI escape) ===
for /F %%A in ('echo prompt $E ^| cmd') do set "ESC=%%A"

rem Foreground Yellow (33), Background Red (41)
set "HL=%ESC%[33;41m"
set "RS=%ESC%[0m"

rem --- Build the line with no newlines between segments ---
<nul set /p ="Enjoy your flight! Greetings from "
<nul set /p ="%HL% VRFLIGHTSIM GUY %RS%"
<nul set /p =", "
<nul set /p ="%HL% SHARK %RS%"
<nul set /p =" and, "
echo %HL% g0ldf1ng3R %RS%
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
    ) else (
        echo [%TIME%] [RESTORE] Discord not found, skipping >> "%LOGFILE%"
    )
)

:: --- ONEDRIVE RESTORE ---
if /i "%RESTART_ONEDRIVE%" NEQ "YES" goto SKIP_ONEDRIVE
set "OD_P="
if exist "%LocalAppData%\Microsoft\OneDrive\OneDrive.exe" set "OD_P=%LocalAppData%\Microsoft\OneDrive\OneDrive.exe"
if exist "C:\Program Files\Microsoft OneDrive\OneDrive.exe" set "OD_P=C:\Program Files\Microsoft OneDrive\OneDrive.exe"

if defined OD_P (
    echo [%TIME%] [RESTORE] OneDrive task start >> "%LOGFILE%"
    
    :: Erstellt eine Aufgabe, die ALS NUTZER (ohne Admin) startet
    schtasks /create /tn "OneDriveRestarter" /tr "\"%OD_P%\" /background" /sc once /st 00:00 /f >nul 2>&1
    schtasks /run /tn "OneDriveRestarter" >nul 2>&1
    
    :: Kurze Verzögerung, damit der Prozess Zeit zum Starten hat
    timeout /t 2 >nul
    schtasks /delete /tn "OneDriveRestarter" /f >nul 2>&1
    
    echo [%TIME%] [RESTORE] OneDrive task finished >> "%LOGFILE%"
)
:SKIP_ONEDRIVE

:: --- CCLEANER RESTORE ---
if /i "%RESTART_CCLEANER%"=="YES" if exist "C:\Program Files\CCleaner\CCleaner64.exe" (
    echo Restoring CCleaner...
    start "" "C:\Program Files\CCleaner\CCleaner64.exe" /MONITOR
)

:: --- ICLOUD RESTORE ---
if /i "%RESTART_ICLOUD%" NEQ "YES" goto SKIP_ICLOUD
echo Restoring iCloud...
:: Wir verzichten auf die 'if exist' Prüfung im WindowsApps Ordner, da diese oft Zugriffsfehler (Crash) auslöst
start explorer.exe shell:AppsFolder\AppleInc.iCloud_skh98v6769f6t^!iCloud
if exist "C:\Program Files (x86)\Common Files\Apple\Internet Services\iCloud.exe" (
    start "" "C:\Program Files (x86)\Common Files\Apple\Internet Services\iCloud.exe"
)
:SKIP_ICLOUD

echo [%TIME%] [SESSION END] >> "%LOGFILE%"
echo.
echo Operation complete. Returning to main menu...
timeout /t 5
goto PREMENU


