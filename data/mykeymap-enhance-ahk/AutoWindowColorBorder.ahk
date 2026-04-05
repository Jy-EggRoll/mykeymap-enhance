#Requires AutoHotkey v2.0

#Include ./LoggerLib/Logger.ahk
#Include ./ThemeAndColorLib/ThemeAndColor.ahk
#Include AutoActivateWindow.ahk

class AutoWindowColorBorderDebug {
    static mode := true
}

; Windows DWM API 常量
DWMWA_BORDER_COLOR := 34
DWMWA_COLOR_DEFAULT := 0xFFFFFFFF

; 全局状态管理
borderEnabled := false
lastActiveWindow := 0
windowStates := Map() ; 用于记录窗口鼠标访问状态

/**
 * 核心逻辑：获取当前应应用的 BGR 颜色值
 * 规则：
 * 1. 置顶窗口 OR 未访问窗口 -> 使用高对比补色 (Contrast)
 * 2. 已访问激活窗口 -> 使用系统主题荧光色 (Vibrant)
 */
GetDynamicBorderColor(hwnd) {
    global windowStates
    try {
        ; 读取系统 DWM 强调色 (ABGR 格式)
        rawColor := RegRead("HKEY_CURRENT_USER\Software\Microsoft\Windows\DWM", "AccentColor")
        r := rawColor & 0xFF
        g := (rawColor >> 8) & 0xFF
        b := (rawColor >> 16) & 0xFF
    } catch {
        r := 0, g := 120, b := 215
    }

    ; 转换为 HSL 空间
    hsl := RGBtoHSL(r, g, b)

    ; --- 逻辑判断 ---
    isTopmost := (WinGetExStyle(hwnd) & 0x8)
    isVisited := (windowStates.Has(hwnd) && windowStates[hwnd].mouseVisited)

    ; 如果是置顶窗口，或者鼠标还没碰过这个窗口，统一采用补色
    if (isTopmost || !isVisited) {
        targetH := Mod(hsl.h + 180, 360) ; 高对比补色
    } else {
        targetH := hsl.h ; 系统主题荧光色
    }

    ; 转回 RGB (饱和度 100%, 亮度 50%)
    rgb := HSLtoRGB(targetH, 1.0, 0.5)

    return (rgb.b << 16) | (rgb.g << 8) | rgb.r
}

/**
 * 更新活动窗口边框
 */
UpdateWindowBorder() {
    global lastActiveWindow, borderEnabled, windowStates

    if (!borderEnabled)
        return

    try {
        currentActiveWindow := WinExist("A")

        ; 实时监测鼠标是否进入当前活动窗口
        if (currentActiveWindow != 0) {
            MouseGetPos(, , &mHwnd)
            if (mHwnd == currentActiveWindow) {
                if !windowStates.Has(currentActiveWindow)
                    windowStates[currentActiveWindow] := { mouseVisited: true }
                else
                    windowStates[currentActiveWindow].mouseVisited := true
            }
        }

        ; 焦点切换处理
        if (currentActiveWindow != lastActiveWindow && lastActiveWindow != 0) {
            if WinExist(lastActiveWindow) {
                ; 失去焦点时，若非置顶窗口则清除边框
                if !(WinGetExStyle(lastActiveWindow) & 0x8) {
                    ClearWindowBorder(lastActiveWindow)
                }
            }
        }

        ; 应用颜色
        if (currentActiveWindow != 0) {
            borderColor := GetDynamicBorderColor(currentActiveWindow)
            if (SetWindowBorder(currentActiveWindow, borderColor)) {
                lastActiveWindow := currentActiveWindow
            }
        }
    }
    catch Error as e {
        LogError(e, , AutoWindowColorBorderDebug.mode)
    }
}

; --- DWM 操作 ---
SetWindowBorder(hwnd, color) {
    try {
        if !hwnd || !WinExist(hwnd)
            return false
        result := DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hwnd, "uint", DWMWA_BORDER_COLOR, "uint*", color,
            "uint", 4, "int")
        return (result = 0)
    } catch {
        return false
    }
}

ClearWindowBorder(hwnd) => SetWindowBorder(hwnd, DWMWA_COLOR_DEFAULT)

AutoWindowColorBorder(pollingTime := 20) {
    global borderEnabled
    if (!borderEnabled) {
        SetTimer(UpdateWindowBorder, pollingTime)
        borderEnabled := true
    } else {
        SetTimer(UpdateWindowBorder, 0)
        CleanupBorder()
        borderEnabled := false
    }
}

CleanupBorder() {
    global lastActiveWindow
    if (lastActiveWindow != 0 && WinExist(lastActiveWindow))
        ClearWindowBorder(lastActiveWindow)
    lastActiveWindow := 0
}

CleanupOnExit(*) => CleanupBorder()

; --- 色彩数学转换 ---
RGBtoHSL(r, g, b) {
    rf := r / 255, gf := g / 255, bf := b / 255
    mx := Max(rf, gf, bf), mn := Min(rf, gf, bf)
    h := s := l := (mx + mn) / 2
    if (mx == mn) {
        h := s := 0
    } else {
        d := mx - mn
        s := l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn)
        if (mx == rf)
            h := (gf - bf) / d + (gf < bf ? 6 : 0)
        else if (mx == gf)
            h := (bf - rf) / d + 2
        else
            h := (rf - gf) / d + 4
        h *= 60
    }
    return { h: h, s: s, l: l }
}

HSLtoRGB(h, s, l) {
    c := (1 - Abs(2 * l - 1)) * s
    x := c * (1 - Abs(Mod(h / 60, 2) - 1))
    m := l - c / 2
    tr := 0, tg := 0, tb := 0
    if (h < 60)
        tr := c, tg := x, tb := 0
    else if (h < 120)
        tr := x, tg := c, tb := 0
    else if (h < 180)
        tr := 0, tg := c, tb := x
    else if (h < 240)
        tr := 0, tg := x, tb := c
    else if (h < 300)
        tr := x, tg := 0, tb := c
    else
        tr := c, tg := 0, tb := x
    return { r: Round((tr + m) * 255), g: Round((tg + m) * 255), b: Round((tb + m) * 255) }
}

AutoWindowColorBorder()
OnExit(CleanupOnExit)