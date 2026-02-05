#Requires -Version 5.1
<#
.SYNOPSIS
  Force a running process to P-cores only (Intel hybrid) and set High priority.
  On AMD / non-hybrid Intel, uses all LPs (no E-cores to exclude). Single group (<=64 LP) only.

.PARAMETER ProcessName
  Process name with or without ".exe" (e.g., "FlightSimulator2024" or "FlightSimulator2024.exe").

.PARAMETER LogPath
  Optional path to a log file; the script writes to console and to this file.

.PARAMETER IntelPcoreCount
  Optional manual override when CPU Sets API is unavailable on Intel hybrid.
  Example: -IntelPcoreCount 8  (for 8 P-cores / 16 P-threads).
#>

param(
  [Parameter(Mandatory = $true)]
  [string]$ProcessName,

  [string]$LogPath,

  [int]$IntelPcoreCount
)

$ErrorActionPreference = 'Stop'

function Write-Both([string]$msg, [ConsoleColor]$color = [ConsoleColor]::Cyan) {
  # Console
  $orig = $Host.UI.RawUI.ForegroundColor
  try { $Host.UI.RawUI.ForegroundColor = $color; Write-Host $msg } finally { $Host.UI.RawUI.ForegroundColor = $orig }
  # File
  if ($LogPath) {
    try { Add-Content -LiteralPath $LogPath -Value ("{0} {1}" -f (Get-Date -Format "HH:mm:ss.fff"), $msg) } catch {}
  }
}

function Get-TargetProcess {
  param([string]$n)
  $base = [IO.Path]::GetFileNameWithoutExtension($n)
  if ([string]::IsNullOrWhiteSpace($base)) { $base = $n }
  $p = Get-Process -Name $base -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($p) { return $p }
  return Get-Process -ErrorAction SilentlyContinue | Where-Object {
    $_.ProcessName -ieq $base -or ($_.Path -and $_.Path -like "*$base*")
  } | Select-Object -First 1
}

function New-AffinityMask64([int[]]$lp) {
  $m = [UInt64]0
  foreach ($i in $lp) { if ($i -ge 0 -and $i -lt 64) { $m = $m -bor ([UInt64]1 -shl $i) } }
  return [IntPtr][Int64]$m
}
function MaskToLpList([IntPtr]$mask) {
  $u = [UInt64][Int64]$mask
  $out = New-Object System.Collections.Generic.List[int]
  for ($i=0; $i -lt 64; $i++) { if ( ($u -band ([UInt64]1 -shl $i)) -ne 0 ) { [void]$out.Add($i) } }
  return $out.ToArray()
}
function ListToRanges([int[]]$arr) {
  if (-not $arr -or $arr.Count -eq 0) { return "" }
  $arr = $arr | Sort-Object
  $ranges = @()
  $start = $arr[0]; $prev = $arr[0]
  for ($i=1; $i -lt $arr.Count; $i++) {
    if ($arr[$i] -eq $prev + 1) { $prev = $arr[$i]; continue }
    if ($start -eq $prev) { $ranges += "$start" } else { $ranges += "$start-$prev" }
    $start = $arr[$i]; $prev = $arr[$i]
  }
  if ($start -eq $prev) { $ranges += "$start" } else { $ranges += "$start-$prev" }
  return ($ranges -join ",")
}

# --- Resolve process ---
$p = Get-TargetProcess $ProcessName
if (-not $p) { Write-Both "[AFFINITY] Process not found: $ProcessName" ([ConsoleColor]::Yellow); exit 1 }

# --- CPU facts ---
$cpu     = Get-CimInstance Win32_Processor
$logical = [int]$cpu.NumberOfLogicalProcessors
$cores   = [int]$cpu.NumberOfCores
$isIntel = ($cpu.Manufacturer -like '*Intel*')

$maxLp = [Math]::Min($logical, 64)  # single group only

# === CPU Sets API (Win10/11) to map LPs & efficiency ===
$cpuSetApiAvailable = $false
$cpuSets = @()

$cs = @"
using System;
using System.Runtime.InteropServices;
public static class CpuSetsApi
{
    [StructLayout(LayoutKind.Sequential)]
    public struct SYSTEM_CPU_SET_INFORMATION
    {
        public int Size;
        public int Type; // 0 = CpuSetInformation
        public CPU_SET CpuSet;
    }
    [StructLayout(LayoutKind.Sequential)]
    public struct CPU_SET
    {
        public int Id;
        public short Group;
        public byte LogicalProcessorIndex;
        public byte CoreIndex;
        public byte LastLevelCacheIndex;
        public byte NUMANodeIndex;
        public byte EfficiencyClass; // Intel: 0=P-core, >0=E-core typically
        public byte Parked;
        public byte Allocated;
        public byte AllocatedToTargetProcess;
        public uint Flags;
        public ulong Reserved0;
        public ulong Reserved1;
    }
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool GetSystemCpuSetInformation(
        IntPtr information, int bufferLength, out int returnedLength, IntPtr process, int flags
    );
}
"@

try {
  Add-Type -TypeDefinition $cs -ErrorAction Stop | Out-Null
  $retLen = 0
  [CpuSetsApi]::GetSystemCpuSetInformation([IntPtr]::Zero, 0, [ref]$retLen, [IntPtr]::Zero, 0) | Out-Null
  if ($retLen -gt 0) {
    $buf = [Runtime.InteropServices.Marshal]::AllocHGlobal($retLen)
    try {
      if ([CpuSetsApi]::GetSystemCpuSetInformation($buf, $retLen, [ref]$retLen, [IntPtr]::Zero, 0)) {
        $cpuSetApiAvailable = $true
        $offset = 0
        $recType = [type]'CpuSetsApi+SYSTEM_CPU_SET_INFORMATION'
        while ($offset -lt $retLen) {
          $ptr = [IntPtr]::Add($buf, $offset)
          $rec = [Runtime.InteropServices.Marshal]::PtrToStructure($ptr, $recType)
          $cpuSets += $rec.CpuSet
          $offset += $rec.Size
        }
      }
    } finally { [Runtime.InteropServices.Marshal]::FreeHGlobal($buf) }
  }
} catch {
  $cpuSetApiAvailable = $false
}

# --- Select P-cores ---
$sel = @()

if ($isIntel) {
  if ($cpuSetApiAvailable) {
    # Intel hybrid: P-cores = EfficiencyClass==0, group 0, within 0..63
    $sel = $cpuSets |
      Where-Object { $_.Group -eq 0 -and $_.EfficiencyClass -eq 0 } |
      Select-Object -ExpandProperty LogicalProcessorIndex |
      Where-Object { $_ -ge 0 -and $_ -lt $maxLp } |
      Sort-Object -Unique

    if (-not $sel -or $sel.Count -eq 0) {
      Write-Both "[AFFINITY] CPU Sets present but no P-cores returned; falling back." ([ConsoleColor]::Yellow)
    }
  }

  if (-not $cpuSetApiAvailable -or -not $sel -or $sel.Count -eq 0) {
    # Fallback when CPU Sets are not available:
    if ($IntelPcoreCount -gt 0) {
      $pThreads = $IntelPcoreCount * 2   # each P-core has 2 threads
      $upper = [Math]::Min($pThreads, $maxLp) - 1
      if ($upper -ge 0) { $sel = 0..$upper } else { $sel = 0..($maxLp-1) }
      Write-Both "[AFFINITY] Fallback: Using first $($upper+1) LPs as P-cores (user override: $IntelPcoreCount P-cores)." ([ConsoleColor]::Yellow)
    } else {
      # Without CPU Sets and no override, safest is to avoid guessing → all LPs
      $sel = 0..($maxLp-1)
      Write-Both "[AFFINITY] Warning: CPU Sets unavailable; cannot safely isolate P-cores. Using ALL LPs." ([ConsoleColor]::Yellow)
      Write-Both "[AFFINITY] Tip: Pass -IntelPcoreCount (e.g., 8) to select first 16 LPs on Intel hybrid." ([ConsoleColor]::Yellow)
    }
  }
}
else {
  # AMD / non-Intel → no E-cores; P-only == all
  $sel = 0..($maxLp-1)
}

# Safety clamp & uniq
$sel = $sel | Where-Object { $_ -ge 0 -and $_ -lt $maxLp } | Sort-Object -Unique

if (-not $sel -or $sel.Count -eq 0) {
  Write-Both "[AFFINITY] No LPs selected for P-cores." ([ConsoleColor]::Red)
  exit 2
}

# --- Build intended mask ---
$intendedMask  = New-AffinityMask64 $sel
$intendedLPs   = $sel
$intendedRange = ListToRanges $intendedLPs
$intendedHex   = ("0x{0:X}" -f ([UInt64][Int64]$intendedMask))

# --- Apply & verify ---
$appliedStatus = "FAILED"
$appliedMask   = [IntPtr]::Zero
$appliedLPs    = @()
$appliedHex    = "0x0"

try {
  $p.PriorityClass = 'High'
  $p.ProcessorAffinity = $intendedMask
  Start-Sleep -Milliseconds 50
  $appliedMask = $p.ProcessorAffinity
  $appliedLPs  = MaskToLpList $appliedMask
  $appliedHex  = ("0x{0:X}" -f ([UInt64][Int64]$appliedMask))

  if ([UInt64][Int64]$appliedMask -eq [UInt64][Int64]$intendedMask) {
    $appliedStatus = "APPLIED"
  } elseif ($appliedLPs.Count -gt 0) {
    $appliedStatus = "PARTIAL"
  } else {
    $appliedStatus = "FAILED"
  }
}
catch {
  Write-Both "[AFFINITY] Exception: $($_.Exception.Message)" ([ConsoleColor]::Yellow)
  $appliedStatus = "FAILED"
}

$appliedRange = ListToRanges $appliedLPs

# --- Output summary ---
Write-Both ("[AFFINITY] Target=P-cores only | Process={0} PID={1}" -f $p.ProcessName,$p.Id) ([ConsoleColor]::DarkCyan)
Write-Both ("[AFFINITY] INTENDED LPs : {0}  (ranges: {1})" -f ($intendedLPs -join ','), $intendedRange)
Write-Both ("[AFFINITY] INTENDED HEX : {0}" -f $intendedHex)
Write-Both ("[AFFINITY] APPLIED  LPs : {0}  (ranges: {1})" -f (($appliedLPs -join ',')), $appliedRange)
Write-Both ("[AFFINITY] APPLIED  HEX : {0}" -f $appliedHex)

switch ($appliedStatus) {
  "APPLIED"  { Write-Both "[AFFINITY] Status: APPLIED (exact P-core binding)" ([ConsoleColor]::Green) }
  "PARTIAL"  { Write-Both "[AFFINITY] Status: PARTIAL (some bits rejected by OS/anti-cheat/protected threads)" ([ConsoleColor]::Yellow) }
  default    { Write-Both "[AFFINITY] Status: FAILED (no change)" ([ConsoleColor]::Red) }
}

if ($logical -gt 64) {
  Write-Both "[AFFINITY] Note: System has >64 LP (multiple groups). This helper targets Group 0 only." ([ConsoleColor]::Yellow)
}
