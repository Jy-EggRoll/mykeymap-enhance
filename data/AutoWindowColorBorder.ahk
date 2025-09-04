#Requires AutoHotkey v2.0

#Include LogError.ahk

; Windows DWM API 常量
DWMWA_BORDER_COLOR := 34  ; DWM 边框颜色属性
DWMWA_COLOR_NONE := 0xFFFFFFFE  ; DWM 边框清除值

; 颜色配置（标准 RGB 值）
COLORS := [
    Map("name", "红色", "rgb", "255,0,0"),
    Map("name", "绿色", "rgb", "0,255,0")
]

; 全局变量
global borderEnabled := false
global currentColorIndex := 1
global lastActiveWindow := 0

/**
 * RGB 转 BGR 颜色格式函数
 * @param {String} rgbString - RGB 颜色字符串，格式为 "r,g,b" 例如 "255,0,0"
 * @return {Integer} BGR 格式的颜色值
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
AutoWindowColorBorder() {
    global borderEnabled

    if (!borderEnabled) {
        ; 启动边框功能
        SetTimer(UpdateWindowBorder, 100)
        borderEnabled := true
        ToolTip("窗口边框功能已启动")
        SetTimer(ToolTip, -1000)
    } else {
        ; 停止边框功能
        SetTimer(UpdateWindowBorder, 0)
        CleanupBorder()
        borderEnabled := false
        ToolTip("窗口边框功能已停止")
        SetTimer(ToolTip, -1000)
    }
}

/**
 * 切换到下一个颜色
 */
SwitchToNextColor() {
    global currentColorIndex, COLORS

    currentColorIndex := currentColorIndex >= COLORS.Length ? 1 : currentColorIndex + 1
    colorName := COLORS[currentColorIndex]["name"]

    ToolTip("切换到颜色: " . colorName)
    SetTimer(ToolTip, -1000)
}

/**
 * 设置窗口边框颜色
 * @param {Integer} hwnd - 窗口句柄
 * @param {Integer} color - 边框颜色值 (BGR 格式)
 * @return {Boolean} 操作是否成功
 */
SetWindowBorder(hwnd, color) {
    try {
        if (!hwnd || !DllCall("IsWindow", "ptr", hwnd)) {
            return false
        }

        result := DllCall("dwmapi\DwmSetWindowAttribute",
            "ptr", hwnd,
            "uint", DWMWA_BORDER_COLOR,
            "uint*", color,
            "uint", 4,
            "int")

        return (result == 0)
    }
    catch Error as e {
        ; LogError(e, "AutoWindowColorBorder_Error.log")
        ; 静默处理
        return false
    }
}

/**
 * 清除窗口边框
 * @param {Integer} hwnd - 窗口句柄
 * @return {Boolean} 操作是否成功
 */
ClearWindowBorder(hwnd) {
    return SetWindowBorder(hwnd, DWMWA_COLOR_NONE)
}

/**
 * 获取当前边框颜色
 * @return {Integer} 当前边框颜色值
 */
GetCurrentBorderColor() {
    global currentColorIndex, COLORS
    return RGBtoBGR(COLORS[currentColorIndex]["rgb"])
}

/**
 * 判断窗口是否应该跳过
 * @param {Integer} hwnd - 窗口句柄
 * @return {Boolean} true 表示应该跳过该窗口
 */
ShouldSkipWindow(hwnd) {
    try {
        ; windowStyle := DllCall("GetWindowLong", "ptr", hwnd, "int", -16, "uint")

        ; ; ; 跳过不可见窗口
        ; ; if (!(windowStyle & 0x10000000)) {
        ; ;     return true
        ; ; }

        ; ; ; 跳过最小化窗口
        ; ; if (windowStyle & 0x20000000) {
        ; ;     return true
        ; ; }

        ; ; 获取窗口类名
        ; classBuffer := Buffer(256)
        ; DllCall("GetClassName", "ptr", hwnd, "ptr", classBuffer, "int", 256)
        ; className := StrGet(classBuffer, "UTF-16")

        ; ; 使用静态 Map 存储需要跳过的窗口类名
        ; static skipClasses := Map()

        ; return skipClasses.Has(className)
    }
    catch {
        return true
    }
}

/**
 * 更新活动窗口边框
 */
UpdateWindowBorder() {
    global lastActiveWindow, borderEnabled

    if (!borderEnabled) {
        return
    }

    try {
        currentActiveWindow := DllCall("GetForegroundWindow", "ptr")

        if (currentActiveWindow != lastActiveWindow) {
            ; 立即清除失去焦点的窗口边框
            if (lastActiveWindow != 0 && DllCall("IsWindow", "ptr", lastActiveWindow)) {
                ClearWindowBorder(lastActiveWindow)
            }

            ; 立即为获得焦点的窗口设置边框
            if (currentActiveWindow != 0 && !ShouldSkipWindow(currentActiveWindow)) {
                SetWindowBorder(currentActiveWindow, GetCurrentBorderColor())
            }

            lastActiveWindow := currentActiveWindow
        }
    }
    catch Error as e {
        ; LogError(e, "AutoWindowColorBorder_Error.log")
        ; 静默处理
    }
}

/**
 * 清理边框
 */
CleanupBorder() {
    global lastActiveWindow
    try {
        if (lastActiveWindow != 0 && DllCall("IsWindow", "ptr", lastActiveWindow)) {
            ClearWindowBorder(lastActiveWindow)
        }
        lastActiveWindow := 0
    }
    catch Error as e {
        ; LogError(e, "AutoWindowColorBorder_Error.log")
        ; 静默处理
    }
}

/**
 * 程序退出时的清理函数
 */
CleanupOnExit(*) {
    CleanupBorder()
}

AutoWindowColorBorder()  ; MyKeymap 启动时自动运行

; 注册程序退出清理函数
OnExit(CleanupOnExit)