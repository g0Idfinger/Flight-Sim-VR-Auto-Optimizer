@echo off
setlocal EnableExtensions EnableDelayedExpansion

:: ============================================================
:: UNIVERSAL SIM VR OPTIMIZER - Configurable Edition (v7.3.3b)
:: ANSI-Optimized Edition (No PowerShell UI Calls)
:: ============================================================

:: ------------------------------------------------------------
:: FAST ANSI ESCAPE SUPPORT
:: ------------------------------------------------------------
for /f "delims=" %%A in ('echo prompt $E^| cmd') do set "ESC=%%A"

:colorEcho
setlocal
set "c=%~1"
set "t=%~2"
<nul set /p "=%ESC%[%c%m%t%%ESC%[0m"
echo.
endlocal
goto :eof

:: Paths & Files
set "SCRIPT_DIR=%~dp0"
set "LOGFILE=%SCRIPT_DIR%sim_launcher.log"
set "CFG=%SCRIPT_DIR%vr_opt.cfg"

:: -----------------------------
:: Load (or create) configuration
:: -----------------------------
call :load_config

:: -----------------------------
:: Optional auto-run on start
:: -----------------------------
if /i "!AUTO_RUN_ON_START!"=="YES" (
    if defined DEFAULT_SIM (
        call :RESOLVE_SIM "!DEFAULT_SIM!"
        if defined choice (
            call :ADMIN_START
            goto PREP_FLOW
        )
    )
)

:: ============================================================
:: MAIN MENU
:: ============================================================
:MAIN_MENU
cls
call :colorEcho 36 "============================================================"
call :colorEcho 36 "        VR AUTO-OPTIMIZER - MAIN MENU"
call :colorEcho 36 "============================================================"
echo.

call :colorEcho 32 "[1] Launch Simulator (manual selection)"
call :colorEcho 33 "[2] Configure App Controls"
echo.
call :colorEcho 31 "[X] Exit"
echo.

set /p _main_choice="Selection: "
if /i "%_main_choice%"=="1" goto MENU
if /i "%_main_choice%"=="2" goto CONFIG_MENU
if /i "%_main_choice%"=="X" exit /b
goto MAIN_MENU

:: ============================================================
:: DEFAULT SIM LAUNCH
:: ============================================================
:LAUNCH_DEFAULT_OR_SET
if defined DEFAULT_SIM (
    call :RESOLVE_SIM "!DEFAULT_SIM!"
    if not defined choice (
        echo [!] DEFAULT_SIM value "!DEFAULT_SIM!" is invalid. Press any key to set a valid one...
        pause >nul
        goto SET_DEFAULT_SIM_AND_LAUNCH
    )
    call :ADMIN_START
    goto PREP_FLOW
) else (
    goto SET_DEFAULT_SIM_AND_LAUNCH
)

:: ============================================================
:: RESOLVE SIM SELECTION
:: ============================================================
:RESOLVE_SIM
set "choice=%~1"
set "LAUNCH_METHOD=STEAM"

if "%choice%"=="1" (
    set "STEAM_APPID=2537590" & set "GAME_EXE=FlightSimulator2024.exe" & set "VERSION_NAME=MSFS 2024 (Steam)"
) else if "%choice%"=="2" (
    set "STEAM_APPID=1250410" & set "GAME_EXE=FlightSimulator.exe" & set "VERSION_NAME=MSFS 2020 (Steam)"
) else if "%choice%"=="3" (
    set "STEAM_APPID=223750" & set "GAME_EXE=DCS.exe" & set "VERSION_NAME=DCS World (Steam)"
) else if "%choice%"=="5" (
    set "LAUNCH_METHOD=STORE" & set "GAME_EXE=FlightSimulator2024.exe" & set "VERSION_NAME=MSFS 2024 Store"
    for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "$p = Get-AppxPackage | Where-Object { ($_.Name -match 'Limitless' -or $_.Name -match 'MicrosoftFlightSimulator' -or $_.Name -match 'FlightSimulator') -and $_.Name -notmatch '2020' }; if($p){ $p.PackageFamilyName }" 2^>nul`) do set "STORE_URI=shell:AppsFolder\%%A^!App"
    if "!STORE_URI!"=="" set "STORE_URI=shell:AppsFolder\Microsoft.Limitless_8wekyb3d8bbwe^!App -FastLaunch"
) else if "%choice%"=="6" (
    set "LAUNCH_METHOD=STORE" & set "STORE_URI=shell:AppsFolder\Microsoft.FlightSimulator_8wekyb3d8bbwe^!App -FastLaunch"
    set "GAME_EXE=FlightSimulator.exe" & set "VERSION_NAME=MSFS 2020 (Store)"
) else if "%choice%"=="7" (
    set "LAUNCH_METHOD=DCS_STORE" & set "GAME_EXE=DCS.exe" & set "VERSION_NAME=DCS World (Standalone)"
) else if "%choice%"=="8" (
    set "STEAM_APPID=2014780"
    set "GAME_EXE=X-Plane.exe"
    set "VERSION_NAME=X-Plane 12 (Steam)"
) else if "%choice%"=="9" (
    set "LAUNCH_METHOD=XPLANE_STANDALONE"
    set "GAME_EXE=X-Plane.exe"
    set "VERSION_NAME=X-Plane 12 (Standalone)"
) else (
    if not defined VERSION_NAME set "choice="
)
goto :eof

:: ============================================================
:: SIMULATOR SELECTION MENU
:: ============================================================
:MENU
cls
call :colorEcho 36 "============================================================"
call :colorEcho 36 "     VR AUTO-OPTIMIZER - SELECT YOUR SIMULATOR"
call :colorEcho 36 "============================================================"
echo.

call :colorEcho 32 "[1] MSFS 2024 (Steam)"
call :colorEcho 32 "[2] MSFS 2020 (Steam)"
call :colorEcho 32 "[3] DCS World (Steam)"
call :colorEcho 32 "[8] X-Plane 12 (Steam)"
echo.
call :colorEcho 33 "[5] MSFS 2024 (Store/GamePass)"
call :colorEcho 33 "[6] MSFS 2020 (Store/GamePass)"
call :colorEcho 33 "[7] DCS World (Standalone)"
call :colorEcho 33 "[9] X-Plane 12 (Standalone)"
echo.
call :colorEcho 37 "[B] Back to Main Menu"
call :colorEcho 31 "[X] Exit"
echo.

set /p choice="Selection (1-9/B/X): "

if /i "%choice%"=="X" exit /b
if /i "%choice%"=="B" goto MAIN_MENU

call :RESOLVE_SIM "%choice%"
if not defined choice goto MENU

call :ADMIN_START
goto PREP_FLOW

:: ============================================================
:: PREP FLOW
:: ============================================================
:PREP_FLOW
echo [1/4] Preparing system...
for /f "tokens=3 delims=:()" %%G in ('powercfg /getactivescheme ^| findstr /I "GUID"') do set "PREV_PWR=%%G"
call :ensure_ultimate
echo [%TIME%] [PREP] Power Plan active: %VERSION_NAME% >> "%LOGFILE%"

call :kill_if "OneDrive.exe"       "!KILL_ONEDRIVE!"       "OneDrive killed"
call :kill_if "msedge.exe"         "!KILL_EDGE!"           "Edge killed"
call :kill_if "CCleaner64.exe"     "!KILL_CCLEANER!"       "CCleaner killed"
call :kill_if "iCloudServices.exe" "!KILL_ICLOUDSERVICES!" "iCloudServices killed"
call :kill_if "iCloudDrive.exe"    "!KILL_ICLOUDDRIVE!"    "iCloudDrive killed"

call :kill_custom

net stop SysMain /y >nul 2>&1
net stop Spooler /y >nul 2>&1
nvidia-smi -pm 1 >nul 2>&1
ipconfig /flushdns >nul

if exist "C:\Program Files\Virtual Desktop Streamer\VirtualDesktop.Streamer.exe" (
    echo [2/4] Launching VR...
    echo [%TIME%] [VR] Streamer started >> "%LOGFILE%"
    start "" "C:\Program Files\Virtual Desktop Streamer\VirtualDesktop.Streamer.exe"
    timeout /t 8 >nul
)

:: ============================================================
:: LAUNCH SIM
:: ============================================================
if "%LAUNCH_METHOD%"=="STEAM" (
    start "" "steam://run/%STEAM_APPID%"
) else if "%LAUNCH_METHOD%"=="STORE" (
    echo [%TIME%] [LAUNCH] Store-URI: !STORE_URI! >> "%LOGFILE%"
    powershell -NoProfile -Command "explorer.exe $env:STORE_URI"
) else if "%LAUNCH_METHOD%"=="DCS_STORE" (
    set "DCS_BIN="
    for %%D in (C D E F G H I J) do (
        if exist "%%D:\Eagle Dynamics\DCS World\bin-mt\DCS.exe" set "DCS_BIN=%%D:\Eagle Dynamics\DCS World\bin-mt\DCS.exe"
        if exist "%%D:\DCS World\bin-mt\DCS.exe" set "DCS_BIN=%%D:\DCS World\bin-mt\DCS.exe"
    )
    if defined DCS_BIN (
        pushd "!DCS_BIN:\DCS.exe=!"
        start "" "DCS.exe"
        popd
    )
) else if "%LAUNCH_METHOD%"=="XPLANE_STANDALONE" (
    set "XPLANE_PATH="
    for %%D in (C D E F G H I J) do (
        if exist "%%D:\X-Plane 12\X-Plane.exe" (
            set "XPLANE_PATH=%%D:\X-Plane 12"
            goto XP_FOUND
        )
    )
    :XP_FOUND
    if defined XPLANE_PATH (
        pushd "!XPLANE_PATH!"
        start "" "X-Plane.exe"
        popd
    ) else (
        echo [%TIME%] [ERROR] X-Plane 12 Standalone not found >> "%LOGFILE%"
        echo X-Plane 12 Standalone not found!
        timeout /t 3 >nul
        goto RESTORE
    )
)

:: ============================================================
:: GAME DETECTION
:: ============================================================
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
  "$n='%GAME_EXE%'.Replace('.exe','');" ^
  "$p=Get-Process $n -ErrorAction SilentlyContinue;" ^
  "if($p){" ^
  "  try {" ^
  "    $p.PriorityClass='High';" ^
  "    $cpu=Get-CimInstance Win32_Processor;" ^
  "    $cores=$cpu.NumberOfCores;" ^
  "    $logical=$cpu.NumberOfLogicalProcessors;" ^
  "    $mask=[int64]0;" ^
  "    if($logical -gt $cores){" ^
  "      for($i=0; $i -lt $cores; $i++){ $mask += [int64][math]::Pow(2,$i*2) }" ^
  "    } else {" ^
  "      for($i=0; $i -lt $cores; $i++){ $mask += [int64][math]::Pow(2,$i) }" ^
  "    };" ^
  "    $p.ProcessorAffinity=[IntPtr]$mask;" ^
  "    Write-Host 'Optimized Performance' -ForegroundColor Cyan" ^
  "  } catch { Write-Host 'Affinity partially applied' -ForegroundColor Green }" ^
  "}"

call :colorEcho 36 "============================================================"
call :colorEcho 36 "   %VERSION_NAME% RUNNING - DO NOT CLOSE THIS WINDOW"
call :colorEcho 36 "============================================================"
echo.

echo Enjoy your flight!
echo.

:WAIT_EXIT
timeout /t 15 >nul
tasklist /NH /FI "IMAGENAME eq %GAME_EXE%" | find /i "%GAME_EXE%" >nul
if not errorlevel 1 goto WAIT_EXIT
echo [%TIME%] [DETECT] %GAME_EXE% exited >> "%LOGFILE%"
goto RESTORE

:: ============================================================
:: RESTORE SYSTEM
:: ============================================================
:RESTORE
echo [4/4] Restoring system...
echo [%TIME%] [RESTORE] Starting Cleanup >> "%LOGFILE%"

net start SysMain /y >nul 2>&1
net start Spooler /y >nul 2>&1
nvidia-smi -pm 0 >nul 2>&1

if defined PREV_PWR (
    powercfg /setactive %PREV_PWR% >nul 2>&1
) else (
    powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e >nul 2>&1
)

echo [%TIME%] [RESTORE] System reverted >> "%LOGFILE%"

if /i "!RESTART_EDGE!"=="YES" call :restart_edge
if /i "!RESTART_DISCORD!"=="YES" call :restart_discord
if /i "!RESTART_ONEDRIVE!"=="YES" call :restart_onedrive
if /i "!RESTART_CCLEANER!"=="YES" call :restart_ccleaner
if /i "!RESTART_ICLOUD!"=="YES" call :restart_icloud

call :restart_custom

echo [SESSION END] %DATE% %TIME% >> "%LOGFILE%"
echo.
echo Operation complete. Returning to main menu...
timeout /t 5 >nul
goto MAIN_MENU

:: ============================================================
:: CONFIGURATION MENU
:: ============================================================
:CONFIG_MENU
cls
call :colorEcho 36 "============================================================"
call :colorEcho 36 "        CONFIGURATION - APP CONTROLS"
call :colorEcho 36 "============================================================"
echo.

call :colorEcho 33 "KILL FLAGS:"
echo  [1] OneDrive        = !KILL_ONEDRIVE!
echo  [2] Discord         = !KILL_DISCORD!
echo  [3] Chrome          = !KILL_CHROME!
echo  [4] Edge            = !KILL_EDGE!
echo  [5] CCleaner        = !KILL_CCLEANER!
echo  [6] iCloudServices  = !KILL_ICLOUDSERVICES!
echo  [7] iCloudDrive     = !KILL_ICLOUDDRIVE!
echo.

call :colorEcho 32 "RESTART FLAGS:"
echo  [8]  Restart Edge     = !RESTART_EDGE!
echo  [9]  Restart Discord  = !RESTART_DISCORD!
echo  [10] Restart OneDrive = !RESTART_ONEDRIVE!
echo  [11] Restart CCleaner = !RESTART_CCLEANER!
echo  [12] Restart iCloud   = !RESTART_ICLOUD!
echo.

call :colorEcho 36 "DEFAULTS:"
echo  [D] Set default sim (current: !DEFAULT_SIM!)
echo  [A] Toggle auto-run on start (AUTO_RUN_ON_START = !AUTO_RUN_ON_START!)
echo.

call :colorEcho 33 "[C] Manage custom apps"
call :colorEcho 32 "[S] Save and return"
call :colorEcho 37 "[B] Back without saving"
echo.

set /p _cfg_choice="Selection: "
if /i "%_cfg_choice%"=="S" ( call :save_config & goto MAIN_MENU )
if /i "%_cfg_choice%"=="B" ( goto MAIN_MENU )
if /i "%_cfg_choice%"=="C" ( goto CUSTOM_MENU )
if /i "%_cfg_choice%"=="D" ( goto SET_DEFAULT_SIM )
if /i "%_cfg_choice%"=="A" ( call :toggle AUTO_RUN_ON_START & goto CONFIG_MENU )

if "%_cfg_choice%"=="1"  call :toggle KILL_ONEDRIVE
if "%_cfg_choice%"=="4"  call :toggle KILL_EDGE
if "%_cfg_choice%"=="5"  call :toggle KILL_CCLEANER
if "%_cfg_choice%"=="6"  call :toggle KILL_ICLOUDSERVICES
if "%_cfg_choice%"=="7"  call :toggle KILL_ICLOUDDRIVE
if "%_cfg_choice%"=="8"  call :toggle RESTART_EDGE
if "%_cfg_choice%"=="9"  call :toggle RESTART_DISCORD
if "%_cfg_choice%"=="10" call :toggle RESTART_ONEDRIVE
if "%_cfg_choice%"=="11" call :toggle RESTART_CCLEANER
if "%_cfg_choice%"=="12" call :toggle RESTART_ICLOUD
goto CONFIG_MENU

:: ============================================================
:: SET DEFAULT SIM
:: ============================================================
:SET_DEFAULT_SIM
cls
call :colorEcho 36 "============================================================"
call :colorEcho 36 "        SET DEFAULT SIM (1..9)"
call :colorEcho 36 "============================================================"
echo.

echo 
