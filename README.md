# Flight-Sim-VR-Auto-Optimizer


## How to use:
Copy the code into a text file and save it as VR_Optimizer.bat.
Right-click -> Run as Administrator (Required for CPU priority and service management).
Select your Simulator from the menu and enjoy your flight! ✈️
__
## ⚠️ Disclaimer & Known Issues
Please read before use:
•    Antivirus/Windows Defender: Some scanners might flag .bat scripts that use PowerShell commands as a "False Positive." This script is transparent—you can inspect every line of code in Notepad.
•    Custom Paths: If you installed DCS World or Virtual Desktop in a non-standard directory (outside of C:, D:, etc.), you might need to adjust the path variables in the CONFIG section of the script.
•    Experimental Feature: The CPU Affinity optimization works best on modern Intel (12th Gen+) and AMD Ryzen CPUs. If you experience unusual stuttering, you can disable the affinity block by putting a :: before the PowerShell command in the script.
