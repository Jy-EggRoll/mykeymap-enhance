#Requires AutoHotkey v2.0

; 本文件依赖的库

#Include ./LoggerLib/Logger.ahk
#Include ./ThemeAndColorLib/ThemeAndColor.ahk
#Include ./AutoActivateWindow.ahk
#Include ./WindowStyleLib/WindowStyle.ahk

; 常量与全局状态

class AutoWindowColorBorderDebug {
    static mode := false
}

; Windows DWM API & 消息常量
DWMWA_BORDER_COLOR := 34
DWMWA_COLOR_DEFAULT := 0xFFFFFFFF
WM_SETTINGCHANGE := 0x001A

; 全局变量
borderEnabled := false      ; 功能开关状态
lastActiveWindow := 0       ; 上一个获得焦点的窗口句柄
windowStates := Map()       ; 存储窗口访问状态 {mouseVisited: bool}
cachedHsl := { h: 0, s: 0, l: 0 } ; 缓存强调色，避免每次轮询都读注册表

; 初始化与系统事件监听

; 启动时先取一次强调色，否则第一次轮询用的是缓存的初始值
RefreshColorCache()

; 用户改强调色或深浅色模式时不会重启脚本，靠这条消息重新取色
OnMessage(WM_SETTINGCHANGE, SystemSettingChanged)

SystemSettingChanged(wParam, lParam, msg, hwnd) {
    global lastActiveWindow
    RefreshColorCache()
    lastActiveWindow := 0 ; 强制触发下一次轮询的重绘逻辑
    LogInfo("检测到系统设置变更，已重新加载主题色并刷新缓存", , AutoWindowColorBorderDebug.mode)
}

/**
 * 刷新颜色缓存：从注册表读取一次最新的强调色并转为 HSL
 */
RefreshColorCache() {
    global cachedHsl
    try {
        ; 读取 Windows 强调色（ABGR 格式）
        rawColor := RegRead("HKEY_CURRENT_USER\Software\Microsoft\Windows\DWM", "AccentColor")
        r := rawColor & 0xFF
        g := (rawColor >> 8) & 0xFF
        b := (rawColor >> 16) & 0xFF
    } catch {
        r := 0, g := 120, b := 215 ; 默认蓝
    }
    cachedHsl := RGBtoHSL(r, g, b)
}

; 核心逻辑函数

/**
 * 获取动态边框颜色（BGR 格式）
 *
 * 置顶窗口、抢占焦点的弹出窗口与未访问窗口共用补色分支。补色与强调色相差 180 度，
 * 让这些窗口和已访问的普通窗口一眼就能分开；饱和度与亮度取满，只让色相跟随系统强调色
 */
GetDynamicBorderColor(hwnd) {
    global cachedHsl, windowStates

    ; mouseVisited 为 true 表示鼠标已经移入过这个窗口
    isVisited := (windowStates.Has(hwnd) && windowStates[hwnd].mouseVisited)

    if (IsTopmost(hwnd) || IsPopUp(hwnd) || !isVisited) {
        targetH := Mod(cachedHsl.h + 180, 360) ; 色相转 180 度得到补色
    } else {
        targetH := cachedHsl.h ; 强调色的色相，饱和度与亮度取满
    }

    ; DWM 的边框颜色按 BGR 顺序取分量，因此这里按 b、g、r 打包
    rgb := HSLtoRGB(targetH, 1.0, 0.5)
    return (rgb.b << 16) | (rgb.g << 8) | rgb.r
}

/**
 * 定时轮询函数
 */
UpdateWindowBorder() {
    global lastActiveWindow, borderEnabled, windowStates

    if (!borderEnabled)
        return

    try {
        currentActiveWindow := WinExist("A")

        ; 实时更新鼠标访问状态
        if (currentActiveWindow != 0) {
            MouseGetPos(, , &mHwnd)
            if (mHwnd == currentActiveWindow) {
                if !windowStates.Has(currentActiveWindow)
                    windowStates[currentActiveWindow] := { mouseVisited: true }
                else
                    windowStates[currentActiveWindow].mouseVisited := true
            }
        }

        ; 处理焦点切换时的边框清除
        if (currentActiveWindow != lastActiveWindow && lastActiveWindow != 0) {
            if WinExist(lastActiveWindow) {
                ; 失去焦点时，非置顶窗口要清除边框
                if !IsTopmost(lastActiveWindow) {
                    ClearWindowBorder(lastActiveWindow)
                } else {
                    ; 置顶窗口保留边框，但要按新状态重算颜色
                    SetWindowBorder(lastActiveWindow, GetDynamicBorderColor(lastActiveWindow))
                }
            }
        }

        ; 应用或刷新当前窗口边框
        if (currentActiveWindow != 0) {
            if (SetWindowBorder(currentActiveWindow, GetDynamicBorderColor(currentActiveWindow))) {
                lastActiveWindow := currentActiveWindow
            }
        }
    }
    catch Error as e {
        LogError(e, , AutoWindowColorBorderDebug.mode)
    }
}

; 工具函数（DWM 与颜色换算）

SetWindowBorder(hwnd, color) {
    try {
        if !hwnd || !WinExist(hwnd)
            return false
        ; `DwmSetWindowAttribute` 返回 0 表示成功，取反后转成布尔值
        return !DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hwnd, "uint", DWMWA_BORDER_COLOR, "uint*", color, "uint",
            4, "int")
    } catch
        return false
}

ClearWindowBorder(hwnd) => SetWindowBorder(hwnd, DWMWA_COLOR_DEFAULT)

AutoWindowColorBorder(pollingTime := 20) {
    global borderEnabled
    if (!borderEnabled) {
        SetTimer(UpdateWindowBorder, pollingTime)
        borderEnabled := true
        LogInfo("窗口边框着色已启动", , AutoWindowColorBorderDebug.mode)
    } else {
        SetTimer(UpdateWindowBorder, 0)
        CleanupBorder()
        borderEnabled := false
        LogInfo("窗口边框着色已停止", , AutoWindowColorBorderDebug.mode)
    }
}

CleanupBorder() {
    global lastActiveWindow
    if (lastActiveWindow != 0 && WinExist(lastActiveWindow))
        ClearWindowBorder(lastActiveWindow)
    lastActiveWindow := 0
}

CleanupOnExit(*) => CleanupBorder()

; ------------------------------------------------------------------------------
; 色彩转换算法
; ------------------------------------------------------------------------------

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

; 启动时由 custom_functions.ahk 统一调用
; AutoWindowColorBorder()

; 退出时清理边框
OnExit(CleanupOnExit)
