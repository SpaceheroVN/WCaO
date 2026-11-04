#include "WCaO_UI.h"

// ============================================================================
//  1. UNIFIED DASHBOARD & SYSTEM TRAY CONTROLLER
// ============================================================================
class WCaO_DashboardApp {
public:
    HWND hMainWnd = nullptr;
    NOTIFYICONDATAW nid = {};
    HICON hCurrentTrayIcon = nullptr;
    HICON hAppIconBig = nullptr;
    HICON hAppIconSmall = nullptr;
    int lastTrayIconRam = -1;

    UINT msgTaskbarCreated = 0;
    UINT msgShowGui = 0;
    UINT msgQuitApp = 0;
    UINT msgElevateAdmin = 0;

    bool realExit = false;
    bool isDarkTheme = true;
    bool isEnLang = false;
    std::wstring appFontName = L"Segoe UI";

    // Offscreen double-buffer (freed when hidden to tray)
    HDC hBackDC = nullptr;
    HBITMAP hBackBmp = nullptr;
    HGDIOBJ hOldBackBmp = nullptr;
    int backW = 0, backH = 0;

    // Tab & Scroll State
    int selectedTab = 0;
    int hoverTab = -1;
    int scrollY[3] = { 0, 0, 0 };
    int maxScroll[3] = { 0, 102, 165 };
    bool scrollDrag = false;
    int dragStartY = 0;
    int dragStartScroll = 0;
    bool scrollBarHover = false;

    std::wstring hoverCtrlId;
    std::wstring openComboId;

    // Numeric Box Inline Edit State (0=TransPct, 1=Warn, 2=Dang, 3=PrevPct, 4=AutoAbove, 5=AutoEvery)
    int focusedNumIdx = -1;
    std::wstring numEditBuffer;
    bool numEditTyping = false;

    RamConfig stagedCfg;
    int previewTestPct = 67;

    std::wstring statusResultText;
    double lastDisplayFreedMB = -1.0;
    std::wstring btnViewSaveFeedback;
    std::wstring btnViewResetFeedback;
    std::wstring btnSetSaveFeedback;
    std::wstring btnSetResetFeedback;

    ULONGLONG lastPeriodicCleanTick = 0;
    ULONGLONG lastAboveCleanTick = 0;
    ULONGLONG lastSelfCompactTick = 0;
    ULONGLONG lastShowGuiTick = 0;
    ULONGLONG cleanCooldownUntilTick = 0;

    HANDLE* pMutexGlobal = nullptr;
    HANDLE* pMutexLocal  = nullptr;
    HANDLE* pMutexLegacy = nullptr;

    int GetCleanCooldownRemainingSec() const {
        ULONGLONG now = GetTickCount64();
        if (now >= cleanCooldownUntilTick) return 0;
        return (int)((cleanCooldownUntilTick - now + 999ULL) / 1000ULL);
    }

    std::wstring GetLocalizedFontStyle(const std::wstring& style) const {
        if (isEnLang) return style;
        if (style == L"Regular") return L"Thường";
        if (style == L"Italic")  return L"Nghiêng";
        return L"Đậm";
    }

    static std::wstring NormalizeFontStyleConfig(const std::wstring& disp) {
        if (disp == L"Regular" || disp == L"Thường")  return L"Regular";
        if (disp == L"Italic"  || disp == L"Nghiêng") return L"Italic";
        return L"Bold";
    }

    void RelaunchAsAdmin(bool openGuiWindow = true) {
        if (WcaoAppEnv::IsAdmin) return;

        if (pMutexGlobal && *pMutexGlobal) { ReleaseMutex(*pMutexGlobal); CloseHandle(*pMutexGlobal); *pMutexGlobal = nullptr; }
        if (pMutexLocal  && *pMutexLocal)  { ReleaseMutex(*pMutexLocal);  CloseHandle(*pMutexLocal);  *pMutexLocal  = nullptr; }
        if (pMutexLegacy && *pMutexLegacy) { ReleaseMutex(*pMutexLegacy); CloseHandle(*pMutexLegacy); *pMutexLegacy = nullptr; }

        SHELLEXECUTEINFOW sei = { sizeof(sei) };
        sei.lpVerb = L"runas";
        sei.lpFile = WcaoAppEnv::ExePath.c_str();
        sei.lpParameters = openGuiWindow ? L"-gui_direct" : L"-tray_direct -elevated_toast";
        sei.nShow = openGuiWindow ? SW_SHOWNORMAL : SW_HIDE;

        if (ShellExecuteExW(&sei)) {
            WcaoAppEnv::WriteLog(L"ACTION", isEnLang ? L"Switched to Administrator mode" : L"Đã chuyển sang quyền Quản trị viên");
            realExit = true;
            DestroyWindow(hMainWnd);
        } else {
            SECURITY_DESCRIPTOR sd = {};
            InitializeSecurityDescriptor(&sd, SECURITY_DESCRIPTOR_REVISION);
            SetSecurityDescriptorDacl(&sd, TRUE, nullptr, FALSE);
            SECURITY_ATTRIBUTES sa = { sizeof(sa), &sd, FALSE };
            if (pMutexGlobal) *pMutexGlobal = CreateMutexW(&sa, TRUE, L"Global\\WCaO_RAM_Tray_Mutex");
            if (pMutexLocal)  *pMutexLocal  = CreateMutexW(&sa, TRUE, L"WCaO_RAM_Tray_Mutex");
            if (pMutexLegacy) *pMutexLegacy = CreateMutexW(&sa, TRUE, L"WCaO_RAM_Single_Mutex");
        }
    }

    void DetectFontFamily() {
        Gdiplus::FontFamily ff(L"Segoe UI Variable Text");
        appFontName = ff.IsAvailable() ? L"Segoe UI Variable Text" : L"Segoe UI";
    }

    void FreeBackBuffer() {
        if (hBackDC) {
            if (hOldBackBmp) SelectObject(hBackDC, hOldBackBmp);
            if (hBackBmp) DeleteObject(hBackBmp);
            DeleteDC(hBackDC);
            hBackDC = nullptr;
            hBackBmp = nullptr;
            hOldBackBmp = nullptr;
            backW = 0;
            backH = 0;
        }
    }

    void SyncStagedFromSaved() {
        stagedCfg = WcaoAppEnv::CurrentConfig;
        if (!WcaoAppEnv::IsAdmin) {
            stagedCfg.CleanFileCache = false;
            stagedCfg.CleanModifiedPageList = false;
            stagedCfg.CleanStandbyList = false;
            stagedCfg.CleanStandbyLowPriority = false;
        } else if (stagedCfg.CleanStandbyList) {
            stagedCfg.CleanStandbyLowPriority = false;
        }
    }

    bool IsViewDirty() const {
        const RamConfig& s = WcaoAppEnv::CurrentConfig;
        return (stagedCfg.Theme != s.Theme) ||
               (stagedCfg.Language != s.Language) ||
               (stagedCfg.TrayShowBorder != s.TrayShowBorder) ||
               (stagedCfg.TrayRoundedBorder != s.TrayRoundedBorder) ||
               (stagedCfg.TrayTransparentBelow60 != s.TrayTransparentBelow60) ||
               (stagedCfg.TrayTransparentBelowPct != s.TrayTransparentBelowPct) ||
               (stagedCfg.TrayFontFamily != s.TrayFontFamily) ||
               (stagedCfg.TrayFontSize != s.TrayFontSize) ||
               (stagedCfg.TrayFontStyle != s.TrayFontStyle) ||
               (_wcsicmp(stagedCfg.TrayTextColorCustom.c_str(), s.TrayTextColorCustom.c_str()) != 0) ||
               (_wcsicmp(stagedCfg.TrayBgDefault.c_str(), s.TrayBgDefault.c_str()) != 0) ||
               (stagedCfg.WarningLevel != s.WarningLevel) ||
               (stagedCfg.DangerLevel != s.DangerLevel) ||
               (_wcsicmp(stagedCfg.TrayBgWarning.c_str(), s.TrayBgWarning.c_str()) != 0) ||
               (_wcsicmp(stagedCfg.TrayBgDanger.c_str(), s.TrayBgDanger.c_str()) != 0);
    }

    bool IsViewSavedDefault() const {
        const RamConfig& s = WcaoAppEnv::CurrentConfig;
        RamConfig d = RamConfig::GetDefaults();
        return (s.Theme == d.Theme) &&
               (s.Language == d.Language) &&
               (s.TrayShowBorder == d.TrayShowBorder) &&
               (s.TrayRoundedBorder == d.TrayRoundedBorder) &&
               (s.TrayTransparentBelow60 == d.TrayTransparentBelow60) &&
               (s.TrayTransparentBelowPct == d.TrayTransparentBelowPct) &&
               (s.TrayFontFamily == d.TrayFontFamily) &&
               (s.TrayFontSize == d.TrayFontSize) &&
               (s.TrayFontStyle == d.TrayFontStyle) &&
               (_wcsicmp(s.TrayTextColorCustom.c_str(), d.TrayTextColorCustom.c_str()) == 0) &&
               (_wcsicmp(s.TrayBgDefault.c_str(), d.TrayBgDefault.c_str()) == 0) &&
               (s.WarningLevel == d.WarningLevel) &&
               (s.DangerLevel == d.DangerLevel) &&
               (_wcsicmp(s.TrayBgWarning.c_str(), d.TrayBgWarning.c_str()) == 0) &&
               (_wcsicmp(s.TrayBgDanger.c_str(), d.TrayBgDanger.c_str()) == 0);
    }

    bool IsSetDirty() const {
        const RamConfig& s = WcaoAppEnv::CurrentConfig;
        if (stagedCfg.CleanWorkingSet != s.CleanWorkingSet) return true;
        if (WcaoAppEnv::IsAdmin) {
            if (stagedCfg.CleanFileCache != s.CleanFileCache ||
                stagedCfg.CleanModifiedPageList != s.CleanModifiedPageList ||
                stagedCfg.CleanStandbyList != s.CleanStandbyList ||
                stagedCfg.CleanStandbyLowPriority != s.CleanStandbyLowPriority) {
                return true;
            }
        }
        return (stagedCfg.CleanWhenAboveEnabled != s.CleanWhenAboveEnabled) ||
               (stagedCfg.CleanWhenAbovePct != s.CleanWhenAbovePct) ||
               (stagedCfg.CleanEveryEnabled != s.CleanEveryEnabled) ||
               (stagedCfg.CleanEveryMin != s.CleanEveryMin) ||
               (stagedCfg.HotkeyEnabled != s.HotkeyEnabled) ||
               (stagedCfg.Hotkey != s.Hotkey) ||
               (stagedCfg.BalloonShowResult != s.BalloonShowResult) ||
               (stagedCfg.BalloonPlaySound != s.BalloonPlaySound);
    }

    bool IsSetSavedDefault() const {
        const RamConfig& s = WcaoAppEnv::CurrentConfig;
        RamConfig d = RamConfig::GetDefaults();
        if (s.CleanWorkingSet != d.CleanWorkingSet) return false;
        if (WcaoAppEnv::IsAdmin) {
            if (s.CleanFileCache != d.CleanFileCache ||
                s.CleanModifiedPageList != d.CleanModifiedPageList ||
                s.CleanStandbyList != d.CleanStandbyList ||
                s.CleanStandbyLowPriority != d.CleanStandbyLowPriority) {
                return false;
            }
        }
        return (s.CleanWhenAboveEnabled == d.CleanWhenAboveEnabled) &&
               (s.CleanWhenAbovePct == d.CleanWhenAbovePct) &&
               (s.CleanEveryEnabled == d.CleanEveryEnabled) &&
               (s.CleanEveryMin == d.CleanEveryMin) &&
               (s.HotkeyEnabled == d.HotkeyEnabled) &&
               (s.Hotkey == d.Hotkey) &&
               (s.BalloonShowResult == d.BalloonShowResult) &&
               (s.BalloonPlaySound == d.BalloonPlaySound);
    }

    void UpdateWindowTitleAndTheme() {
        isEnLang = (WcaoAppEnv::CurrentConfig.Language == L"en");
        isDarkTheme = (WcaoAppEnv::CurrentConfig.GetActiveThemeMode() == L"dark");

        const wchar_t* title = isEnLang
            ? (WcaoAppEnv::IsAdmin ? L"WCaO RAM Manager [Admin]" : L"WCaO RAM Manager [User]")
            : (WcaoAppEnv::IsAdmin ? L"WCaO RAM Manager [Quản trị viên]" : L"WCaO RAM Manager [Người dùng]");
        SetWindowTextW(hMainWnd, title);

        if (lastDisplayFreedMB >= 0.0 && !statusResultText.empty()) {
            std::wstring sizeStr = FormatRamSize(lastDisplayFreedMB);
            statusResultText = isEnLang ? (L"Freed " + sizeStr + L" RAM") : (L"Đã giải phóng " + sizeStr + L" RAM");
        }

        maxScroll[1] = 440 - 338;
        int setContentH = WcaoAppEnv::IsAdmin ? 480 : 500;
        maxScroll[2] = setContentH - 338;

        ApplyDwmWindowTheme(hMainWnd, isDarkTheme, true);
        SetWindowPos(hMainWnd, nullptr, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_FRAMECHANGED);
        InvalidateRect(hMainWnd, nullptr, FALSE);
    }

    void RegisterGlobalHotkey() {
        UnregisterHotKey(hMainWnd, HOTKEY_ID_CLEAN);
        const RamConfig& cfg = WcaoAppEnv::CurrentConfig;
        if (!cfg.HotkeyEnabled || cfg.Hotkey.empty()) return;

        UINT mods = MOD_NOREPEAT;
        if (cfg.Hotkey.find(L"Ctrl") != std::wstring::npos)  mods |= MOD_CONTROL;
        if (cfg.Hotkey.find(L"Alt") != std::wstring::npos)   mods |= MOD_ALT;
        if (cfg.Hotkey.find(L"Shift") != std::wstring::npos) mods |= MOD_SHIFT;
        if (cfg.Hotkey.find(L"Win") != std::wstring::npos)   mods |= MOD_WIN;

        UINT vk = 0;
        if (cfg.Hotkey.find(L"F1") != std::wstring::npos) vk = VK_F1;
        else if (cfg.Hotkey.find(L"F2") != std::wstring::npos) vk = VK_F2;
        else if (cfg.Hotkey.back() == L'R') vk = 'R';
        else if (cfg.Hotkey.back() == L'M') vk = 'M';

        if (vk != 0) {
            RegisterHotKey(hMainWnd, HOTKEY_ID_CLEAN, mods, vk);
        }
    }

    // Dispatches Native Windows Toast Notification with action buttons (falls back to Shell_NotifyIconW NIIF_NONE)
    void ShowTrayNotification(const std::wstring& line1, const std::wstring& line2 = L"", bool playSound = true) {
        std::wstring titleLine = line2.empty() ? L"WCaO RAM Manager" : line1;
        std::wstring bodyLine  = line2.empty() ? line1 : line2;

        if (WinRtToast::ShowNativeToast(titleLine, bodyLine, playSound, WcaoAppEnv::IsAdmin, !isEnLang)) {
            return;
        }

        nid.uFlags = NIF_INFO;
        wcsncpy_s(nid.szInfoTitle, titleLine.c_str(), _TRUNCATE);
        wcsncpy_s(nid.szInfo, bodyLine.c_str(), _TRUNCATE);
        nid.dwInfoFlags = NIIF_NONE | (playSound ? 0 : NIIF_NOSOUND);
        Shell_NotifyIconW(NIM_MODIFY, &nid);
        nid.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
    }

    void UpdateTrayIconAndTooltip(const RamStatsSnapshot& st, bool forceIcon = false) {
        const RamConfig& cfg = WcaoAppEnv::CurrentConfig;
        if (forceIcon || st.PhysLoad != lastTrayIconRam || !hCurrentTrayIcon) {
            HICON hNew = DynamicTrayIconRenderer::CreateTrayHIcon(st.PhysLoad, cfg);
            if (hNew) {
                HICON hOld = hCurrentTrayIcon;
                hCurrentTrayIcon = hNew;
                nid.hIcon = hCurrentTrayIcon;
                lastTrayIconRam = st.PhysLoad;
                if (hOld) DestroyIcon(hOld);
            }
        }

        wchar_t tipBuf[128] = {};
        if (cfg.Language == L"en") {
            swprintf(tipBuf, 128, L"Physical Memory: %.3f%%\nVirtual Memory: %.3f%%\nSystem File Cache: %.3f%%",
                st.PhysPct, st.PagePct, st.WsPct);
        } else {
            swprintf(tipBuf, 128, L"Bộ nhớ vật lý: %.3f%%\nBộ nhớ ảo: %.3f%%\nBộ đệm tập tin hệ thống: %.3f%%",
                st.PhysPct, st.PagePct, st.WsPct);
        }
        wcscpy_s(nid.szTip, tipBuf);
        nid.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
        Shell_NotifyIconW(NIM_MODIFY, &nid);
    }

    void TriggerMemoryClean(const std::wstring& source) {
        if (Win32RamNative::IsCleaningInProgress) return;
        if (GetTickCount64() < cleanCooldownUntilTick) return;
        const RamConfig& cfg = WcaoAppEnv::CurrentConfig;
        WcaoAppEnv::WriteLog(L"ACTION", (isEnLang ? L"Triggered memory clean (Source=" : L"Kích hoạt dọn dẹp bộ nhớ (Nguồn=") + source + L")");

        InvalidateRect(hMainWnd, nullptr, FALSE);
        Win32RamNative::StartCleanAsync(
            GetCurrentProcessId(),
            WcaoAppEnv::IsAdmin,
            cfg.CleanWorkingSet,
            WcaoAppEnv::IsAdmin && cfg.CleanFileCache,
            WcaoAppEnv::IsAdmin && cfg.CleanModifiedPageList,
            WcaoAppEnv::IsAdmin && cfg.CleanStandbyList,
            WcaoAppEnv::IsAdmin && cfg.CleanStandbyLowPriority,
            source
        );
    }

    void ShowDashboardWindow() {
        ULONGLONG now = GetTickCount64();
        if (now - lastShowGuiTick < 250) return;
        lastShowGuiTick = now;

        Win32RamNative::GetCurrentRamStats(true);
        if (!IsWindowVisible(hMainWnd)) {
            ShowWindow(hMainWnd, SW_SHOW);
        }
        if (IsIconic(hMainWnd)) {
            ShowWindow(hMainWnd, SW_RESTORE);
        }
        SetForegroundWindow(hMainWnd);
        SetFocus(hMainWnd);
        SetTimer(hMainWnd, 1, 1000, nullptr);
        InvalidateRect(hMainWnd, nullptr, FALSE);
    }

    void HideToTray() {
        CommitFocusedNumEdit();
        ShowWindow(hMainWnd, SW_HIDE);
        FreeBackBuffer();
        SetTimer(hMainWnd, 1, 2000, nullptr);
        Win32RamNative::TrimSelfMemory();
    }

    // ------------------------------------------------------------------------
    //  NUMERIC BOX FOCUS & KEYBOARD COMMIT
    // ------------------------------------------------------------------------
    int* GetNumValuePtr(int idx) {
        switch (idx) {
        case 0: return &stagedCfg.TrayTransparentBelowPct;
        case 1: return &stagedCfg.WarningLevel;
        case 2: return &stagedCfg.DangerLevel;
        case 3: return &previewTestPct;
        case 4: return &stagedCfg.CleanWhenAbovePct;
        case 5: return &stagedCfg.CleanEveryMin;
        }
        return nullptr;
    }

    void GetNumBounds(int idx, int& minV, int& maxV) const {
        switch (idx) {
        case 0: minV = 10; maxV = 99;  break;
        case 1: minV = 1;  maxV = 99;  break;
        case 2: minV = 1;  maxV = 99;  break;
        case 3: minV = 0;  maxV = 100; break;
        case 4: minV = 10; maxV = 99;  break;
        case 5: minV = 1;  maxV = 120; break;
        default: minV = 1; maxV = 100; break;
        }
    }

    void CommitFocusedNumEdit() {
        if (focusedNumIdx < 0) return;
        if (numEditTyping && !numEditBuffer.empty()) {
            int* ptr = GetNumValuePtr(focusedNumIdx);
            if (ptr) {
                int minV, maxV;
                GetNumBounds(focusedNumIdx, minV, maxV);
                int v = _wtoi(numEditBuffer.c_str());
                *ptr = (std::max)(minV, (std::min)(maxV, v));
            }
        }
        focusedNumIdx = -1;
        numEditTyping = false;
        numEditBuffer.clear();
        InvalidateRect(hMainWnd, nullptr, FALSE);
    }

    void AdjustNumValue(int idx, int delta) {
        int* ptr = GetNumValuePtr(idx);
        if (!ptr) return;
        int minV, maxV;
        GetNumBounds(idx, minV, maxV);
        *ptr = (std::max)(minV, (std::min)(maxV, *ptr + delta));
        if (focusedNumIdx == idx) {
            numEditBuffer = std::to_wstring(*ptr);
            numEditTyping = false;
        }
        InvalidateRect(hMainWnd, nullptr, FALSE);
    }

    // ------------------------------------------------------------------------
    //  UI DRAWING PRIMITIVES
    // ------------------------------------------------------------------------
    void DrawModernButton(Gdiplus::Graphics& g, Gdiplus::RectF r, const std::wstring& text, bool isPrimary, bool enabled, bool hovered, float fontSize = 9.0f, bool bold = false, int radius = 6) {
        Gdiplus::Color bg, fg, border;
        int borderW = 0;

        if (!enabled) {
            if (isDarkTheme) {
                bg = isPrimary ? Gdiplus::Color(28, 30, 36) : Gdiplus::Color(24, 25, 29);
                fg = Gdiplus::Color(90, 96, 110);
                border = Gdiplus::Color(45, 48, 58);
                borderW = 1;
            } else {
                bg = isPrimary ? Gdiplus::Color(226, 232, 240) : Gdiplus::Color(241, 245, 249);
                fg = Gdiplus::Color(148, 163, 184);
                border = Gdiplus::Color(203, 213, 225);
                borderW = 1;
            }
        } else if (isPrimary) {
            bg = hovered ? Gdiplus::Color(0, 135, 185) : Gdiplus::Color(0, 150, 200);
            fg = Gdiplus::Color(255, 255, 255);
            border = Gdiplus::Color(0, 0, 0, 0);
            borderW = 0;
        } else {
            if (isDarkTheme) {
                bg = hovered ? Gdiplus::Color(42, 45, 52) : Gdiplus::Color(33, 34, 38);
                fg = Gdiplus::Color(220, 225, 235);
                border = Gdiplus::Color(65, 70, 82);
                borderW = 1;
            } else {
                bg = hovered ? Gdiplus::Color(240, 245, 250) : Gdiplus::Color(255, 255, 255);
                fg = Gdiplus::Color(30, 41, 59);
                border = Gdiplus::Color(195, 205, 218);
                borderW = 1;
            }
        }

        Gdiplus::RectF rf(r.X + 0.5f, r.Y + 0.5f, r.Width - 1.0f, r.Height - 1.0f);
        Gdiplus::GraphicsPath path;
        AddRoundedPath(path, rf, (float)radius);
        Gdiplus::SolidBrush b(bg);
        g.FillPath(&b, &path);
        if (borderW > 0) {
            Gdiplus::Pen p(border, (float)borderW);
            g.DrawPath(&p, &path);
        }

        Gdiplus::Font font(appFontName.c_str(), fontSize, bold ? Gdiplus::FontStyleBold : Gdiplus::FontStyleRegular, Gdiplus::UnitPoint);
        Gdiplus::StringFormat sf;
        sf.SetAlignment(Gdiplus::StringAlignmentCenter);
        sf.SetLineAlignment(Gdiplus::StringAlignmentCenter);
        sf.SetFormatFlags(Gdiplus::StringFormatFlagsNoWrap);
        Gdiplus::SolidBrush fb(fg);
        g.DrawString(text.c_str(), -1, &font, r, &sf, &fb);
    }

    void DrawModernCheckBox(Gdiplus::Graphics& g, float x, float y, float w, float h, const std::wstring& text, bool checked, bool enabled = true) {
        float boxSize = 15.0f;
        float boxY = y + (h - boxSize) / 2.0f;
        float boxX = x + 1.0f;
        Gdiplus::RectF boxRect(boxX, boxY, boxSize, boxSize);

        Gdiplus::Color boxBorder = isDarkTheme ? Gdiplus::Color(80, 85, 95) : Gdiplus::Color(148, 163, 184);
        Gdiplus::Color boxCheck  = Gdiplus::Color(16, 185, 129);
        Gdiplus::Color boxBg     = isDarkTheme ? Gdiplus::Color(22, 23, 26) : Gdiplus::Color(248, 250, 252);
        Gdiplus::Color textCol   = enabled
            ? (isDarkTheme ? Gdiplus::Color(240, 242, 245) : Gdiplus::Color(30, 41, 59))
            : Gdiplus::Color(130, 135, 145);

        Gdiplus::GraphicsPath path;
        AddRoundedPath(path, boxRect, 3.0f);
        if (checked) {
            Gdiplus::SolidBrush fb(boxCheck);
            g.FillPath(&fb, &path);
            Gdiplus::Pen pen(Gdiplus::Color(255, 255, 255), 1.8f);
            pen.SetStartCap(Gdiplus::LineCapRound);
            pen.SetEndCap(Gdiplus::LineCapRound);
            Gdiplus::PointF pts[3] = {
                Gdiplus::PointF(boxX + 3.5f, boxY + 7.5f),
                Gdiplus::PointF(boxX + 6.2f, boxY + 10.5f),
                Gdiplus::PointF(boxX + 11.5f, boxY + 4.5f)
            };
            g.DrawLines(&pen, pts, 3);
        } else {
            Gdiplus::SolidBrush fb(boxBg);
            g.FillPath(&fb, &path);
            Gdiplus::Pen pen(boxBorder, 1.2f);
            g.DrawPath(&pen, &path);
        }

        Gdiplus::Font font(appFontName.c_str(), 9.0f, Gdiplus::FontStyleRegular, Gdiplus::UnitPoint);
        Gdiplus::StringFormat sf;
        sf.SetAlignment(Gdiplus::StringAlignmentNear);
        sf.SetLineAlignment(Gdiplus::StringAlignmentCenter);
        sf.SetFormatFlags(Gdiplus::StringFormatFlagsNoWrap);
        Gdiplus::SolidBrush tb(textCol);
        Gdiplus::RectF textRect(boxX + boxSize + 8.0f, y, w - (boxSize + 9.0f), h);
        g.DrawString(text.c_str(), -1, &font, textRect, &sf, &tb);
    }

    void DrawModernRadioButton(Gdiplus::Graphics& g, float x, float y, float w, float h, const std::wstring& text, bool checked) {
        float circleSize = 14.0f;
        float circleX = x + 1.0f;
        float circleY = y + (h - circleSize) / 2.0f;
        Gdiplus::RectF circleRect(circleX, circleY, circleSize, circleSize);

        Gdiplus::Color radioBorder = isDarkTheme ? Gdiplus::Color(80, 85, 95) : Gdiplus::Color(148, 163, 184);
        Gdiplus::Color radioCheck  = isDarkTheme ? Gdiplus::Color(0, 210, 255) : Gdiplus::Color(2, 132, 199);
        Gdiplus::Color radioBg     = isDarkTheme ? Gdiplus::Color(22, 23, 26) : Gdiplus::Color(248, 250, 252);
        Gdiplus::Color textCol     = isDarkTheme ? Gdiplus::Color(240, 242, 245) : Gdiplus::Color(30, 41, 59);

        if (checked) {
            Gdiplus::Pen pen(radioCheck, 1.8f);
            g.DrawEllipse(&pen, circleRect);
            float dotSize = 7.0f;
            float dotX = circleX + (circleSize - dotSize) / 2.0f;
            float dotY = circleY + (circleSize - dotSize) / 2.0f;
            Gdiplus::SolidBrush fb(radioCheck);
            g.FillEllipse(&fb, dotX, dotY, dotSize, dotSize);
        } else {
            Gdiplus::SolidBrush fb(radioBg);
            g.FillEllipse(&fb, circleRect);
            Gdiplus::Pen pen(radioBorder, 1.2f);
            g.DrawEllipse(&pen, circleRect);
        }

        Gdiplus::Font font(appFontName.c_str(), 9.0f, Gdiplus::FontStyleRegular, Gdiplus::UnitPoint);
        Gdiplus::StringFormat sf;
        sf.SetAlignment(Gdiplus::StringAlignmentNear);
        sf.SetLineAlignment(Gdiplus::StringAlignmentCenter);
        sf.SetFormatFlags(Gdiplus::StringFormatFlagsNoWrap);
        Gdiplus::SolidBrush tb(textCol);
        Gdiplus::RectF textRect(circleX + circleSize + 8.0f, y, w - (circleSize + 9.0f), h);
        g.DrawString(text.c_str(), -1, &font, textRect, &sf, &tb);
    }

    void DrawModernComboBox(Gdiplus::Graphics& g, float x, float y, float w, float h, const std::wstring& text, bool enabled, bool hovered, bool droppedDown) {
        Gdiplus::Color bg = enabled
            ? (isDarkTheme ? Gdiplus::Color(28, 30, 36) : Gdiplus::Color(255, 255, 255))
            : (isDarkTheme ? Gdiplus::Color(24, 25, 29) : Gdiplus::Color(243, 244, 246));
        Gdiplus::Color fg = enabled
            ? (isDarkTheme ? Gdiplus::Color(240, 242, 245) : Gdiplus::Color(30, 41, 59))
            : (isDarkTheme ? Gdiplus::Color(100, 105, 115) : Gdiplus::Color(160, 170, 180));
        Gdiplus::Color borderCol = isDarkTheme ? Gdiplus::Color(60, 65, 75) : Gdiplus::Color(203, 213, 225);
        Gdiplus::Color arrowCol  = isDarkTheme ? Gdiplus::Color(160, 175, 195) : Gdiplus::Color(100, 116, 139);
        Gdiplus::Color itemHover = isDarkTheme ? Gdiplus::Color(0, 122, 204) : Gdiplus::Color(2, 132, 199);

        Gdiplus::SolidBrush bgB(bg);
        g.FillRectangle(&bgB, x, y, w, h);

        Gdiplus::Font font(appFontName.c_str(), 9.0f, Gdiplus::FontStyleRegular, Gdiplus::UnitPoint);
        Gdiplus::StringFormat sf;
        sf.SetAlignment(Gdiplus::StringAlignmentNear);
        sf.SetLineAlignment(Gdiplus::StringAlignmentCenter);
        sf.SetFormatFlags(Gdiplus::StringFormatFlagsNoWrap);
        Gdiplus::SolidBrush fgB(fg);
        Gdiplus::RectF rTxt(x + 8.0f, y, w - 24.0f, h);
        g.DrawString(text.c_str(), -1, &font, rTxt, &sf, &fgB);

        float arrowX = x + w - 15.0f;
        Gdiplus::Color curArrow = enabled
            ? (droppedDown ? itemHover : (hovered ? fg : arrowCol))
            : (isDarkTheme ? Gdiplus::Color(80, 85, 95) : Gdiplus::Color(180, 190, 200));
        Gdiplus::Pen ap(curArrow, 1.8f);
        ap.SetStartCap(Gdiplus::LineCapRound);
        ap.SetEndCap(Gdiplus::LineCapRound);
        if (droppedDown) {
            float ay = y + h / 2.0f + 2.0f;
            Gdiplus::PointF pts[3] = { Gdiplus::PointF(arrowX, ay), Gdiplus::PointF(arrowX + 3.5f, ay - 4.0f), Gdiplus::PointF(arrowX + 7.0f, ay) };
            g.DrawLines(&ap, pts, 3);
        } else {
            float ay = y + h / 2.0f - 2.0f;
            Gdiplus::PointF pts[3] = { Gdiplus::PointF(arrowX, ay), Gdiplus::PointF(arrowX + 3.5f, ay + 4.0f), Gdiplus::PointF(arrowX + 7.0f, ay) };
            g.DrawLines(&ap, pts, 3);
        }

        Gdiplus::Color curBorder = enabled
            ? (droppedDown ? itemHover : (hovered ? arrowCol : borderCol))
            : (isDarkTheme ? Gdiplus::Color(45, 48, 55) : Gdiplus::Color(220, 225, 230));
        Gdiplus::Pen bp(curBorder, droppedDown ? 1.5f : 1.0f);
        g.DrawRectangle(&bp, x, y, w - 1.0f, h - 1.0f);
    }

    void DrawModernNumericBox(Gdiplus::Graphics& g, float x, float y, float w, float h, int val, bool enabled, int numIdx, const std::wstring& downId, const std::wstring& upId) {
        Gdiplus::Color bg = isDarkTheme ? Gdiplus::Color(22, 23, 26) : Gdiplus::Color(255, 255, 255);
        Gdiplus::Color fg = enabled
            ? (isDarkTheme ? Gdiplus::Color(240, 242, 245) : Gdiplus::Color(30, 41, 59))
            : (isDarkTheme ? Gdiplus::Color(100, 105, 115) : Gdiplus::Color(160, 170, 180));
        Gdiplus::Color btnBg = isDarkTheme ? Gdiplus::Color(42, 44, 52) : Gdiplus::Color(226, 232, 240);
        Gdiplus::Color btnHov = isDarkTheme ? Gdiplus::Color(58, 62, 72) : Gdiplus::Color(203, 213, 225);
        Gdiplus::Color btnFg = enabled
            ? (isDarkTheme ? Gdiplus::Color(210, 220, 235) : Gdiplus::Color(30, 41, 59))
            : (isDarkTheme ? Gdiplus::Color(90, 95, 105) : Gdiplus::Color(170, 180, 190));
        bool isFocused = (focusedNumIdx == numIdx);
        Gdiplus::Color borderCol = isFocused
            ? (isDarkTheme ? Gdiplus::Color(0, 210, 255) : Gdiplus::Color(2, 132, 199))
            : (enabled ? (isDarkTheme ? Gdiplus::Color(60, 65, 75) : Gdiplus::Color(203, 213, 225))
                       : (isDarkTheme ? Gdiplus::Color(45, 48, 55) : Gdiplus::Color(220, 225, 230)));

        Gdiplus::SolidBrush bgB(bg);
        g.FillRectangle(&bgB, x, y, w, h);

        float btnW = 22.0f;
        Gdiplus::SolidBrush downB((enabled && hoverCtrlId == downId) ? btnHov : btnBg);
        Gdiplus::SolidBrush upB((enabled && hoverCtrlId == upId) ? btnHov : btnBg);
        g.FillRectangle(&downB, x, y, btnW, h);
        g.FillRectangle(&upB, x + w - btnW, y, btnW, h);

        Gdiplus::Pen symPen(btnFg, 1.8f);
        symPen.SetStartCap(Gdiplus::LineCapRound);
        symPen.SetEndCap(Gdiplus::LineCapRound);
        float cy = y + h / 2.0f;
        g.DrawLine(&symPen, x + 6.0f, cy, x + btnW - 6.0f, cy);
        float upX = x + w - btnW;
        float upCx = upX + btnW / 2.0f;
        g.DrawLine(&symPen, upX + 6.0f, cy, upX + btnW - 6.0f, cy);
        g.DrawLine(&symPen, upCx, y + 6.0f, upCx, y + h - 6.0f);

        std::wstring disp = (isFocused && numEditTyping) ? numEditBuffer : std::to_wstring(val);
        Gdiplus::Font font(appFontName.c_str(), 9.0f, Gdiplus::FontStyleBold, Gdiplus::UnitPoint);
        Gdiplus::StringFormat sf;
        sf.SetAlignment(Gdiplus::StringAlignmentCenter);
        sf.SetLineAlignment(Gdiplus::StringAlignmentCenter);
        Gdiplus::SolidBrush fgB(fg);
        Gdiplus::RectF rTxt(x + btnW, y, w - btnW * 2.0f, h);
        g.DrawString(disp.c_str(), -1, &font, rTxt, &sf, &fgB);

        Gdiplus::Pen bp(borderCol, isFocused ? 1.5f : 1.2f);
        g.DrawRectangle(&bp, x, y, w - 1.0f, h - 1.0f);
    }

    void DrawModernSwatch(Gdiplus::Graphics& g, float x, float y, float w, float h, const std::wstring& hexColor, bool showText) {
        COLORREF colRef = ParseHexColor(hexColor);
        Gdiplus::RectF rf(x + 0.5f, y + 0.5f, w - 1.0f, h - 1.0f);
        Gdiplus::GraphicsPath path;
        AddRoundedPath(path, rf, 4.0f);

        Gdiplus::SolidBrush fb(ColorRefToGdip(colRef));
        g.FillPath(&fb, &path);

        Gdiplus::Color bCol = isDarkTheme ? Gdiplus::Color(203, 213, 225) : Gdiplus::Color(51, 65, 85);
        Gdiplus::Pen bp(bCol, 1.0f);
        g.DrawPath(&bp, &path);

        if (showText) {
            COLORREF fgRef = GetContrastForeColor(colRef);
            Gdiplus::SolidBrush tb(ColorRefToGdip(fgRef));
            Gdiplus::Font font(appFontName.c_str(), 9.0f, Gdiplus::FontStyleRegular, Gdiplus::UnitPoint);
            Gdiplus::StringFormat sf;
            sf.SetAlignment(Gdiplus::StringAlignmentCenter);
            sf.SetLineAlignment(Gdiplus::StringAlignmentCenter);
            g.DrawString(hexColor.c_str(), -1, &font, Gdiplus::RectF(x, y, w, h), &sf, &tb);
        }
    }

    void DrawScrollBar(Gdiplus::Graphics& g, int tabIdx, float viewX, float viewY, float viewW, float viewH, float contentH) {
        int maxS = maxScroll[tabIdx];
        if (maxS <= 0) return;

        float barW = (scrollBarHover || scrollDrag) ? 7.0f : 4.0f;
        float barX = viewX + viewW - barW - 2.0f;

        Gdiplus::Color trackCol = isDarkTheme ? Gdiplus::Color(25, 255, 255, 255) : Gdiplus::Color(30, 0, 0, 0);
        Gdiplus::Color thumbCol = (scrollBarHover || scrollDrag)
            ? (isDarkTheme ? Gdiplus::Color(130, 200, 200, 200) : Gdiplus::Color(120, 100, 100, 100))
            : (isDarkTheme ? Gdiplus::Color(70, 180, 180, 180)  : Gdiplus::Color(60, 80, 80, 80));

        Gdiplus::GraphicsPath trackPath;
        AddRoundedPath(trackPath, Gdiplus::RectF(barX, viewY + 2.0f, barW, viewH - 4.0f), barW / 2.0f);
        Gdiplus::SolidBrush trackB(trackCol);
        g.FillPath(&trackB, &trackPath);

        float ratio = viewH / contentH;
        float thumbH = (std::max)(24.0f, viewH * ratio);
        float trackH = viewH - 4.0f;
        float thumbTop = viewY + 2.0f + ((float)scrollY[tabIdx] / (float)maxS) * (trackH - thumbH);

        Gdiplus::GraphicsPath thumbPath;
        AddRoundedPath(thumbPath, Gdiplus::RectF(barX, thumbTop, barW, thumbH), barW / 2.0f);
        Gdiplus::SolidBrush thumbB(thumbCol);
        g.FillPath(&thumbB, &thumbPath);
    }

    // ------------------------------------------------------------------------
    //  DASHBOARD RENDERING (TABBAR + TAB 1 / TAB 2 / TAB 3)
    // ------------------------------------------------------------------------
    void RenderDashboard(HDC hdc, int clientW, int clientH) {
        if (!hBackDC || backW != clientW || backH != clientH) {
            FreeBackBuffer();
            hBackDC = CreateCompatibleDC(hdc);
            hBackBmp = CreateCompatibleBitmap(hdc, clientW, clientH);
            hOldBackBmp = SelectObject(hBackDC, hBackBmp);
            backW = clientW;
            backH = clientH;
        }

        Gdiplus::Graphics g(hBackDC);
        g.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
        g.SetPixelOffsetMode(Gdiplus::PixelOffsetModeHighQuality);
        g.SetTextRenderingHint(Gdiplus::TextRenderingHintClearTypeGridFit);

        Gdiplus::Color bgApp      = isDarkTheme ? Gdiplus::Color(33, 34, 38)    : Gdiplus::Color(237, 241, 247);
        Gdiplus::Color bgCard     = isDarkTheme ? Gdiplus::Color(22, 23, 26)    : Gdiplus::Color(255, 255, 255);
        Gdiplus::Color bgPanelAlt = isDarkTheme ? Gdiplus::Color(26, 27, 31)    : Gdiplus::Color(210, 218, 228);
        Gdiplus::Color textPrim   = isDarkTheme ? Gdiplus::Color(240, 242, 245) : Gdiplus::Color(30, 41, 59);
        Gdiplus::Color textMuted  = isDarkTheme ? Gdiplus::Color(156, 163, 175) : Gdiplus::Color(100, 116, 139);
        Gdiplus::Color textVal    = isDarkTheme ? Gdiplus::Color(255, 255, 255) : Gdiplus::Color(15, 23, 42);
        Gdiplus::Color cyanTitle  = isDarkTheme ? Gdiplus::Color(0, 210, 255)   : Gdiplus::Color(2, 132, 199);

        Gdiplus::SolidBrush appBrush(bgApp);
        g.FillRectangle(&appBrush, 0, 0, clientW, clientH);

        // 1. TabBar (0..34)
        const wchar_t* tabs[3] = {
            isEnLang ? L"General"    : L"Chung",
            isEnLang ? L"Appearance" : L"Giao diện",
            isEnLang ? L"Settings"   : L"Cài đặt"
        };
        int tabW = clientW / 3;
        Gdiplus::Font fontTabReg(appFontName.c_str(), 9.25f, Gdiplus::FontStyleRegular, Gdiplus::UnitPoint);
        Gdiplus::Font fontTabBold(appFontName.c_str(), 9.25f, Gdiplus::FontStyleBold, Gdiplus::UnitPoint);
        Gdiplus::StringFormat sfCenter;
        sfCenter.SetAlignment(Gdiplus::StringAlignmentCenter);
        sfCenter.SetLineAlignment(Gdiplus::StringAlignmentCenter);

        for (int i = 0; i < 3; ++i) {
            int tx = i * tabW;
            int tw = (i == 2) ? (clientW - tx) : tabW;
            bool isSel = (i == selectedTab);
            bool isHov = (i == hoverTab && !isSel);

            Gdiplus::Color tBg = isSel
                ? (isDarkTheme ? Gdiplus::Color(33, 34, 38) : Gdiplus::Color(231, 237, 243))
                : (isHov ? (isDarkTheme ? Gdiplus::Color(38, 40, 46) : Gdiplus::Color(210, 216, 226))
                         : (isDarkTheme ? Gdiplus::Color(26, 27, 31) : Gdiplus::Color(220, 226, 234)));
            Gdiplus::Color tFg = isSel
                ? (isDarkTheme ? Gdiplus::Color(0, 220, 255) : Gdiplus::Color(2, 132, 199))
                : textMuted;

            Gdiplus::SolidBrush tb(tBg);
            g.FillRectangle(&tb, tx, 0, tw, 34);
            Gdiplus::SolidBrush tf(tFg);
            g.DrawString(tabs[i], -1, isSel ? &fontTabBold : &fontTabReg, Gdiplus::RectF((float)tx, 0.0f, (float)tw, 34.0f), &sfCenter, &tf);

            if (isSel) {
                Gdiplus::Pen indPen(isDarkTheme ? Gdiplus::Color(0, 210, 255) : Gdiplus::Color(2, 132, 199), 2.5f);
                g.DrawLine(&indPen, tx, 33, tx + tw, 33);
            }
        }
        Gdiplus::Pen divPen(isDarkTheme ? Gdiplus::Color(45, 48, 56) : Gdiplus::Color(203, 213, 225), 1.0f);
        g.DrawLine(&divPen, 0, 33, clientW, 33);

        Gdiplus::Font fontBold925(appFontName.c_str(), 9.25f, Gdiplus::FontStyleBold, Gdiplus::UnitPoint);
        Gdiplus::Font fontBold9(appFontName.c_str(), 9.0f, Gdiplus::FontStyleBold, Gdiplus::UnitPoint);
        Gdiplus::Font fontReg9(appFontName.c_str(), 9.0f, Gdiplus::FontStyleRegular, Gdiplus::UnitPoint);
        Gdiplus::Font fontReg825(appFontName.c_str(), 8.25f, Gdiplus::FontStyleRegular, Gdiplus::UnitPoint);
        Gdiplus::Font fontBold85(appFontName.c_str(), 8.5f, Gdiplus::FontStyleBold, Gdiplus::UnitPoint);

        // 2. Active Tab Content
        if (selectedTab == 0) {
            const RamStatsSnapshot& st = Win32RamNative::GetCurrentRamStats();
            const RamConfig& cfg = WcaoAppEnv::CurrentConfig;

            Gdiplus::Color colDef  = ColorRefToGdip(ParseHexColor(cfg.TrayBgDefault, RGB(16, 185, 129)));
            Gdiplus::Color colWarn = ColorRefToGdip(ParseHexColor(cfg.TrayBgWarning, RGB(234, 88, 12)));
            Gdiplus::Color colDang = ColorRefToGdip(ParseHexColor(cfg.TrayBgDanger,  RGB(220, 38, 38)));

            auto drawMemCard = [&](int topY, const wchar_t* title, double pct, const wchar_t* lineAvail, const wchar_t* lineTotal, double warnLvl, double dangLvl) {
                float cy = 34.0f + (float)topY;
                Gdiplus::SolidBrush cb(bgCard);
                g.FillRectangle(&cb, 14.0f, cy, 372.0f, 76.0f);
                Gdiplus::Pen bp(isDarkTheme ? Gdiplus::Color(52, 55, 65) : Gdiplus::Color(180, 195, 210), 1.0f);
                g.DrawRectangle(&bp, 14.0f, cy, 371.0f, 75.0f);

                Gdiplus::SolidBrush titleB(cyanTitle);
                g.DrawString(title, -1, &fontBold925, Gdiplus::PointF(24.0f, cy + 6.0f), &titleB);

                Gdiplus::StringFormat sfRight;
                sfRight.SetAlignment(Gdiplus::StringAlignmentFar);
                sfRight.SetLineAlignment(Gdiplus::StringAlignmentCenter);

                wchar_t uBuf[64];
                swprintf(uBuf, 64, isEnLang ? L"Usage: %.3f%%" : L"Đang dùng: %.3f%%", pct);
                Gdiplus::SolidBrush valB(textVal);
                g.DrawString(uBuf, -1, &fontBold9, Gdiplus::RectF(194.0f, cy + 6.0f, 182.0f, 18.0f), &sfRight, &valB);

                Gdiplus::SolidBrush mutB(textMuted);
                g.DrawString(lineAvail, -1, &fontReg825, Gdiplus::RectF(154.0f, cy + 26.0f, 222.0f, 16.0f), &sfRight, &mutB);
                g.DrawString(lineTotal, -1, &fontReg825, Gdiplus::RectF(154.0f, cy + 42.0f, 222.0f, 16.0f), &sfRight, &mutB);

                Gdiplus::SolidBrush trackB(isDarkTheme ? Gdiplus::Color(40, 42, 48) : Gdiplus::Color(216, 224, 234));
                g.FillRectangle(&trackB, 24.0f, cy + 60.0f, 352.0f, 6.0f);

                double clamped = (std::max)(0.0, (std::min)(100.0, pct));
                int fillW = (int)(352.0 * (clamped / 100.0));
                if (fillW > 0) {
                    Gdiplus::Color barCol = (clamped >= dangLvl) ? colDang : ((clamped >= warnLvl) ? colWarn : colDef);
                    Gdiplus::SolidBrush fillB(barCol);
                    g.FillRectangle(&fillB, 24.0f, cy + 60.0f, (float)fillW, 6.0f);
                }
            };

            wchar_t aBuf[64], tBuf[64];
            double gb = 1024.0 * 1024.0 * 1024.0;
            double mb = 1024.0 * 1024.0;

            swprintf(aBuf, 64, isEnLang ? L"Available: %.2f GB" : L"Khả dụng: %.2f GB", st.PhysAvail / gb);
            swprintf(tBuf, 64, isEnLang ? L"Total: %.2f GB"     : L"Tổng cộng: %.2f GB", st.PhysTotal / gb);
            drawMemCard(12, isEnLang ? L"Physical Memory" : L"Bộ nhớ vật lý", st.PhysPct, aBuf, tBuf, cfg.WarningLevel, cfg.DangerLevel);

            swprintf(aBuf, 64, isEnLang ? L"Available: %.2f GB" : L"Khả dụng: %.2f GB", (std::max)(0.0, st.PageTotal - st.PageUsed) / gb);
            swprintf(tBuf, 64, isEnLang ? L"Total: %.2f GB"     : L"Tổng cộng: %.2f GB", st.PageTotal / gb);
            drawMemCard(104, isEnLang ? L"Virtual Memory" : L"Bộ nhớ ảo", st.PagePct, aBuf, tBuf, cfg.WarningLevel, cfg.DangerLevel);

            swprintf(aBuf, 64, isEnLang ? L"Cache: %.0f MB" : L"Bộ đệm: %.0f MB", st.WsUsed / mb);
            swprintf(tBuf, 64, isEnLang ? L"Peak: %.0f MB"  : L"Đỉnh: %.0f MB", st.WsTotal / mb);
            drawMemCard(196, isEnLang ? L"System File Cache" : L"Bộ đệm tập tin hệ thống", st.WsPct, aBuf, tBuf, 20.0, 35.0);

            if (!statusResultText.empty()) {
                Gdiplus::SolidBrush resB(Gdiplus::Color(16, 185, 129));
                float statusY = WcaoAppEnv::IsAdmin ? (34.0f + 289.0f) : 309.0f;
                g.DrawString(statusResultText.c_str(), -1, &fontBold85, Gdiplus::RectF(14.0f, statusY, 372.0f, 20.0f), &sfCenter, &resB);
            }

            if (!WcaoAppEnv::IsAdmin) {
                Gdiplus::RectF rAdmBtn(14.0f, 334.0f, 366.0f, 30.0f);
                bool isAdmHov = (hoverCtrlId == L"btnElevateAdmin");
                Gdiplus::Color admBg = isAdmHov
                    ? (isDarkTheme ? Gdiplus::Color(55, 48, 28) : Gdiplus::Color(254, 243, 199))
                    : (isDarkTheme ? Gdiplus::Color(38, 34, 22) : Gdiplus::Color(255, 251, 235));
                Gdiplus::Color admBorder = isAdmHov ? Gdiplus::Color(245, 158, 11) : Gdiplus::Color(217, 119, 6);
                Gdiplus::Color admText = isDarkTheme ? Gdiplus::Color(251, 191, 36) : Gdiplus::Color(180, 83, 9);

                Gdiplus::GraphicsPath admPath;
                AddRoundedPath(admPath, rAdmBtn, 6.0f);
                Gdiplus::SolidBrush admBgB(admBg);
                g.FillPath(&admBgB, &admPath);
                Gdiplus::Pen admPen(admBorder, isAdmHov ? 1.5f : 1.0f);
                g.DrawPath(&admPen, &admPath);
                Gdiplus::SolidBrush admTxtB(admText);
                const wchar_t* admLabel = isEnLang ? L"Switch to Administrator Mode" : L"Chuyển sang quyền Quản trị viên";
                g.DrawString(admLabel, -1, &fontBold9, rAdmBtn, &sfCenter, &admTxtB);
            }

            float actY = (float)(clientH - 44);
            Gdiplus::SolidBrush actB(bgPanelAlt);
            g.FillRectangle(&actB, 0.0f, actY, (float)clientW, 44.0f);

            bool cleaning = (Win32RamNative::IsCleaningInProgress != 0);
            int cdSec = GetCleanCooldownRemainingSec();
            bool btnEnabled = (!cleaning && cdSec <= 0);
            std::wstring cleanTxt;
            if (cleaning) {
                cleanTxt = isEnLang ? L"CLEANING..." : L"ĐANG DỌN DẸP...";
            } else if (cdSec > 0) {
                wchar_t cdBuf[64];
                swprintf(cdBuf, 64, isEnLang ? L"PLEASE WAIT (%ds)..." : L"CHỜ DỌN TIẾP (%ds)...", cdSec);
                cleanTxt = cdBuf;
            } else {
                cleanTxt = isEnLang ? L"CLEAN MEMORY" : L"DỌN DẸP BỘ NHỚ";
            }
            DrawModernButton(g, Gdiplus::RectF(14.0f, actY + 7.0f, 366.0f, 30.0f), cleanTxt, true, btnEnabled, hoverCtrlId == L"btnClean", 9.5f, true, 6);
        }
        else if (selectedTab == 1) {
            float viewTop = 34.0f;
            float viewH = (float)(clientH - 34 - 44);
            g.SetClip(Gdiplus::RectF(0.0f, viewTop, (float)clientW, viewH));

            float sy = viewTop - (float)scrollY[1];
            Gdiplus::SolidBrush fgB(textPrim);

            g.DrawString(isEnLang ? L"Theme:" : L"Chủ đề:", -1, &fontBold9, Gdiplus::PointF(14.0f, sy + 12.0f), &fgB);
            DrawModernRadioButton(g, 85.0f,  sy + 10.0f, 95.0f, 22.0f, isEnLang ? L"System" : L"Hệ thống", stagedCfg.Theme == L"system");
            DrawModernRadioButton(g, 185.0f, sy + 10.0f, 80.0f, 22.0f, isEnLang ? L"Dark"   : L"Tối",      stagedCfg.Theme == L"dark");
            DrawModernRadioButton(g, 270.0f, sy + 10.0f, 80.0f, 22.0f, isEnLang ? L"Light"  : L"Sáng",     stagedCfg.Theme == L"light");

            g.DrawString(isEnLang ? L"Language:" : L"Ngôn ngữ:", -1, &fontBold9, Gdiplus::PointF(14.0f, sy + 42.0f), &fgB);
            DrawModernRadioButton(g, 95.0f,  sy + 40.0f, 100.0f, 22.0f, L"Tiếng Việt", stagedCfg.Language == L"vi");
            DrawModernRadioButton(g, 200.0f, sy + 40.0f, 90.0f,  22.0f, L"English",    stagedCfg.Language == L"en");

            DrawModernCheckBox(g, 14.0f, sy + 74.0f,  320.0f, 22.0f, isEnLang ? L"Show tray icon border"       : L"Hiển thị bo viền biểu tượng", stagedCfg.TrayShowBorder);
            DrawModernCheckBox(g, 14.0f, sy + 100.0f, 320.0f, 22.0f, isEnLang ? L"Rounded tray icon corners"   : L"Bo tròn góc biểu tượng",      stagedCfg.TrayRoundedBorder);
            DrawModernCheckBox(g, 14.0f, sy + 126.0f, 240.0f, 22.0f, isEnLang ? L"Transparent below (%):"      : L"Nền trong suốt khi dưới (%):", stagedCfg.TrayTransparentBelow60);
            DrawModernNumericBox(g, 260.0f, sy + 126.0f, 78.0f, 24.0f, stagedCfg.TrayTransparentBelowPct, stagedCfg.TrayTransparentBelow60, 0, L"num0_down", L"num0_up");

            g.DrawString(isEnLang ? L"Font & size:" : L"Phông chữ & cỡ:", -1, &fontReg9, Gdiplus::PointF(14.0f, sy + 161.0f), &fgB);
            DrawModernComboBox(g, 140.0f, sy + 158.0f, 120.0f, 24.0f, stagedCfg.TrayFontFamily, true, hoverCtrlId == L"cbFont", openComboId == L"cbFont");
            DrawModernComboBox(g, 270.0f, sy + 158.0f, 55.0f,  24.0f, std::to_wstring(stagedCfg.TrayFontSize), true, hoverCtrlId == L"cbSize", openComboId == L"cbSize");

            g.DrawString(isEnLang ? L"Font style & color:" : L"Kiểu chữ & màu:", -1, &fontReg9, Gdiplus::PointF(14.0f, sy + 193.0f), &fgB);
            DrawModernComboBox(g, 140.0f, sy + 190.0f, 85.0f, 24.0f, GetLocalizedFontStyle(stagedCfg.TrayFontStyle), true, hoverCtrlId == L"cbStyle", openComboId == L"cbStyle");
            DrawModernSwatch(g, 232.0f, sy + 190.0f, 130.0f, 24.0f, stagedCfg.TrayTextColorCustom, true);

            g.DrawString(isEnLang ? L"Color indication & levels:" : L"Chỉ báo màu sắc & ngưỡng:", -1, &fontBold9, Gdiplus::PointF(14.0f, sy + 224.0f), &fgB);
            g.DrawString(isEnLang ? L"Default color (< warning):" : L"Màu mặc định (< cảnh báo):", -1, &fontReg9, Gdiplus::PointF(14.0f, sy + 251.0f), &fgB);
            DrawModernSwatch(g, 232.0f, sy + 248.0f, 130.0f, 24.0f, stagedCfg.TrayBgDefault, true);

            COLORREF warnAdapt = GetAdaptiveLabelColor(ParseHexColor(stagedCfg.TrayBgWarning), isDarkTheme);
            Gdiplus::SolidBrush warnLblB(ColorRefToGdip(warnAdapt));
            g.DrawString(isEnLang ? L"Warning threshold (%):" : L"Mức cảnh báo bắt đầu ở (%):", -1, &fontBold9, Gdiplus::PointF(14.0f, sy + 281.0f), &warnLblB);
            DrawModernNumericBox(g, 232.0f, sy + 278.0f, 78.0f, 24.0f, stagedCfg.WarningLevel, true, 1, L"num1_down", L"num1_up");
            DrawModernSwatch(g, 320.0f, sy + 278.0f, 42.0f, 24.0f, stagedCfg.TrayBgWarning, false);

            COLORREF dangAdapt = GetAdaptiveLabelColor(ParseHexColor(stagedCfg.TrayBgDanger), isDarkTheme);
            Gdiplus::SolidBrush dangLblB(ColorRefToGdip(dangAdapt));
            g.DrawString(isEnLang ? L"Danger threshold (%):" : L"Mức nguy hiểm bắt đầu ở (%):", -1, &fontBold9, Gdiplus::PointF(14.0f, sy + 311.0f), &dangLblB);
            DrawModernNumericBox(g, 232.0f, sy + 308.0f, 78.0f, 24.0f, stagedCfg.DangerLevel, true, 2, L"num2_down", L"num2_up");
            DrawModernSwatch(g, 320.0f, sy + 308.0f, 42.0f, 24.0f, stagedCfg.TrayBgDanger, false);

            g.DrawString(isEnLang ? L"Tray icon preview:" : L"Xem trước biểu tượng:", -1, &fontBold9, Gdiplus::PointF(14.0f, sy + 344.0f), &fgB);
            g.DrawString(isEnLang ? L"Test %:" : L"Mức thử (%):", -1, &fontReg9, Gdiplus::PointF(14.0f, sy + 373.0f), &fgB);
            DrawModernNumericBox(g, 105.0f, sy + 370.0f, 78.0f, 24.0f, previewTestPct, true, 3, L"num3_down", L"num3_up");

            Gdiplus::SolidBrush prevBoxBg(isDarkTheme ? Gdiplus::Color(35, 37, 42) : Gdiplus::Color(216, 224, 234));
            g.FillRectangle(&prevBoxBg, 250.0f, sy + 342.0f, 56.0f, 56.0f);
            Gdiplus::Pen prevBorder(isDarkTheme ? Gdiplus::Color(70, 75, 85) : Gdiplus::Color(160, 175, 190), 1.0f);
            g.DrawRectangle(&prevBorder, 250.0f, sy + 342.0f, 55.0f, 55.0f);

            Gdiplus::Bitmap prevBmp(48, 48, PixelFormat32bppARGB);
            {
                Gdiplus::Graphics gp(&prevBmp);
                gp.Clear(Gdiplus::Color(0, 0, 0, 0));
                DynamicTrayIconRenderer::RenderIconGraphics(gp, 48, previewTestPct, stagedCfg);
            }
            g.DrawImage(&prevBmp, 254.0f, sy + 346.0f, 48.0f, 48.0f);

            DrawScrollBar(g, 1, 0.0f, viewTop, (float)clientW, viewH, 440.0f);
            g.ResetClip();

            float actY = (float)(clientH - 44);
            Gdiplus::SolidBrush actB(bgPanelAlt);
            g.FillRectangle(&actB, 0.0f, actY, (float)clientW, 44.0f);

            std::wstring txtReset = !btnViewResetFeedback.empty() ? btnViewResetFeedback : (isEnLang ? L"Reset Defaults" : L"Mặc định");
            std::wstring txtSave  = !btnViewSaveFeedback.empty()  ? btnViewSaveFeedback  : (isEnLang ? L"Apply"          : L"Áp dụng");
            DrawModernButton(g, Gdiplus::RectF(14.0f,  actY + 7.0f, 120.0f, 30.0f), txtReset, false, !IsViewSavedDefault(), hoverCtrlId == L"btnViewReset", 9.0f, false, 6);
            DrawModernButton(g, Gdiplus::RectF(260.0f, actY + 7.0f, 120.0f, 30.0f), txtSave,  true,  IsViewDirty(),         hoverCtrlId == L"btnViewSave",  9.0f, true,  6);
        }
        else if (selectedTab == 2) {
            float viewTop = 34.0f;
            float viewH = (float)(clientH - 34 - 44);
            g.SetClip(Gdiplus::RectF(0.0f, viewTop, (float)clientW, viewH));

            float sy = viewTop - (float)scrollY[2];
            Gdiplus::SolidBrush fgB(textPrim);

            g.DrawString(isEnLang ? L"Memory regions to clean:" : L"Vùng nhớ cần dọn dẹp:", -1, &fontBold9, Gdiplus::PointF(14.0f, sy + 12.0f), &fgB);

            Gdiplus::SolidBrush cardB(bgCard);
            g.FillRectangle(&cardB, 14.0f, sy + 36.0f, 360.0f, 132.0f);

            bool adm = WcaoAppEnv::IsAdmin;
            DrawModernCheckBox(g, 20.0f, sy + 42.0f,  335.0f, 22.0f, isEnLang ? L"Working set processes"           : L"Vùng làm việc tiến trình",            stagedCfg.CleanWorkingSet, true);
            DrawModernCheckBox(g, 20.0f, sy + 66.0f,  335.0f, 22.0f, isEnLang ? L"System file cache*"              : L"Bộ đệm tập tin hệ thống*",            stagedCfg.CleanFileCache, adm);
            DrawModernCheckBox(g, 20.0f, sy + 90.0f,  335.0f, 22.0f, isEnLang ? L"Modified page list*"             : L"Danh sách trang đã sửa đổi*",         stagedCfg.CleanModifiedPageList, adm);
            DrawModernCheckBox(g, 20.0f, sy + 114.0f, 335.0f, 22.0f, isEnLang ? L"Standby list (all priorities)*"  : L"Danh sách bộ nhớ chờ (tất cả mức)*",  stagedCfg.CleanStandbyList, adm);
            DrawModernCheckBox(g, 20.0f, sy + 138.0f, 335.0f, 22.0f, isEnLang ? L"Low-priority standby list only*" : L"Bộ nhớ chờ mức ưu tiên thấp*",        stagedCfg.CleanStandbyLowPriority, adm && !stagedCfg.CleanStandbyList);

            float ySet = 174.0f;
            if (!adm) {
                Gdiplus::SolidBrush warnB(isDarkTheme ? Gdiplus::Color(251, 191, 36) : Gdiplus::Color(180, 83, 9));
                g.DrawString(
                    isEnLang ? L"⚠ User mode: Kernel memory lists (*) require Administrator rights!"
                             : L"⚠ Chế độ Người dùng: Vùng nhớ nhân (*) cần quyền Quản trị viên!",
                    -1, &fontBold85, Gdiplus::PointF(14.0f, sy + ySet), &warnB
                );
                ySet += 22.0f;
            }

            g.DrawString(isEnLang ? L"Automatic memory management:" : L"Quản lý tự động dọn RAM:", -1, &fontBold9, Gdiplus::PointF(14.0f, sy + ySet), &fgB);
            ySet += 24.0f;
            DrawModernCheckBox(g, 20.0f, sy + ySet, 215.0f, 22.0f, isEnLang ? L"Clean when RAM exceeds (%):" : L"Tự dọn khi vượt quá (%):", stagedCfg.CleanWhenAboveEnabled);
            DrawModernNumericBox(g, 245.0f, sy + ySet, 78.0f, 24.0f, stagedCfg.CleanWhenAbovePct, stagedCfg.CleanWhenAboveEnabled, 4, L"num4_down", L"num4_up");

            ySet += 28.0f;
            DrawModernCheckBox(g, 20.0f, sy + ySet, 215.0f, 22.0f, isEnLang ? L"Clean periodically every (min):" : L"Tự dọn định kỳ mỗi (phút):", stagedCfg.CleanEveryEnabled);
            DrawModernNumericBox(g, 245.0f, sy + ySet, 78.0f, 24.0f, stagedCfg.CleanEveryMin, stagedCfg.CleanEveryEnabled, 5, L"num5_down", L"num5_up");

            ySet += 35.0f;
            g.DrawString(isEnLang ? L"Global Hotkey:" : L"Phím tắt toàn cục:", -1, &fontBold9, Gdiplus::PointF(14.0f, sy + ySet), &fgB);
            ySet += 24.0f;
            DrawModernCheckBox(g, 20.0f, sy + ySet, 120.0f, 22.0f, isEnLang ? L"Clean RAM:" : L"Dọn RAM:", stagedCfg.HotkeyEnabled);
            DrawModernComboBox(g, 150.0f, sy + ySet, 140.0f, 24.0f, stagedCfg.Hotkey, stagedCfg.HotkeyEnabled, hoverCtrlId == L"cbHk", openComboId == L"cbHk");

            ySet += 35.0f;
            g.DrawString(isEnLang ? L"Notifications & Sound:" : L"Thông báo & Âm thanh:", -1, &fontBold9, Gdiplus::PointF(14.0f, sy + ySet), &fgB);
            ySet += 24.0f;
            DrawModernCheckBox(g, 20.0f, sy + ySet, 340.0f, 22.0f, isEnLang ? L"Show notification results after cleaning" : L"Hiển thị thông báo kết quả sau khi dọn RAM", stagedCfg.BalloonShowResult);
            ySet += 24.0f;
            DrawModernCheckBox(g, 20.0f, sy + ySet, 340.0f, 22.0f, isEnLang ? L"Enable notification sound" : L"Bật âm thanh thông báo", stagedCfg.BalloonPlaySound);

            ySet += 35.0f;
            g.DrawString(isEnLang ? L"Activity Log:" : L"Nhật ký hoạt động:", -1, &fontBold9, Gdiplus::PointF(14.0f, sy + ySet), &fgB);
            ySet += 24.0f;
            DrawModernButton(g, Gdiplus::RectF(14.0f,  sy + ySet, 175.0f, 28.0f), isEnLang ? L"Export Log..."   : L"Xuất nhật ký...",      false, true, hoverCtrlId == L"btnExportLog", 8.5f, false, 6);
            DrawModernButton(g, Gdiplus::RectF(201.0f, sy + ySet, 175.0f, 28.0f), isEnLang ? L"Open Log Folder" : L"Mở thư mục nhật ký", false, true, hoverCtrlId == L"btnOpenLogFolder", 8.5f, false, 6);

            float totalSetH = ySet + 45.0f;
            DrawScrollBar(g, 2, 0.0f, viewTop, (float)clientW, viewH, totalSetH);
            g.ResetClip();

            float actY = (float)(clientH - 44);
            Gdiplus::SolidBrush actB(bgPanelAlt);
            g.FillRectangle(&actB, 0.0f, actY, (float)clientW, 44.0f);

            std::wstring txtReset = !btnSetResetFeedback.empty() ? btnSetResetFeedback : (isEnLang ? L"Reset Defaults" : L"Mặc định");
            std::wstring txtSave  = !btnSetSaveFeedback.empty()  ? btnSetSaveFeedback  : (isEnLang ? L"Apply"          : L"Áp dụng");
            DrawModernButton(g, Gdiplus::RectF(14.0f,  actY + 7.0f, 120.0f, 30.0f), txtReset, false, !IsSetSavedDefault(), hoverCtrlId == L"btnSetReset", 9.0f, false, 6);
            DrawModernButton(g, Gdiplus::RectF(260.0f, actY + 7.0f, 120.0f, 30.0f), txtSave,  true,  IsSetDirty(),         hoverCtrlId == L"btnSetSave",  9.0f, true,  6);
        }

        BitBlt(hdc, 0, 0, clientW, clientH, hBackDC, 0, 0, SRCCOPY);
    }

    // ------------------------------------------------------------------------
    //  USER ACTIONS: APPLY / RESET / LOG EXPORT / TRAY MENU
    // ------------------------------------------------------------------------
    void TriggerButtonFeedback(int id, const std::wstring& msg) {
        if (id == 101) btnViewResetFeedback = msg;
        if (id == 102) btnViewSaveFeedback  = msg;
        if (id == 103) btnSetResetFeedback  = msg;
        if (id == 104) btnSetSaveFeedback   = msg;
        SetTimer(hMainWnd, id, 1400, nullptr);
        InvalidateRect(hMainWnd, nullptr, FALSE);
    }

    void OnClickViewReset() {
        if (IsViewSavedDefault()) return;
        CommitFocusedNumEdit();
        RamConfig cfg = WcaoAppEnv::CurrentConfig;
        std::wstring curLang = cfg.Language;
        cfg.Theme                   = L"system";
        cfg.Language                = curLang;
        cfg.TrayShowBorder          = true;
        cfg.TrayRoundedBorder       = false;
        cfg.TrayTransparentBelow60  = false;
        cfg.TrayTransparentBelowPct = 60;
        cfg.TrayFontFamily          = L"Tahoma";
        cfg.TrayFontSize            = 7;
        cfg.TrayFontStyle           = L"Bold";
        cfg.TrayTextColorCustom     = L"#FFFFFF";
        cfg.TrayBgDefault           = L"#10B981";
        cfg.WarningLevel            = 70;
        cfg.TrayBgWarning           = L"#EA580C";
        cfg.DangerLevel             = 90;
        cfg.TrayBgDanger            = L"#DC2626";

        if (!WcaoAppEnv::SaveRamConfig(cfg)) {
            TriggerButtonFeedback(101, isEnLang ? L"✗ Reset Failed!" : L"✗ Khôi phục lỗi!");
            return;
        }
        WcaoAppEnv::CurrentConfig = cfg;
        SyncStagedFromSaved();
        previewTestPct = 67;
        UpdateWindowTitleAndTheme();
        UpdateTrayIconAndTooltip(Win32RamNative::GetCurrentRamStats(), true);
        WcaoAppEnv::WriteLog(L"CONFIG", isEnLang ? L"Appearance settings restored to defaults" : L"Đã khôi phục cài đặt giao diện về mặc định");
        TriggerButtonFeedback(101, isEnLang ? L"✓ Restored!" : L"✓ Đã khôi phục!");
    }

    void OnClickViewSave() {
        if (!IsViewDirty()) return;
        CommitFocusedNumEdit();
        if (stagedCfg.WarningLevel >= stagedCfg.DangerLevel) {
            MessageBoxW(hMainWnd,
                isEnLang ? L"Warning threshold must be lower than Danger threshold!" : L"Mức cảnh báo phải nhỏ hơn mức nguy hiểm!",
                L"WCaO RAM Manager", MB_OK | MB_ICONWARNING);
            return;
        }

        RamConfig cfg = WcaoAppEnv::CurrentConfig;
        cfg.Theme                   = stagedCfg.Theme;
        cfg.Language                = stagedCfg.Language;
        cfg.TrayShowBorder          = stagedCfg.TrayShowBorder;
        cfg.TrayRoundedBorder       = stagedCfg.TrayRoundedBorder;
        cfg.TrayTransparentBelow60  = stagedCfg.TrayTransparentBelow60;
        cfg.TrayTransparentBelowPct = stagedCfg.TrayTransparentBelowPct;
        cfg.TrayFontFamily          = stagedCfg.TrayFontFamily;
        cfg.TrayFontSize            = stagedCfg.TrayFontSize;
        cfg.TrayFontStyle           = stagedCfg.TrayFontStyle;
        cfg.TrayTextColorCustom     = stagedCfg.TrayTextColorCustom;
        cfg.TrayBgDefault           = stagedCfg.TrayBgDefault;
        cfg.WarningLevel            = stagedCfg.WarningLevel;
        cfg.TrayBgWarning           = stagedCfg.TrayBgWarning;
        cfg.DangerLevel             = stagedCfg.DangerLevel;
        cfg.TrayBgDanger            = stagedCfg.TrayBgDanger;

        if (!WcaoAppEnv::SaveRamConfig(cfg)) {
            TriggerButtonFeedback(102, isEnLang ? L"✗ Save Failed!" : L"✗ Lưu lỗi!");
            return;
        }
        WcaoAppEnv::CurrentConfig = cfg;
        SyncStagedFromSaved();
        UpdateWindowTitleAndTheme();
        UpdateTrayIconAndTooltip(Win32RamNative::GetCurrentRamStats(), true);
        WcaoAppEnv::WriteLog(L"CONFIG", isEnLang
            ? (L"Appearance settings saved (Theme: " + cfg.Theme + L", Lang: " + cfg.Language + L")")
            : (L"Đã lưu cài đặt giao diện (Chủ đề: " + cfg.Theme + L", Ngôn ngữ: " + cfg.Language + L")"));
        TriggerButtonFeedback(102, isEnLang ? L"✓ Applied!" : L"✓ Đã lưu!");
    }

    void OnClickSetReset() {
        if (IsSetSavedDefault()) return;
        CommitFocusedNumEdit();
        RamConfig cfg = WcaoAppEnv::CurrentConfig;
        cfg.CleanWorkingSet         = true;
        cfg.CleanFileCache          = true;
        cfg.CleanModifiedPageList   = false;
        cfg.CleanStandbyList        = false;
        if (WcaoAppEnv::IsAdmin) cfg.CleanStandbyLowPriority = true;
        cfg.CleanWhenAboveEnabled   = false;
        cfg.CleanWhenAbovePct       = 70;
        cfg.CleanEveryEnabled       = false;
        cfg.CleanEveryMin           = 5;
        cfg.HotkeyEnabled           = false;
        cfg.Hotkey                  = L"Ctrl + F1";
        cfg.BalloonShowResult       = true;
        cfg.BalloonPlaySound        = true;

        if (!WcaoAppEnv::SaveRamConfig(cfg)) {
            TriggerButtonFeedback(103, isEnLang ? L"✗ Reset Failed!" : L"✗ Khôi phục lỗi!");
            return;
        }
        WcaoAppEnv::CurrentConfig = cfg;
        SyncStagedFromSaved();
        RegisterGlobalHotkey();
        WcaoAppEnv::WriteLog(L"CONFIG", isEnLang ? L"Cleaning settings restored to defaults" : L"Đã khôi phục cài đặt dọn dẹp về mặc định");
        TriggerButtonFeedback(103, isEnLang ? L"✓ Restored!" : L"✓ Đã khôi phục!");
    }

    void OnClickSetSave() {
        if (!IsSetDirty()) return;
        CommitFocusedNumEdit();
        RamConfig cfg = WcaoAppEnv::CurrentConfig;
        cfg.CleanWorkingSet = stagedCfg.CleanWorkingSet;
        if (WcaoAppEnv::IsAdmin) {
            cfg.CleanFileCache          = stagedCfg.CleanFileCache;
            cfg.CleanModifiedPageList   = stagedCfg.CleanModifiedPageList;
            cfg.CleanStandbyList        = stagedCfg.CleanStandbyList;
            cfg.CleanStandbyLowPriority = stagedCfg.CleanStandbyLowPriority;
        }
        cfg.CleanWhenAboveEnabled = stagedCfg.CleanWhenAboveEnabled;
        cfg.CleanWhenAbovePct     = stagedCfg.CleanWhenAbovePct;
        cfg.CleanEveryEnabled     = stagedCfg.CleanEveryEnabled;
        cfg.CleanEveryMin         = stagedCfg.CleanEveryMin;
        cfg.HotkeyEnabled         = stagedCfg.HotkeyEnabled;
        cfg.Hotkey                = stagedCfg.Hotkey;
        cfg.BalloonShowResult     = stagedCfg.BalloonShowResult;
        cfg.BalloonPlaySound      = stagedCfg.BalloonPlaySound;

        if (!WcaoAppEnv::SaveRamConfig(cfg)) {
            TriggerButtonFeedback(104, isEnLang ? L"✗ Save Failed!" : L"✗ Lưu lỗi!");
            return;
        }
        WcaoAppEnv::CurrentConfig = cfg;
        SyncStagedFromSaved();
        RegisterGlobalHotkey();
        WcaoAppEnv::WriteLog(L"CONFIG", isEnLang ? L"Cleaning settings saved" : L"Đã lưu cài đặt dọn dẹp");
        TriggerButtonFeedback(104, isEnLang ? L"✓ Applied!" : L"✓ Đã lưu!");
    }

    void OnClickExportLog() {
        if (GetFileAttributesW(WcaoAppEnv::ActionsLogPath.c_str()) == INVALID_FILE_ATTRIBUTES) {
            ShowTrayNotification(isEnLang ? L"No actions to export." : L"Không có nhật ký để xuất.");
            return;
        }
        SYSTEMTIME st;
        GetLocalTime(&st);
        wchar_t fileBuf[MAX_PATH] = {};
        swprintf(fileBuf, MAX_PATH, L"WCaO_Log_%04d%02d%02d_%02d%02d%02d.txt",
            st.wYear, st.wMonth, st.wDay, st.wHour, st.wMinute, st.wSecond);

        wchar_t desktopDir[MAX_PATH] = {};
        SHGetFolderPathW(nullptr, CSIDL_DESKTOPDIRECTORY, nullptr, 0, desktopDir);

        OPENFILENAMEW ofn = { sizeof(ofn) };
        ofn.hwndOwner = hMainWnd;
        ofn.lpstrFilter = L"Text Files (*.txt)\0*.txt\0Log Files (*.log)\0*.log\0All Files (*.*)\0*.*\0";
        ofn.lpstrFile = fileBuf;
        ofn.nMaxFile = MAX_PATH;
        ofn.lpstrInitialDir = desktopDir;
        ofn.lpstrTitle = isEnLang ? L"Export WCaO Action Log To..." : L"Xuất nhật ký WCaO ra tập tin";
        ofn.Flags = OFN_OVERWRITEPROMPT | OFN_PATHMUSTEXIST | OFN_NOCHANGEDIR;
        ofn.lpstrDefExt = L"txt";

        if (GetSaveFileNameW(&ofn)) {
            if (CopyFileW(WcaoAppEnv::ActionsLogPath.c_str(), fileBuf, FALSE)) {
                WcaoAppEnv::WriteLog(L"ACTION", (isEnLang ? L"Exported action log to: " : L"Đã xuất nhật ký hoạt động tới: ") + std::wstring(fileBuf));
                ShowTrayNotification(isEnLang ? L"Log exported successfully!" : L"Đã xuất nhật ký thành công!");
            }
        }
    }

    void OnClickOpenLogFolder() {
        CreateDirectoryW(WcaoAppEnv::AppDataDir.c_str(), nullptr);
        ShellExecuteW(nullptr, L"open", WcaoAppEnv::AppDataDir.c_str(), nullptr, nullptr, SW_SHOWNORMAL);
        WcaoAppEnv::WriteLog(L"ACTION", (isEnLang ? L"Opened log directory: " : L"Đã mở thư mục nhật ký: ") + WcaoAppEnv::AppDataDir);
    }

    void OnShowTrayContextMenu() {
        bool dummyBlocked = false;
        bool autoEnabled = WcaoAppEnv::ManageAutostart(false, dummyBlocked);
        int action = ModernTrayMenuPopup::Show(hMainWnd, isDarkTheme, isEnLang, autoEnabled, appFontName);
        if (action == 1) {
            TriggerMemoryClean(L"tray");
        } else if (action == 2) {
            ShowDashboardWindow();
        } else if (action == 3) {
            bool blocked = false;
            bool nowEnabled = WcaoAppEnv::ManageAutostart(true, blocked);
            if (blocked) {
                MessageBoxW(hMainWnd,
                    isEnLang
                        ? L"An Administrator-level autostart task exists in the system.\nPlease switch to Administrator mode to turn off autostart!"
                        : L"Tác vụ tự khởi động quyền Quản trị viên đang tồn tại trong hệ thống.\nVui lòng chuyển sang quyền Quản trị viên để tắt tự khởi động!",
                    L"WCaO RAM Manager", MB_OK | MB_ICONWARNING);
            } else if (nowEnabled) {
                WcaoAppEnv::WriteLog(L"CONFIG", isEnLang ? L"Autostart enabled" : L"Đã bật tự khởi động cùng Windows");
                ShowTrayNotification(isEnLang ? L"Enabled startup with Windows!" : L"Đã bật tự khởi động cùng Windows!");
            } else {
                WcaoAppEnv::WriteLog(L"CONFIG", isEnLang ? L"Autostart disabled" : L"Đã tắt tự khởi động cùng Windows");
                ShowTrayNotification(isEnLang ? L"Disabled startup with Windows!" : L"Đã tắt tự khởi động cùng Windows!");
            }
        } else if (action == 4) {
            realExit = true;
            DestroyWindow(hMainWnd);
        }
    }

    // ------------------------------------------------------------------------
    //  MOUSE HIT-TESTING & INTERACTION
    // ------------------------------------------------------------------------
    void OpenComboDropdown(const std::wstring& id, int x, int yInScroll, int w, int h, const std::vector<std::wstring>& items, std::wstring& targetVal) {
        CommitFocusedNumEdit();
        openComboId = id;
        InvalidateRect(hMainWnd, nullptr, FALSE);

        POINT ptTL = { x, 34 + yInScroll - scrollY[selectedTab] };
        POINT ptBR = { x + w, 34 + yInScroll - scrollY[selectedTab] + h };
        ClientToScreen(hMainWnd, &ptTL);
        ClientToScreen(hMainWnd, &ptBR);
        RECT screenRc = { ptTL.x, ptTL.y, ptBR.x, ptBR.y };

        int curIdx = 0;
        for (size_t i = 0; i < items.size(); ++i) {
            if (items[i] == targetVal) { curIdx = (int)i; break; }
        }
        int chosen = ModernComboPopup::Show(hMainWnd, screenRc, items, curIdx, isDarkTheme, appFontName);
        openComboId.clear();
        if (chosen >= 0 && chosen < (int)items.size()) {
            targetVal = items[chosen];
        }
        InvalidateRect(hMainWnd, nullptr, FALSE);
    }

    bool HandleNumericBoxClick(int mx, int myInScroll, int bx, int by, int bw, int bh, bool enabled, int numIdx) {
        if (!enabled) return false;
        if (mx >= bx && mx < bx + bw && myInScroll >= by && myInScroll < by + bh) {
            if (mx < bx + 22) {
                CommitFocusedNumEdit();
                AdjustNumValue(numIdx, -1);
            } else if (mx >= bx + bw - 22) {
                CommitFocusedNumEdit();
                AdjustNumValue(numIdx, +1);
            } else {
                if (focusedNumIdx != numIdx) {
                    CommitFocusedNumEdit();
                    focusedNumIdx = numIdx;
                    int* ptr = GetNumValuePtr(numIdx);
                    numEditBuffer = ptr ? std::to_wstring(*ptr) : L"";
                    numEditTyping = false;
                    InvalidateRect(hMainWnd, nullptr, FALSE);
                }
            }
            return true;
        }
        return false;
    }

    void OnMouseDown(int mx, int my) {
        RECT rc; GetClientRect(hMainWnd, &rc);
        int clientW = rc.right - rc.left;
        int clientH = rc.bottom - rc.top;

        if (my >= 0 && my < 34) {
            CommitFocusedNumEdit();
            int tabW = clientW / 3;
            int idx = (std::min)(2, mx / tabW);
            if (idx != selectedTab) {
                selectedTab = idx;
                InvalidateRect(hMainWnd, nullptr, FALSE);
            }
            return;
        }

        if ((selectedTab == 1 || selectedTab == 2) && my >= 34 && my < clientH - 44 && maxScroll[selectedTab] > 0) {
            if (mx >= clientW - 12) {
                CommitFocusedNumEdit();
                scrollDrag = true;
                dragStartY = my;
                dragStartScroll = scrollY[selectedTab];
                SetCapture(hMainWnd);
                InvalidateRect(hMainWnd, nullptr, FALSE);
                return;
            }
        }

        int actY = clientH - 44;
        if (my >= actY) {
            CommitFocusedNumEdit();
            if (selectedTab == 0) {
                if (mx >= 14 && mx < 380 && my >= actY + 7 && my < actY + 37) {
                    TriggerMemoryClean(L"button");
                }
            } else if (selectedTab == 1) {
                if (mx >= 14 && mx < 134 && my >= actY + 7 && my < actY + 37) OnClickViewReset();
                else if (mx >= 260 && mx < 380 && my >= actY + 7 && my < actY + 37) OnClickViewSave();
            } else if (selectedTab == 2) {
                if (mx >= 14 && mx < 134 && my >= actY + 7 && my < actY + 37) OnClickSetReset();
                else if (mx >= 260 && mx < 380 && my >= actY + 7 && my < actY + 37) OnClickSetSave();
            }
            return;
        }

        if (selectedTab == 0) {
            if (!WcaoAppEnv::IsAdmin && mx >= 14 && mx < 380 && my >= 334 && my < 364) {
                RelaunchAsAdmin(true);
            }
            return;
        }

        int contentY = my - 34 + scrollY[selectedTab];

        if (selectedTab == 1) {
            if (HandleNumericBoxClick(mx, contentY, 260, 126, 78, 24, stagedCfg.TrayTransparentBelow60, 0)) return;
            if (HandleNumericBoxClick(mx, contentY, 232, 278, 78, 24, true, 1)) return;
            if (HandleNumericBoxClick(mx, contentY, 232, 308, 78, 24, true, 2)) return;
            if (HandleNumericBoxClick(mx, contentY, 105, 370, 78, 24, true, 3)) return;

            CommitFocusedNumEdit();

            if (contentY >= 8 && contentY < 34) {
                if (mx >= 85 && mx < 180)  { stagedCfg.Theme = L"system"; InvalidateRect(hMainWnd, nullptr, FALSE); UpdateWindow(hMainWnd); return; }
                if (mx >= 185 && mx < 265) { stagedCfg.Theme = L"dark";   InvalidateRect(hMainWnd, nullptr, FALSE); UpdateWindow(hMainWnd); return; }
                if (mx >= 270 && mx < 350) { stagedCfg.Theme = L"light";  InvalidateRect(hMainWnd, nullptr, FALSE); UpdateWindow(hMainWnd); return; }
            }
            if (contentY >= 38 && contentY < 64) {
                if (mx >= 95 && mx < 195)  { stagedCfg.Language = L"vi"; InvalidateRect(hMainWnd, nullptr, FALSE); UpdateWindow(hMainWnd); return; }
                if (mx >= 200 && mx < 290) { stagedCfg.Language = L"en"; InvalidateRect(hMainWnd, nullptr, FALSE); UpdateWindow(hMainWnd); return; }
            }
            if (mx >= 14 && mx < 334 && contentY >= 72 && contentY < 98) {
                stagedCfg.TrayShowBorder = !stagedCfg.TrayShowBorder;
                InvalidateRect(hMainWnd, nullptr, FALSE);
                UpdateWindow(hMainWnd);
                return;
            }
            if (mx >= 14 && mx < 334 && contentY >= 98 && contentY < 124) {
                stagedCfg.TrayRoundedBorder = !stagedCfg.TrayRoundedBorder;
                InvalidateRect(hMainWnd, nullptr, FALSE);
                UpdateWindow(hMainWnd);
                return;
            }
            if (mx >= 14 && mx < 254 && contentY >= 124 && contentY < 150) {
                stagedCfg.TrayTransparentBelow60 = !stagedCfg.TrayTransparentBelow60;
                InvalidateRect(hMainWnd, nullptr, FALSE);
                UpdateWindow(hMainWnd);
                return;
            }
            if (mx >= 140 && mx < 260 && contentY >= 158 && contentY < 182) {
                OpenComboDropdown(L"cbFont", 140, 158, 120, 24, { L"Tahoma", L"Segoe UI", L"Arial", L"Consolas" }, stagedCfg.TrayFontFamily);
                return;
            }
            if (mx >= 270 && mx < 325 && contentY >= 158 && contentY < 182) {
                std::wstring szStr = std::to_wstring(stagedCfg.TrayFontSize);
                OpenComboDropdown(L"cbSize", 270, 158, 55, 24, { L"6", L"7", L"8", L"9" }, szStr);
                stagedCfg.TrayFontSize = _wtoi(szStr.c_str());
                return;
            }
            if (mx >= 140 && mx < 225 && contentY >= 190 && contentY < 214) {
                std::wstring dispStyle = GetLocalizedFontStyle(stagedCfg.TrayFontStyle);
                std::vector<std::wstring> styleItems = isEnLang
                    ? std::vector<std::wstring>{ L"Bold", L"Regular", L"Italic" }
                    : std::vector<std::wstring>{ L"Đậm", L"Thường", L"Nghiêng" };
                OpenComboDropdown(L"cbStyle", 140, 190, 85, 24, styleItems, dispStyle);
                stagedCfg.TrayFontStyle = NormalizeFontStyleConfig(dispStyle);
                return;
            }
            if (mx >= 232 && mx < 362 && contentY >= 190 && contentY < 214) {
                COLORREF picked;
                if (NativeColorPicker::Show(hMainWnd, ParseHexColor(stagedCfg.TrayTextColorCustom), picked)) {
                    stagedCfg.TrayTextColorCustom = ColorToHex(picked);
                    InvalidateRect(hMainWnd, nullptr, FALSE);
                }
                return;
            }
            if (mx >= 232 && mx < 362 && contentY >= 248 && contentY < 272) {
                COLORREF picked;
                if (NativeColorPicker::Show(hMainWnd, ParseHexColor(stagedCfg.TrayBgDefault), picked)) {
                    stagedCfg.TrayBgDefault = ColorToHex(picked);
                    InvalidateRect(hMainWnd, nullptr, FALSE);
                }
                return;
            }
            if (mx >= 320 && mx < 362 && contentY >= 278 && contentY < 302) {
                COLORREF picked;
                if (NativeColorPicker::Show(hMainWnd, ParseHexColor(stagedCfg.TrayBgWarning), picked)) {
                    stagedCfg.TrayBgWarning = ColorToHex(picked);
                    InvalidateRect(hMainWnd, nullptr, FALSE);
                }
                return;
            }
            if (mx >= 320 && mx < 362 && contentY >= 308 && contentY < 332) {
                COLORREF picked;
                if (NativeColorPicker::Show(hMainWnd, ParseHexColor(stagedCfg.TrayBgDanger), picked)) {
                    stagedCfg.TrayBgDanger = ColorToHex(picked);
                    InvalidateRect(hMainWnd, nullptr, FALSE);
                }
                return;
            }
        }
        else if (selectedTab == 2) {
            int yBase = WcaoAppEnv::IsAdmin ? 174 : 196;
            if (HandleNumericBoxClick(mx, contentY, 245, yBase + 24, 78, 24, stagedCfg.CleanWhenAboveEnabled, 4)) return;
            if (HandleNumericBoxClick(mx, contentY, 245, yBase + 52, 78, 24, stagedCfg.CleanEveryEnabled, 5)) return;

            CommitFocusedNumEdit();

            if (mx >= 20 && mx < 355) {
                if (contentY >= 40 && contentY < 65) {
                    stagedCfg.CleanWorkingSet = !stagedCfg.CleanWorkingSet;
                    InvalidateRect(hMainWnd, nullptr, FALSE);
                    UpdateWindow(hMainWnd);
                    return;
                }
                if (WcaoAppEnv::IsAdmin) {
                    if (contentY >= 65 && contentY < 89) {
                        stagedCfg.CleanFileCache = !stagedCfg.CleanFileCache;
                        InvalidateRect(hMainWnd, nullptr, FALSE);
                        UpdateWindow(hMainWnd);
                        return;
                    }
                    if (contentY >= 89 && contentY < 113) {
                        stagedCfg.CleanModifiedPageList = !stagedCfg.CleanModifiedPageList;
                        InvalidateRect(hMainWnd, nullptr, FALSE);
                        UpdateWindow(hMainWnd);
                        return;
                    }
                    if (contentY >= 113 && contentY < 137) {
                        stagedCfg.CleanStandbyList = !stagedCfg.CleanStandbyList;
                        if (stagedCfg.CleanStandbyList) stagedCfg.CleanStandbyLowPriority = false;
                        InvalidateRect(hMainWnd, nullptr, FALSE);
                        UpdateWindow(hMainWnd);
                        return;
                    }
                    if (contentY >= 137 && contentY < 162 && !stagedCfg.CleanStandbyList) {
                        stagedCfg.CleanStandbyLowPriority = !stagedCfg.CleanStandbyLowPriority;
                        InvalidateRect(hMainWnd, nullptr, FALSE);
                        UpdateWindow(hMainWnd);
                        return;
                    }
                }
            }

            if (mx >= 20 && mx < 235 && contentY >= yBase + 22 && contentY < yBase + 49) {
                stagedCfg.CleanWhenAboveEnabled = !stagedCfg.CleanWhenAboveEnabled;
                InvalidateRect(hMainWnd, nullptr, FALSE);
                UpdateWindow(hMainWnd);
                return;
            }
            if (mx >= 20 && mx < 235 && contentY >= yBase + 50 && contentY < yBase + 76) {
                stagedCfg.CleanEveryEnabled = !stagedCfg.CleanEveryEnabled;
                InvalidateRect(hMainWnd, nullptr, FALSE);
                UpdateWindow(hMainWnd);
                return;
            }

            int yHk = yBase + 111;
            if (mx >= 20 && mx < 140 && contentY >= yHk - 2 && contentY < yHk + 24) {
                stagedCfg.HotkeyEnabled = !stagedCfg.HotkeyEnabled;
                InvalidateRect(hMainWnd, nullptr, FALSE);
                UpdateWindow(hMainWnd);
                return;
            }
            if (stagedCfg.HotkeyEnabled && mx >= 150 && mx < 290 && contentY >= yHk && contentY < yHk + 24) {
                OpenComboDropdown(L"cbHk", 150, yHk, 140, 24, { L"Ctrl + F1", L"Ctrl + F2", L"Ctrl + Shift + R", L"Ctrl + Alt + M" }, stagedCfg.Hotkey);
                return;
            }

            int yNotif = yHk + 59;
            if (mx >= 20 && mx < 360 && contentY >= yNotif - 2 && contentY < yNotif + 23) {
                stagedCfg.BalloonShowResult = !stagedCfg.BalloonShowResult;
                InvalidateRect(hMainWnd, nullptr, FALSE);
                UpdateWindow(hMainWnd);
                return;
            }
            if (mx >= 20 && mx < 360 && contentY >= yNotif + 23 && contentY < yNotif + 48) {
                stagedCfg.BalloonPlaySound = !stagedCfg.BalloonPlaySound;
                InvalidateRect(hMainWnd, nullptr, FALSE);
                UpdateWindow(hMainWnd);
                return;
            }

            int yLogBtns = yNotif + 83;
            if (contentY >= yLogBtns && contentY < yLogBtns + 28) {
                if (mx >= 14 && mx < 189)  { OnClickExportLog(); return; }
                if (mx >= 201 && mx < 376) { OnClickOpenLogFolder(); return; }
            }
        }
    }

    void OnMouseMove(int mx, int my) {
        RECT rc; GetClientRect(hMainWnd, &rc);
        int clientW = rc.right - rc.left;
        int clientH = rc.bottom - rc.top;

        if (scrollDrag && (selectedTab == 1 || selectedTab == 2)) {
            int maxS = maxScroll[selectedTab];
            if (maxS > 0) {
                float viewH = (float)(clientH - 34 - 44);
                float contentH = (float)(viewH + maxS);
                float thumbH = (std::max)(24.0f, viewH * (viewH / contentH));
                float denom = (viewH - 4.0f) - thumbH;
                int dy = my - dragStartY;
                float scrollPerPx = (denom > 0.0f) ? ((float)maxS / denom) : 0.0f;
                scrollY[selectedTab] = (std::max)(0, (std::min)(maxS, dragStartScroll + (int)(dy * scrollPerPx)));
                InvalidateRect(hMainWnd, nullptr, FALSE);
            }
            return;
        }

        int newHoverTab = -1;
        if (my >= 0 && my < 34) {
            newHoverTab = (std::min)(2, mx / (clientW / 3));
        }

        bool newBarHover = ((selectedTab == 1 || selectedTab == 2) && my >= 34 && my < clientH - 44 && mx >= clientW - 12);

        std::wstring newHoverCtrl;
        int actY = clientH - 44;
        if (my >= actY) {
            if (selectedTab == 0 && mx >= 14 && mx < 380 && my >= actY + 7 && my < actY + 37) newHoverCtrl = L"btnClean";
            if (selectedTab == 1) {
                if (mx >= 14 && mx < 134 && my >= actY + 7 && my < actY + 37) newHoverCtrl = L"btnViewReset";
                else if (mx >= 260 && mx < 380 && my >= actY + 7 && my < actY + 37) newHoverCtrl = L"btnViewSave";
            }
            if (selectedTab == 2) {
                if (mx >= 14 && mx < 134 && my >= actY + 7 && my < actY + 37) newHoverCtrl = L"btnSetReset";
                else if (mx >= 260 && mx < 380 && my >= actY + 7 && my < actY + 37) newHoverCtrl = L"btnSetSave";
            }
        } else if (my >= 34 && my < actY) {
            int cy = my - 34 + scrollY[selectedTab];
            if (selectedTab == 0) {
                if (!WcaoAppEnv::IsAdmin && mx >= 14 && mx < 380 && my >= 334 && my < 364) {
                    newHoverCtrl = L"btnElevateAdmin";
                }
            } else if (selectedTab == 1) {
                if (mx >= 140 && mx < 260 && cy >= 158 && cy < 182) newHoverCtrl = L"cbFont";
                else if (mx >= 270 && mx < 325 && cy >= 158 && cy < 182) newHoverCtrl = L"cbSize";
                else if (mx >= 140 && mx < 225 && cy >= 190 && cy < 214) newHoverCtrl = L"cbStyle";
                else if (cy >= 126 && cy < 150 && mx >= 260 && mx < 282) newHoverCtrl = L"num0_down";
                else if (cy >= 126 && cy < 150 && mx >= 316 && mx < 338) newHoverCtrl = L"num0_up";
                else if (cy >= 278 && cy < 302 && mx >= 232 && mx < 254) newHoverCtrl = L"num1_down";
                else if (cy >= 278 && cy < 302 && mx >= 288 && mx < 310) newHoverCtrl = L"num1_up";
                else if (cy >= 308 && cy < 332 && mx >= 232 && mx < 254) newHoverCtrl = L"num2_down";
                else if (cy >= 308 && cy < 332 && mx >= 288 && mx < 310) newHoverCtrl = L"num2_up";
                else if (cy >= 370 && cy < 394 && mx >= 105 && mx < 127) newHoverCtrl = L"num3_down";
                else if (cy >= 370 && cy < 394 && mx >= 161 && mx < 183) newHoverCtrl = L"num3_up";
            } else if (selectedTab == 2) {
                int yBase = WcaoAppEnv::IsAdmin ? 174 : 196;
                int yHk = yBase + 111;
                int yLogBtns = yHk + 59 + 83;
                if (cy >= yBase + 24 && cy < yBase + 48 && mx >= 245 && mx < 267) newHoverCtrl = L"num4_down";
                else if (cy >= yBase + 24 && cy < yBase + 48 && mx >= 301 && mx < 323) newHoverCtrl = L"num4_up";
                else if (cy >= yBase + 52 && cy < yBase + 76 && mx >= 245 && mx < 267) newHoverCtrl = L"num5_down";
                else if (cy >= yBase + 52 && cy < yBase + 76 && mx >= 301 && mx < 323) newHoverCtrl = L"num5_up";
                else if (mx >= 150 && mx < 290 && cy >= yHk && cy < yHk + 24) newHoverCtrl = L"cbHk";
                else if (cy >= yLogBtns && cy < yLogBtns + 28 && mx >= 14 && mx < 189) newHoverCtrl = L"btnExportLog";
                else if (cy >= yLogBtns && cy < yLogBtns + 28 && mx >= 201 && mx < 376) newHoverCtrl = L"btnOpenLogFolder";
            }
        }

        if (newHoverTab != hoverTab || newBarHover != scrollBarHover || newHoverCtrl != hoverCtrlId) {
            hoverTab = newHoverTab;
            scrollBarHover = newBarHover;
            hoverCtrlId = newHoverCtrl;
            InvalidateRect(hMainWnd, nullptr, FALSE);
        }
    }

    // ------------------------------------------------------------------------
    //  PERIODIC UNIFIED TIMER & CLEAN COMPLETION HANDLER
    // ------------------------------------------------------------------------
    void OnCleanCompleted() {
        if (InterlockedCompareExchange(&Win32RamNative::CleanFinished, 0, 1) != 1) return;

        double freedMB = Win32RamNative::LastFreedMB;
        double latSavedMs = Win32RamNative::LastLatencySavedMs;
        int fpsMin = Win32RamNative::LastFpsGainMin;
        int fpsMax = Win32RamNative::LastFpsGainMax;
        std::wstring src = Win32RamNative::LastCleanSource;
        std::wstring sizeStr = FormatRamSize(freedMB);

        lastPeriodicCleanTick = GetTickCount64();
        cleanCooldownUntilTick = GetTickCount64() + 3000ULL;
        SetTimer(hMainWnd, 3, 200, nullptr);

        wchar_t logBuf[256];
        double timerMs = (Win32RamNative::LockedTimerRes100ns > 0) ? (Win32RamNative::LockedTimerRes100ns / 10000.0) : 0.5;
        swprintf(logBuf, 256,
            isEnLang ? L"Memory cleaned (%s). Freed: %s | Latency: -%.1f ms | FPS: +%d-%d | Timer: %.2f ms"
                     : L"Đã dọn bộ nhớ (%s). Giải phóng: %s | Giảm trễ: ~%.1f ms | Tăng: ~%d-%d FPS | Xung nhân: %.2f ms",
            src.c_str(), sizeStr.c_str(), latSavedMs, fpsMin, fpsMax, timerMs);
        WcaoAppEnv::WriteLog(L"CLEAN", logBuf);

        if (src == L"button") {
            lastDisplayFreedMB = freedMB;
            statusResultText = isEnLang ? (L"Freed " + sizeStr + L" RAM") : (L"Đã giải phóng " + sizeStr + L" RAM");
            SetTimer(hMainWnd, 2, 15000, nullptr);
        }

        const RamConfig& cfg = WcaoAppEnv::CurrentConfig;
        if (cfg.BalloonShowResult) {
            std::wstring toastLine1 = isEnLang
                ? (L"Freed " + sizeStr + L" RAM")
                : (L"Đã giải phóng " + sizeStr + L" RAM");
            wchar_t toastLine2[160];
            swprintf(toastLine2, 160,
                isEnLang ? L"Latency -%.1f ms • +%d-%d FPS depending on game"
                         : L"Giảm độ trễ ~%.1f ms • Tăng ~%d-%d FPS tùy game",
                latSavedMs, fpsMin, fpsMax);
            ShowTrayNotification(toastLine1, toastLine2, cfg.BalloonPlaySound);
        }

        const RamStatsSnapshot& st = Win32RamNative::GetCurrentRamStats(true);
        UpdateTrayIconAndTooltip(st);
        if (IsWindowVisible(hMainWnd)) {
            InvalidateRect(hMainWnd, nullptr, FALSE);
        } else {
            Win32RamNative::TrimSelfMemory();
        }
    }

    void OnUnifiedTimerTick() {
        const RamConfig& cfg = WcaoAppEnv::CurrentConfig;

        if (cfg.Theme == L"system") {
            bool curDark = (cfg.GetActiveThemeMode() == L"dark");
            if (curDark != isDarkTheme) {
                UpdateWindowTitleAndTheme();
            }
        }

        const RamStatsSnapshot& st = Win32RamNative::GetCurrentRamStats();
        UpdateTrayIconAndTooltip(st);
        Win32RamNative::BoostForegroundGameProcess(GetCurrentProcessId());

        if (IsWindowVisible(hMainWnd)) {
            if (selectedTab == 0) {
                InvalidateRect(hMainWnd, nullptr, FALSE);
            }
        } else {
            ULONGLONG now = GetTickCount64();
            if (now - lastSelfCompactTick >= 600000ULL) {
                lastSelfCompactTick = now;
                Win32RamNative::TrimSelfMemory();
            }
        }

        OnCleanCompleted();

        if (!Win32RamNative::IsCleaningInProgress) {
            ULONGLONG now = GetTickCount64();
            bool triggered = false;
            if (cfg.CleanWhenAboveEnabled && st.PhysLoad >= cfg.CleanWhenAbovePct) {
                if (lastAboveCleanTick == 0 || (now - lastAboveCleanTick) >= 180000ULL) {
                    lastAboveCleanTick = now;
                    triggered = true;
                    TriggerMemoryClean(L"threshold");
                }
            }
            if (!triggered && cfg.CleanEveryEnabled && cfg.CleanEveryMin > 0) {
                ULONGLONG intervalMs = (ULONGLONG)cfg.CleanEveryMin * 60000ULL;
                if (now - lastPeriodicCleanTick >= intervalMs) {
                    lastPeriodicCleanTick = now;
                    TriggerMemoryClean(L"periodic");
                }
            }
        }
    }

    // ------------------------------------------------------------------------
    //  MAIN WINDOW PROCEDURE
    // ------------------------------------------------------------------------
    static LRESULT CALLBACK MainWndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam) {
        WCaO_DashboardApp* app = (WCaO_DashboardApp*)GetWindowLongPtrW(hWnd, GWLP_USERDATA);
        if (msg == WM_NCCREATE) {
            CREATESTRUCTW* cs = (CREATESTRUCTW*)lParam;
            app = (WCaO_DashboardApp*)cs->lpCreateParams;
            app->hMainWnd = hWnd;
            SetWindowLongPtrW(hWnd, GWLP_USERDATA, (LONG_PTR)app);
            return TRUE;
        }
        if (!app) return DefWindowProcW(hWnd, msg, wParam, lParam);

        if (app->msgTaskbarCreated != 0 && msg == app->msgTaskbarCreated) {
            Shell_NotifyIconW(NIM_DELETE, &app->nid);
            Shell_NotifyIconW(NIM_ADD, &app->nid);
            app->UpdateTrayIconAndTooltip(Win32RamNative::GetCurrentRamStats(), true);
            return 0;
        }
        if (app->msgShowGui != 0 && msg == app->msgShowGui) {
            app->ShowDashboardWindow();
            return 0;
        }
        if (app->msgQuitApp != 0 && msg == app->msgQuitApp) {
            app->realExit = true;
            DestroyWindow(hWnd);
            return 0;
        }
        if (app->msgElevateAdmin != 0 && msg == app->msgElevateAdmin) {
            app->RelaunchAsAdmin(IsWindowVisible(hWnd) != FALSE);
            return 0;
        }

        switch (msg) {
        case WM_APP_TRAYMSG: {
            if (lParam == WM_LBUTTONDBLCLK) {
                app->ShowDashboardWindow();
            } else if (lParam == WM_RBUTTONUP || lParam == WM_CONTEXTMENU) {
                app->OnShowTrayContextMenu();
            }
            return 0;
        }
        case WM_APP_CLEAN_DONE: {
            app->OnCleanCompleted();
            return 0;
        }
        case WM_APP_ELEVATE_ADMIN: {
            app->RelaunchAsAdmin(IsWindowVisible(hWnd) != FALSE);
            return 0;
        }
        case WM_HOTKEY: {
            if (wParam == HOTKEY_ID_CLEAN) {
                app->TriggerMemoryClean(L"hotkey");
            }
            return 0;
        }
        case WM_TIMER: {
            if (wParam == 1) {
                app->OnUnifiedTimerTick();
            } else if (wParam == 2) {
                KillTimer(hWnd, 2);
                app->statusResultText.clear();
                app->lastDisplayFreedMB = -1.0;
                InvalidateRect(hWnd, nullptr, FALSE);
            } else if (wParam == 3) {
                if (GetTickCount64() >= app->cleanCooldownUntilTick) {
                    KillTimer(hWnd, 3);
                }
                if (IsWindowVisible(hWnd) && app->selectedTab == 0) {
                    InvalidateRect(hWnd, nullptr, FALSE);
                }
            } else if (wParam >= 101 && wParam <= 104) {
                KillTimer(hWnd, wParam);
                if (wParam == 101) app->btnViewResetFeedback.clear();
                if (wParam == 102) app->btnViewSaveFeedback.clear();
                if (wParam == 103) app->btnSetResetFeedback.clear();
                if (wParam == 104) app->btnSetSaveFeedback.clear();
                InvalidateRect(hWnd, nullptr, FALSE);
            }
            return 0;
        }
        case WM_SETTINGCHANGE:
        case WM_THEMECHANGED: {
            if (WcaoAppEnv::CurrentConfig.Theme == L"system") {
                bool curDark = (WcaoAppEnv::CurrentConfig.GetActiveThemeMode() == L"dark");
                if (curDark != app->isDarkTheme) {
                    app->UpdateWindowTitleAndTheme();
                }
            }
            break;
        }
        case WM_LBUTTONDOWN:
        case WM_LBUTTONDBLCLK: {
            app->OnMouseDown((short)LOWORD(lParam), (short)HIWORD(lParam));
            return 0;
        }
        case WM_MOUSEMOVE: {
            app->OnMouseMove((short)LOWORD(lParam), (short)HIWORD(lParam));
            TRACKMOUSEEVENT tme = { sizeof(tme), TME_LEAVE, hWnd, 0 };
            TrackMouseEvent(&tme);
            return 0;
        }
        case WM_MOUSELEAVE: {
            if (app->hoverTab != -1 || app->scrollBarHover || !app->hoverCtrlId.empty()) {
                app->hoverTab = -1;
                app->scrollBarHover = false;
                app->hoverCtrlId.clear();
                InvalidateRect(hWnd, nullptr, FALSE);
            }
            return 0;
        }
        case WM_LBUTTONUP: {
            if (app->scrollDrag) {
                app->scrollDrag = false;
                ReleaseCapture();
                InvalidateRect(hWnd, nullptr, FALSE);
            }
            return 0;
        }
        case WM_MOUSEWHEEL: {
            int delta = GET_WHEEL_DELTA_WPARAM(wParam);
            if (app->focusedNumIdx >= 0) {
                app->AdjustNumValue(app->focusedNumIdx, (delta > 0) ? +1 : -1);
                return 0;
            }
            if (app->selectedTab == 1 || app->selectedTab == 2) {
                int maxS = app->maxScroll[app->selectedTab];
                if (maxS > 0) {
                    app->scrollY[app->selectedTab] -= (delta > 0) ? 40 : -40;
                    app->scrollY[app->selectedTab] = (std::max)(0, (std::min)(maxS, app->scrollY[app->selectedTab]));
                    InvalidateRect(hWnd, nullptr, FALSE);
                }
            }
            return 0;
        }
        case WM_CHAR: {
            if (app->focusedNumIdx >= 0) {
                wchar_t ch = (wchar_t)wParam;
                if (ch >= L'0' && ch <= L'9') {
                    if (!app->numEditTyping) {
                        app->numEditBuffer.clear();
                        app->numEditTyping = true;
                    }
                    if (app->numEditBuffer.size() < 3) {
                        app->numEditBuffer.push_back(ch);
                        InvalidateRect(hWnd, nullptr, FALSE);
                    }
                } else if (ch == L'\b') {
                    app->numEditTyping = true;
                    if (!app->numEditBuffer.empty()) {
                        app->numEditBuffer.pop_back();
                    }
                    InvalidateRect(hWnd, nullptr, FALSE);
                } else if (ch == L'\r') {
                    app->CommitFocusedNumEdit();
                }
            }
            return 0;
        }
        case WM_KEYDOWN: {
            if (wParam == VK_ESCAPE && app->focusedNumIdx >= 0) {
                app->focusedNumIdx = -1;
                app->numEditTyping = false;
                app->numEditBuffer.clear();
                InvalidateRect(hWnd, nullptr, FALSE);
            }
            return 0;
        }
        case WM_ERASEBKGND:
            return 1;
        case WM_PAINT: {
            PAINTSTRUCT ps;
            HDC hdc = BeginPaint(hWnd, &ps);
            RECT rc; GetClientRect(hWnd, &rc);
            app->RenderDashboard(hdc, rc.right - rc.left, rc.bottom - rc.top);
            EndPaint(hWnd, &ps);
            return 0;
        }
        case WM_QUERYENDSESSION:
        case WM_ENDSESSION: {
            app->realExit = true;
            return TRUE;
        }
        case WM_CLOSE: {
            if (!app->realExit) {
                app->HideToTray();
                return 0;
            }
            DestroyWindow(hWnd);
            return 0;
        }
        case WM_DESTROY: {
            UnregisterHotKey(hWnd, HOTKEY_ID_CLEAN);
            Shell_NotifyIconW(NIM_DELETE, &app->nid);
            if (app->hCurrentTrayIcon) {
                DestroyIcon(app->hCurrentTrayIcon);
                app->hCurrentTrayIcon = nullptr;
            }
            app->FreeBackBuffer();
            PostQuitMessage(0);
            return 0;
        }
        }
        return DefWindowProcW(hWnd, msg, wParam, lParam);
    }

    int Run(HINSTANCE hInstance, bool startInTrayMode, bool notifyElevatedToast, ULONGLONG bootStartTick) {
        DetectFontFamily();
        SyncStagedFromSaved();

        msgTaskbarCreated = RegisterWindowMessageW(L"TaskbarCreated");
        msgShowGui        = RegisterWindowMessageW(L"WCaO_RAM_ShowGUI");
        msgQuitApp        = RegisterWindowMessageW(L"WCaO_RAM_Quit");
        msgElevateAdmin   = RegisterWindowMessageW(L"WCaO_RAM_ElevateAdmin");

        hAppIconBig   = (HICON)LoadImageW(hInstance, MAKEINTRESOURCEW(IDI_APPICON), IMAGE_ICON, 32, 32, LR_DEFAULTCOLOR);
        hAppIconSmall = (HICON)LoadImageW(hInstance, MAKEINTRESOURCEW(IDI_APPICON), IMAGE_ICON, 16, 16, LR_DEFAULTCOLOR);

        WNDCLASSEXW wc = { sizeof(wc) };
        wc.style         = CS_HREDRAW | CS_VREDRAW;
        wc.lpfnWndProc   = MainWndProc;
        wc.hInstance     = hInstance;
        wc.hIcon         = hAppIconBig;
        wc.hIconSm       = hAppIconSmall;
        wc.hCursor       = LoadCursorW(nullptr, IDC_ARROW);
        wc.lpszClassName = L"WCaO_RAM_MainWndCls";
        RegisterClassExW(&wc);

        DWORD style = WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX;
        RECT winRc = { 0, 0, 399, 416 };
        AdjustWindowRectEx(&winRc, style, FALSE, 0);
        int winW = winRc.right - winRc.left;
        int winH = winRc.bottom - winRc.top;

        int scrW = GetSystemMetrics(SM_CXSCREEN);
        int scrH = GetSystemMetrics(SM_CYSCREEN);
        int posX = (std::max)(0, (scrW - winW) / 2);
        int posY = (std::max)(0, (scrH - winH) / 2);

        hMainWnd = CreateWindowExW(
            0, L"WCaO_RAM_MainWndCls", L"WCaO RAM Manager",
            style, posX, posY, winW, winH,
            nullptr, nullptr, hInstance, this
        );
        if (!hMainWnd) return 1;

        Win32RamNative::NotifyHwnd = hMainWnd;
        WcaoAppEnv::SetWindowAppId(hMainWnd, L"WCaO.RAM.Manager");

        if (msgShowGui)        ChangeWindowMessageFilterEx(hMainWnd, msgShowGui, MSGFLT_ALLOW, nullptr);
        if (msgQuitApp)        ChangeWindowMessageFilterEx(hMainWnd, msgQuitApp, MSGFLT_ALLOW, nullptr);
        if (msgElevateAdmin)   ChangeWindowMessageFilterEx(hMainWnd, msgElevateAdmin, MSGFLT_ALLOW, nullptr);
        if (msgTaskbarCreated) ChangeWindowMessageFilterEx(hMainWnd, msgTaskbarCreated, MSGFLT_ALLOW, nullptr);
        ChangeWindowMessageFilterEx(hMainWnd, WM_SETTINGCHANGE, MSGFLT_ALLOW, nullptr);
        ChangeWindowMessageFilterEx(hMainWnd, WM_THEMECHANGED, MSGFLT_ALLOW, nullptr);

        nid.cbSize = sizeof(nid);
        nid.hWnd = hMainWnd;
        nid.uID = 1;
        nid.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
        nid.uCallbackMessage = WM_APP_TRAYMSG;
        const RamStatsSnapshot& stInit = Win32RamNative::GetCurrentRamStats(true);
        hCurrentTrayIcon = DynamicTrayIconRenderer::CreateTrayHIcon(stInit.PhysLoad, WcaoAppEnv::CurrentConfig);
        nid.hIcon = hCurrentTrayIcon;
        lastTrayIconRam = stInit.PhysLoad;
        Shell_NotifyIconW(NIM_ADD, &nid);
        UpdateTrayIconAndTooltip(stInit, false);

        UpdateWindowTitleAndTheme();
        RegisterGlobalHotkey();

        lastPeriodicCleanTick = GetTickCount64();
        lastSelfCompactTick   = GetTickCount64();

        if (WcaoAppEnv::ConfigHadError && !WcaoAppEnv::ConfigReadFailed) {
            ShowTrayNotification(isEnLang
                ? L"Configuration file contained invalid values and was automatically restored to defaults."
                : L"Tập tin cấu hình có giá trị lỗi và đã được tự động khôi phục về mặc định.");
        } else if (notifyElevatedToast && WcaoAppEnv::IsAdmin) {
            ShowTrayNotification(
                isEnLang ? L"Switched to Administrator Mode" : L"Đã chuyển sang quyền Quản trị viên",
                isEnLang ? L"Full deep kernel memory cleaning is now active." : L"Đã kích hoạt dọn dẹp sâu toàn bộ vùng nhớ nhân.",
                WcaoAppEnv::CurrentConfig.BalloonPlaySound
            );
        }

        if (!startInTrayMode) {
            ShowWindow(hMainWnd, SW_SHOW);
            UpdateWindow(hMainWnd);
            SetTimer(hMainWnd, 1, 1000, nullptr);
        } else {
            SetTimer(hMainWnd, 1, 2000, nullptr);
            Win32RamNative::TrimSelfMemory();
        }

        ULONGLONG totalBootMs = GetTickCount64() - bootStartTick;
        wchar_t perfMsg[128];
        swprintf(perfMsg, 128, L"=== %s: %llu ms ===",
            isEnLang ? L"TOTAL NATIVE C++ STARTUP TIME" : L"TỔNG THỜI GIAN KHỞI ĐỘNG C++", totalBootMs);
        WcaoAppEnv::WriteLog(L"PERF", perfMsg);

        MSG msg;
        while (GetMessageW(&msg, nullptr, 0, 0)) {
            TranslateMessage(&msg);
            DispatchMessageW(&msg);
        }

        if (hAppIconBig)   DestroyIcon(hAppIconBig);
        if (hAppIconSmall) DestroyIcon(hAppIconSmall);
        return (int)msg.wParam;
    }
};

// ============================================================================
//  2. APPLICATION ENTRY POINT, PROTOCOL HANDLER & SINGLE-INSTANCE GUARD
// ============================================================================
int WINAPI wWinMain(HINSTANCE hInstance, HINSTANCE, LPWSTR lpCmdLine, int) {
    ULONGLONG bootStartTick = GetTickCount64();

    std::wstring cmdLine = lpCmdLine ? lpCmdLine : L"";
    bool isProtoAdmin    = (cmdLine.find(L"wcaoram:admin") != std::wstring::npos || cmdLine.find(L"-elevate_admin") != std::wstring::npos);
    bool isProtoOpen     = (cmdLine.find(L"wcaoram:open")  != std::wstring::npos);
    bool isElevatedToast = (cmdLine.find(L"-elevated_toast") != std::wstring::npos);
    bool isGuiDirect     = (cmdLine.find(L"-gui_direct")  != std::wstring::npos) || isProtoOpen;
    bool isTrayDirect    = (cmdLine.find(L"-tray_direct") != std::wstring::npos);
    bool isTrayMode      = isTrayDirect || (cmdLine.find(L"-tray") != std::wstring::npos);

    SECURITY_DESCRIPTOR sd = {};
    InitializeSecurityDescriptor(&sd, SECURITY_DESCRIPTOR_REVISION);
    SetSecurityDescriptorDacl(&sd, TRUE, nullptr, FALSE);
    SECURITY_ATTRIBUTES sa = { sizeof(sa), &sd, FALSE };

    HANDLE hMutexGlobal = CreateMutexW(&sa, TRUE, L"Global\\WCaO_RAM_Tray_Mutex");
    DWORD errGlobal = GetLastError();
    HANDLE hMutexLocal  = CreateMutexW(&sa, TRUE, L"WCaO_RAM_Tray_Mutex");
    DWORD errLocal = GetLastError();
    HANDLE hMutexLegacy = CreateMutexW(&sa, TRUE, L"WCaO_RAM_Single_Mutex");

    bool alreadyRunning = (errGlobal == ERROR_ALREADY_EXISTS || errGlobal == ERROR_ACCESS_DENIED ||
                           errLocal == ERROR_ALREADY_EXISTS  || errLocal == ERROR_ACCESS_DENIED);

    if (alreadyRunning) {
        if (isProtoAdmin) {
            UINT msgElev = RegisterWindowMessageW(L"WCaO_RAM_ElevateAdmin");
            if (msgElev != 0) {
                PostMessageW(HWND_BROADCAST, msgElev, 0, 0);
            }
        } else if (!isTrayMode) {
            UINT msgShow = RegisterWindowMessageW(L"WCaO_RAM_ShowGUI");
            if (msgShow != 0) {
                PostMessageW(HWND_BROADCAST, msgShow, 0, 0);
            }
        }
        if (hMutexGlobal) CloseHandle(hMutexGlobal);
        if (hMutexLocal)  CloseHandle(hMutexLocal);
        if (hMutexLegacy) CloseHandle(hMutexLegacy);
        return 0;
    }

    if ((!isGuiDirect && !isTrayMode && !Win32RamNative::IsProcessElevated()) || (isProtoAdmin && !Win32RamNative::IsProcessElevated())) {
        if (hMutexGlobal) { ReleaseMutex(hMutexGlobal); CloseHandle(hMutexGlobal); }
        if (hMutexLocal)  { ReleaseMutex(hMutexLocal);  CloseHandle(hMutexLocal); }
        if (hMutexLegacy) { ReleaseMutex(hMutexLegacy); CloseHandle(hMutexLegacy); }

        wchar_t exePath[MAX_PATH] = {};
        GetModuleFileNameW(nullptr, exePath, MAX_PATH);

        SHELLEXECUTEINFOW sei = { sizeof(sei) };
        sei.lpVerb = L"runas";
        sei.lpFile = exePath;
        sei.lpParameters = isProtoAdmin ? L"-tray_direct -elevated_toast" : L"-gui_direct";
        sei.nShow = isProtoAdmin ? SW_HIDE : SW_SHOWNORMAL;
        if (!ShellExecuteExW(&sei) && !isProtoAdmin) {
            sei.lpVerb = L"open";
            ShellExecuteExW(&sei);
        }
        return 0;
    }

    CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

    Gdiplus::GdiplusStartupInput gdipInput;
    ULONG_PTR gdipToken = 0;
    Gdiplus::GdiplusStartup(&gdipToken, &gdipInput, nullptr);

    Win32RamNative::InitNtApi();
    WcaoAppEnv::InitPaths();
    if (WcaoAppEnv::IsAdmin) {
        Win32RamNative::EscalateAllMemoryPrivileges();
    }

    WcaoAppEnv::CurrentConfig = WcaoAppEnv::LoadRamConfig();
    WcaoAppEnv::EnsureAppShortcutAndAppId();
    WcaoAppEnv::UpdateLinkRegistry();

    bool isEn = (WcaoAppEnv::CurrentConfig.Language == L"en");
    wchar_t sessionLine[128];
    if (isEn) {
        swprintf(sessionLine, 128, L"Session initialized (C++ Native) - Elevated: %s - Mode: %s",
            WcaoAppEnv::IsAdmin ? L"True" : L"False", isTrayMode ? L"TRAY" : L"GUI");
    } else {
        swprintf(sessionLine, 128, L"Khởi tạo phiên (C++ gốc) - Quản trị viên: %s - Chế độ: %s",
            WcaoAppEnv::IsAdmin ? L"Có" : L"Không", isTrayMode ? L"Khay hệ thống" : L"Giao diện");
    }
    WcaoAppEnv::WriteLog(L"INFO", sessionLine);

    int exitCode = 0;
    {
        WCaO_DashboardApp app;
        app.pMutexGlobal = &hMutexGlobal;
        app.pMutexLocal  = &hMutexLocal;
        app.pMutexLegacy = &hMutexLegacy;
        exitCode = app.Run(hInstance, isTrayMode, isElevatedToast, bootStartTick);
    }

    Gdiplus::GdiplusShutdown(gdipToken);
    CoUninitialize();

    if (hMutexGlobal) { ReleaseMutex(hMutexGlobal); CloseHandle(hMutexGlobal); }
    if (hMutexLocal)  { ReleaseMutex(hMutexLocal);  CloseHandle(hMutexLocal); }
    if (hMutexLegacy) { ReleaseMutex(hMutexLegacy); CloseHandle(hMutexLegacy); }
    return exitCode;
}
