# VR Optimizer

<img width="1024" height="1536" alt="image" src="https://github.com/user-attachments/assets/01b9319f-e835-4f8a-be8c-23f55786696e" />

# ✈ VR Auto-Optimizer

**Version:** 7.4.2 (Stable Beta)  
**Platform:** Windows 10 / 11  
**Framework:** .NET 8 (WPF, C#)

---

## Overview

**VR Auto-Optimizer** is a Windows desktop application designed to streamline launching VR flight simulators with maximum performance. It replaces legacy batch scripts with a modern, themeable WPF interface and manages the *entire lifecycle* of a VR sim session.

### What it does
- Detects installed simulators (Steam, Microsoft Store, Standalone)
- Stops background applications and services that impact performance
- Applies safe or aggressive system optimizations
- Launches the simulator and optional VR runtime
- Monitors the simulator process and applies runtime tweaks
- Fully restores the system when the simulator exits or is cancelled

**No permanent system changes are made.**

---

## Key Features

- Auto-detection of **9 simulator configurations**
- Two optimization modes: **Standard** and **Aggressive**
- Per-optimization granular toggles
- Custom kill and restart app lists
- Real-time 5-stage optimization pipeline
- Automatic full system restoration
- Session logging with log rotation
- One-click Auto-Run mode
- Aviation instrument–themed dark UI
- Configurable VR runtimes (Virtual Desktop, PimaxPlay, SteamVR, None)
- Content Creator Mode for OBS / streaming setups

---

## System Requirements

| Requirement | Details |
|------------|---------|
| OS | Windows 10 (21H2+) or Windows 11 |
| Runtime | .NET 8 Desktop Runtime |
| Permissions | Administrator (required) |
| GPU | NVIDIA recommended |
| VR Runtime | Optional (Virtual Desktop, PimaxPlay, SteamVR) |
| Disk | < 10 MB |

> **Important:** The application must be run as **Administrator** for full functionality.

---

## File Locations

All user data is stored in AppData:

```text
%APPDATA%\SimVROptimizer├── vr_opt.cfg
├── sim_launcher.log
└── sim_launcher.log.old
```

---

## Configuration File (`vr_opt.cfg`)

- Plain-text `KEY=VALUE` format
- Boolean values: `YES` / `NO`
- Safe to edit manually (UI recommended)

### Example

```ini
OPT_LEVEL=Standard
KILL_DISCORD=YES
AUTO_RUN_ON_START=NO
VR_RUNTIME=None
```

---

## Optimization Levels

### Standard (Safe)
- Ultimate Performance power plan
- Stop SysMain and Print Spooler
- NVIDIA persistence mode
- DNS flush
- High process priority
- CPU affinity (vendor-aware)

### Aggressive (Reverted on Exit)
- Disable Game Bar / Game DVR
- Clear standby memory
- High-resolution timer (0.5ms)
- Disable fullscreen optimizations
- NVIDIA max performance mode
- Disable power throttling
- Network and memory optimizations

---

## Supported Simulators

| # | Simulator | Launch Method |
|---|-----------|---------------|
| 1 | MSFS 2024 (Steam) | Steam |
| 2 | MSFS 2020 (Steam) | Steam |
| 3 | DCS World (Steam) | Steam |
| 5 | MSFS 2024 (Store) | Microsoft Store |
| 6 | MSFS 2020 (Store) | Microsoft Store |
| 7 | DCS World (Standalone) | Direct EXE |
| 8 | X-Plane 12 (Steam) | Steam |
| 9 | X-Plane 12 (Standalone) | Direct EXE |

---

## CPU Affinity Intelligence

The optimizer adapts behavior based on detected CPU architecture:

- **AMD X3D:** Affinity skipped (scheduler optimal)
- **AMD non-X3D:** Priority only
- **Intel Hybrid:** P-core affinity applied
- **Intel non-hybrid:** Priority only

---

## Restoration Guarantee

Every system change is tracked and reverted:

- Power plans
- Services
- Registry values
- NVIDIA settings
- OpenXR runtime
- Killed applications

Restoration triggers on:
- Normal simulator exit
- User cancellation
- Errors
- Detection timeouts

---

## Troubleshooting

| Issue | Solution |
|------|----------|
| No sims detected | Click **Rescan**, verify install paths |
| Optimizations fail | Run as Administrator |
| NVIDIA errors | Ensure `nvidia-smi` is available |
| Config not saving | Check AppData permissions |

---

## Reset to Defaults

1. Close the application
2. Delete `%APPDATA%\SimVROptimizer\vr_opt.cfg`
3. Relaunch the app

---

## Credits

**VR Auto-Optimizer**  
Concept & Direction: **VRFLIGHTSIM GUY • SHARK • g0|df!ng3R**  
UI Development: **OverKill Simulations**

✈ Enjoy your flight.