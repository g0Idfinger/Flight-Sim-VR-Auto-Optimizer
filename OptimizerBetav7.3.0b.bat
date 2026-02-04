
@echo off
setlocal EnableExtensions EnableDelayedExpansion

:: ============================================================
:: UNIVERSAL SIM VR OPTIMIZER - Configurable Edition (v7.3.0b)
:: - Adds persistent configuration for which apps are killed
::   and which apps are restarted on restore.
:: - Stores settings in vr_opt.cfg next to this script.
:: ============================================================

:: Paths & Files
set "SCRIPT_DIR=%~dp0"
set "LOGFILE=%SCRIPT_DIR%sim_launcher.log"
set "CFG=%SCRIPT_DIR%vr_opt.cfg"

:: -----------------------------
:: Load (or create) configuration
:: -----------------------------
call :load_config

:: -----------------------------
:: Main Menu
:: -----------------------------
:MAIN_MENU
cls
echo ============================================================
echo        VR AUTO-OPTIMIZER - MAIN MENU
echo ============================================================
echo.
echo [1] Launch Simulator
echo [2] Configure App Controls (kill/restart + custom)
echo [X] Exit
echo.
set /p _main_choice="Selection: "
if /i "%_main_choice%"=="1" goto MENU
if /i "%_main_choice%"=="2" goto CONFIG_MENU
if /i "%_main_choice%"=="X" exit /b
goto MAIN_MENU

:: -----------------------------
:: Original Simulator Menu
:: -----------------------------
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
echo [B] Back to Main Menu    [X] EXIT
echo.
set /p choice="Selection (1-7/B/X): "

if /i "%choice%"=="X" exit /b
if /i "%choice%"=="B" goto MAIN_MENU

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
    if "!STORE_URI!"=="" set "STORE_URI=shell:AppsFolder\Microsoft.Limitless_8wekyb3d8bbwe^!App"
) else if "%choice%"=="6" (
    set "LAUNCH_METHOD=STORE" & set "STORE_URI=shell:AppsFolder\Microsoft.FlightSimulator_8wekyb3d8bbwe^!App"
    set "GAME_EXE=FlightSimulator.exe" & set "VERSION_NAME=MSFS 2020 (Store)"
) else if "%choice%"=="7" (
    set "LAUNCH_METHOD=DCS_STORE" & set "GAME_EXE=DCS.exe" & set "VERSION_NAME=DCS World (Standalone)"
) else ( goto MENU )

:: -----------------------------
:: ADMIN CHECK & LOG START
:: -----------------------------
if exist "%LOGFILE%" (
    set "count=0"
    for /f "usebackq" %%A in (`find /c /i "[SESSION START]" "%LOGFILE%"`) do set "count=%%A"
    for %%I in ("%LOGFILE%") do set "fsize=%%~zI"
    if !count! GEQ 10 ( move /y "%LOGFILE%" "%LOGFILE%.old" >nul & echo [%DATE% %TIME%] [LOG] Rotation triggered >> "%LOGFILE%" )
    if !fsize! GTR 2097152 ( move /y "%LOGFILE%" "%LOGFILE%.old" >nul )
)
echo ============================================================ >> "%LOGFILE%"
echo [%DATE% %TIME%] [SESSION START] Target: %VERSION_NAME% >> "%LOGFILE%"

net session >nul 2>&1 || ( powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -ArgumentList 'LAUNCH %choice%' -Verb RunAs" & exit /b )
if /i "%~1"=="LAUNCH" if not "%~2"=="" set "choice=%~2"
cd /d "%SCRIPT_DIR%"

:: -----------------------------
:: [1/4] PREP (driven by config)
:: -----------------------------
echo [1/4] Preparing system...
powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c >nul 2>&1
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

:: Optional service/network prep (unchanged from your script)
net stop SysMain /y >nul 2>&1
net stop Spooler /y >nul 2>&1
nvidia-smi -pm 1 >nul 2>&1
ipconfig /flushdns >nul

:: [2/4] VR – keep your logic
if exist "C:\Program Files\Virtual Desktop Streamer\VirtualDesktop.Streamer.exe" (
    echo [2/4] Launching VR...
    echo [%TIME%] [VR] Streamer started >> "%LOGFILE%"
    start "" "C:\Program Files\Virtual Desktop Streamer\VirtualDesktop.Streamer.exe"
    timeout /t 8 >nul
)

:: [3/4] LAUNCH – keep your logic
echo [3/4] Launching %VERSION_NAME%...
echo [%TIME%] [LAUNCH] Method: %LAUNCH_METHOD% - Target: %GAME_EXE% >> "%LOGFILE%"

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
    if defined DCS_BIN ( pushd "!DCS_BIN:\DCS.exe=!" & start "" "DCS.exe" & popd )
)

:: DETECTION (unchanged + small tidy)
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
  "Write-Host 'Enjoy your flight! Greetings from ' -NoNewline; Write-Host ' VRFLIGHTSIM GUY ' -ForegroundColor Yellow -BackgroundColor Red -NoNewline; Write-Host ' and ' -NoNewline; Write-Host ' SHARK ' -ForegroundColor Yellow -BackgroundColor Red; Write-Host ' and ' -NoNewline; Write-Host ' goldfinger ' -ForegroundColor Yellow -BackgroundColor Red;"
echo ============================================================

:WAIT_EXIT
timeout /t 15 >nul
tasklist /NH /FI "IMAGENAME eq %GAME_EXE%" | find /i "%GAME_EXE%" >nul
if not errorlevel 1 goto WAIT_EXIT

:: -----------------------------
:: [4/4] RESTORE (driven by config)
:: -----------------------------
:RESTORE
echo [4/4] Restoring system...
echo [%TIME%] [RESTORE] Starting Cleanup >> "%LOGFILE%"
taskkill /f /im VirtualDesktop.Streamer.exe >nul 2>&1
net start SysMain /y >nul 2>&1
net start Spooler /y >nul 2>&1
nvidia-smi -pm 0 >nul 2>&1
powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e
echo [%TIME%] [RESTORE] System reverted >> "%LOGFILE%"

:: Built-in restarts
if /i "!RESTART_EDGE!"=="YES" call :restart_edge
if /i "!RESTART_DISCORD!"=="YES" call :restart_discord
if /i "!RESTART_ONEDRIVE!"=="YES" call :restart_onedrive
if /i "!RESTART_CCLEANER!"=="YES" call :restart_ccleaner
if /i "!RESTART_ICLOUD!"=="YES" call :restart_icloud

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
echo        CONFIGURATION - APP CONTROLS
echo ============================================================
echo.
echo KILL FLAGS:
echo  [1] OneDrive        = !KILL_ONEDRIVE!
echo  [2] Discord         = !KILL_DISCORD!
echo  [3] Chrome          = !KILL_CHROME!
echo  [4] Edge            = !KILL_EDGE!
echo  [5] CCleaner        = !KILL_CCLEANER!
echo  [6] iCloudServices  = !KILL_ICLOUDSERVICES!
echo  [7] iCloudDrive     = !KILL_ICLOUDDRIVE!
echo.
echo RESTART FLAGS:
echo  [8]  Restart Edge     = !RESTART_EDGE!
echo  [9]  Restart Discord  = !RESTART_DISCORD!
echo  [10] Restart OneDrive = !RESTART_ONEDRIVE!
echo  [11] Restart CCleaner = !RESTART_CCLEANER!
echo  [12] Restart iCloud   = !RESTART_ICLOUD!
echo.
echo CUSTOM APPS:
echo  [C] Manage custom apps (kill/restart)
echo.
echo [S] Save and return     [B] Back without saving
echo.
set /p _cfg_choice="Selection: "
if /i "%_cfg_choice%"=="S" ( call :save_config & goto MAIN_MENU )
if /i "%_cfg_choice%"=="B" ( goto MAIN_MENU )
if /i "%_cfg_choice%"=="C" ( goto CUSTOM_MENU )

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
goto CONFIG_MENU

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
    for /f "usebackq delims=" %%P in ("!CUST_K_%%I!") do (
        if not "%%~P"=="" taskkill /f /im "%%~P" /t >nul 2>&1 && echo [%TIME%] [PREP] Custom kill: %%~P >> "%LOGFILE%"
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
    start "" "C:\Program Files\x86\Common Files\Apple\Internet Services\iCloud.exe"
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
for /l %%J in (%_idx%,1,%CUST_K_COUNT%) do (
    set /a _n=%%J+1
    for /f "usebackq delims=" %%X in ("!CUST_K_!_n!!") do set "CUST_K_%%J=%%~X"
)
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
for /l %%J in (%_idx%,1,%CUST_R_COUNT%) do (
    set /a _n=%%J+1
    for /f "usebackq delims=" %%X in ("!CUST_R_CMD_!_n!!") do set "CUST_R_CMD_%%J=%%~X"
    for /f "usebackq delims=" %%X in ("!CUST_R_ARGS_!_n!!") do set "CUST_R_ARGS_%%J=%%~X"
)
set /a CUST_R_COUNT-=1
echo Removed. New custom restart count: !CUST_R_COUNT!
goto :eof

:: -----------------------------
:: Config I/O (robust writer)
:: ----------------------------


:load_config
if exist "%CFG%" (
    setlocal EnableExtensions EnableDelayedExpansion
    for /f "usebackq tokens=1,* delims==" %%A in ("%CFG%") do (
        set "line=%%A"
        if not defined line (
            REM blank line, skip
        ) else (
            set "firstChar=!line:~0,1!"
            if "!firstChar!" NEQ "#" if "!firstChar!" NEQ ";" if "!firstChar!" NEQ "[" (
                set "%%~A=%%~B"
            )
        )
    )
    endlocal & (
        REM Ensure critical defaults exist if not present in file
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
        if not defined CUST_K_COUNT set "CUST_K_COUNT=0"
        if not defined CUST_R_COUNT set "CUST_R_COUNT=0"
    )
) else (
    call :set_defaults
    call :save_config
)
goto :eof



:set_defaults
:: Built-in defaults
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

set "CUST_K_COUNT=0"
set "CUST_R_COUNT=0"
goto :eof
-

:save_config
REM Guarantee numeric defaults so we don't write blank counts
if not defined CUST_K_COUNT set "CUST_K_COUNT=0"
if not defined CUST_R_COUNT set "CUST_R_COUNT=0"

REM Turn OFF delayed expansion to avoid losing '!' and breaking the block
setlocal DisableDelayedExpansion

REM 1) Write fixed keys in one pass (overwrite)
> "%CFG%" (
  echo # VR Optimizer Config - auto-generated
  echo # Toggle YES/NO; custom entries are indexed.
  echo KILL_ONEDRIVE=%KILL_ONEDRIVE%
  echo KILL_DISCORD=%KILL_DISCORD%
  echo KILL_CHROME=%KILL_CHROME%
  echo KILL_EDGE=%KILL_EDGE%
  echo KILL_CCLEANER=%KILL_CCLEANER%
  echo KILL_ICLOUDSERVICES=%KILL_ICLOUDSERVICES%
  echo KILL_ICLOUDDRIVE=%KILL_ICLOUDDRIVE%
  echo RESTART_EDGE=%RESTART_EDGE%
  echo RESTART_DISCORD=%RESTART_DISCORD%
  echo RESTART_ONEDRIVE=%RESTART_ONEDRIVE%
  echo RESTART_CCLEANER=%RESTART_CCLEANER%
  echo RESTART_ICLOUD=%RESTART_ICLOUD%
  echo CUST_K_COUNT=%CUST_K_COUNT%
)

REM 2) Append dynamic custom KILL entries safely (no delayed expansion while echoing)
for /l %%I in (1,1,%CUST_K_COUNT%) do (
  call :_persist_line "CUST_K_%%I" "!CUST_K_%%I!"
)

REM 3) Append dynamic custom RESTART entries safely
>> "%CFG%" echo CUST_R_COUNT=%CUST_R_COUNT%
for /l %%I in (1,1,%CUST_R_COUNT%) do (
  call :_persist_line "CUST_R_CMD_%%I" "!CUST_R_CMD_%%I!"
  call :_persist_line "CUST_R_ARGS_%%I" "!CUST_R_ARGS_%%I!"
)

endlocal

REM 4) Verify write success (optional but helpful)
if not exist "%CFG%" (
  echo [ERROR] Could not create "%CFG%". Check permissions folder read-only?.
  goto :eof
)
echo [%TIME%] [CFG] Saved to "%CFG%" >> "%LOGFILE%"
goto :eof

:_persist_line
REM Usage: call :_persist_line "KEY" "VALUE"
REM Disable delayed expansion specifically while echoing to preserve any '!'
setlocal DisableDelayedExpansion
set "K=%~1"
set "V=%~2"
>> "%CFG%" echo %K%=%V%
endlocal & goto :eof



:_append_kv
REM Uses PowerShell to append: KEY=VALUE (preserves quotes, carets, !, etc.)
set "_k=%~1"
set "_v=%~2"
powershell -NoProfile -ExecutionPolicy Bypass ^
  -Command "$k=%~1; $v=%~2; Add-Content -LiteralPath '%CFG%' -Value ($k+'='+$v)"
goto :eof


:_persist
:: Safe dynamic var write using CALL expansion
set "_line=%~1"
for /f "tokens=1* delims==" %%a in ('set %_line% 2^>nul') do >>"%CFG%" echo %%a=%%b
goto :eof

