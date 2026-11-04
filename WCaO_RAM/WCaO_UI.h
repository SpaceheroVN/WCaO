#pragma once
#include "WCaO_Core.h"

// ============================================================================
//  1. GDI+ GEOMETRY, THEME HELPERS & DYNAMIC TRAY ICON RENDERER
// ============================================================================
inline void AddRoundedPath(Gdiplus::GraphicsPath& path, Gdiplus::RectF r, float radius) {
    float d = radius * 2.0f;
    if (d > r.Width)  d = r.Width;
    if (d > r.Height) d = r.Height;
    if (d <= 0.1f) {
        path.AddRectangle(r);
        return;
    }
    path.AddArc(r.X, r.Y, d, d, 180.0f, 90.0f);
    path.AddArc(r.GetRight() - d, r.Y, d, d, 270.0f, 90.0f);
    path.AddArc(r.GetRight() - d, r.GetBottom() - d, d, d, 0.0f, 90.0f);
    path.AddArc(r.X, r.GetBottom() - d, d, d, 90.0f, 90.0f);
    path.CloseFigure();
}

inline COLORREF GetAdaptiveLabelColor(COLORREF c, bool isDark) {
    double r = GetRValue(c), g = GetGValue(c), b = GetBValue(c);
    double lum = 0.299 * r + 0.587 * g + 0.114 * b;
    if (!isDark) {
        if (lum > 135.0) {
            double factor = 135.0 / (std::max)(1.0, lum);
            return RGB((int)(r * factor), (int)(g * factor), (int)(b * factor));
        }
    } else {
        if (lum < 90.0) {
            double factor = 90.0 / (std::max)(1.0, lum);
            return RGB((std::min)(255, (int)(r * factor + 30)),
                       (std::min)(255, (int)(g * factor + 30)),
                       (std::min)(255, (int)(b * factor + 30)));
        }
    }
    return c;
}

inline COLORREF GetContrastForeColor(COLORREF c) {
    double lum = GetRValue(c) * 0.299 + GetGValue(c) * 0.587 + GetBValue(c) * 0.114;
    return (lum > 150.0) ? RGB(0, 0, 0) : RGB(255, 255, 255);
}

inline void ApplyDwmWindowTheme(HWND hWnd, bool isDark, bool roundCorners = true) {
    if (!hWnd || !IsWindow(hWnd)) return;
    BOOL darkVal = isDark ? TRUE : FALSE;
    DwmSetWindowAttribute(hWnd, 19, &darkVal, sizeof(darkVal));
    DwmSetWindowAttribute(hWnd, 20, &darkVal, sizeof(darkVal));
    if (roundCorners) {
        DWORD pref = 2; // DWMWCP_ROUND
        DwmSetWindowAttribute(hWnd, 33, &pref, sizeof(pref));
    }
    COLORREF capCol  = isDark ? RGB(33, 34, 38)    : RGB(237, 241, 247);
    COLORREF capText = isDark ? RGB(240, 242, 245) : RGB(30, 41, 59);
    DwmSetWindowAttribute(hWnd, 35, &capCol, sizeof(capCol));
    DwmSetWindowAttribute(hWnd, 36, &capText, sizeof(capText));
}

class DynamicTrayIconRenderer {
public:
    static void RenderIconGraphics(Gdiplus::Graphics& g, int size, int ramPercent, const RamConfig& cfg) {
        g.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
        g.SetPixelOffsetMode(Gdiplus::PixelOffsetModeHighQuality);

        COLORREF colDef  = ParseHexColor(cfg.TrayBgDefault, RGB(16, 185, 129));
        COLORREF colWarn = ParseHexColor(cfg.TrayBgWarning, RGB(234, 88, 12));
        COLORREF colDang = ParseHexColor(cfg.TrayBgDanger,  RGB(220, 38, 38));

        int transPct = (cfg.TrayTransparentBelowPct <= 0) ? 60 : cfg.TrayTransparentBelowPct;
        bool isTrans = (cfg.TrayTransparentBelow60 && ramPercent < transPct);

        COLORREF bgColRef = (ramPercent >= cfg.DangerLevel) ? colDang :
                            (ramPercent >= cfg.WarningLevel) ? colWarn : colDef;
        Gdiplus::Color bgColor = ColorRefToGdip(bgColRef);

        float scale = (float)size / 16.0f;

        if (!isTrans) {
            Gdiplus::SolidBrush bgBrush(bgColor);
            if (cfg.TrayRoundedBorder) {
                float pad = 0.5f * scale;
                float w = (float)size - (1.0f * scale);
                Gdiplus::RectF r(pad, pad, w, w);
                float rad = 3.25f * scale;
                Gdiplus::GraphicsPath path;
                AddRoundedPath(path, r, rad);
                g.FillPath(&bgBrush, &path);
                if (cfg.TrayShowBorder) {
                    float bWidth = (size > 16) ? 2.0f : 1.0f;
                    Gdiplus::Pen pen(Gdiplus::Color(220, 255, 255, 255), bWidth);
                    g.DrawPath(&pen, &path);
                }
            } else {
                g.FillRectangle(&bgBrush, 0, 0, size, size);
                if (cfg.TrayShowBorder) {
                    float bWidth = (size > 16) ? 2.0f : 1.0f;
                    float half = bWidth / 2.0f;
                    Gdiplus::Pen pen(Gdiplus::Color(220, 255, 255, 255), bWidth);
                    g.DrawRectangle(&pen, half, half, (float)size - bWidth, (float)size - bWidth);
                }
            }
        } else {
            if (size > 16) {
                Gdiplus::Pen dashPen(Gdiplus::Color(80, 128, 128, 128), 1.0f);
                dashPen.SetDashStyle(Gdiplus::DashStyleDash);
                g.DrawRectangle(&dashPen, 0, 0, size - 1, size - 1);
            }
        }

        COLORREF textColRef = isTrans ? bgColRef : ParseHexColor(cfg.TrayTextColorCustom, RGB(255, 255, 255));
        Gdiplus::SolidBrush textBrush(ColorRefToGdip(textColRef));

        INT fStyle = Gdiplus::FontStyleBold;
        if (cfg.TrayFontStyle == L"Regular") fStyle = Gdiplus::FontStyleRegular;
        else if (cfg.TrayFontStyle == L"Italic") fStyle = Gdiplus::FontStyleItalic;

        float fSize = (cfg.TrayFontSize <= 0) ? 7.0f : (float)cfg.TrayFontSize;
        if (ramPercent >= 100) fSize = (std::max)(4.5f, fSize * 0.68f);

        Gdiplus::Font font(cfg.TrayFontFamily.c_str(), fSize * scale, fStyle, Gdiplus::UnitPoint);
        g.SetTextRenderingHint((size > 16) ? Gdiplus::TextRenderingHintAntiAliasGridFit : Gdiplus::TextRenderingHintSingleBitPerPixelGridFit);

        const Gdiplus::StringFormat* genericTypo = Gdiplus::StringFormat::GenericTypographic();
        Gdiplus::StringFormat sf(genericTypo);
        sf.SetAlignment(Gdiplus::StringAlignmentCenter);
        sf.SetLineAlignment(Gdiplus::StringAlignmentCenter);
        sf.SetFormatFlags(sf.GetFormatFlags() | Gdiplus::StringFormatFlagsNoWrap);

        float yOff = (size > 16) ? (-0.5f * scale) : 0.5f;
        Gdiplus::RectF rect(0.0f, yOff, (float)size, (float)size);
        wchar_t numStr[16];
        swprintf(numStr, 16, L"%d", ramPercent);
        g.DrawString(numStr, -1, &font, rect, &sf, &textBrush);
    }

    static HICON CreateTrayHIcon(int ramPercent, const RamConfig& cfg) {
        Gdiplus::Bitmap bmp(16, 16, PixelFormat32bppARGB);
        {
            Gdiplus::Graphics g(&bmp);
            g.Clear(Gdiplus::Color(0, 0, 0, 0));
            RenderIconGraphics(g, 16, ramPercent, cfg);
        }
        HICON hIcon = nullptr;
        bmp.GetHICON(&hIcon);
        return hIcon;
    }
};

// ============================================================================
//  2. CUSTOM DROPDOWN COMBOBOX POPUP
// ============================================================================
class ModernComboPopup {
    struct State {
        std::vector<std::wstring> items;
        int selectedIndex = -1;
        int hoverIndex = -1;
        bool isDark = true;
        int itemHeight = 25;
        bool closed = false;
        int chosenIndex = -1;
        std::wstring fontName = L"Segoe UI";
    };

    static LRESULT CALLBACK WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam) {
        State* st = (State*)GetWindowLongPtrW(hWnd, GWLP_USERDATA);
        switch (msg) {
        case WM_NCCREATE: {
            CREATESTRUCTW* cs = (CREATESTRUCTW*)lParam;
            SetWindowLongPtrW(hWnd, GWLP_USERDATA, (LONG_PTR)cs->lpCreateParams);
            return TRUE;
        }
        case WM_MOUSEMOVE: {
            if (!st) break;
            POINT pt = { (short)LOWORD(lParam), (short)HIWORD(lParam) };
            RECT rc; GetClientRect(hWnd, &rc);
            int idx = -1;
            if (PtInRect(&rc, pt)) {
                idx = pt.y / st->itemHeight;
                if (idx < 0 || idx >= (int)st->items.size()) idx = -1;
            }
            if (idx != st->hoverIndex) {
                st->hoverIndex = idx;
                InvalidateRect(hWnd, nullptr, FALSE);
            }
            TRACKMOUSEEVENT tme = { sizeof(tme), TME_LEAVE, hWnd, 0 };
            TrackMouseEvent(&tme);
            return 0;
        }
        case WM_MOUSELEAVE: {
            if (st && st->hoverIndex != -1) {
                st->hoverIndex = -1;
                InvalidateRect(hWnd, nullptr, FALSE);
            }
            return 0;
        }
        case WM_LBUTTONDOWN: {
            if (!st) break;
            POINT pt = { (short)LOWORD(lParam), (short)HIWORD(lParam) };
            int idx = pt.y / st->itemHeight;
            if (idx >= 0 && idx < (int)st->items.size()) {
                st->chosenIndex = idx;
            }
            st->closed = true;
            return 0;
        }
        case WM_KEYDOWN: {
            if (wParam == VK_ESCAPE && st) {
                st->closed = true;
            }
            return 0;
        }
        case WM_ACTIVATE: {
            if (LOWORD(wParam) == WA_INACTIVE && st) {
                st->closed = true;
            }
            return 0;
        }
        case WM_PAINT: {
            PAINTSTRUCT ps;
            HDC hdc = BeginPaint(hWnd, &ps);
            if (st) {
                RECT rc; GetClientRect(hWnd, &rc);
                int w = rc.right - rc.left;
                int h = rc.bottom - rc.top;
                HDC memDC = CreateCompatibleDC(hdc);
                HBITMAP memBmp = CreateCompatibleBitmap(hdc, w, h);
                HGDIOBJ oldBmp = SelectObject(memDC, memBmp);

                Gdiplus::Graphics g(memDC);
                g.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
                g.SetTextRenderingHint(Gdiplus::TextRenderingHintClearTypeGridFit);

                Gdiplus::Color bgCol = st->isDark ? Gdiplus::Color(28, 30, 36) : Gdiplus::Color(255, 255, 255);
                Gdiplus::Color fgCol = st->isDark ? Gdiplus::Color(240, 242, 245) : Gdiplus::Color(30, 41, 59);
                Gdiplus::Color hovCol = st->isDark ? Gdiplus::Color(0, 122, 204) : Gdiplus::Color(2, 132, 199);
                Gdiplus::Color borderCol = st->isDark ? Gdiplus::Color(60, 65, 75) : Gdiplus::Color(203, 213, 225);

                Gdiplus::SolidBrush bgBrush(bgCol);
                g.FillRectangle(&bgBrush, 0, 0, w, h);

                Gdiplus::Font font(st->fontName.c_str(), 9.0f, Gdiplus::FontStyleRegular, Gdiplus::UnitPoint);
                Gdiplus::StringFormat sf;
                sf.SetLineAlignment(Gdiplus::StringAlignmentCenter);
                sf.SetAlignment(Gdiplus::StringAlignmentNear);
                sf.SetFormatFlags(Gdiplus::StringFormatFlagsNoWrap);

                for (size_t i = 0; i < st->items.size(); ++i) {
                    float iy = (float)(i * st->itemHeight);
                    bool isHov = ((int)i == st->hoverIndex);
                    if (isHov) {
                        Gdiplus::RectF pill(3.0f, iy + 1.5f, (float)w - 6.0f, (float)st->itemHeight - 3.0f);
                        Gdiplus::GraphicsPath path;
                        AddRoundedPath(path, pill, 4.0f);
                        Gdiplus::SolidBrush hb(hovCol);
                        g.FillPath(&hb, &path);
                    }
                    Gdiplus::SolidBrush tb(isHov ? Gdiplus::Color(255, 255, 255) : fgCol);
                    Gdiplus::RectF tr(10.0f, iy, (float)w - 14.0f, (float)st->itemHeight);
                    g.DrawString(st->items[i].c_str(), -1, &font, tr, &sf, &tb);
                }

                Gdiplus::Pen bp(borderCol, 1.0f);
                g.DrawRectangle(&bp, 0, 0, w - 1, h - 1);

                BitBlt(hdc, 0, 0, w, h, memDC, 0, 0, SRCCOPY);
                SelectObject(memDC, oldBmp);
                DeleteObject(memBmp);
                DeleteDC(memDC);
            }
            EndPaint(hWnd, &ps);
            return 0;
        }
        }
        return DefWindowProcW(hWnd, msg, wParam, lParam);
    }

public:
    static int Show(HWND owner, RECT anchorScreenRect, const std::vector<std::wstring>& items, int curIdx, bool isDark, const std::wstring& fontName) {
        static bool registered = false;
        if (!registered) {
            WNDCLASSEXW wc = { sizeof(wc) };
            wc.lpfnWndProc = WndProc;
            wc.hInstance = GetModuleHandleW(nullptr);
            wc.hCursor = LoadCursorW(nullptr, IDC_ARROW);
            wc.lpszClassName = L"WCaO_ComboPopupCls";
            RegisterClassExW(&wc);
            registered = true;
        }

        State st;
        st.items = items;
        st.selectedIndex = curIdx;
        st.hoverIndex = curIdx;
        st.isDark = isDark;
        st.fontName = fontName;

        int w = anchorScreenRect.right - anchorScreenRect.left;
        int h = (int)items.size() * st.itemHeight + 2;
        int x = anchorScreenRect.left;
        int y = anchorScreenRect.bottom;

        HWND hPopup = CreateWindowExW(
            WS_EX_TOPMOST | WS_EX_TOOLWINDOW,
            L"WCaO_ComboPopupCls", L"",
            WS_POPUP,
            x, y, w, h,
            owner, nullptr, GetModuleHandleW(nullptr), &st
        );
        if (!hPopup) return -1;

        ShowWindow(hPopup, SW_SHOW);
        SetForegroundWindow(hPopup);

        MSG msg;
        while (!st.closed && GetMessageW(&msg, nullptr, 0, 0)) {
            if (msg.message == WM_QUIT) {
                PostQuitMessage((int)msg.wParam);
                break;
            }
            TranslateMessage(&msg);
            DispatchMessageW(&msg);
        }
        DestroyWindow(hPopup);
        return st.chosenIndex;
    }
};

// ============================================================================
//  3. THEMED TRAY CONTEXT MENU POPUP
// ============================================================================
class ModernTrayMenuPopup {
    struct State {
        bool isDark = true;
        bool isEn = false;
        bool autostartChecked = false;
        int hoverIdx = -1;
        int chosenAction = 0; // 1=Clean, 2=Dashboard, 3=Autostart, 4=Exit
        bool closed = false;
        std::wstring fontName = L"Segoe UI";
    };

    static int HitTestItem(int y) {
        if (y >= 4 && y < 32)   return 0;
        if (y >= 39 && y < 67)  return 1;
        if (y >= 67 && y < 95)  return 2;
        if (y >= 102 && y < 130) return 3;
        return -1;
    }

    static LRESULT CALLBACK WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam) {
        State* st = (State*)GetWindowLongPtrW(hWnd, GWLP_USERDATA);
        switch (msg) {
        case WM_NCCREATE: {
            CREATESTRUCTW* cs = (CREATESTRUCTW*)lParam;
            SetWindowLongPtrW(hWnd, GWLP_USERDATA, (LONG_PTR)cs->lpCreateParams);
            return TRUE;
        }
        case WM_MOUSEMOVE: {
            if (!st) break;
            POINT pt = { (short)LOWORD(lParam), (short)HIWORD(lParam) };
            RECT rc; GetClientRect(hWnd, &rc);
            int idx = PtInRect(&rc, pt) ? HitTestItem(pt.y) : -1;
            if (idx != st->hoverIdx) {
                st->hoverIdx = idx;
                InvalidateRect(hWnd, nullptr, FALSE);
            }
            TRACKMOUSEEVENT tme = { sizeof(tme), TME_LEAVE, hWnd, 0 };
            TrackMouseEvent(&tme);
            return 0;
        }
        case WM_MOUSELEAVE: {
            if (st && st->hoverIdx != -1) {
                st->hoverIdx = -1;
                InvalidateRect(hWnd, nullptr, FALSE);
            }
            return 0;
        }
        case WM_LBUTTONUP:
        case WM_LBUTTONDOWN: {
            if (!st) break;
            POINT pt = { (short)LOWORD(lParam), (short)HIWORD(lParam) };
            int idx = HitTestItem(pt.y);
            if (idx >= 0) {
                st->chosenAction = idx + 1;
                st->closed = true;
            }
            return 0;
        }
        case WM_KEYDOWN: {
            if (wParam == VK_ESCAPE && st) st->closed = true;
            return 0;
        }
        case WM_ACTIVATE: {
            if (LOWORD(wParam) == WA_INACTIVE && st) st->closed = true;
            return 0;
        }
        case WM_PAINT: {
            PAINTSTRUCT ps;
            HDC hdc = BeginPaint(hWnd, &ps);
            if (st) {
                RECT rc; GetClientRect(hWnd, &rc);
                int w = rc.right - rc.left;
                int h = rc.bottom - rc.top;

                HDC memDC = CreateCompatibleDC(hdc);
                HBITMAP memBmp = CreateCompatibleBitmap(hdc, w, h);
                HGDIOBJ oldBmp = SelectObject(memDC, memBmp);

                Gdiplus::Graphics g(memDC);
                g.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
                g.SetTextRenderingHint(Gdiplus::TextRenderingHintClearTypeGridFit);

                Gdiplus::Color cBack = st->isDark ? Gdiplus::Color(32, 32, 32) : Gdiplus::Color(255, 255, 255);
                Gdiplus::Color cBorder = st->isDark ? Gdiplus::Color(62, 62, 62) : Gdiplus::Color(208, 208, 208);
                Gdiplus::Color cSel = st->isDark ? Gdiplus::Color(52, 52, 52) : Gdiplus::Color(240, 243, 246);
                Gdiplus::Color cText = st->isDark ? Gdiplus::Color(235, 235, 235) : Gdiplus::Color(25, 25, 25);

                Gdiplus::SolidBrush bgBrush(cBack);
                g.FillRectangle(&bgBrush, 0, 0, w, h);

                const wchar_t* labels[4] = {
                    st->isEn ? L"Clean memory..."    : L"Dọn dẹp bộ nhớ...",
                    st->isEn ? L"Dashboard"          : L"Bảng điều khiển",
                    st->isEn ? L"Start with Windows" : L"Khởi động cùng Windows",
                    st->isEn ? L"Exit"               : L"Thoát"
                };
                int itemTops[4] = { 4, 39, 67, 102 };

                Gdiplus::Font font(st->fontName.c_str(), 8.75f, Gdiplus::FontStyleRegular, Gdiplus::UnitPoint);
                Gdiplus::StringFormat sf;
                sf.SetLineAlignment(Gdiplus::StringAlignmentCenter);
                sf.SetAlignment(Gdiplus::StringAlignmentNear);
                sf.SetFormatFlags(Gdiplus::StringFormatFlagsNoWrap);

                Gdiplus::SolidBrush textBrush(cText);
                Gdiplus::SolidBrush selBrush(cSel);

                for (int i = 0; i < 4; ++i) {
                    if (st->hoverIdx == i) {
                        Gdiplus::RectF rSel(4.0f, (float)itemTops[i], (float)w - 8.0f, 28.0f);
                        Gdiplus::GraphicsPath pSel;
                        AddRoundedPath(pSel, rSel, 4.0f);
                        g.FillPath(&selBrush, &pSel);
                    }
                    Gdiplus::RectF rTxt(32.0f, (float)itemTops[i], (float)w - 40.0f, 28.0f);
                    g.DrawString(labels[i], -1, &font, rTxt, &sf, &textBrush);
                }

                // Emerald check for item 2 (Start with Windows)
                if (st->autostartChecked) {
                    Gdiplus::Pen checkPen(Gdiplus::Color(16, 185, 129), 2.0f);
                    checkPen.SetStartCap(Gdiplus::LineCapRound);
                    checkPen.SetEndCap(Gdiplus::LineCapRound);
                    int cx = 18;
                    int cy = itemTops[2] + 14;
                    g.DrawLine(&checkPen, cx - 4, cy, cx - 1, cy + 3);
                    g.DrawLine(&checkPen, cx - 1, cy + 3, cx + 4, cy - 3);
                }

                // Separators
                Gdiplus::Pen sepPen(cBorder, 1.0f);
                g.DrawLine(&sepPen, 8, 35, w - 8, 35);
                g.DrawLine(&sepPen, 8, 98, w - 8, 98);

                // Rounded Border
                Gdiplus::GraphicsPath borderPath;
                AddRoundedPath(borderPath, Gdiplus::RectF(0.5f, 0.5f, (float)w - 1.0f, (float)h - 1.0f), 7.0f);
                Gdiplus::Pen borderPen(cBorder, 1.0f);
                g.DrawPath(&borderPen, &borderPath);

                BitBlt(hdc, 0, 0, w, h, memDC, 0, 0, SRCCOPY);
                SelectObject(memDC, oldBmp);
                DeleteObject(memBmp);
                DeleteDC(memDC);
            }
            EndPaint(hWnd, &ps);
            return 0;
        }
        }
        return DefWindowProcW(hWnd, msg, wParam, lParam);
    }

public:
    static int Show(HWND owner, bool isDark, bool isEn, bool autostartChecked, const std::wstring& fontName) {
        static bool registered = false;
        if (!registered) {
            WNDCLASSEXW wc = { sizeof(wc) };
            wc.lpfnWndProc = WndProc;
            wc.hInstance = GetModuleHandleW(nullptr);
            wc.hCursor = LoadCursorW(nullptr, IDC_ARROW);
            wc.lpszClassName = L"WCaO_TrayMenuCls";
            RegisterClassExW(&wc);
            registered = true;
        }

        State st;
        st.isDark = isDark;
        st.isEn = isEn;
        st.autostartChecked = autostartChecked;
        st.fontName = fontName;

        int w = isEn ? 195 : 215;
        int h = 134;

        POINT pt;
        GetCursorPos(&pt);
        RECT workArea = {};
        SystemParametersInfoW(SPI_GETWORKAREA, 0, &workArea, 0);

        int x = pt.x;
        int y = pt.y - h;
        if (x + w > workArea.right) x = workArea.right - w - 4;
        if (x < workArea.left) x = workArea.left + 4;
        if (y < workArea.top) y = pt.y;
        if (y + h > workArea.bottom) y = workArea.bottom - h - 4;

        HWND hMenu = CreateWindowExW(
            WS_EX_TOPMOST | WS_EX_TOOLWINDOW,
            L"WCaO_TrayMenuCls", L"",
            WS_POPUP,
            x, y, w, h,
            owner, nullptr, GetModuleHandleW(nullptr), &st
        );
        if (!hMenu) return 0;

        DWORD pref = 2; // DWMWCP_ROUND
        DwmSetWindowAttribute(hMenu, 33, &pref, sizeof(pref));

        ShowWindow(hMenu, SW_SHOW);
        SetForegroundWindow(hMenu);

        MSG msg;
        while (!st.closed && GetMessageW(&msg, nullptr, 0, 0)) {
            if (msg.message == WM_QUIT) {
                PostQuitMessage((int)msg.wParam);
                break;
            }
            TranslateMessage(&msg);
            DispatchMessageW(&msg);
        }
        DestroyWindow(hMenu);
        return st.chosenAction;
    }
};

// ============================================================================
//  4. NATIVE WINDOWS COLOR PICKER (ChooseColorW)
// ============================================================================
class NativeColorPicker {
public:
    static bool Show(HWND owner, COLORREF initialColor, COLORREF& outColor) {
        static COLORREF customCols[16] = {
            RGB(0, 210, 255),   RGB(16, 185, 129),  RGB(245, 158, 11),  RGB(239, 68, 68),
            RGB(59, 130, 246),  RGB(139, 92, 246),  RGB(236, 72, 153),  RGB(20, 184, 166),
            RGB(132, 204, 22),  RGB(234, 179, 8),   RGB(220, 38, 38),   RGB(234, 88, 12),
            RGB(30, 41, 59),    RGB(51, 65, 85),    RGB(100, 116, 139), RGB(255, 255, 255)
        };
        CHOOSECOLORW cc = { sizeof(cc) };
        cc.hwndOwner = owner;
        cc.rgbResult = initialColor;
        cc.lpCustColors = customCols;
        cc.Flags = CC_FULLOPEN | CC_RGBINIT;
        if (ChooseColorW(&cc)) {
            outColor = cc.rgbResult;
            return true;
        }
        return false;
    }
};

