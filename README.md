
# 📌 VR Auto‑Optimizer (Universal SIM VR Optimizer)

A fully automated, configurable launcher designed to optimize Windows performance for **VR flight simulators** such as:

- Microsoft Flight Simulator 2024 (Steam / Store)
- Microsoft Flight Simulator 2020 (Steam / Store)
- DCS World (Steam / Standalone)

The script automatically prepares your system before launching a sim, boosts performance, and restores normal operation when the sim exits. It includes a full menu‑driven UI, modular configuration system, and support for custom app kill/restart rules.

---

## ✨ Features

### 🔧 System Optimization Before Launch
- Switches to **High Performance** power profile
- Kills background apps that may reduce VR performance (Discord, Chrome, OneDrive, etc.)
- Supports **custom process kill list**
- Stops optional Windows services (SysMain, Spooler)
- Enables persistent GPU mode via `nvidia-smi`
- Flushes DNS cache
- Auto‑launches Virtual Desktop Streamer (if installed)

### 🛫 Smart Simulator Launcher
- Launches Steam games via `steam://run`
- Launches Microsoft Store apps via Appx URI detection
- Launches DCS Standalone by scanning common install drives
- Applies **High Priority** and **CPU Affinity Mask Optimization**

### 🔄 System Restore on Exit
- Restores normal power plan
- Restarts previously killed apps (configurable)
- Supports **custom restart commands**
- Restarts system services
- Shuts down Virtual Desktop Streamer
- Logs everything

### ⚙️ Full Configuration Menu
- Toggle built‑in kill/restart rules
- Add/remove custom kill processes
- Add/remove custom restart commands
- Persist settings in `vr_opt.cfg`

---

## 📁 Configuration File (`vr_opt.cfg`)

The script auto‑creates and maintains a simple config file:

```ini
KILL_ONEDRIVE=YES
KILL_DISCORD=NO
KILL_CHROME=YES
...

CUST_K_COUNT=2
CUST_K_1=obs64.exe
CUST_K_2=RGBFusion.exe

CUST_R_COUNT=1
CUST_R_CMD_1="C:\Tools\Overlay\overlay.exe"
CUST_R_ARGS_1=--minimized
```

### Built‑in KILL toggles (YES/NO)
- `KILL_ONEDRIVE`
- `KILL_DISCORD`
- `KILL_CHROME`
- `KILL_EDGE`
- `KILL_CCLEANER`
- `KILL_ICLOUDSERVICES`
- `KILL_ICLOUDDRIVE`

### Built‑in RESTART toggles
- `RESTART_EDGE`
- `RESTART_DISCORD`
- `RESTART_ONEDRIVE`
- `RESTART_CCLEANER`
- `RESTART_ICLOUD`

### Custom Kills
Processes to terminate during prep.

### Custom Restarts
Commands to run after restore.

---

## 🧭 How to Use

### 1. Download the Script
Place the `.bat` file anywhere.

### 2. Run as Administrator
The script auto‑elevates if needed.

### 3. Choose a Simulator
Menu options let you launch MSFS/DCS.

### 4. Configure Behavior (Optional)
Use:
```
[2] Configure App Controls
```
Make changes → Save → Written to `vr_opt.cfg`.

### 5. Launch the Sim
Script optimizes, launches, monitors, applies tweaks.

### 6. Restore System
After sim exit, everything is reversed.

---

## 📜 Logging
Logs saved to:
```
sim_launcher.log
```
Includes:
- Prep steps
- Killed/restarted apps
- Launch info
- Restore info
- Log rotation

---

## 🧩 Customization Tips

### Custom Kill Example
```
obs64.exe
MSIAfterburner.exe
RazerSynapse.exe
```

### Custom Restart Example
```
Command: "C:\Program Files\obs-studio\bin\64bit\obs64.exe"
Args: --minimize-to-tray
```

---

## 🛠️ Requirements
- Windows 10/11
- Admin rights
- Steam or Microsoft Store
- NVIDIA GPU (optional, recommended)

---

## 🚀 Why This Script Exists
VR sims demand clean system conditions. This tool automates the whole prep/restore cycle so you can focus on flying—not on babysitting Windows.

---

## 🤝 Contributions
Pull requests welcome! Improvements, additional sim profiles, PowerShell ports, or optimizations are encouraged.

---
## ⚠️ Disclaimer & Known Issues
Please read before use:
-    Antivirus/Windows Defender: Some scanners might flag .bat scripts that use PowerShell commands as a "False Positive." This script is transparent—you can inspect every line of code in Notepad.
-    Custom Paths: If you installed DCS World or Virtual Desktop in a non-standard directory (outside of C:, D:, etc.), you might need to adjust the path variables in the CONFIG section of the script.
-    Experimental Feature: The CPU Affinity optimization works best on modern Intel (12th Gen+) and AMD Ryzen CPUs. If you experience unusual stuttering, you can disable the affinity block by putting a :: before the PowerShell command in the script.

---
## 📄 License
MIT License
