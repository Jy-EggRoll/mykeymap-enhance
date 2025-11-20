#Requires AutoHotkey v2.0

; 注意：该脚本极其严格地遵守“获得焦点”即着色边框，“失去焦点”则恢复边框，为了该功能的稳定，不做任何特殊情况处理。若有时您看到边框颜色意外消失，请注意这不是 bug，一定是该窗口丢失了焦点。例 1：收藏页面时，跳出了一个小窗口，浏览器的边框着色消失了；例 2：使用鼠标手势时，浏览器的边框着色消失了。以上两种情况都是正确且合理的。若您实在不适，请自行取消注释我的部分代码。

#Include QueryTheme.ahk
DEBUGMODE := false  ; 是否启用开发模式，设为 true 会打开控制台并显示调试信息

; Windows DWM API 常量
DWMWA_BORDER_COLOR := 34  ; DWM 边框颜色属性
DWMWA_COLOR_DEFAULT := 0xFFFFFFFF  ; DWM 边框默认值，外观看起来是一般是淡灰色的，可能与不同软件亦有关

; 颜色配置（标准 RGB 值），目前的颜色选自 Catppuccin 的 Latte 风味，其中 Peach 色彩鲜艳且适合多种主题，如需添加自己的颜色，请按照相同格式添加 Map，逗号分隔
COLORS := [
    Map("name", "Peach", "rgb", "254,100,11"),
    Map("name", "sky", "rgb", "4,165,229")
]

COLORS_MODE2 := [
    Map("name", "Peach", "rgb", "254,100,11"),
    Map("name", "sky", "rgb", "4,165,229")
]

borderEnabled := false
currentColorIndex := 1  ; 用来设定默认选择列表中的哪个颜色
currentColorIndexMode2 := 1
lastActiveWindow := 0
lightTheme := IsLightTheme()

/**
 * RGB 转 BGR 颜色格式函数
 * @param {String} rgbString - RGB 颜色字符串，格式为 "r,g,b" 例如 "255,0,0"
 * @return {Integer} BGR 格式的颜色值，这是 Windows DWM API 所需的格式
 */
RGBtoBGR(rgbString) {
    parts := StrSplit(rgbString, ",")
    if (parts.Length != 3) {
        return 0x0000FF  ; 默认返回红色
    }

    r := Integer(parts[1])
    g := Integer(parts[2])
    b := Integer(parts[3])

    return (b << 16) | (g << 8) | r
}

/**
 * 切换窗口边框功能的开关函数
 */
AutoWindowColorBorder(pollingTime := 50) {
    global borderEnabled

    if (!borderEnabled) {
        ; 启动边框功能
        SetTimer(UpdateWindowBorder, pollingTime)
        borderEnabled := true
        LogInfo("窗口边框着色已启动", , DEBUGMODE)
    } else {
        ; 停止边框功能
        SetTimer(UpdateWindowBorder, 0)
        CleanupBorder()
        borderEnabled := false
        LogInfo("窗口边框着色已停止", , DEBUGMODE)
    }
}

/**
 * 切换到下一个颜色
 */
SwitchToNextColor() {
    global currentColorIndex, COLORS, currentColorIndexMode2, COLORS_MODE2, lightTheme

    test := IsLightTheme()

    if (test != lightTheme) {
        lightTheme := test
        LogInfo("系统主题变化 已刷新列表", , DEBUGMODE)
    }

    if (lightTheme) {
        currentColorIndexMode2 := currentColorIndexMode2 >= COLORS_MODE2.Length ? 1 : currentColorIndexMode2 + 1
        colorName := COLORS_MODE2[currentColorIndexMode2]["name"]
    } else {
        currentColorIndex := currentColorIndex >= COLORS.Length ? 1 : currentColorIndex + 1
        colorName := COLORS[currentColorIndex]["name"]
    }
    LogInfo("已切换到下一个颜色：" colorName, , DEBUGMODE)
}

/**
 * 设置窗口边框颜色
 * @param {Integer} hwnd - 窗口句柄
 * @param {Integer} color - 边框颜色值 (BGR 格式)
 * @return {Boolean} 操作是否成功
 */
SetWindowBorder(hwnd, color) {
    try {
        if (!hwnd) {
            return false
        }

        result := DllCall("dwmapi\DwmSetWindowAttribute",
            "ptr", hwnd,
            "uint", DWMWA_BORDER_COLOR,
            "uint*", color,
            "uint", 4,
            "int")
        return (result = 0)
    }
    catch Error as e {
        LogError(e, , DEBUGMODE)
        return false
    }
}

/**
 * 清除窗口边框
 * @param {Integer} hwnd - 窗口句柄
 * @return {Boolean} 操作是否成功
 */
ClearWindowBorder(hwnd) {
    return SetWindowBorder(hwnd, DWMWA_COLOR_DEFAULT)
}

/**
 * 获取当前边框颜色
 * @return {Integer} 当前边框颜色值
 */
GetCurrentBorderColor(hwnd) {
    global lightTheme
    if (windowStates.Has(hwnd) && windowStates[hwnd].mouseVisited == true) {
        if (lightTheme) {
            return RGBtoBGR(COLORS_MODE2[currentColorIndexMode2]["rgb"])
        } else {
            return RGBtoBGR(COLORS[currentColorIndex]["rgb"])
        }
    } else {
        if (lightTheme) {
            return RGBtoBGR(COLORS_MODE2[currentColorIndexMode2 + 1]["rgb"])
        } else {
            return RGBtoBGR(COLORS[currentColorIndex + 1]["rgb"])
        }
    }
}

/**
 * 更新活动窗口边框
 */
UpdateWindowBorder() {
    global lastActiveWindow, borderEnabled, lightTheme

    if (!borderEnabled) {
        return
    }

    try {
        currentActiveWindow := WinExist("A")

        if (currentActiveWindow != lastActiveWindow && currentActiveWindow != 0) {  ; currentActiveWindow 不能为零，否则易产生无效的清除死循环
            ; 立即清除失去焦点的窗口边框
            if (lastActiveWindow != 0) {
                if (ClearWindowBorder(lastActiveWindow)) {
                    LogInfo("成功清除 [" WinGetTitle(lastActiveWindow) "] [" WinGetClass(lastActiveWindow) "] [" lastActiveWindow "] 的边框颜色", ,
                    DEBUGMODE)
                }
            }
        }
        if (currentActiveWindow != 0) {  ; 尽可能保证激活的窗口一定可以被设置边框颜色，这相当于每 pollingTime 就尝试设置一次
            borderColor := GetCurrentBorderColor(currentActiveWindow)
            if (SetWindowBorder(currentActiveWindow, borderColor)) {
                lastActiveWindow := currentActiveWindow  ; 只有设置成功后才更新 lastActiveWindow，这保证了颜色可以被正确清除
            }
        }
    }
    catch Error as e {
        LogError(e, , DEBUGMODE)
    }
}

/**
 * 清理边框
 */
CleanupBorder() {
    global lastActiveWindow
    try {
        if (lastActiveWindow != 0) {
            ClearWindowBorder(lastActiveWindow)
        }
        lastActiveWindow := 0
    }
    catch Error as e {
        LogError(e, , DEBUGMODE)
    }
}

/**
 * 程序退出时的清理函数
 */
CleanupOnExit(*) {
    CleanupBorder()
}

AutoWindowColorBorder()  ; MyKeymap 启动时自动运行

; 注册程序退出清理函数，确保退出时不残留带有颜色的边框
OnExit(CleanupOnExit)