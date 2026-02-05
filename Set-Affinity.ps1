#Requires -Version 5.1
<#
.SYNOPSIS
  Apply safe, vendor-agnostic CPU affinity and High priority for a running process.
  Works on AMD and Intel (incl. hybrid P/E cores using CPU Sets on Win10/11). Single-group (<=64 LP) only.

.PARAMETER ProcessName
  Process name with or without ".exe" (e.g., "FlightSimulator2024.exe" or "FlightSimulator2024").

.PARAMETER Mode
  Auto         : Intel hybrid -> P-cores only; otherwise -> All LPs
  All          : All logical processors
  PCoresOnly   : Intel hybrid P-cores (EfficiencyClass==0)
  ECoresOnly   : Intel hybrid E-cores (EfficiencyClass>0)
  PhysicalOnly : One LP per physical core (SMT-aware)

.PARAMETER LogPath
  Full path to a log file. If present, the script logs to it and to console.
#>

param(
  [Parameter(Mandatory = $true)]
  [string]$ProcessName,

  [ValidateSet('Auto','All','PCoresOnly','ECoresOnly','PhysicalOnly')]
  [string]$Mode = 'Auto',

  [string]$LogPath
)

$ErrorActionPreference = 'Stop'

function Write-Both([string]$msg, [ConsoleColor]$color = [ConsoleColor]::Cyan) {
  # Console
  $orig = $Host.UI.RawUI.ForegroundColor
  try {
    $Host.UI.RawUI.ForegroundColor = $color
    Write-Host $msg
  } finally {
    $Host.UI.RawUI.ForegroundColor = $orig
  }
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
    if ($arr[$i] -eq $prev + 1) {
      $prev = $arr[$i]
      continue
    }
    if ($start -eq $prev) {
      $ranges += "$start"
    } else {
      $ranges += "$start-$prev"
    }
    $start = $arr[$i]; $prev = $arr[$i]
  }
  if ($start -eq $prev) {
    $ranges += "$start"
  } else {
    $ranges += "$start-$prev"
  }
  return ($ranges -join ",")
}

$p = Get-TargetProcess $ProcessName
if (-not $p) {
  Write-Both "[AFFINITY] Process not found: $ProcessName" ([ConsoleColor]::Yellow)
  exit 1
}

$cpu     = Get-CimInstance Win32_Processor
$logical = [int]$cpu.NumberOfLogicalProcessors
$cores   = [int]$cpu.NumberOfCores
$isIntel = ($cpu.Manufacturer -like '*Intel*')

# ---- CPU Sets API (Win10/11) ----
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
        public short Group; // processor group
        public byte LogicalProcessorIndex;
        public byte CoreIndex;
        public byte LastLevelCacheIndex;
        public byte NUMANodeIndex;
        public byte EfficiencyClass; // 0 => P-core on Intel hybrid typically
        public byte Parked;
        public byte Allocated;
        public byte AllocatedToTargetProcess;
        public uint Flags;
        public ulong Reserved0;
        public ulong Reserved1;
    }

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool GetSystemCpuSetInformation(
        IntPtr information,
        int bufferLength,
        out int returnedLength,
        IntPtr process,
        int flags
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
    } finally {
      [Runtime.InteropServices.Marshal]::FreeHGlobal($buf)
    }
  }
} catch {
  $cpuSetApiAvailable = $false
}

# ---- Select LPs ----
$sel = @()
switch ($Mode) {
  'All' {
    $sel = 0..([Math]::Min($logical,64)-1)
  }
  'PCoresOnly' {
    if ($cpuSetApiAvailable -and $isIntel) {
      $sel = $cpuSets | Where-Object { $_.Group -eq 0 -and $_.EfficiencyClass -eq 0 } |
        Select-Object -ExpandProperty LogicalProcessorIndex | Sort-Object -Unique
      if (-not $sel) { $sel = 0..([Math]::Min($logical,64)-1) }
    } else { $Mode = 'PhysicalOnly' }
    if ($Mode -ne 'PhysicalOnly') { break }
  }
  'ECoresOnly' {
    if ($cpuSetApiAvailable -and $isIntel) {
      $sel = $cpuSets | Where-Object { $_.Group -eq 0 -and $_.EfficiencyClass -gt 0 } |
        Select-Object -ExpandProperty LogicalProcessorIndex | Sort-Object -Unique
      if (-not $sel) { $sel = 0..([Math]::Min($logical,64)-1) }
    } else { $Mode = 'PhysicalOnly' }
    if ($Mode -ne 'PhysicalOnly') { break }
  }
  'PhysicalOnly' {
    if ($cpuSetApiAvailable) {
      $sel = $cpuSets | Where-Object { $_.Group -eq 0 } |
        Group-Object CoreIndex | ForEach-Object { $_.Group | Select-Object -First 1 } |
        Select-Object -ExpandProperty LogicalProcessorIndex | Sort-Object -Unique
    } else {
      if ($logical -gt $cores) {
        $max = [Math]::Min($cores, 32)
        $list = New-Object System.Collections.Generic.List[int]
        for ($i=0; $i -lt $max; $i++) { [void]$list.Add($i*2) }
        $sel = $list.ToArray()
      } else {
        $sel = 0..([Math]::Min($logical,64)-1)
      }
    }
  }
  'Auto' {
    if ($cpuSetApiAvailable -and $isIntel) {
      $hasE = (($cpuSets | Where-Object { $_.EfficiencyClass -gt 0 }).Count -gt 0)
      if ($hasE) {
        $sel = $cpuSets | Where-Object { $_.Group -eq 0 -and $_.EfficiencyClass -eq 0 } |
          Select-Object -ExpandProperty LogicalProcessorIndex | Sort-Object -Unique
      } else {
        $sel = 0..([Math]::Min($logical,64)-1)
      }
    } else {
      if ($logical -gt $cores) {
        if ($cpuSetApiAvailable) {
          $sel = $cpuSets | Where-Object { $_.Group -eq 0 } |
            Group-Object CoreIndex | ForEach-Object { $_.Group | Select-Object -First 1 } |
            Select-Object -ExpandProperty LogicalProcessorIndex | Sort-Object -Unique
        } else {
          $max = [Math]::Min($cores, 32)
          $list = New-Object System.Collections.Generic.List[int]
          for ($i=0; $i -lt $max; $i++) { [void]$list.Add($i*2) }
          $sel = $list.ToArray()
        }
      } else {
        $sel = 0..([Math]::Min($logical,64)-1)
      }
    }
  }
}

if (-not $sel -or $sel.Count -eq 0) {
  Write-Both "[AFFINITY] No LPs selected (Mode=$Mode)" ([ConsoleColor]::Yellow)
  exit 2
}

$intendedMask  = New-AffinityMask64 $sel
$intendedLPs   = $sel
$intendedRange = ListToRanges $intendedLPs
$intendedHex   = ("0x{0:X}" -f ([UInt64][Int64]$intendedMask))

# Apply and verify
$appliedStatus = "FAILED"
$appliedMask   = [IntPtr]::Zero
$appliedLPs    = @()
$appliedHex    = "0x0"

try {
  $p.PriorityClass = 'High'
  $p.ProcessorAffinity = $intendedMask
  Start-Sleep -Milliseconds 50  # small settle
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
  $appliedStatus = "FAILED"
  Write-Both "[AFFINITY] Exception: $($_.Exception.Message)" ([ConsoleColor]::Yellow)
}

$appliedRange = ListToRanges $appliedLPs

# Output summary
Write-Both ("[AFFINITY] Mode={0} Process={1} PID={2}" -f $Mode,$p.ProcessName,$p.Id) ([ConsoleColor]::DarkCyan)
Write-Both ("[AFFINITY] INTENDED LPs : {0}  (ranges: {1})" -f ($intendedLPs -join ','), $intendedRange)
Write-Both ("[AFFINITY] INTENDED HEX : {0}" -f $intendedHex)
Write-Both ("[AFFINITY] APPLIED  LPs : {0}  (ranges: {1})" -f (($appliedLPs -join ',')), $appliedRange)
Write-Both ("[AFFINITY] APPLIED  HEX : {0}" -f $appliedHex)

switch ($appliedStatus) {
  "APPLIED"  { Write-Both "[AFFINITY] Status: APPLIED (exact match)" ([ConsoleColor]::Green) }
  "PARTIAL"  { Write-Both "[AFFINITY] Status: PARTIAL (some bits rejected by OS/anti-cheat/protected threads)" ([ConsoleColor]::Yellow) }
  default    { Write-Both "[AFFINITY] Status: FAILED (no change)" ([ConsoleColor]::Red) }
}