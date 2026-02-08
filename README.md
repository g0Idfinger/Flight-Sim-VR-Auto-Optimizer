# VR Optimizer — PowerShell Edition

A modern, single‑file PowerShell application that prepares your Windows system for VR flight simulation, launches your simulator with optimized CPU settings, and restores your system afterward.  
Designed for **MSFS 2020/2024**, **DCS**, and **X‑Plane 12**.

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

