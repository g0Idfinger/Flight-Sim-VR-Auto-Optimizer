# VR Optimizer — PowerShell Edition

## Requires Powershell 7.5+
[Download](https://github.com/powershell/powershell/releases)

---
A modern, single‑file PowerShell application that prepares your Windows system for VR flight simulation, launches your simulator with optimized CPU settings, and restores your system afterward.  
Designed for **MSFS 2020/2024**, **DCS**, and **X‑Plane 12**.

---

## 📸 Screenshots

> Replace these image paths when I find the time to take screenshots... note for self

### Main Menu
<img width="573" height="256" alt="image" src="https://github.com/user-attachments/assets/4d139b6a-233c-406e-879e-0b2d0588aa55" />


### Simulator Selection
<img width="569" height="331" alt="image" src="https://github.com/user-attachments/assets/04c3909d-e515-4e6f-889a-326371fc7418" />


### Configuration Menu
<img width="566" height="529" alt="image" src="https://github.com/user-attachments/assets/aee53b23-aeb2-43df-a006-b7bf5a2980c6" />

---

## ✨ Features

### 🔧 System Optimization
- Kills background apps (OneDrive, Edge, CCleaner, iCloud, etc.)
- Stops unnecessary services (SysMain, Spooler)
- Enables NVIDIA Persistence Mode
- Flushes DNS
- Launches Virtual Desktop Streamer (if installed)

### 🚀 Simulator Launching
Supports:
- **MSFS 2024 (Steam / Store)**
- **MSFS 2020 (Steam / Store)**
- **DCS World (Steam / Standalone)**
- **X‑Plane 12 (Steam / Standalone)**

Includes:
- Steam launching via `steam://run/<appid>`
- Store/GamePass launching via AppX URI resolution
- Auto‑detection of standalone DCS & X‑Plane paths
- Process detection + wait loop
- CPU priority + affinity optimization

### 🔄 System Restore
After the simulator exits:
- Restores services
- Restores previous power plan
- Disables NVIDIA persistence mode
- Restarts apps (Edge, Discord, OneDrive, CCleaner, iCloud)
- Restarts custom apps defined in config

### ⚙️ Configuration
- Clean `config.json` stored next to the script
- Auto‑created on first run
- Toggle kill/restart flags
- Manage custom kill/restart lists
- Set default simulator
- Optional auto‑run on script start

### 🖥️ Modern Terminal UI
- Light box‑drawing borders
- Clean, centered headers
- Color‑coded output
- Intuitive menus

### 📝 Logging
- Full session logging to `sim_launcher.log`
- Automatic log rotation (2MB)
- Session start/end markers

---

## 📂 File Structure

```
VR-Optimizer.ps1
config.json              (auto-created)
sim_launcher.log         (auto-created)
sim_launcher.log.old     (auto-rotated)
```

---

## ▶️ Installation

### 1. Download the script
Place `VR-Optimizer.ps1` anywhere you like.


### 2. Run the script
Right‑click → **Run with PowerShell**  
or:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\VR-Optimizer.ps1
```

### 3. First‑run setup
The script will automatically:
- Elevate to Administrator
- Create `config.json`
- Create/rotate logs
- Initialize default settings

---

## ⚙️ Configuration File (`config.json`)

Example structure:

```
{
  "Kill": {
    "OneDrive": true,
    "Edge": true,
    "CCleaner": true,
    "iCloudServices": true,
    "iCloudDrive": true,
    "Custom": []
  },
  "Restart": {
    "Edge": true,
    "Discord": true,
    "OneDrive": true,
    "CCleaner": true,
    "iCloud": true,
    "Custom": []
  },
  "DefaultSim": null,
  "AutoRunOnStart": false
}
```

You can edit this manually or through the built‑in config menu.

---

## 🧭 Menu Overview

### **Main Menu**
```
1) Launch Simulator
2) Configure App Controls
X) Exit
```

### **Simulator Selection**
```
1) MSFS 2024 (Steam)
2) MSFS 2020 (Steam)
3) DCS World (Steam)
5) MSFS 2024 (Store/GamePass)
6) MSFS 2020 (Store/GamePass)
7) DCS Standalone
8) X-Plane 12 (Steam)
9) X-Plane 12 (Standalone)
```

### **Config Menu**
- Toggle kill/restart flags  
- Manage custom apps  
- Set default simulator  
- Enable/disable auto‑run  

---

## 🧠 How It Works (High‑Level Flow)

1. **User selects a simulator**
2. Script:
   - Saves current power plan
   - Switches to Ultimate Performance
   - Runs System Prep
   - Launches the simulator
3. Script waits for the simulator to exit
4. Script restores:
   - Services
   - Power plan
   - NVIDIA persistence mode
   - Restart apps
5. Logs everything

---

## 🛠 Requirements

- Windows 10/11  
- PowerShell 5.1+  
- Administrator privileges  
- Steam (if using Steam sims)  
- Microsoft Store (if using Store sims)  
- NVIDIA GPU (for persistence mode)  

---

## 🧩 Troubleshooting

### ❗ Script won’t run (Execution Policy)
Run PowerShell as Administrator:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
```

---

### ❗ Simulator doesn’t launch
Check:
- Steam is running (for Steam sims)
- Microsoft Store version is installed (for Store sims)
- Standalone DCS/X‑Plane paths exist

---

### ❗ CPU affinity not applied
Some antivirus tools block process manipulation.  
Add the script folder to your AV exclusions.

---

### ❗ Virtual Desktop Streamer doesn’t launch
Ensure it exists at:

```
C:\Program Files\Virtual Desktop Streamer\VirtualDesktop.Streamer.exe
```

---

### ❗ Power plan doesn’t switch
Run:

```powershell
powercfg /list
```

Ensure **Ultimate Performance** exists.

---

### ❗ Log file missing
The script auto‑creates:

```
sim_launcher.log
```

If it fails, check folder permissions.

---
