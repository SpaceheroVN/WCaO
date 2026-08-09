*Read this in other languages: [English](README.md) | [Tiếng Việt](README-vi.md)*

# 🚀 Windows Cleanup & Optimizer v6.2.0 - Ultimate Toolkit (WCaO) <a href="https://github.com/SpaceheroVN/Windows_Cleanup_And_Optimizer/releases/download/6.2.0/WCaO.bat"><img src="https://img.shields.io/badge/Download-brightgreen?style=flat&logo=download&logoColor=white" alt="Latest Release" width="85"></a>

![Version](https://img.shields.io/badge/version-v6.2.0-blue?style=plastic) ![Platform](https://img.shields.io/badge/platform-Windows-0078D6?style=plastic&logo=windows&logoColor=white) ![Language](https://img.shields.io/badge/language-Batch-4D4D4D?style=plastic&logo=windows-terminal&logoColor=white) ![License](https://img.shields.io/badge/license-Open%20Source-brightgreen?style=plastic&logo=opensource&logoColor=white) ![Admin](https://img.shields.io/badge/requires_Admin-Optional-yellow?style=plastic&logo=powershell&logoColor=white) ![Status](https://img.shields.io/badge/status-Active-success?style=plastic&logo=rocket&logoColor=white)

Open-source system maintenance tool written in Batch Script. Version v6.2.0 provides a total of **9 categories** with specific functions to help clean, fix, and optimize Windows. If you see me updating **README.md** to the **current** version, it means the project is ***indefinitely paused***...

---

## ⚠️ DISCLAIMER
**BY USING THIS TOOLKIT, YOU AGREE TO THE [TERMS OF USE](#terms-of-use).**
The author is **NOT responsible** for any data loss or system instability. **Use at your own risk.**

---

## ⚙️ Features Detail

The toolkit is divided into 9 main categories on the Menu, including the following functions:

### 1. Quick Cleanup
*No Admin rights required.*
* Clear user temporary folder (`%temp%`) and recent shortcuts.
* Clear system temporary folder (`%SystemRoot%\Temp`) and Prefetch *(if Admin)*.
* Flush DNS Cache *(if Admin)*.
* Fully empty the Recycle Bin.

### 2. Deep Cleanup
*Requires Admin rights.*
* **DISM /RestoreHealth:** Repair Windows system image.
* **SFC /scannow:** Scan and restore corrupted system files.
* **Disk Cleanup:** Automated disk scanning and cleaning.

### 3. System Optimization
| Function | Specific Feature | Admin Required |
| :--- | :--- | :--- |
| **Check Disk Integrity** | Scan disk for errors (`chkdsk /scan`). | Yes |
| **Defrag / Trim Drive** | Defragment or optimize SSD. | Yes |
| **Rebuild Caches** | Refresh icons, thumbnails, and restart WSearch. | No |
| **Optimize Power Plan** | Add, remove, or set power plans (Ultimate, High...). | Yes |
| **Optimize Visual Effects** | Enable/disable visual effects to boost performance. | No |
| **Win 11 Context Menu** | Toggle between Win 10 and Win 11 context menus (Auto-restarts Explorer to apply). | No |
| **Edge Rounded Corners Fix** | Patch shortcuts to disable forced rounded corners on Edge v149+. | No |

### 4. Advanced Tools
| Function | Specific Feature | Expert Mode Required |
| :--- | :--- | :--- |
| **Clear Update Cache** | Clean Windows Update cache. | No |
| **Uninstall Office Key** | Remove Office 2016 license key. | No |
| **Remove Windows.old** | Delete old Windows installation folder. | **Yes** |
| **Manage Pagefile/Hibernation**| Disable Pagefile or Hibernation mode. | **Yes** |
| **Network Reset & Flush DNS** | Reset network settings and flush DNS cache. | No |
| **Create Restore Point** | Create a system Restore Point. | No |

### 5. System Utilities
* Display detailed system information (OS, CPU, RAM, GPU, Storage).
* Restart Windows Explorer to fix UI glitches.
* Force kill 'Not Responding' applications.
* **Check Windows License Key & Status:** Check detailed license status (detects KMS/Volume keys), extract original key from BIOS/UEFI.
* **Generate Battery Health Report:** Automatically generate and open a detailed HTML battery health report.
* **Winget Power Tools:** * Update all software silently & automatically, or selectively by App ID.
  * Install essential software categorized by type (Runtimes, Browsers, Media, Dev Tools, Utilities...).
  * Fix and reset Winget cache (Reset Source).

### 6. Screen & Power Tools
* Turn off the screen immediately.
* Create a `Turn Off Screen.bat` script on the Desktop for quick access.

### 7. Quick Rename Pro
Direct drag-and-drop tool for bulk renaming Files and Folders:
* **File:** Extract brackets, sequential numbering (1, 2, 3...), remove suffixes, or find & replace strings.
* **Folder:** Extract brackets, remove suffixes.
* **Fast Rename:** Quick interactive step-by-step renaming, or bulk rename based on a `.txt` list (Supports both Files and Folders).
* **Undo:** Support undoing the last rename batch action.

### 8. Auto Maintenance
*Requires Admin rights.*
* Automatically execute the task sequence: Quick Cleanup -> Deep Cleanup -> Clear Windows Update Cache.

### 9. Toolkit Options
* Toggle **Expert Mode** to display advanced/dangerous features.
* Export Action Report logs.

---

## 🛠 How to Use

1. **Download** the `WCaO.bat` file.
2. It is highly recommended to right-click and select **Run as administrator** to utilize all features.
3. Type the corresponding number from the Menu (0-9) and press `Enter` to navigate.
4. For some deep system interventions (Menu 4), you need to go to Menu `9` to enable **Expert Mode** first.
5. All activity history is temporarily saved; you can export the Log file in Menu `9`.

---

## Terms of Use
1. **Educational Purpose:** For research and learning only.
2. **No Liability:** The author assumes no liability for damages.
3. **Precaution:** Create a **Restore Point** before use.

---
## License
MIT License - Copyright (c) 2026 SpaceheroVN.
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
