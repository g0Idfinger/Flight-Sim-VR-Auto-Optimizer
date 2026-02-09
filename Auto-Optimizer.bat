@echo off
setlocal EnableExtensions EnableDelayedExpansion

:: ============================================================
:: UNIVERSAL SIM VR OPTIMIZER - Configurable Edition (v7.3.3.7b)
:: Optimized
:: ============================================================

:: Paths & Files
set "SCRIPT_DIR=%~dp0"
set "LOGFILE=%SCRIPT_DIR%sim_launcher.log"
set "CFG=%SCRIPT_DIR%vr_opt.cfg"

:: ------------- ANSI init (once) -------------
for /F %%a in ('echo prompt $E^| cmd') do set "ESC=%%a"

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

:: -----------------------------
:: Main Menu
:: -----------------------------
:MAIN_MENU
cls
echo ============================================================
echo %ESC%[36m        VR AUTO-OPTIMIZER - MAIN MENU%ESC%[0m
echo ============================================================
echo.
echo %ESC%[32m[1] Launch Simulator (manual selection)%ESC%[0m
echo %ESC%[33m[2] Configure App Controls%ESC%[0m
echo.
echo %ESC%[31m[X] Exit%ESC%[0m
echo.

set /p _main_choice="Selection: "
if /i "%_main_choice%"=="1" goto MENU
if /i "%_main_choice%"=="2" goto CONFIG_MENU
if /i "%_main_choice%"=="X" exit /b
goto MAIN_MENU

:: -----------------------------
:: Launch default if set; else prompt to set, then launch
:: -----------------------------
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

:: -----------------------------
:: Resolve sim by selection (1..13)
:: -----------------------------
:RESOLVE_SIM
set "choice=%~1"
set "LAUNCH_METHOD=STEAM"
set "STEAM_APPID="
set "STORE_URI="
set "GAME_EXE="
set "VERSION_NAME="

if "%choice%"=="1" (
    set "STEAM_APPID=2537590" & set "GAME_EXE=FlightSimulator2024.exe" & set "VERSION_NAME=MSFS 2024 (Steam)"
) else if "%choice%"=="2" (
    set "STEAM_APPID=1250410" & set "GAME_EXE=FlightSimulator.exe" & set "VERSION_NAME=MSFS 2020 (Steam)"
) else if "%choice%"=="3" (
    set "STEAM_APPID=223750" & set "GAME_EXE=DCS.exe" & set "VERSION_NAME=DCS World (Steam)"
) else if "%choice%"=="5" (
    set "LAUNCH_METHOD=STORE" & set "STORE_URI=shell:AppsFolder\Microsoft.Limitless_8wekyb3d8bbwe^!App"
    set "GAME_EXE=FlightSimulator2024.exe" & set "VERSION_NAME=MSFS 2024 (Store)"
) else if "%choice%"=="6" (
    set "LAUNCH_METHOD=STORE" & set "STORE_URI=shell:AppsFolder\Microsoft.FlightSimulator_8wekyb3d8bbwe^!App"
    set "GAME_EXE=FlightSimulator.exe" & set "VERSION_NAME=MSFS 2020 (Store)"
) else if "%choice%"=="7" (
    set "LAUNCH_METHOD=DCS_STORE" & set "GAME_EXE=DCS.exe" & set "VERSION_NAME=DCS World (Standalone)"
) else if "%choice%"=="8" (
    set "STEAM_APPID=2014780" & set "GAME_EXE=X-Plane.exe" & set "VERSION_NAME=X-Plane 12 (Steam)"
) else if "%choice%"=="9" (
    set "LAUNCH_METHOD=XPLANE_STANDALONE" & set "GAME_EXE=X-Plane.exe" & set "VERSION_NAME=X-Plane 12 (Standalone)"
) else if "%choice%"=="10" (
    set "GAME_EXE=AssettoCorsaEVO.exe" & set "VERSION_NAME=Assetto Corsa EVO (VR)" & set "LAUNCH_METHOD=VR_ACE"
) else if "%choice%"=="11" (
    set "GAME_EXE=AssettoCorsaEVO.exe" & set "VERSION_NAME=Assetto Corsa EVO (2D)" & set "LAUNCH_METHOD=ACE_2D"
) else if "%choice%"=="12" (
    set "LAUNCH_METHOD=AMS2_OC" & set "VERSION_NAME=Automobilista 2 (VR - OpenComposite)"
) else if "%choice%"=="13" (
    set "LAUNCH_METHOD=AMS2_2D" & set "VERSION_NAME=Automobilista 2 (2D)"
) else (
    if not defined VERSION_NAME set "choice="
)
goto :eof

:: -----------------------------
:: Simulator Menu (manual picker)
:: -----------------------------
:MENU
cls
echo ============================================================
echo %ESC%[36m     VR AUTO-OPTIMIZER - SELECT YOUR SIMULATOR%ESC%[0m
echo ============================================================
echo.
echo %ESC%[32m[1] MSFS 2024 (Steam)%ESC%[0m
echo %ESC%[32m[2] MSFS 2020 (Steam)%ESC%[0m
echo %ESC%[32m[3] DCS World (Steam)%ESC%[0m
echo %ESC%[32m[8] X-Plane 12 (Steam)%ESC%[0m
echo.
echo %ESC%[33m[5] MSFS 2024 (Store / GamePass)%ESC%[0m
echo %ESC%[33m[6] MSFS 2020 (Store / GamePass)%ESC%[0m
echo %ESC%[33m[7] DCS World (Standalone)%ESC%[0m
echo %ESC%[33m[9] X-Plane 12 (Standalone)%ESC%[0m
echo %ESC%[32m[10] Assetto Corsa EVO (VR OpenXR)%ESC%[0m
echo %ESC%[33m[11] Assetto Corsa EVO (2D)%ESC%[0m
echo %ESC%[32m[12] Automobilista 2 (VR - OpenComposite)%ESC%[0m
echo %ESC%[33m[13] Automobilista 2 (2D)%ESC%[0m
echo.
echo %ESC%[37m[B] Back to Main Menu%ESC%[0m
echo %ESC%[31m[X] Exit%ESC%[0m
echo.

set /p choice="Selection (1-13/B/X): "
if /i "%choice%"=="X" exit /b
if /i "%choice%"=="B" goto MAIN_MENU

call :RESOLVE_SIM "%choice%"
if not defined choice goto MENU

call :ADMIN_START
goto PREP_FLOW

:PREP_FLOW
:: -----------------------------
:: [1/4] PREP (driven by config)
:: -----------------------------
echo [1/4] Preparing system...
for /f "tokens=3 delims=:()" %%G in ('powercfg /getactivescheme ^| findstr /I "GUID"') do set "PREV_PWR=%%G"
call :ensure_ultimate
echo [%TIME%] [PREP] Power Plan active: %VERSION_NAME% >> "%LOGFILE%"

:: Built-in app kills (toggleable)
call :kill_if "OneDrive.exe"       "!KILL_ONEDRIVE!"       "OneDrive killed"
call :kill_if "Discord.exe"        "!KILL_DISCORD!"        "Discord killed"
call :kill_if "chrome.exe"         "!KILL_CHROME!"         "Chrome killed"
call :kill_if "msedge.exe"         "!KILL_EDGE!"           "Edge killed"
call :kill_if "CCleaner64.exe"     "!KILL_CCLEANER!"       "CCleaner killed"
call :kill_if "iCloudServices.exe" "!KILL_ICLOUDSERVICES!" "iCloudServices killed"
call :kill_if "iCloudDrive.exe"    "!KILL_ICLOUDDRIVE!"    "iCloudDrive killed"

:: Custom app kills (CUST_K_1..N)
call :kill_custom

:: Optional service/network prep
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
if "%LAUNCH_METHOD%"=="STEAM" (
    start "" "steam://run/%STEAM_APPID%"
)

if "%LAUNCH_METHOD%"=="STORE" (
    echo [%TIME%] [LAUNCH] Store-URI: !STORE_URI! >> "%LOGFILE%"
    powershell -NoProfile -Command "Start-Process $env:STORE_URI -ArgumentList ' -FastLaunch'"
)


if "%LAUNCH_METHOD%"=="DCS_STORE" (
    set "DCS_BIN="
    set "DCS_UPD="
    set "DEBUG_DCS=1"

    rem --- 0) Registry probe for the install root (bin first) ---
    if not defined DCS_BIN (
        call :dcs_from_registry DCS_ROOT
        if defined DCS_ROOT (
            if exist "!DCS_ROOT!\bin\DCS.exe" set "DCS_BIN=!DCS_ROOT!\bin\DCS.exe"
            if not defined DCS_BIN if exist "!DCS_ROOT!\bin\DCS_updater.exe" set "DCS_UPD=!DCS_ROOT!\bin\DCS_updater.exe"
            if not defined DCS_BIN if exist "!DCS_ROOT!\bin-mt\DCS.exe" set "DCS_BIN=!DCS_ROOT!\bin-mt\DCS.exe"
            if defined DCS_BIN echo [%TIME%] [DCS_REG] Root=!DCS_ROOT! Bin=!DCS_BIN!>>"%LOGFILE%"
            if not defined DCS_BIN if defined DCS_UPD echo [%TIME%] [DCS_REG] Root=!DCS_ROOT! Upd=!DCS_UPD!>>"%LOGFILE%"
        ) else (
            echo [%TIME%] [DCS_REG] No registry root found>>"%LOGFILE%"
        )
    )

    rem --- 1) Drive scan (bin first, then bin-mt), all common layouts ---
    if not defined DCS_BIN call :find_on_drives_pf "Eagle Dynamics\DCS World\bin\DCS.exe" DCS_BIN
    if not defined DCS_BIN call :find_on_drives_pf "Eagle Dynamics\DCS World\bin-mt\DCS.exe" DCS_BIN

    if not defined DCS_BIN call :find_on_drives_pf "Eagle Dynamics\DCS World OpenBeta\bin\DCS.exe" DCS_BIN
    if not defined DCS_BIN call :find_on_drives_pf "Eagle Dynamics\DCS World OpenBeta\bin-mt\DCS.exe" DCS_BIN

    if not defined DCS_BIN call :find_on_drives_pf "Eagle Dynamics\DCS World Open Beta\bin\DCS.exe" DCS_BIN
    if not defined DCS_BIN call :find_on_drives_pf "Eagle Dynamics\DCS World Open Beta\bin-mt\DCS.exe" DCS_BIN

    rem --- 1b) Fallback to updater (bin first), all common layouts ---
    if not defined DCS_BIN call :find_on_drives_pf "Eagle Dynamics\DCS World\bin\DCS_updater.exe" DCS_UPD
    if not defined DCS_UPD call :find_on_drives_pf "Eagle Dynamics\DCS World OpenBeta\bin\DCS_updater.exe" DCS_UPD
    if not defined DCS_UPD call :find_on_drives_pf "Eagle Dynamics\DCS World Open Beta\bin\DCS_updater.exe" DCS_UPD

    rem --- 2) Launch using the full path (no pushd/popd) ---
    if defined DCS_BIN (
        echo [%TIME%] [LAUNCH] DCS path: !DCS_BIN!>>"%LOGFILE%"
        start "" "!DCS_BIN!"
    ) else if defined DCS_UPD (
        echo [%TIME%] [LAUNCH] DCS via updater: !DCS_UPD!>>"%LOGFILE%"
        start "" "!DCS_UPD!"
    ) else (
        echo [%TIME%] [ERROR] DCS Standalone not found>>"%LOGFILE%"
        echo DCS Standalone not found!
        timeout /t 3 >nul
        goto RESTORE
    )
)


if "%LAUNCH_METHOD%"=="XPLANE_STANDALONE" (
    call :find_on_drives "X-Plane 12\X-Plane.exe" XPLANE_EXE
    if defined XPLANE_EXE (
        pushd "!XPLANE_EXE:\X-Plane.exe=!"
        start "" "X-Plane.exe"
        popd
    ) else (
        echo [%TIME%] [ERROR] X-Plane 12 Standalone not found >> "%LOGFILE%"
        echo X-Plane 12 Standalone not found!
        timeout /t 3 >nul
        goto RESTORE
    )
)

if "%LAUNCH_METHOD%"=="AMS2_OC" (
    echo [%TIME%] [LAUNCH] Starting Automobilista 2 VR >> "%LOGFILE%"
    call :find_on_drives "Program Files (x86)\Steam\steamapps\common\Automobilista 2\AMS2AVX.exe" AMS2_EXE
    if not defined AMS2_EXE call :find_on_drives "Program Files (x86)\Steam\steamapps\common\Automobilista 2\ams2.exe" AMS2_EXE
    if defined AMS2_EXE (
        pushd "!AMS2_EXE:\AMS2AVX.exe=!"
        start "" "AMS2AVX.exe" -vr -openvr
        popd
    ) else (
        echo [%TIME%] [ERROR] AMS2AVX.exe not found >> "%LOGFILE%"
        timeout /t 3 >nul
        goto RESTORE
    )
)

if "%LAUNCH_METHOD%"=="AMS2_2D" (
    echo [%TIME%] [LAUNCH] Starting Automobilista 2 2D >> "%LOGFILE%"
    call :find_on_drives "Program Files (x86)\Steam\steamapps\common\Automobilista 2\AMS2.exe" AMS2_EXE
    if defined AMS2_EXE (
        pushd "!AMS2_EXE:\AMS2.exe=!"
        start "" "AMS2.exe"
        popd
    ) else (
        echo [%TIME%] [ERROR] AMS2.exe not found >> "%LOGFILE%"
        timeout /t 3 >nul
        goto RESTORE
    )
)

if "%LAUNCH_METHOD%"=="VR_ACE" (
    if not defined GAME_EXE (
        echo [%TIME%] [ERROR] GAME_EXE not defined >> "%LOGFILE%"
        goto RESTORE
    )
    call :find_on_drives "Program Files (x86)\Steam\steamapps\common\Assetto Corsa EVO\%GAME_EXE%" ACE_EXE
    if defined ACE_EXE (
        echo [%TIME%] [LAUNCH] Starting Assetto Corsa EVO VR >> "%LOGFILE%"
        start "" "!ACE_EXE!" -vr -openxr
    ) else (
        echo [%TIME%] [ERROR] Assetto Corsa EVO not found >> "%LOGFILE%"
        timeout /t 3 >nul
        goto RESTORE
    )
)

if "%LAUNCH_METHOD%"=="ACE_2D" (
    if not defined GAME_EXE goto RESTORE
    call :find_on_drives "Program Files (x86)\Steam\steamapps\common\Assetto Corsa EVO\%GAME_EXE%" ACE_EXE
    if defined ACE_EXE (
        echo [%TIME%] [LAUNCH] Starting Assetto Corsa EVO 2D >> "%LOGFILE%"
        start "" "!ACE_EXE!"
    ) else (
        echo [%TIME%] [ERROR] Assetto Corsa EVO not found >> "%LOGFILE%"
        timeout /t 3 >nul
        goto RESTORE
    )
)

:: DETECTION
set /a retry_count=0
:WAIT_GAME
set "ACTIVE_EXE="
for %%E in (
 "%GAME_EXE%"
 "FlightSimulator2024.exe"
 "FlightSimulator.exe"
 "AMS2AVX.exe"
 "AMS2.exe"
 "AssettoCorsaEVO.exe"
 "DCS_mt.exe"
 "DCS.exe"
) do (
    tasklist /NH /FI "IMAGENAME eq %%~E" | find /i "%%~E" >nul
    if not errorlevel 1 set "ACTIVE_EXE=%%~E"
)
if defined ACTIVE_EXE (
    set "GAME_EXE=%ACTIVE_EXE%"
    echo [%TIME%] [DETECT] Process active: !GAME_EXE! >> "%LOGFILE%"
    goto GAME_DETECTED
)
set /a retry_count+=1
echo [^^!] Waiting... (!retry_count!/7)
if !retry_count! GEQ 7 (
    echo [%TIME%] [TIMEOUT] Game not found >> "%LOGFILE%"
    goto RESTORE
)
timeout /t 5 >nul
goto WAIT_GAME

:: -----------------------------
:: CPU Vendor / Affinity / X3D-Aware Block
:: -----------------------------
:GAME_DETECTED
echo [!] %GAME_EXE% detected. Optimizing Performance...

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$exe='%GAME_EXE%'.Replace('.exe','');" ^
  "$p=Get-Process $exe -ErrorAction SilentlyContinue;" ^
  "if(-not $p){ exit }" ^
  "" ^
  "$cpu = Get-CimInstance Win32_Processor;" ^
  "$vendor = $cpu.Manufacturer;" ^
  "$name   = $cpu.Name;" ^
  "$l3     = $cpu.L3CacheSize;" ^
  "$cores  = $cpu.NumberOfCores;" ^
  "$logical = $cpu.NumberOfLogicalProcessors;" ^
  "" ^
  "$isIntel = $vendor -match 'Intel';" ^
  "$isAMD   = $vendor -match 'AMD';" ^
  "$isX3D   = ($name -match 'X3D') -or ($l3 -ge 65536);" ^
  "" ^
  "try { $p.PriorityClass = 'High' } catch {}" ^
  "" ^
  "if($isIntel){" ^
  "  if($logical -gt $cores){" ^
  "    $mask=[int64]0;" ^
  "    for($i=0;$i -lt $cores;$i++){ $mask += [int64][math]::Pow(2,$i*2) }" ^
  "    try { $p.ProcessorAffinity=[IntPtr]$mask } catch {}" ^
  "    Write-Host '[CPU] Intel Hybrid – P-Core affinity applied' -ForegroundColor Cyan" ^
  "  } else {" ^
  "    Write-Host '[CPU] Intel CPU – no hybrid, priority only' -ForegroundColor Cyan" ^
  "  }" ^
  "} elseif($isAMD -and $isX3D){" ^
  "  Write-Host '[CPU] AMD X3D detected – CCD/UMA aware, affinity skipped (cache-safe)' -ForegroundColor Green" ^
  "} elseif($isAMD){" ^
  "  Write-Host '[CPU] AMD non-X3D – scheduler-managed, priority only' -ForegroundColor Green" ^
  "} else {" ^
  "  Write-Host '[CPU] Unknown CPU – priority only' -ForegroundColor Yellow" ^
  "}" ^
  "" ^
  "$strategy = if($isIntel -and $logical -gt $cores) {'P-Cores'} elseif($isAMD -and $isX3D) {'CCD-aware'} else {'Scheduler-managed'};" ^
  "Add-Content -Path '%LOGFILE%' -Value ('[%TIME%] [CPU] Vendor=' + $vendor + ' Model=' + $name + ' Priority=High Strategy=' + $strategy)"

echo ============================================================
echo %VERSION_NAME% RUNNING - DO NOT CLOSE THIS WINDOW

setlocal DisableDelayedExpansion
<nul set /p "=%ESC%[0mEnjoy your flight! Greetings from "
<nul set /p "=%ESC%[33;41m VRFLIGHTSIM GUY %ESC%[0m"
<nul set /p "=%ESC%[0m , "
<nul set /p "=%ESC%[34;47m SHARK %ESC%[0m"
<nul set /p "=%ESC%[0m and, "
echo %ESC%[31;43m g0^|df^!ng3R %ESC%[0m
endlocal

echo ============================================================

:WAIT_EXIT
timeout /t 15 >nul
tasklist /NH /FI "IMAGENAME eq %GAME_EXE%" | find /i "%GAME_EXE%" >nul
if not errorlevel 1 goto WAIT_EXIT
echo [%TIME%] [DETECT] %GAME_EXE% exited >> "%LOGFILE%"
goto RESTORE

:: -----------------------------
:: Ensure Ultimate Performance power plan
:: -----------------------------
:ensure_ultimate
setlocal EnableDelayedExpansion
set "ULT_BUILTIN=e9a42b02-d5df-448d-aa00-03f14749eb61"
set "ULT_GUID="

powercfg /list | findstr /I "%ULT_BUILTIN%" >nul
if not errorlevel 1 (
    set "ULT_GUID=%ULT_BUILTIN%"
) else (
    for /f "tokens=3 delims=:()" %%G in ('
        powercfg -duplicatescheme %ULT_BUILTIN% 2^>nul ^| findstr /I "GUID"
    ') do set "ULT_GUID=%%G"
)

if defined ULT_GUID (
    powercfg /setactive !ULT_GUID! >nul 2>&1
    if not errorlevel 1 (
        echo [%TIME%] [PREP] Power Plan active: Ultimate Performance (!ULT_GUID!)>>"%LOGFILE%"
        endlocal & goto :eof
    )
)

echo [%TIME%] [PREP] Ultimate unavailable/failed; falling back to High Performance>>"%LOGFILE%"
powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c >nul 2>&1
endlocal & goto :eof

:: -----------------------------
:: [4/4] RESTORE (driven by config)
:: -----------------------------
:RESTORE
echo [4/4] Restoring system...
echo [%TIME%] [RESTORE] Starting Cleanup >> "%LOGFILE%"
::taskkill /f /im VirtualDesktop.Streamer.exe >nul 2>&1
net start SysMain /y >nul 2>&1
net start Spooler /y >nul 2>&1
nvidia-smi -pm 0 >nul 2>&1

if defined PREV_PWR (
    powercfg /setactive %PREV_PWR% >nul 2>&1
) else (
    powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e >nul 2>&1
)

echo [%TIME%] [RESTORE] System reverted >> "%LOGFILE%"

:: Built-in restarts
if /i "!RESTART_EDGE!"=="YES" call :restart_edge
if /i "!RESTART_DISCORD!"=="YES" call :restart_discord
if /i "!RESTART_ONEDRIVE!"=="YES" call :restart_onedrive
if /i "!RESTART_CCLEANER!"=="YES" call :restart_ccleaner
if /i "!RESTART_ICLOUD!"=="YES" call :restart_icloud
if /i "!RESTART_CHROME!"=="YES" call :restart_chrome

:: Custom restarts (CUST_R_CMD_i + CUST_R_ARGS_i)
call :restart_custom

echo [SESSION END] %DATE% %TIME% >> "%LOGFILE%"
echo.
echo Operation complete. Returning to main menu...
timeout /t 5 >nul
goto MAIN_MENU

:: ============================================================
::               CONFIGURATION MENUS & HELPERS
:: ============================================================
:CONFIG_MENU
cls
echo ============================================================
echo %ESC%[36m        CONFIGURATION - APP CONTROLS%ESC%[0m
echo ============================================================
echo.
echo %ESC%[33mKILL FLAGS:%ESC%[0m
echo  [1] OneDrive        = !KILL_ONEDRIVE!
echo  [2] Discord         = !KILL_DISCORD!
echo  [3] Chrome          = !KILL_CHROME!
echo  [4] Edge            = !KILL_EDGE!
echo  [5] CCleaner        = !KILL_CCLEANER!
echo  [6] iCloudServices  = !KILL_ICLOUDSERVICES!
echo  [7] iCloudDrive     = !KILL_ICLOUDDRIVE!
echo.
echo %ESC%[32mRESTART FLAGS:%ESC%[0m
echo  [8]  Restart Edge     = !RESTART_EDGE!
echo  [9]  Restart Discord  = !RESTART_DISCORD!
echo  [10] Restart OneDrive = !RESTART_ONEDRIVE!
echo  [11] Restart CCleaner = !RESTART_CCLEANER!
echo  [12] Restart iCloud   = !RESTART_ICLOUD!
echo  [13] Restart Chrome   = !RESTART_CHROME!
echo.
echo %ESC%[36mDEFAULTS:%ESC%[0m
echo  [D] Set default sim (current: !DEFAULT_SIM!)
echo  [A] Toggle auto-run on start (AUTO_RUN_ON_START = !AUTO_RUN_ON_START!)
echo.
echo %ESC%[33m[C] Manage custom apps%ESC%[0m
echo %ESC%[32m[S] Save and return%ESC%[0m
echo %ESC%[37m[B] Back without saving%ESC%[0m
echo.

set /p _cfg_choice="Selection: "
if /i "%_cfg_choice%"=="S" ( call :save_config & goto MAIN_MENU )
if /i "%_cfg_choice%"=="B" ( goto MAIN_MENU )
if /i "%_cfg_choice%"=="C" ( goto CUSTOM_MENU )
if /i "%_cfg_choice%"=="D" ( goto SET_DEFAULT_SIM )
if /i "%_cfg_choice%"=="A" ( call :toggle AUTO_RUN_ON_START & goto CONFIG_MENU )

if "%_cfg_choice%"=="1"  call :toggle KILL_ONEDRIVE
if "%_cfg_choice%"=="2"  call :toggle KILL_DISCORD
if "%_cfg_choice%"=="3"  call :toggle KILL_CHROME
if "%_cfg_choice%"=="4"  call :toggle KILL_EDGE
if "%_cfg_choice%"=="5"  call :toggle KILL_CCLEANER
if "%_cfg_choice%"=="6"  call :toggle KILL_ICLOUDSERVICES
if "%_cfg_choice%"=="7"  call :toggle KILL_ICLOUDDRIVE
if "%_cfg_choice%"=="8"  call :toggle RESTART_EDGE
if "%_cfg_choice%"=="9"  call :toggle RESTART_DISCORD
if "%_cfg_choice%"=="10" call :toggle RESTART_ONEDRIVE
if "%_cfg_choice%"=="11" call :toggle RESTART_CCLEANER
if "%_cfg_choice%"=="12" call :toggle RESTART_ICLOUD
if "%_cfg_choice%"=="13" call :toggle RESTART_CHROME
goto CONFIG_MENU

:SET_DEFAULT_SIM
cls
echo ============================================================
echo        SET DEFAULT SIM (1..13)
echo ============================================================
echo 1 = MSFS 2024 (Steam)
echo 2 = MSFS 2020 (Steam)
echo 3 = DCS World (Steam)
echo 5 = MSFS 2024 (Store/GamePass)
echo 6 = MSFS 2020 (Store/GamePass)
echo 7 = DCS World (Standalone)
echo 8 = X-Plane 12 (Steam)
echo 9 = X-Plane 12 (Standalone)
echo 10 = Assetto Corsa EVO (VR)
echo 11 = Assetto Corsa EVO (2D)
echo 12 = Automobilista 2 (VR)
echo 13 = Automobilista 2 (2D)
echo.
echo [Enter] to clear (no default)
set /p _def="Default sim number: "
if "%_def%"=="" ( set "DEFAULT_SIM=" & goto CONFIG_MENU )
for %%N in (1 2 3 5 6 7 8 9 10 11 12 13) do if "%%N"=="%_def%" ( set "DEFAULT_SIM=%%N" & goto CONFIG_MENU )
echo Invalid selection. Press any key to continue...
pause >nul
goto SET_DEFAULT_SIM

:CUSTOM_MENU
cls
echo ============================================================
echo        CUSTOM APPS MANAGER
echo ============================================================
echo.
echo Custom KILL entries: !CUST_K_COUNT!
for /l %%I in (1,1,!CUST_K_COUNT!) do echo   [K%%I] !CUST_K_%%I!
echo.
echo Custom RESTART entries: !CUST_R_COUNT!
for /l %%I in (1,1,!CUST_R_COUNT!) do echo   [R%%I] "!CUST_R_CMD_%%I!" !CUST_R_ARGS_%%I!
echo.
echo [1] Add custom KILL
echo [2] Remove custom KILL
echo [3] Add custom RESTART
echo [4] Remove custom RESTART
echo [S] Save and return     [B] Back without saving
echo.
set /p _cust="Selection: "
if /i "%_cust%"=="S" ( call :save_config & goto CONFIG_MENU )
if /i "%_cust%"=="B" ( goto CONFIG_MENU )
if "%_cust%"=="1" call :add_custom_kill
if "%_cust%"=="2" call :remove_custom_kill
if "%_cust%"=="3" call :add_custom_restart
if "%_cust%"=="4" call :remove_custom_restart
goto CUSTOM_MENU

:: -----------------------------
:: Helpers: toggle YES/NO
:: -----------------------------
:toggle
set "_var=%~1"
for /f "tokens=2 delims==" %%A in ('set %_var% 2^>nul') do set "_val=%%A"
if /i "!_val!"=="YES" ( set "%_var%=NO" ) else ( set "%_var%=YES" )
goto :eof

:: -----------------------------
:: Kill a single app if flag YES
:: -----------------------------
:kill_if
set "_exe=%~1"
set "_flag=%~2"
set "_msg=%~3"
if /i "!_flag!"=="YES" (
    taskkill /f /im "!_exe!" /t >nul 2>&1 && echo [%TIME%] [PREP] !_msg! >> "%LOGFILE%"
)
goto :eof

:: -----------------------------
:: Kill custom (CUST_K_1..N)
:: -----------------------------
:kill_custom
if not defined CUST_K_COUNT goto :eof
for /l %%I in (1,1,!CUST_K_COUNT!) do (
    set "proc=!CUST_K_%%I!"
    if not "!proc!"=="" (
        taskkill /f /im "!proc!" /t >nul 2>&1 && echo [%TIME%] [PREP] Custom kill: !proc! >> "%LOGFILE%"
    )
)
goto :eof

:: -----------------------------
:: Built-in restart routines
:: -----------------------------
:restart_edge
if exist "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" (
    echo Restoring Microsoft Edge...
    start "" "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
    echo [%TIME%] [RESTORE] Edge restart triggered >> "%LOGFILE%"
) else (
    echo [%TIME%] [RESTORE] Edge not found, skipping >> "%LOGFILE%"
)
goto :eof

:restart_chrome
if exist "C:\Program Files\Google\Chrome\Application\chrome.exe" (
    echo Restoring Google Chrome...
    start "" "C:\Program Files\Google\Chrome\Application\chrome.exe"
    echo [%TIME%] [RESTORE] Chrome restart triggered >> "%LOGFILE%"
) else (
    echo [%TIME%] [RESTORE] Chrome not found, skipping >> "%LOGFILE%"
)
goto :eof

:restart_discord
if exist "%LocalAppData%\Discord\Update.exe" (
    echo Restoring Discord...
    start "" "%LocalAppData%\Discord\Update.exe" --processStart Discord.exe
    echo [%TIME%] [RESTORE] Discord restart triggered >> "%LOGFILE%"
)
goto :eof

:restart_onedrive
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
goto :eof

:restart_ccleaner
if exist "C:\Program Files\CCleaner\CCleaner64.exe" (
    echo Restoring CCleaner...
    start "" "C:\Program Files\CCleaner\CCleaner64.exe" /MONITOR
)
goto :eof

:restart_icloud
if exist "C:\Program Files\WindowsApps\AppleInc.iCloud_*" (
    echo Restoring iCloud (Store Version)...
    start explorer.exe shell:AppsFolder\AppleInc.iCloud_skh98v6769f6t^!iCloud
) else if exist "C:\Program Files (x86)\Common Files\Apple\Internet Services\iCloud.exe" (
    echo Restoring iCloud (Desktop Version)...
    start "" "C:\Program Files (x86)\Common Files\Apple\Internet Services\iCloud.exe"
)
goto :eof

:: -----------------------------
:: Custom restart executor
:: -----------------------------
:restart_custom
if not defined CUST_R_COUNT goto :eof
for /l %%I in (1,1,!CUST_R_COUNT!) do (
    set "_cmd=!CUST_R_CMD_%%I!"
    set "_arg=!CUST_R_ARGS_%%I!"
    if not "!_cmd!"=="" (
        echo [%TIME%] [RESTORE] Custom restart: "!_cmd!" !_arg! >> "%LOGFILE%"
        start "" "!_cmd!" !_arg!
    )
)
goto :eof

:: -----------------------------
:: Add/remove custom kills
:: -----------------------------
:add_custom_kill
set /p _pname="Enter process image name to kill (e.g., obs64.exe): "
if "%_pname%"=="" goto :eof
set /a CUST_K_COUNT+=1
set "CUST_K_%CUST_K_COUNT%=%_pname%"
echo Added custom kill #%CUST_K_COUNT%: %_pname%
goto :eof

:remove_custom_kill
if not defined CUST_K_COUNT ( echo None to remove.& goto :eof )
set /p _idx="Enter index to remove (1..%CUST_K_COUNT%): "
if "%_idx%"=="" goto :eof
if %_idx% LSS 1 goto :eof
if %_idx% GTR %CUST_K_COUNT% goto :eof
if %_idx% LSS %CUST_K_COUNT% (
    set "CUST_K_%_idx%=!CUST_K_%CUST_K_COUNT%!"
)
set "CUST_K_%CUST_K_COUNT%="
set /a CUST_K_COUNT-=1
echo Removed. New custom kill count: !CUST_K_COUNT!
goto :eof

:: -----------------------------
:: Add/remove custom restarts
:: -----------------------------
:add_custom_restart
set "_cmd=" & set "_args="
echo Enter full path to executable to start (quotes optional):
set /p _cmd="Command: "
if "%_cmd%"=="" goto :eof
echo Optional arguments (leave blank if none):
set /p _args="Args: "
set /a CUST_R_COUNT+=1
set "CUST_R_CMD_%CUST_R_COUNT%=%_cmd%"
set "CUST_R_ARGS_%CUST_R_COUNT%=%_args%"
echo Added custom restart #%CUST_R_COUNT%: "%_cmd%" %_args%
goto :eof

:remove_custom_restart
if not defined CUST_R_COUNT ( echo None to remove.& goto :eof )
set /p _idx="Enter index to remove (1..%CUST_R_COUNT%): "
if "%_idx%"=="" goto :eof
if %_idx% LSS 1 goto :eof
if %_idx% GTR %CUST_R_COUNT% goto :eof
if %_idx% LSS %CUST_R_COUNT% (
    set "CUST_R_CMD_%_idx%=!CUST_R_CMD_%CUST_R_COUNT%!"
    set "CUST_R_ARGS_%_idx%=!CUST_R_ARGS_%CUST_R_COUNT%!"
)
set "CUST_R_CMD_%CUST_R_COUNT%="
set "CUST_R_ARGS_%CUST_R_COUNT%="
set /a CUST_R_COUNT-=1
echo Removed. New custom restart count: !CUST_R_COUNT!
goto :eof

:: -----------------------------
:: ADMIN CHECK & LOG START
:: -----------------------------
:ADMIN_START
if exist "%LOGFILE%" (
    set "count=0"
    for /f %%A in ('type "%LOGFILE%" ^| find /c /i "[SESSION START]"') do set "count=%%A"
    for %%I in ("%LOGFILE%") do set "fsize=%%~zI"
    if !count! GEQ 10 (
        move /y "%LOGFILE%" "%LOGFILE%.old" >nul
        echo [%DATE% %TIME%] [LOG] Rotation triggered >> "%LOGFILE%"
    )
    if !fsize! GTR 2097152 (
        move /y "%LOGFILE%" "%LOGFILE%.old" >nul
    )
)
echo ============================================================ >> "%LOGFILE%"
echo [%DATE% %TIME%] [SESSION START] Target: %VERSION_NAME% >> "%LOGFILE%"

net session >nul 2>&1 || ( powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -ArgumentList 'LAUNCH %choice%' -Verb RunAs" & exit /b )
if /i "%~1"=="LAUNCH" if not "%~2"=="" set "choice=%~2"
cd /d "%SCRIPT_DIR%"
goto :eof

:: ============================================================
::                    CONFIG I/O — robust & safe
:: ============================================================
:load_config
if not exist "%CFG%" (
    call :set_defaults
    call :save_config
    goto :eof
)

setlocal DisableDelayedExpansion
for /f "usebackq tokens=1,* delims==" %%A in ("%CFG%") do (
    if not "%%A"=="" if not "%%A:~0,1%"=="#" if not "%%A:~0,1%"==";" if not "%%A:~0,1%"=="[" (
        endlocal & set "%%A=%%B"
        setlocal DisableDelayedExpansion
    )
)
endlocal

rem ---- Safety net defaults ----
if not defined KILL_ONEDRIVE set "KILL_ONEDRIVE=YES"
if not defined KILL_DISCORD set "KILL_DISCORD=YES"
if not defined KILL_CHROME set "KILL_CHROME=YES"
if not defined KILL_EDGE set "KILL_EDGE=YES"
if not defined KILL_CCLEANER set "KILL_CCLEANER=YES"
if not defined KILL_ICLOUDSERVICES set "KILL_ICLOUDSERVICES=YES"
if not defined KILL_ICLOUDDRIVE set "KILL_ICLOUDDRIVE=YES"
if not defined RESTART_EDGE set "RESTART_EDGE=YES"
if not defined RESTART_DISCORD set "RESTART_DISCORD=YES"
if not defined RESTART_ONEDRIVE set "RESTART_ONEDRIVE=YES"
if not defined RESTART_CCLEANER set "RESTART_CCLEANER=YES"
if not defined RESTART_ICLOUD set "RESTART_ICLOUD=YES"
if not defined RESTART_CHROME set "RESTART_CHROME=YES"
if not defined CUST_K_COUNT set "CUST_K_COUNT=0"
if not defined CUST_R_COUNT set "CUST_R_COUNT=0"
if not defined DEFAULT_SIM set "DEFAULT_SIM="
if not defined AUTO_RUN_ON_START set "AUTO_RUN_ON_START=NO"
goto :eof

:set_defaults
set "KILL_ONEDRIVE=YES"
set "KILL_DISCORD=YES"
set "KILL_CHROME=YES"
set "KILL_EDGE=YES"
set "KILL_CCLEANER=YES"
set "KILL_ICLOUDSERVICES=YES"
set "KILL_ICLOUDDRIVE=YES"

set "RESTART_EDGE=YES"
set "RESTART_DISCORD=YES"
set "RESTART_ONEDRIVE=YES"
set "RESTART_CCLEANER=YES"
set "RESTART_ICLOUD=YES"
set "RESTART_CHROME=YES"

set "CUST_K_COUNT=0"
set "CUST_R_COUNT=0"

set "DEFAULT_SIM="
set "AUTO_RUN_ON_START=NO"
goto :eof

:save_config
if not defined CUST_K_COUNT set "CUST_K_COUNT=0"
if not defined CUST_R_COUNT set "CUST_R_COUNT=0"
if not defined AUTO_RUN_ON_START set "AUTO_RUN_ON_START=NO"

>  "%CFG%" echo # VR Optimizer Config - auto-generated
>> "%CFG%" echo # Toggle YES/NO; custom entries are indexed.
>> "%CFG%" echo KILL_ONEDRIVE=%KILL_ONEDRIVE%
>> "%CFG%" echo KILL_DISCORD=%KILL_DISCORD%
>> "%CFG%" echo KILL_CHROME=%KILL_CHROME%
>> "%CFG%" echo KILL_EDGE=%KILL_EDGE%
>> "%CFG%" echo KILL_CCLEANER=%KILL_CCLEANER%
>> "%CFG%" echo KILL_ICLOUDSERVICES=%KILL_ICLOUDSERVICES%
>> "%CFG%" echo KILL_ICLOUDDRIVE=%KILL_ICLOUDDRIVE%
>> "%CFG%" echo RESTART_EDGE=%RESTART_EDGE%
>> "%CFG%" echo RESTART_DISCORD=%RESTART_DISCORD%
>> "%CFG%" echo RESTART_ONEDRIVE=%RESTART_ONEDRIVE%
>> "%CFG%" echo RESTART_CCLEANER=%RESTART_CCLEANER%
>> "%CFG%" echo RESTART_ICLOUD=%RESTART_ICLOUD%
>> "%CFG%" echo RESTART_CHROME=%RESTART_CHROME%
>> "%CFG%" echo DEFAULT_SIM=%DEFAULT_SIM%
>> "%CFG%" echo AUTO_RUN_ON_START=%AUTO_RUN_ON_START%
>> "%CFG%" echo CUST_K_COUNT=%CUST_K_COUNT%
for /l %%I in (1,1,%CUST_K_COUNT%) do (
  >> "%CFG%" echo CUST_K_%%I=!CUST_K_%%I!
)
>> "%CFG%" echo CUST_R_COUNT=%CUST_R_COUNT%
for /l %%I in (1,1,%CUST_R_COUNT%) do (
  >> "%CFG%" echo CUST_R_CMD_%%I=!CUST_R_CMD_%%I!
  >> "%CFG%" echo CUST_R_ARGS_%%I=!CUST_R_ARGS_%%I!
)
echo [%TIME%] [CFG] Saved to "%CFG%" >> "%LOGFILE%"
goto :eof


:: -----------------------------
:: Helper: Find a file across drives in common roots
::   %~1 = relative path AFTER the root (e.g., "Eagle Dynamics\DCS World\bin\DCS.exe")
::   %~2 = OUT var to receive full path
:: Tries:
::   <D>:\%1
::   <D>:\Program Files\%1
::   <D>:\Program Files (x86)\%1
:: -----------------------------
:find_on_drives_pf
setlocal
set "rel=%~1"
set "outvar=%~2"
set "found="
for %%D in (C D E F G H I J) do (
  for %%P in (
    "%%D:\%rel%"
    "%%D:\Program Files\%rel%"
    "%%D:\Program Files (x86)\%rel%"
  ) do (
    if defined DEBUG_DCS echo [%TIME%] [DCS_SCAN] Try: %%~P >> "%LOGFILE%"
    if exist "%%~P" (
      set "found=%%~P"
      goto :_done_pf
    )
  )
)
:_done_pf
endlocal & if defined found set "%outvar%=%found%"
goto :eof

:: -----------------------------
:: DCS root from registry (fast path)
::   %~1 = OUT var to receive the install folder (e.g., E:\Program Files\Eagle Dynamics\DCS World)
:: Checks HKLM + HKCU for DCS World and DCS World OpenBeta.
:: -----------------------------
:dcs_from_registry
setlocal
set "outvar=%~1"
set "root="
for %%K in (
  "HKLM\SOFTWARE\Eagle Dynamics\DCS World"
  "HKLM\SOFTWARE\Eagle Dynamics\DCS World OpenBeta"
  "HKCU\SOFTWARE\Eagle Dynamics\DCS World"
  "HKCU\SOFTWARE\Eagle Dynamics\DCS World OpenBeta"
) do (
  for /f "tokens=2,*" %%A in ('reg query %%K /v Path 2^>nul ^| find /i "Path"') do (
     set "root=%%B"
     goto :_found_root
  )
)
:_found_root
endlocal & if defined root set "%outvar%=%root%"
goto :eof
