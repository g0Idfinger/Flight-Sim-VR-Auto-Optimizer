#region HEADER & GLOBALS

<#
    VR-Optimizer.ps1
    Modern PowerShell rewrite of the Universal SIM VR Optimizer
    - Single-file application
    - Terminal-style boxed UI (light borders)
    - JSON configuration stored next to the script
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Resolve script directory and core paths
$ScriptDir = Split-Path -Parent $PSCommandPath
$ConfigPath = Join-Path $ScriptDir 'config.json'
$LogFile    = Join-Path $ScriptDir 'sim_launcher.log'

#endregion HEADER & GLOBALS

#region ADMIN ELEVATION

function Ensure-Admin {
    $currentIdentity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal        = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    $isAdmin          = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Host "Requesting administrative privileges..." -ForegroundColor Yellow
        $psi = @{
            FilePath     = 'powershell.exe'
            ArgumentList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
            Verb         = 'RunAs'
        }
        try {
            Start-Process @psi
        } catch {
            Write-Host "Elevation cancelled or failed. Exiting." -ForegroundColor Red
        }
        exit
    }
}

Ensure-Admin

#endregion ADMIN ELEVATION

#region BASIC UTILITIES

function Write-Log {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [ValidateSet('INFO','WARN','ERROR','DEBUG')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[{0}] [{1}] {2}" -f $timestamp, $Level, $Message
    Add-Content -Path $LogFile -Value $line
}

#endregion BASIC UTILITIES
#region UI FRAMEWORK
<#
    UI Framework
    - Light box-drawing borders
    - Color helpers
    - Input helpers
    - Menu rendering utilities
#>

# Unicode light box characters
$UI = @{
    TopLeft     = "┌"
    TopRight    = "┐"
    BottomLeft  = "└"
    BottomRight = "┘"
    Horizontal  = "─"
    Vertical    = "│"
}

function New-BoxLine {
    param(
        [Parameter(Mandatory)]
        [string]$Text,
        [ValidateSet('Header','Footer','Line')]
        [string]$Type = 'Line',
        [int]$Width = 60
    )

    switch ($Type) {
        'Header' {
            $h = $UI.Horizontal * $Width
            return "$($UI.TopLeft)$h$($UI.TopRight)"
        }
        'Footer' {
            $h = $UI.Horizontal * $Width
            return "$($UI.BottomLeft)$h$($UI.BottomRight)"
        }
        'Line' {
            # Center text inside the box
            $padding = $Width - $Text.Length
            if ($padding -lt 0) { $padding = 0 }
            $leftPad  = [math]::Floor($padding / 2)
            $rightPad = $padding - $leftPad
            return "$($UI.Vertical)$(' ' * $leftPad)$Text$(' ' * $rightPad)$($UI.Vertical)"
        }
    }
}

function Show-Box {
    param(
        [Parameter(Mandatory)]
        [string]$Title,
        [int]$Width = 60
    )

    Write-Host (New-BoxLine -Text $Title -Type Header -Width $Width) -ForegroundColor Cyan
    Write-Host (New-BoxLine -Text $Title -Type Line   -Width $Width) -ForegroundColor Cyan
    Write-Host (New-BoxLine -Text $Title -Type Footer -Width $Width) -ForegroundColor Cyan
    Write-Host ""
}

# Color helpers
function Write-Info    { param($t) Write-Host $t -ForegroundColor Cyan }
function Write-Warn    { param($t) Write-Host $t -ForegroundColor Yellow }
function Write-ErrorUI { param($t) Write-Host $t -ForegroundColor Red }
function Write-Success { param($t) Write-Host $t -ForegroundColor Green }
function Write-White   { param($t) Write-Host $t -ForegroundColor White }

# Input helper
function Read-Choice {
    param(
        [Parameter(Mandatory)]
        [string]$Prompt
    )
    Write-Host ""
    Write-Host -NoNewline "$Prompt "
    return Read-Host
}

#endregion UI FRAMEWORK
#region CONFIG SYSTEM
<#
    JSON Configuration System
    - Loads config.json from script directory
    - Creates default config if missing
    - Provides Get/Set helpers
    - Ensures strong structure and validation
#>

# Default configuration structure
$DefaultConfig = @{
    Kill = @{
        OneDrive        = $true
        Edge            = $true
        CCleaner        = $true
        iCloudServices  = $true
        iCloudDrive     = $true
        Discord         = $true 
        Custom          = @()   # array of process names
    }
    Restart = @{
        Edge            = $true
        Discord         = $true
        OneDrive        = $true
        CCleaner        = $true
        iCloud          = $true
        Custom          = @()   # array of @{ Command=""; Args="" }
    }
    DefaultSim       = $null
    AutoRunOnStart   = $false
}

function Save-Config {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    try {
        $json = $Config | ConvertTo-Json -Depth 10 -Compress
        Set-Content -Path $ConfigPath -Value $json -Encoding UTF8
        Write-Log "Configuration saved to $ConfigPath"
    }
    catch {
        Write-ErrorUI "Failed to save configuration."
        Write-Log "Failed to save configuration: $_" -Level ERROR
    }
}

function Load-Config {
    if (-not (Test-Path $ConfigPath)) {
        Write-Warn "Config file not found. Creating default config.json..."
        Save-Config -Config $DefaultConfig
        return $DefaultConfig
    }

    try {
        $json = Get-Content -Path $ConfigPath -Raw
        $config = $json | ConvertFrom-Json -AsHashtable

        # Validate structure and fill missing keys
        foreach ($key in $DefaultConfig.Keys) {
            if (-not $config.ContainsKey($key)) {
                $config[$key] = $DefaultConfig[$key]
            }
        }

        # Validate nested keys
        foreach ($section in @('Kill','Restart')) {
            foreach ($key in $DefaultConfig[$section].Keys) {
                if (-not $config[$section].ContainsKey($key)) {
                    $config[$section][$key] = $DefaultConfig[$section][$key]
                }
            }
        }

        Write-Log "Configuration loaded from $ConfigPath"
        return $config
    }
    catch {
        Write-ErrorUI "Config file is corrupted. Creating a new one."
        Write-Log "Config corrupted. Resetting: $_" -Level ERROR
        Save-Config -Config $DefaultConfig
        return $DefaultConfig
    }
}

# Load config into global variable
$Config = Load-Config

# Helper: Get config value
function Get-ConfigValue {
    param(
        [Parameter(Mandatory)][string]$Path
    )
    return $Config.$Path
}

# Helper: Set config value
function Set-ConfigValue {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$Value
    )
    $Config.$Path = $Value
    Save-Config -Config $Config
}

#endregion CONFIG SYSTEM
#region LOGGING SYSTEM
<#
    Logging System
    - Timestamped log entries
    - Automatic log rotation
    - Session markers
    - Integrated with Write-Log helper
#>

# Maximum log size before rotation (2 MB)
$MaxLogSizeBytes = 2MB

function Initialize-Log {
    if (Test-Path $LogFile) {
        $size = (Get-Item $LogFile).Length
        if ($size -ge $MaxLogSizeBytes) {
            $backup = "$LogFile.old"
            try {
                Move-Item -Path $LogFile -Destination $backup -Force
                Write-Host "Log rotated (size exceeded 2MB)" -ForegroundColor Yellow
            }
            catch {
                Write-Host "Failed to rotate log file." -ForegroundColor Red
            }
        }
    }

    # Start a new session entry
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Add-Content -Path $LogFile -Value "============================================================"
    Add-Content -Path $LogFile -Value "[$timestamp] [SESSION START]"
}

function Close-LogSession {
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Add-Content -Path $LogFile -Value "[$timestamp] [SESSION END]"
    Add-Content -Path $LogFile -Value ""
}

# Override Write-Log to include rotation checks
function Write-Log {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [ValidateSet('INFO','WARN','ERROR','DEBUG')]
        [string]$Level = 'INFO'
    )

    # Rotate if needed
    if (Test-Path $LogFile) {
        $size = (Get-Item $LogFile).Length
        if ($size -ge $MaxLogSizeBytes) {
            $backup = "$LogFile.old"
            try {
                Move-Item -Path $LogFile -Destination $backup -Force
                Write-Host "Log rotated (size exceeded 2MB)" -ForegroundColor Yellow
            }
            catch {
                Write-Host "Failed to rotate log file." -ForegroundColor Red
            }
        }
    }

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[{0}] [{1}] {2}" -f $timestamp, $Level, $Message
    Add-Content -Path $LogFile -Value $line
}

# Initialize log at script start
Initialize-Log

#endregion LOGGING SYSTEM
#region PROCESS TOOLS
<#
    Process Tools
    - Kill built-in apps
    - Kill custom apps
    - Restart built-in apps
    - Restart custom apps
    - Safe wrappers around process control
#>

function Stop-ProcessSafe {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    try {
        $proc = Get-Process -Name $Name -ErrorAction SilentlyContinue
        if ($proc) {
            Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
            Write-Log "Killed process: $Name"
            Write-Success "Killed: $Name"
        }
    }
    catch {
        Write-Log "Failed to kill process ${Name}: $_" -Level ERROR
        Write-Warn "Could not kill: $Name"
    }
}

function Start-ProcessSafe {
    param(
        [Parameter(Mandatory)]
        [string]$Command,
        [string]$Args = ""
    )

    try {
        if ($Args) {
            Start-Process -FilePath $Command -ArgumentList $Args | Out-Null
        } else {
            Start-Process -FilePath $Command | Out-Null
        }
        Write-Log "Started process: $Command $Args"
        Write-Success "Started: $Command"
    }
    catch {
        Write-Log "Failed to start ${Command}: $_" -Level ERROR
        Write-Warn "Could not start: $Command"
    }
}

# ------------------------------------------------------------
# Built-in KILL actions
# ------------------------------------------------------------
function Invoke-KillBuiltIn {
    Write-Info "Applying built-in kill rules..."

    if ($Config.Kill.OneDrive)       { Stop-ProcessSafe -Name "OneDrive" }
    if ($Config.Kill.Edge)           { Stop-ProcessSafe -Name "msedge" }
    if ($Config.Kill.CCleaner)       { Stop-ProcessSafe -Name "CCleaner64" }
    if ($Config.Kill.iCloudServices) { Stop-ProcessSafe -Name "iCloudServices" }
    if ($Config.Kill.iCloudDrive)    { Stop-ProcessSafe -Name "iCloudDrive" }
    if ($Config.Kill.Discord) 		 { Stop-ProcessSafe -Name "Discord" }
}

# ------------------------------------------------------------
# Custom KILL actions
# ------------------------------------------------------------
function Invoke-KillCustom {
    if ($Config.Kill.Custom.Count -eq 0) { return }

    Write-Info "Applying custom kill rules..."

    foreach ($procName in $Config.Kill.Custom) {
        if ([string]::IsNullOrWhiteSpace($procName)) { continue }
        Stop-ProcessSafe -Name $procName
    }
}

# ------------------------------------------------------------
# Built-in RESTART actions
# ------------------------------------------------------------
function Invoke-RestartBuiltIn {
    Write-Info "Applying built-in restart rules..."

    if ($Config.Restart.Edge) {
        $edgePath = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
        if (Test-Path $edgePath) {
            Start-ProcessSafe -Command $edgePath
        }
    }

    if ($Config.Restart.Discord) {
        $discordUpdater = Join-Path $env:LOCALAPPDATA "Discord\Update.exe"
        if (Test-Path $discordUpdater) {
            Start-ProcessSafe -Command $discordUpdater -Args "--processStart Discord.exe"
        }
    }

    if ($Config.Restart.OneDrive) {
        $paths = @(
            "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe",
            "C:\Program Files\Microsoft OneDrive\OneDrive.exe"
        )
        foreach ($p in $paths) {
            if (Test-Path $p) {
                Start-ProcessSafe -Command $p -Args "/background"
                break
            }
        }
    }

    if ($Config.Restart.CCleaner) {
        $ccleaner = "C:\Program Files\CCleaner\CCleaner64.exe"
        if (Test-Path $ccleaner) {
            Start-ProcessSafe -Command $ccleaner -Args "/MONITOR"
        }
    }

    if ($Config.Restart.iCloud) {
        $storePath = "C:\Program Files\WindowsApps\AppleInc.iCloud_*"
        $desktopPath = "C:\Program Files (x86)\Common Files\Apple\Internet Services\iCloud.exe"

        if (Get-ChildItem $storePath -ErrorAction SilentlyContinue) {
            Start-ProcessSafe -Command "explorer.exe" -Args "shell:AppsFolder\AppleInc.iCloud_skh98v6769f6t!iCloud"
        }
        elseif (Test-Path $desktopPath) {
            Start-ProcessSafe -Command $desktopPath
        }
    }
}

# ------------------------------------------------------------
# Custom RESTART actions
# ------------------------------------------------------------
function Invoke-RestartCustom {
    if ($Config.Restart.Custom.Count -eq 0) { return }

    Write-Info "Applying custom restart rules..."

    foreach ($entry in $Config.Restart.Custom) {
        if (-not $entry.Command) { continue }
        Start-ProcessSafe -Command $entry.Command -Args $entry.Args
    }
}

#endregion PROCESS TOOLS

#region CPU AFFINITY SYSTEM
<#
    CPU Affinity System
    - Universal Intel 12th gen+ and AMD Ryzen support
    - Detects P-core threads automatically
    - Applies affinity mask to simulator process
#>

function Get-PCoreAffinityMask {
    # Query CPU topology
    $cpu = Get-CimInstance Win32_Processor

    $logical  = $cpu.NumberOfLogicalProcessors
    $physical = $cpu.NumberOfCores

    # P-core threads = physical cores * 2 (SMT)
    $pThreads = $physical * 2

    # Safety clamp
    if ($pThreads -gt $logical) {
        $pThreads = $logical
    }

    # Build mask: first $pThreads bits = 1
    $mask = 0
    for ($i = 0; $i -lt $pThreads; $i++) {
        $mask = $mask -bor (1 -shl $i)
    }

    return $mask
}

function Set-PCoreAffinity {
    param(
        [Parameter(Mandatory)][string]$ProcessName
    )

    $proc = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
    if (-not $proc) {
        Write-Log "Set-PCoreAffinity: Process $ProcessName not found" -Level WARN
        return
    }

    $mask = Get-PCoreAffinityMask

    try {
        $proc.ProcessorAffinity = $mask
        $binary = "{0:b}" -f $mask
        Write-Log "Applied P-core affinity mask ($mask) binary=[$binary] to $ProcessName"
        Write-Info "Applied P-core affinity to $ProcessName"
    }
    catch {
        Write-Log "Failed to apply affinity to ${ProcessName}: $_" -Level ERROR
        Write-Warn "Failed to apply CPU affinity."
    }
}

#endregion CPU AFFINITY SYSTEM

#region POWER PLAN TOOLS
<#
    Power Plan Tools
    - Detect active plan
    - Switch to Ultimate Performance
    - Restore previous plan
    - Logging integration
#>

# GUIDs for known power plans
$PowerPlans = @{
    HighPerformance     = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
    Balanced            = "381b4222-f694-41f0-9685-ff5bb260df2e"
    UltimatePerformance = "e9a42b02-d5df-448d-aa00-03f14749eb61"
}

# ------------------------------------------------------------
# Get the currently active power plan GUID
# ------------------------------------------------------------
function Get-ActivePowerPlan {
    try {
        $output = powercfg /getactivescheme
        if ($output -match 'GUID:\s+([a-fA-F0-9\-]+)') {
            return $Matches[1]
        }
    }
    catch {
        Write-Log "Failed to read active power plan: $_" -Level ERROR
    }
    return $null
}

# ------------------------------------------------------------
# Switch to a specific power plan
# ------------------------------------------------------------
function Set-PowerPlan {
    param(
        [Parameter(Mandatory)]
        [string]$Guid
    )

    try {
        powercfg /setactive $Guid | Out-Null
        Write-Log "Power plan switched to $Guid"
        Write-Info "Power plan set to: $Guid"
    }
    catch {
        Write-Log "Failed to set power plan ${Guid}: $_" -Level ERROR
        Write-Warn "Could not switch power plan."
    }
}

# ------------------------------------------------------------
# Ensure Ultimate Performance is active
# ------------------------------------------------------------
function Ensure-UltimatePerformance {
    Write-Info "Switching to Ultimate Performance power plan..."

    $ultimate = $PowerPlans.UltimatePerformance

    # Check if Ultimate Performance exists
    $plans = powercfg /list
    if ($plans -notmatch $ultimate) {
        Write-Warn "Ultimate Performance plan not found. Attempting to enable it..."
        try {
            powercfg -duplicatescheme $ultimate | Out-Null
            Write-Log "Ultimate Performance plan duplicated/created."
        }
        catch {
            Write-Warn "Failed to create Ultimate Performance plan. Falling back to High Performance."
            Set-PowerPlan -Guid $PowerPlans.HighPerformance
            return
        }
    }

    # Activate Ultimate Performance
    Set-PowerPlan -Guid $ultimate
}

# ------------------------------------------------------------
# Restore previous power plan
# ------------------------------------------------------------
function Restore-PowerPlan {
    param(
        [Parameter(Mandatory)]
        [string]$PreviousGuid
    )

    Write-Info "Restoring previous power plan..."
    Set-PowerPlan -Guid $PreviousGuid
}

#endregion POWER PLAN TOOLS
#region SYSTEM PREP
<#
    System Prep
    - Kill built-in apps
    - Kill custom apps
    - Stop services
    - Enable NVIDIA persistence mode
    - Flush DNS
    - Launch Virtual Desktop Streamer
    - Logging integration
#>

function Stop-ServicesForVR {
    Write-Info "Stopping unnecessary services..."

    $services = @(
        "SysMain",
        "Spooler"
    )

    foreach ($svc in $services) {
        try {
            Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
            Write-Log "Stopped service: $svc"
        }
        catch {
            Write-Log "Failed to stop service ${svc}: $_" -Level WARN
        }
    }
}

function Start-ServicesAfterVR {
    Write-Info "Restoring system services..."

    $services = @(
        "SysMain",
        "Spooler"
    )

    foreach ($svc in $services) {
        try {
            Start-Service -Name $svc -ErrorAction SilentlyContinue
            Write-Log "Started service: $svc"
        }
        catch {
            Write-Log "Failed to start service ${svc}: $_" -Level WARN
        }
    }
}

function Enable-NvidiaPersistence {
    Write-Info "Enabling NVIDIA persistence mode..."
    try {
        nvidia-smi -pm 1 | Out-Null
        Write-Log "NVIDIA persistence mode enabled."
    }
    catch {
        Write-Log "Failed to enable NVIDIA persistence mode: $_" -Level WARN
    }
}

function Disable-NvidiaPersistence {
    Write-Info "Disabling NVIDIA persistence mode..."
    try {
        nvidia-smi -pm 0 | Out-Null
        Write-Log "NVIDIA persistence mode disabled."
    }
    catch {
        Write-Log "Failed to disable NVIDIA persistence mode: $_" -Level WARN
    }
}

function Flush-DNS {
    Write-Info "Flushing DNS..."
    try {
        ipconfig /flushdns | Out-Null
        Write-Log "DNS flushed."
    }
    catch {
        Write-Log "Failed to flush DNS: $_" -Level WARN
    }
}

function Launch-VirtualDesktopStreamer {
    $vdPath = "C:\Program Files\Virtual Desktop Streamer\VirtualDesktop.Streamer.exe"

    if (Test-Path $vdPath) {
        Write-Info "Launching Virtual Desktop Streamer..."
        try {
            Start-Process -FilePath $vdPath | Out-Null
            Write-Log "Virtual Desktop Streamer launched."
            Start-Sleep -Seconds 8
        }
        catch {
            Write-Log "Failed to launch Virtual Desktop Streamer: $_" -Level WARN
        }
    }
}

# ------------------------------------------------------------
# MAIN PREP FUNCTION
# ------------------------------------------------------------
function Invoke-SystemPrep {
    Write-Info "Running system preparation steps..."
    Write-Log "System prep started."

    # Kill apps
    Invoke-KillBuiltIn
    Invoke-KillCustom

    # Stop services
    Stop-ServicesForVR

    # NVIDIA persistence
    Enable-NvidiaPersistence

    # DNS flush
    Flush-DNS

    # Launch VR streamer
    Launch-VirtualDesktopStreamer

    Write-Log "System prep completed."
}

#endregion SYSTEM PREP
#region SIMULATOR LAUNCHER
<#
    Simulator Launcher
    - Steam launch
    - Microsoft Store / GamePass launch
    - Standalone DCS
    - Standalone X-Plane
    - Process detection
    - CPU priority + affinity
    - Logging integration
#>

# ------------------------------------------------------------
# SIM DEFINITIONS
# ------------------------------------------------------------
$SimDefinitions = @{
    "1" = @{
        Name        = "MSFS 2024 (Steam)"
        Method      = "Steam"
        SteamAppId  = "2537590"
        ExeName     = "FlightSimulator2024.exe"
    }
    "2" = @{
        Name        = "MSFS 2020 (Steam)"
        Method      = "Steam"
        SteamAppId  = "1250410"
        ExeName     = "FlightSimulator.exe"
    }
    "3" = @{
        Name        = "DCS World (Steam)"
        Method      = "Steam"
        SteamAppId  = "223750"
        ExeName     = "DCS.exe"
    }
    "5" = @{
        Name        = "MSFS 2024 (Store/GamePass)"
        Method      = "Store"
        ExeName     = "FlightSimulator2024.exe"
        StorePattern = "Limitless|MicrosoftFlightSimulator|FlightSimulator"
    }
    "6" = @{
        Name        = "MSFS 2020 (Store/GamePass)"
        Method      = "Store"
        ExeName     = "FlightSimulator.exe"
        StorePattern = "Microsoft.FlightSimulator"
    }
    "7" = @{
        Name        = "DCS World (Standalone)"
        Method      = "DCSStandalone"
        ExeName     = "DCS.exe"
    }
    "8" = @{
        Name        = "X-Plane 12 (Steam)"
        Method      = "Steam"
        SteamAppId  = "2014780"
        ExeName     = "X-Plane.exe"
    }
    "9" = @{
        Name        = "X-Plane 12 (Standalone)"
        Method      = "XPlaneStandalone"
        ExeName     = "X-Plane.exe"
    }
}

# ------------------------------------------------------------
# Resolve Store URI
# ------------------------------------------------------------
function Get-StoreURI {
    param(
        [Parameter(Mandatory)]
        [string]$Pattern
    )

    try {
        $pkg = Get-AppxPackage |
            Where-Object { $_.Name -match $Pattern } |
            Select-Object -First 1

        if ($pkg) {
            return "shell:AppsFolder\$($pkg.PackageFamilyName)!App"
        }
    }
    catch {
        Write-Log "Failed to resolve Store URI: $_" -Level WARN
    }

    return $null
}

# ------------------------------------------------------------
# Launch Steam sim
# ------------------------------------------------------------
function Launch-SteamSim {
    param(
        [Parameter(Mandatory)]
        [string]$AppId
    )

    Write-Info "Launching Steam simulator..."
    Write-Log "Launching Steam appid $AppId"

    try {
        Start-Process "steam://run/$AppId"
    }
    catch {
        Write-Log "Failed to launch Steam app ${AppId}: $_" -Level ERROR
        Write-ErrorUI "Failed to launch Steam simulator."
    }
}

# ------------------------------------------------------------
# Launch Store sim
# ------------------------------------------------------------
function Launch-StoreSim {
    param(
        [Parameter(Mandatory)]
        [string]$Pattern
    )

    Write-Info "Launching Microsoft Store simulator..."
    $uri = Get-StoreURI -Pattern $Pattern

    if (-not $uri) {
        Write-ErrorUI "Could not resolve Store app. Is it installed?"
        Write-Log "Store app not found for pattern $Pattern" -Level ERROR
        return
    }

    Write-Log "Launching Store URI: $uri"

    try {
        Start-Process "explorer.exe" $uri
    }
    catch {
        Write-Log "Failed to launch Store sim: $_" -Level ERROR
        Write-ErrorUI "Failed to launch Store simulator."
    }
}

# ------------------------------------------------------------
# Launch DCS Standalone
# ------------------------------------------------------------
function Launch-DCSStandalone {
    Write-Info "Launching DCS Standalone..."

    $possiblePaths = @(
        "C:\Eagle Dynamics\DCS World\bin\DCS.exe",
        "C:\DCS World\bin\DCS.exe"
    )

    # Search drives C-J
    foreach ($drive in 'C'..'J') {
        $path = "$drive`:\Eagle Dynamics\DCS World\bin\DCS.exe"
        if (Test-Path $path) { $possiblePaths += $path }

        $path2 = "$drive`:\DCS World\bin\DCS.exe"
        if (Test-Path $path2) { $possiblePaths += $path2 }
    }

    $exe = $possiblePaths | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $exe) {
        Write-ErrorUI "DCS Standalone not found."
        Write-Log "DCS Standalone not found." -Level ERROR
        return
    }

    Write-Log "Launching DCS Standalone: $exe"

    try {
        Start-Process -FilePath $exe
    }
    catch {
        Write-Log "Failed to launch DCS Standalone: $_" -Level ERROR
        Write-ErrorUI "Failed to launch DCS Standalone."
    }
}

# ------------------------------------------------------------
# Launch X-Plane Standalone
# ------------------------------------------------------------
function Launch-XPlaneStandalone {
    Write-Info "Launching X-Plane 12 Standalone..."

    $paths = @()

    foreach ($drive in 'C'..'J') {
        $candidate = "$drive`:\X-Plane 12\X-Plane.exe"
        if (Test-Path $candidate) { $paths += $candidate }
    }

    $exe = $paths | Select-Object -First 1

    if (-not $exe) {
        Write-ErrorUI "X-Plane 12 Standalone not found."
        Write-Log "X-Plane Standalone not found." -Level ERROR
        return
    }

    Write-Log "Launching X-Plane Standalone: $exe"

    try {
        Start-Process -FilePath $exe
    }
    catch {
        Write-Log "Failed to launch X-Plane Standalone: $_" -Level ERROR
        Write-ErrorUI "Failed to launch X-Plane Standalone."
    }
}

# ------------------------------------------------------------
# Detect running sim process
# ------------------------------------------------------------
function Wait-ForSimProcess {
    param(
        [Parameter(Mandatory)]
        [string]$ExeName
    )

    Write-Info "Waiting for simulator process to start..."
    Write-Log "Waiting for process: $ExeName"

    for ($i = 1; $i -le 7; $i++) {
        $proc = Get-Process -Name ($ExeName -replace ".exe","") -ErrorAction SilentlyContinue
        if ($proc) {
            Write-Success "Simulator detected: $ExeName"
            Write-Log "Simulator detected: $ExeName"
            return $proc
        }

        Write-Host "  Attempt $i/7..."
        Start-Sleep -Seconds 5
    }

    Write-ErrorUI "Simulator did not start."
    Write-Log "Simulator failed to start." -Level ERROR
    return $null
}

# ------------------------------------------------------------
# Apply CPU priority + affinity
# ------------------------------------------------------------
function Optimize-SimProcess {
    param(
        [Parameter(Mandatory)]
        [System.Diagnostics.Process]$Process
    )

    Write-Info "Applying CPU priority and affinity..."
    Write-Log "Applying CPU optimization to PID $($Process.Id)"

    try {
        $Process.PriorityClass = "High"

        $cpu = Get-CimInstance Win32_Processor
        $cores = $cpu.NumberOfCores
        $logical = $cpu.NumberOfLogicalProcessors

        $mask = [int64]0

        if ($logical -gt $cores) {
            # Hyperthreading: use physical cores only
            for ($i = 0; $i -lt $cores; $i++) {
                $mask += [int64][math]::Pow(2, $i * 2)
            }
        }
        else {
            # No hyperthreading
            for ($i = 0; $i -lt $cores; $i++) {
                $mask += [int64][math]::Pow(2, $i)
            }
        }

        $Process.ProcessorAffinity = [IntPtr]$mask
        Write-Success "CPU optimization applied."
        Write-Log "CPU affinity mask applied: $mask"
    }
    catch {
        Write-Log "Failed to apply CPU optimization: $_" -Level WARN
        Write-Warn "CPU optimization partially applied."
    }
}

# ------------------------------------------------------------
# MAIN LAUNCH FUNCTION
# ------------------------------------------------------------
function Launch-Simulator {
    param(
        [Parameter(Mandatory)]
        [string]$SimId
    )

    if (-not $SimDefinitions.ContainsKey($SimId)) {
        Write-ErrorUI "Invalid simulator selection."
        return $null
    }

    $sim = $SimDefinitions[$SimId]
    Write-Info "Launching: $($sim.Name)"
    Write-Log "Launching simulator: $($sim.Name)"

    switch ($sim.Method) {
        "Steam"          { Launch-SteamSim -AppId $sim.SteamAppId }
        "Store"          { Launch-StoreSim -Pattern $sim.StorePattern }
        "DCSStandalone"  { Launch-DCSStandalone }
        "XPlaneStandalone" { Launch-XPlaneStandalone }
    }

    # Wait for process
    $proc = Wait-ForSimProcess -ExeName $sim.ExeName
    if (-not $proc) { return $null }

    # Apply P-core affinity 
    Set-PCoreAffinity -ProcessName ($sim.ExeName -replace ".exe","")

    return $proc
}

#endregion SIMULATOR LAUNCHER
#region RESTORE LOGIC
<#
    Restore Logic
    - Restore services
    - Restore power plan
    - Disable NVIDIA persistence mode
    - Restart built-in apps
    - Restart custom apps
    - Logging integration
#>

function Invoke-SystemRestore {
    param(
        [Parameter(Mandatory)]
        [string]$PreviousPowerPlan
    )

    Write-Info "Restoring system state..."
    Write-Log "System restore started."

    # Restore services
    Start-ServicesAfterVR

    # Disable NVIDIA persistence mode
    Disable-NvidiaPersistence

    # Restore previous power plan
    if ($PreviousPowerPlan) {
        Restore-PowerPlan -PreviousGuid $PreviousPowerPlan
    }
    else {
        Write-Warn "Previous power plan unknown — skipping restore."
        Write-Log "Previous power plan missing; restore skipped." -Level WARN
    }

    # Restart built-in apps
    Invoke-RestartBuiltIn

    # Restart custom apps
    Invoke-RestartCustom

    Write-Log "System restore completed."
    Write-Success "System restored."
}

#endregion RESTORE LOGIC
#region MENUS & MAIN FLOW
<#
    Menus & Main Flow
    - Main menu
    - Sim selection
    - Config menu
    - Custom app management
    - Launch + prep + restore orchestration
#>

function Show-MainMenu {
    Clear-Host
    Show-Box -Title "VR AUTO-OPTIMIZER — MAIN MENU"

    Write-White "  1) Launch Simulator (manual selection)"
    Write-White "  2) Configure App Controls"
    Write-White ""
    Write-White "  X) Exit"
}

function Show-SimMenu {
    Clear-Host
    Show-Box -Title "SELECT YOUR SIMULATOR"

    Write-White "  1) MSFS 2024 (Steam)"
    Write-White "  2) MSFS 2020 (Steam)"
    Write-White "  3) DCS World (Steam)"
    Write-White "  5) MSFS 2024 (Store/GamePass)"
    Write-White "  6) MSFS 2020 (Store/GamePass)"
    Write-White "  7) DCS World (Standalone)"
    Write-White "  8) X-Plane 12 (Steam)"
    Write-White "  9) X-Plane 12 (Standalone)"
    Write-White ""
    Write-White "  B) Back"
    Write-White "  X) Exit"
}

function Toggle-Flag {
    param(
        [Parameter(Mandatory)][string]$Path
    )

    # Split "Kill.OneDrive" into "Kill" and "OneDrive"
    $parts = $Path.Split('.')
    $section = $parts[0]
    $key     = $parts[1]

    $current = $Config[$section][$key]

    if ($current -is [bool]) {
        $Config[$section][$key] = -not $current
        Save-Config -Config $Config
    }
}


function Show-ConfigMenu {
    while ($true) {
        Clear-Host
        Show-Box -Title "CONFIGURATION — APP CONTROLS"

        Write-White "  Kill Flags:"
        Write-White "    [1] OneDrive        = $($Config.Kill.OneDrive)"
        Write-White "    [2] Edge            = $($Config.Kill.Edge)"
        Write-White "    [3] CCleaner        = $($Config.Kill.CCleaner)"
        Write-White "    [4] iCloudServices  = $($Config.Kill.iCloudServices)"
        Write-White "    [5] iCloudDrive     = $($Config.Kill.iCloudDrive)"
        Write-White "    [6] Discord         = $($Config.Kill.Discord)"
        Write-Host ""

        Write-White "  Restart Flags:"
        Write-White "    [7] Restart Edge     = $($Config.Restart.Edge)"
        Write-White "    [8] Restart Discord  = $($Config.Restart.Discord)"
        Write-White "    [9] Restart OneDrive = $($Config.Restart.OneDrive)"
        Write-White "    [10] Restart CCleaner = $($Config.Restart.CCleaner)"
        Write-White "    [11] Restart iCloud   = $($Config.Restart.iCloud)"
        Write-Host ""

        Write-White "  D) Set default sim (current: $($Config.DefaultSim))"
        Write-White "  A) Toggle auto-run on start (AutoRunOnStart = $($Config.AutoRunOnStart))"
        Write-White ""
        Write-White "  C) Manage custom apps"
        Write-White "  S) Save and return"
        Write-White "  B) Back without saving"

        $choice = Read-Choice -Prompt "Selection:"
        switch -Regex ($choice) {
            '^1$' { Toggle-Flag 'Kill.OneDrive' }
            '^2$' { Toggle-Flag 'Kill.Edge' }
            '^3$' { Toggle-Flag 'Kill.CCleaner' }
            '^4$' { Toggle-Flag 'Kill.iCloudServices' }
            '^5$' { Toggle-Flag 'Kill.iCloudDrive' }
            '^6$' { Toggle-Flag 'Kill.Discord' }
            '^7$' { Toggle-Flag 'Restart.Edge' }
            '^8$' { Toggle-Flag 'Restart.Discord' }
            '^9$' { Toggle-Flag 'Restart.OneDrive' }
            '^10$' { Toggle-Flag 'Restart.CCleaner' }
            '^11$' { Toggle-Flag 'Restart.iCloud' }
            '^[dD]$' { Set-DefaultSim }
            '^[aA]$' {
                $Config.AutoRunOnStart = -not $Config.AutoRunOnStart
                Save-Config -Config $Config
            }
            '^[cC]$' { Manage-CustomApps }
            '^[sS]$' { Save-Config -Config $Config; return }
            '^[bB]$' { return }
        }
    }
}

function Set-DefaultSim {
    Show-SimMenu
    $sel = Read-Choice -Prompt "Enter default sim ID (1-9, or blank to cancel):"
    if ([string]::IsNullOrWhiteSpace($sel)) { return }
    if (-not $SimDefinitions.ContainsKey($sel)) {
        Write-ErrorUI "Invalid sim ID."
        Start-Sleep -Seconds 2
        return
    }
    $Config.DefaultSim = $sel
    Save-Config -Config $Config
}

function Manage-CustomApps {
    while ($true) {
        Clear-Host
        Show-Box -Title "CUSTOM APPS — KILL / RESTART"

        Write-White "  Custom Kill List (process names):"
        if ($Config.Kill.Custom.Count -eq 0) {
            Write-White "    (none)"
        } else {
            $i = 1
            foreach ($p in $Config.Kill.Custom) {
                Write-White ("    [{0}] {1}" -f $i, $p)
                $i++
            }
        }
        Write-Host ""

        Write-White "  Custom Restart List (Command + Args):"
        if ($Config.Restart.Custom.Count -eq 0) {
            Write-White "    (none)"
        } else {
            $i = 1
            foreach ($entry in $Config.Restart.Custom) {
                Write-White ("    [{0}] {1} {2}" -f $i, $entry.Command, $entry.Args)
                $i++
            }
        }
        Write-Host ""

        Write-White "  1) Add custom kill process"
        Write-White "  2) Remove custom kill process"
        Write-White "  3) Add custom restart entry"
        Write-White "  4) Remove custom restart entry"
        Write-White ""
        Write-White "  B) Back"

        $choice = Read-Choice -Prompt "Selection:"
        switch ($choice) {
            '1' { Add-CustomKill }
            '2' { Remove-CustomKill }
            '3' { Add-CustomRestart }
            '4' { Remove-CustomRestart }
            'B' { return }
            'b' { return }
        }
    }
}

function Add-CustomKill {
    $name = Read-Choice -Prompt "Enter process name to kill (without .exe):"
    if ([string]::IsNullOrWhiteSpace($name)) { return }
    $Config.Kill.Custom += $name
    Save-Config -Config $Config
}

function Remove-CustomKill {
    if ($Config.Kill.Custom.Count -eq 0) { return }
    $idx = Read-Choice -Prompt "Enter index to remove:"
    if (-not [int]::TryParse($idx, [ref]0)) { return }
    $i = [int]$idx
    if ($i -lt 1 -or $i -gt $Config.Kill.Custom.Count) { return }
    $Config.Kill.Custom = @($Config.Kill.Custom | Select-Object -Index (0..($Config.Kill.Custom.Count-1) | Where-Object { $_ -ne ($i-1) }))
    Save-Config -Config $Config
}

function Add-CustomRestart {
    $cmd = Read-Choice -Prompt "Enter full command path:"
    if ([string]::IsNullOrWhiteSpace($cmd)) { return }
    $args = Read-Choice -Prompt "Enter arguments (optional):"

    $entry = [ordered]@{
        Command = $cmd
        Args    = $args
    }
    $Config.Restart.Custom += $entry
    Save-Config -Config $Config
}

function Remove-CustomRestart {
    if ($Config.Restart.Custom.Count -eq 0) { return }
    $idx = Read-Choice -Prompt "Enter index to remove:"
    if (-not [int]::TryParse($idx, [ref]0)) { return }
    $i = [int]$idx
    if ($i -lt 1 -or $i -gt $Config.Restart.Custom.Count) { return }
    $Config.Restart.Custom = @($Config.Restart.Custom | Select-Object -Index (0..($Config.Restart.Custom.Count-1) | Where-Object { $_ -ne ($i-1) }))
    Save-Config -Config $Config
}

function Run-SimFlow {
    param(
        [Parameter(Mandatory)]
        [string]$SimId
    )

    # Capture current power plan
    $prevPlan = Get-ActivePowerPlan

    # Switch to Ultimate Performance
    Ensure-UltimatePerformance

    # System prep
    Invoke-SystemPrep

    # Launch sim
    $proc = Launch-Simulator -SimId $SimId
    if (-not $proc) {
        Write-ErrorUI "Launch failed; restoring system..."
        Invoke-SystemRestore -PreviousPowerPlan $prevPlan
        return
    }

    Show-Box -Title "$($SimDefinitions[$SimId].Name) RUNNING"
    Write-White "  Do not close this window while the simulator is running."
    Write-Host ""

    # Wait for sim exit
    while (-not $proc.HasExited) {
        Start-Sleep -Seconds 15
        try {
            $proc.Refresh()
        } catch {
            break
        }
    }

    Write-Info "Simulator exited. Restoring system..."
    Invoke-SystemRestore -PreviousPowerPlan $prevPlan
}

function Main-Loop {
    # Optional auto-run
    if ($Config.AutoRunOnStart -and $Config.DefaultSim) {
        Write-Info "Auto-run enabled. Launching default sim: $($Config.DefaultSim)"
        Run-SimFlow -SimId $Config.DefaultSim
    }

    while ($true) {
        Show-MainMenu
        $choice = Read-Choice -Prompt "Selection:"

        switch -Regex ($choice) {
            '^1$' {
                while ($true) {
                    Show-SimMenu
                    $sel = Read-Choice -Prompt "Selection (1-9/B/X):"
                    if ($sel -match '^[xX]$') { Close-LogSession; exit }
                    if ($sel -match '^[bB]$') { break }
                    if (-not $SimDefinitions.ContainsKey($sel)) {
                        Write-ErrorUI "Invalid selection."
                        Start-Sleep -Seconds 2
                        continue
                    }
                    Run-SimFlow -SimId $sel
                }
            }
            '^2$' { Show-ConfigMenu }
            '^[xX]$' { Close-LogSession; exit }
        }
    }
}

#endregion MENUS & MAIN FLOW

# Entry point
Main-Loop
