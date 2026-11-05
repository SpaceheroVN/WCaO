*Read this in other languages: [English](README.md) | [Tiếng Việt](README-vi.md)*

# 🚀 Windows Cleanup & Optimizer v6.3.2 - TUI Edition (WCaO) <a href="https://raw.githubusercontent.com/SpaceheroVN/WCaO/refs/heads/main/WCaO_TUI.bat"><img src="https://img.shields.io/badge/Download-brightgreen?style=flat&logo=download&logoColor=white" alt="Latest Release" width="85"></a>

![Version](https://img.shields.io/badge/version-v6.3.2_TUI-blue?style=plastic) ![Platform](https://img.shields.io/badge/platform-Windows-0078D6?style=plastic&logo=windows&logoColor=white) ![Interface](https://img.shields.io/badge/interface-Interactive_TUI-06b6d4?style=plastic&logo=windows-terminal&logoColor=white) ![Language](https://img.shields.io/badge/language-Batch_%26_PowerShell-4D4D4D?style=plastic&logo=gnubash&logoColor=white) ![License](https://img.shields.io/badge/license-Open%20Source-brightgreen?style=plastic&logo=opensource&logoColor=white) ![Admin](https://img.shields.io/badge/requires_Admin-Optional-yellow?style=plastic&logo=powershell&logoColor=white) ![Status](https://img.shields.io/badge/status-Active-success?style=plastic&logo=rocket&logoColor=white)

Open-source, zero-dependency Windows maintenance and optimization toolkit featuring a next-generation **Terminal User Interface (TUI)**. Version **v6.3.2** represents a massive leap forward from legacy command-line scripts, delivering full native mouse interaction, a modern dual-pane console layout, and real-time live activity logging.

---

## 🌟 Highlights of the v6.3.2 TUI Breakthrough

* **Full Native Mouse Navigation:** Point, click, hover buttons, scroll lists, and drag the log scrollbar natively inside your Windows Console or Windows Terminal without relying on keyboard-only inputs.
* **Dual-Pane Modern Console:**
  * **Left Pane:** Categorized interactive navigation menus, toggle badges `[ YES ]` / `[ NO ]` / `[ ENABLED ]` / `[ DISABLED ]`, and step progress indicators.
  * **Right Pane:** Real-time colored action log stream with smooth auto-scroll, history buffering, and scrollbar drag support.
* **Zero-Flicker Launch Relay:** Seamless 1-step bootstrap directly into Windows Terminal (`wt.exe`) or native console with ANSI Virtual Terminal (`ENABLE_VIRTUAL_TERMINAL_PROCESSING`) and UTF-8 encoding.
* **Dynamic Bilingual Engine:** Real-time on-the-fly language toggle between **English** and **Vietnamese** with zero lag or restarting required.
* **Non-Destructive Safety Architecture:** Critical and irreversible tweaks are strictly guarded by **Expert Mode** (`RequireExpert = $true`) and Administrator validation checks.

---

## ⚠️ DISCLAIMER
**BY USING THIS TOOLKIT, YOU AGREE TO THE [TERMS OF USE](#terms-of-use).**
The author is **NOT responsible** for any data loss, system instability, or unintended configuration changes. **Use at your own risk.**

---

## ⚙️ Features & Module Architecture

The TUI Toolkit organizes all maintenance utilities into 9 primary operational groups:

### 1. Quick Cleanup
*Safe for regular maintenance. Runs without requiring Administrator rights.*
* Clear user temporary directory (`%TEMP%`) and recent file shortcuts.
* Clear Windows system temp (`%SystemRoot%\Temp`) and Prefetch cache *(elevated when Admin)*.
* Flush system DNS resolver cache (`ipconfig /flushdns`).
* Empty the Windows Recycle Bin cleanly.

### 2. Deep Cleanup
*Requires Administrator privileges.*
* **DISM Image Repair:** Execute `DISM /Online /Cleanup-Image /RestoreHealth` to repair corrupted Windows Component Store packages.
* **System File Checker (SFC):** Run `sfc /scannow` to verify integrity and automatically replace damaged protected system files.
* **System Disk Cleanup:** Automated system file cleanup and shadow update cache purging.

### 3. System Optimization
| Function | Description | Admin Required |
| :--- | :--- | :--- |
| **Check Disk Integrity** | Scan drive partition health using `chkdsk /scan`. | Yes |
| **Defrag / TRIM Drive** | Defragment HDDs or perform TRIM pass on NVMe / SATA SSDs. | Yes |
| **Rebuild System Caches** | Refresh IconCache, ThumbnailCache, and restart Windows Search. | No |
| **Optimize Power Plan** | Activate Ultimate Performance, High Performance, or Balanced plans. | Yes |
| **Optimize Visual Effects** | Toggle performance-tuned Windows visual settings for smoother UI. | No |
| **Win 11 Classic Context Menu**| Switch between modern Windows 11 and classic Windows 10 context menus. | No |
| **Edge Rounded Corners Patch** | Remove forced web frame rounded borders on Microsoft Edge. | No |

### 4. Advanced Tools
| Function | Description | Expert Mode Required |
| :--- | :--- | :--- |
| **Clear Update Cache** | Purge SoftwareDistribution download cache to fix stuck Windows Updates. | No |
| **Create Restore Point** | Instantly create a system Restore Point before running complex tweaks. | No |
| **Pagefile & Hibernation** | Configure virtual memory allocation or disable large hibernation files. | **Yes** |
| **Remove Windows.old** | Delete residual Windows installation folders after major version updates. | **Yes** |
| **Quick Rename Pro** | Built-in batch renaming tool for files and folders (rules, prefixes, numbering). | No |
| **Winget Power Tools** | Batch scan, silent multi-update, and essential software pack installer. | No |

### 5. System Utilities
* **System & License Info:** Inspect hardware specifications (OS, CPU, RAM, GPU, Storage) and query BIOS/UEFI OEM product keys.
* **Kill Frozen Tasks:** Instant force-termination of unresponsive "Not Responding" application processes.
* **RAM Management:** Interactive control hub linking to background RAM optimization services.
* **Restart Windows Explorer:** Cleanly restart `explorer.exe` to resolve taskbar or shell freezes.
* **Network & Wi-Fi Center:** Reset TCP/IP stack, Winsock catalog, release/renew IP, and diagnose connection health.
* **Turn Off Screen:** Immediately trigger display sleep mode or generate a one-click Desktop shortcut.

### 6. Auto Maintenance
*Automated 1-click execution pipeline.*
* Sequentially executes: **Quick Cleanup** ➔ **Deep Cleanup** ➔ **Clear Windows Update Cache**.
* Real-time step progress spinner with error logging and 7-day auto-rotation.

### 7. Toolkit Options
* **Expert Mode Toggle:** Safeguard switch to show or hide sensitive/deep system modifications.
* **Language Switcher:** Instant switch between English and Vietnamese.
* **Export Action Report:** Save timestamped action logs to `%LocalAppData%\WCaO\Log_*.txt`.

---

## 🛠 How to Use

1. **Download:** Get the latest [`WCaO_TUI.bat`](https://raw.githubusercontent.com/SpaceheroVN/WCaO/refs/heads/main/WCaO_TUI.bat) script file.
2. **Launch:** 
   * Double-click to launch (automatically routes into Windows Terminal if installed).
   * For full access to all deep-system cleanup functions, right-click and choose **Run as administrator**.
3. **Interact:**
   * Use your mouse directly: click buttons, click menu items, and scroll with the mouse wheel.
   * Or use standard keyboard navigation (`Up`/`Down`/`Enter`/`Esc` or shortcut keys).

---

## 📜 Terms of Use
1. **Educational & System Utility Purpose:** Intended for legitimate Windows system maintenance and educational study.
2. **No Liability:** The author assumes no liability for hardware or operating system defects caused by misuse.
3. **Precautionary Measure:** Always create a **Restore Point** before executing advanced tweaks.
