#Requires AutoHotkey v2.0

; F 开头的函数是内置于 MyKeymap 的函数，为了保持本脚本独立性且避免函数冲突，故采用这样的方式，没有额外的意义

/**
 * 没有活动窗口或是桌面返回 true，不是则反之返回 false
 */
F_NotActiveWin() {
    return F_IsDesktop() || not WinExist("A")
}

/**
 * 判断当前窗口是不是桌面
 */
F_IsDesktop() {
    return WinActive("Program Manager ahk_class Progman") || WinActive("ahk_class WorkerW")
}

/**
 * 当前窗口是最大化还是最小化
 * @param {string} winTitle AHK 中的 WinTitle
 * @returns {number} 
 */
F_WindowMaxOrMin(winTitle := "A") {
    return WinGetMinMax(winTitle)
}

/**
 * 获取当前焦点在哪个显示器上
 * @param x 窗口 x 轴的长度
 * @param y 窗口 y 轴的长度
 * @param {number} default 显示器下标
 * @returns {string|number} 匹配的显示器下标
 */
F_GetMonitorAt(x, y, default := 1) {
    m := SysGet(80)
    loop m {
        MonitorGet(A_Index, &l, &t, &r, &b)
        if (x >= l && x <= r && y >= t && y <= b)
            return A_Index
    }
    return default
}

; 注意：以下各函数不能保证窗口的边框紧贴显示器边框，这是 Windows 的已知问题
; 修复是可行的，请查找 WinMoveEx()，但是受限于各种窗口的实现方式有区别，缩放的处理也不太统一，这不是完美的解决方案

; 修复 2025-09-06：完美修复了窗口边框与显示器边框的贴合问题

GetShadowThickness(hwnd) {
    ; DWM 属性常量
    DWMWA_EXTENDED_FRAME_BOUNDS := 9  ; 扩展框架边界
    DWMWA_VISIBLE_FRAME_BORDER_THICKNESS := 37  ; 可见边框厚度

    ; borderInfo := ""

    try {
        ; 获取窗口的常规位置和大小
        WinGetPos(&winX, &winY, &winW, &winH, "ahk_id " hwnd)
        WinGetClientPos(&clientX, &clientY, &clientW, &clientH, "ahk_id " hwnd)

        ; 获取扩展框架边界 (RECT 结构)
        extendedRect := Buffer(16, 0)  ; RECT 结构需要 16 字节
        result1 := DllCall("dwmapi\DwmGetWindowAttribute",
            "ptr", hwnd,
            "uint", DWMWA_EXTENDED_FRAME_BOUNDS,
            "ptr", extendedRect,
            "uint", 16,
            "int")

        if (result1 == 0) {
            ; extLeft := NumGet(extendedRect, 0, "int")
            ; extTop := NumGet(extendedRect, 4, "int")
            ; extRight := NumGet(extendedRect, 8, "int")
            extBottom := NumGet(extendedRect, 12, "int")
            ; extWidth := extRight - extLeft
            ; extHeight := extBottom - extTop

            ; borderInfo .= "--- Window Size & Border Info ---`n"
            ; borderInfo .= "WinGetPosSize: " winW " * " winH "`n"
            ; borderInfo .= "WinGetClientPosSize: " clientW " * " clientH "`n"
            ; borderInfo .= "PlusExtendedFrameSize: " extWidth " * " extHeight "`n"

            ; 计算边框厚度
            ; leftBorder := clientX - extLeft
            ; topBorder := clientY - extTop
            ; rightBorder := extRight - (clientX + clientW)
            ; bottomBorder := extBottom - (clientY + clientH)

            ; borderInfo .= "BorderThickness: [Left: " leftBorder "] [Top: " topBorder "] [Right: " rightBorder "] [Bottom: " bottomBorder "]`n"

            ; 计算阴影厚度 (WinGet 窗口边界与扩展边界的差异)
            ; shadowLeft := extLeft - WinX
            ; shadowTop := extTop - WinY
            ; shadowRight := (winX + winW) - extRight
            shadowBottom := (winY + winH) - extBottom

            ; borderInfo .= "ShadowThickness: [Left: " shadowLeft "] [Top: " shadowTop "] [Right: " shadowRight "] [Bottom: " shadowBottom "]`n"
        }

        ; ; 尝试获取可见边框厚度
        ; borderThickness := Buffer(4, 0)  ; UINT 类型需要 4 字节
        ; result2 := DllCall("dwmapi\DwmGetWindowAttribute",
        ;     "ptr", hwnd,
        ;     "uint", DWMWA_VISIBLE_FRAME_BORDER_THICKNESS,
        ;     "ptr", borderThickness,
        ;     "uint", 4,
        ;     "int")

        ; if (result2 == 0) {
        ;     thickness := NumGet(borderThickness, 0, "uint")
        ;     ; borderInfo .= "VisibleFrameBorderThickness: " thickness " pixels`n"
        ; }

    } catch Error as e {
        ; borderInfo .= "--- Window Size & Border Info ---`n"
        ; borderInfo .= "Error getting border info: " e.Message "`n"
        LogError(e, , DEBUGMODE)
    }

    return shadowBottom  ; 返回底部阴影厚度作为结果，三个阴影的值没有见到不同的时候
}

; GetBorderThickness(hwnd) {
;     ; DWM 属性常量
;     DWMWA_EXTENDED_FRAME_BOUNDS := 9  ; 扩展框架边界
;     DWMWA_VISIBLE_FRAME_BORDER_THICKNESS := 37  ; 可见边框厚度

;     ; borderInfo := ""

;     try {
;         ; 获取窗口的常规位置和大小
;         WinGetPos(&winX, &winY, &winW, &winH, "ahk_id " hwnd)
;         WinGetClientPos(&clientX, &clientY, &clientW, &clientH, "ahk_id " hwnd)

;         ; 获取扩展框架边界 (RECT 结构)
;         extendedRect := Buffer(16, 0)  ; RECT 结构需要 16 字节
;         result1 := DllCall("dwmapi\DwmGetWindowAttribute",
;             "ptr", hwnd,
;             "uint", DWMWA_EXTENDED_FRAME_BOUNDS,
;             "ptr", extendedRect,
;             "uint", 16,
;             "int")

;         if (result1 == 0) {
;             ; extLeft := NumGet(extendedRect, 0, "int")
;             ; extTop := NumGet(extendedRect, 4, "int")
;             ; extRight := NumGet(extendedRect, 8, "int")
;             extBottom := NumGet(extendedRect, 12, "int")
;             ; extWidth := extRight - extLeft
;             ; extHeight := extBottom - extTop

;             ; borderInfo .= "--- Window Size & Border Info ---`n"
;             ; borderInfo .= "WinGetPosSize: " winW " * " winH "`n"
;             ; borderInfo .= "WinGetClientPosSize: " clientW " * " clientH "`n"
;             ; borderInfo .= "PlusExtendedFrameSize: " extWidth " * " extHeight "`n"

;             ; 计算边框厚度
;             ; leftBorder := clientX - extLeft
;             ; topBorder := clientY - extTop
;             ; rightBorder := extRight - (clientX + clientW)
;             bottomBorder := extBottom - (clientY + clientH)

;             ; borderInfo .= "BorderThickness: [Left: " leftBorder "] [Top: " topBorder "] [Right: " rightBorder "] [Bottom: " bottomBorder "]`n"

;             ; 计算阴影厚度 (WinGet 窗口边界与扩展边界的差异)
;             ; shadowLeft := extLeft - WinX
;             ; shadowTop := extTop - WinY
;             ; shadowRight := (winX + winW) - extRight
;             ; shadowBottom := (winY + winH) - extBottom

;             ; borderInfo .= "ShadowThickness: [Left: " shadowLeft "] [Top: " shadowTop "] [Right: " shadowRight "] [Bottom: " shadowBottom "]`n"
;         }

;         ; ; 尝试获取可见边框厚度
;         ; borderThickness := Buffer(4, 0)  ; UINT 类型需要 4 字节
;         ; result2 := DllCall("dwmapi\DwmGetWindowAttribute",
;         ;     "ptr", hwnd,
;         ;     "uint", DWMWA_VISIBLE_FRAME_BORDER_THICKNESS,
;         ;     "ptr", borderThickness,
;         ;     "uint", 4,
;         ;     "int")

;         ; if (result2 == 0) {
;         ;     thickness := NumGet(borderThickness, 0, "uint")
;         ;     ; borderInfo .= "VisibleFrameBorderThickness: " thickness " pixels`n"
;         ; }

;     } catch Error as e {
;         ; borderInfo .= "--- Window Size & Border Info ---`n"
;         ; borderInfo .= "Error getting border info: " e.Message "`n"
;     }

;     return bottomBorder  ; 返回底部边框厚度作为结果，三个边框的值没有见到不同的时候
; }

/**
 * 根据指定的网格数量和网格索引，将当前活动窗口调整到屏幕对应位置并设置相应大小
 * 支持多种分屏布局（2 格、3 格、4 格、9 格），不同网格数量对应不同的屏幕分割方式
 * @param {number} gridNum - 网格数量，决定分屏布局模式，支持的值：2、3、4、9
 * 
 * 2：两格布局，支持水平分割（h1 左半屏、h2 右半屏）和垂直分割（v1 上半屏、v2 下半屏）
 * 
 * 3：三格布局，支持水平分割（h1 左 1/3、h2 中 1/3、h3 右 1/3）和垂直分割（v1 上 1/3、v2 中 1/3、v3 下 1/3）
 * 
 * 4：四格布局（2 * 2 网格），索引 1-4 分别对应左上、右上、左下、右下
 * 
 * 9：九格布局（3 * 3 网格），索引 1-9 对应从左上到右下的 3 * 3 网格位置
 * 
 * @param {number|string} gridIndex - 网格索引，标识窗口在当前网格布局中的位置
 * 
 * 当 gridNum 为 4 或 9 时，取值为数字 1-4 或 1-9，对应网格中的具体位置
 * 
 * 当 gridNum 为 2 时，取值为字符串 "h1"、"h2"（水平分割）或 "v1"、"v2"（垂直分割）
 * 
 * 当 gridNum 为 3 时，取值为字符串 "h1"、"h2"、"h3"（水平分割）或 "v1"、"v2"、"v3"（垂直分割）
 */
SplitScreen(gridNum, gridIndex) {
    switch gridNum {
        case 4:
        {
            switch gridIndex {
                case 1:
                {
                    PerLeftUpAndResizeWindow(0.5, 0.5)
                }
                case 2:
                {
                    PerRightUpAndResizeWindow(0.5, 0.5)
                }
                case 3:
                {
                    PerLeftDownAndResizeWindow(0.5, 0.5)
                }
                case 4:
                {
                    PerRightDownAndResizeWindow(0.5, 0.5)
                }
            }
        }
        case 9:
        {
            switch gridIndex {
                case 1:
                {
                    PerLeftUpAndResizeWindow(0.334, 0.334)
                }
                case 2:
                {
                    PerUpAndResizeWindow(0.334, 0.334)
                }
                case 3:
                {
                    PerRightUpAndResizeWindow(0.334, 0.334)
                }
                case 4:
                {
                    PerLeftAndResizeWindow(0.334, 0.334)
                }
                case 5:
                {
                    PerCenterAndResizeWindow(0.334, 0.334)
                }
                case 6:
                {
                    PerRightAndResizeWindow(0.334, 0.334)
                }
                case 7:
                {
                    PerLeftDownAndResizeWindow(0.334, 0.334)
                }
                case 8:
                {
                    PerDownAndResizeWindow(0.334, 0.334)
                }
                case 9:
                {
                    PerRightDownAndResizeWindow(0.334, 0.334)
                }
            }
        }
        case 2:
        {
            switch gridIndex {
                case "h1":
                {
                    PerLeftAndResizeWindow(0.5, 1)
                }
                case "h2":
                {
                    PerRightAndResizeWindow(0.5, 1)
                }
                case "v1":
                {
                    PerUpAndResizeWindow(1, 0.5)
                }
                case "v2":
                {
                    PerDownAndResizeWindow(1, 0.5)
                }
            }
        }
        case 3:
        {
            switch gridIndex {
                case "h1":
                {
                    PerLeftAndResizeWindow(0.334, 1)
                }
                case "h2":
                {
                    PerCenterAndResizeWindow(0.334, 1)
                }
                case "h3":
                {
                    PerRightAndResizeWindow(0.334, 1)
                }
                case "v1":
                {
                    PerUpAndResizeWindow(1, 0.334)
                }
                case "v2":
                {
                    PerCenterAndResizeWindow(1, 0.334)
                }
                case "v3":
                {
                    PerDownAndResizeWindow(1, 0.334)
                }
            }
        }
    }
}

/**
 * 窗口居中并修改其大小
 * @param percentageW
 * @param percentageH
 * @returns {void} 
 */
PerCenterAndResizeWindow(percentageW, percentageH) {
    if F_NotActiveWin() {
        return
    }

    ; DllCall("SetThreadDpiAwarenessContext", "ptr", -1, "ptr")
    ; borderThickness := GetBorderThickness(hwnd)

    if (F_WindowMaxOrMin())
        WinRestore

    WinGetPos(&x, &y, &w, &h)

    hwnd := WinExist("A")
    shadowThickness := GetShadowThickness(hwnd)

    ms := F_GetMonitorAt(x + w / 2, y + h / 2)
    MonitorGetWorkArea(ms, &l, &t, &r, &b)
    w := r - l
    h := b - t

    winW := percentageW * w + 2 * shadowThickness
    winH := percentageH * h + shadowThickness
    winX := l + (w - winW) / 2
    winY := t + (h - winH + shadowThickness) / 2

    WinMove(winX, winY, winW, winH)
    ; DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
}

/**
 * 窗口左上并修改其大小
 * @param percentageW
 * @param percentageH
 * @returns {void} 
 */
PerLeftUpAndResizeWindow(percentageW, percentageH) {
    if F_NotActiveWin() {
        return
    }

    ; DllCall("SetThreadDpiAwarenessContext", "ptr", -1, "ptr")
    ; borderThickness := GetBorderThickness(hwnd)
    if (F_WindowMaxOrMin())
        WinRestore

    WinGetPos(&x, &y, &w, &h)

    hwnd := WinExist("A")
    shadowThickness := GetShadowThickness(hwnd)
    ms := F_GetMonitorAt(x + w / 2, y + h / 2)
    MonitorGetWorkArea(ms, &l, &t, &r, &b)
    w := r - l
    h := b - t

    winW := percentageW * w + 2 * shadowThickness
    winH := percentageH * h + shadowThickness
    winX := l - shadowThickness  ; 左对齐
    winY := t  ; 上对齐

    WinMove(winX, winY, winW, winH)
    ; DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
}

/**
 * 窗口左下并修改其大小
 * @param percentageW
 * @param percentageH
 * @returns {void} 
 */
PerLeftDownAndResizeWindow(percentageW, percentageH) {
    if F_NotActiveWin() {
        return
    }

    ; DllCall("SetThreadDpiAwarenessContext", "ptr", -1, "ptr")
    ; borderThickness := GetBorderThickness(hwnd)
    if (F_WindowMaxOrMin())
        WinRestore

    WinGetPos(&x, &y, &w, &h)

    hwnd := WinExist("A")
    shadowThickness := GetShadowThickness(hwnd)
    ms := F_GetMonitorAt(x + w / 2, y + h / 2)
    MonitorGetWorkArea(ms, &l, &t, &r, &b)
    w := r - l
    h := b - t

    winW := percentageW * w + 2 * shadowThickness
    winH := percentageH * h + shadowThickness
    winX := l - shadowThickness  ; 左对齐
    winY := b - winH + shadowThickness  ; 下对齐

    WinMove(winX, winY, winW, winH)
    ; DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
}

/**
 * 窗口右上并修改其大小
 * @param percentageW
 * @param percentageH
 * @returns {void} 
 */
PerRightUpAndResizeWindow(percentageW, percentageH) {
    if F_NotActiveWin() {
        return
    }

    ; DllCall("SetThreadDpiAwarenessContext", "ptr", -1, "ptr")
    ; borderThickness := GetBorderThickness(hwnd)
    if (F_WindowMaxOrMin())
        WinRestore

    WinGetPos(&x, &y, &w, &h)

    hwnd := WinExist("A")
    shadowThickness := GetShadowThickness(hwnd)
    ms := F_GetMonitorAt(x + w / 2, y + h / 2)
    MonitorGetWorkArea(ms, &l, &t, &r, &b)
    w := r - l
    h := b - t

    winW := percentageW * w + 2 * shadowThickness
    winH := percentageH * h + shadowThickness
    winX := r - winW + shadowThickness ; 右对齐
    winY := t  ; 上对齐

    WinMove(winX, winY, winW, winH)
    ; DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
}

/**
 * 窗口右下并修改其大小
 * @param percentageW
 * @param percentageH
 * @returns {void} 
 */
PerRightDownAndResizeWindow(percentageW, percentageH) {
    if F_NotActiveWin() {
        return
    }

    ; DllCall("SetThreadDpiAwarenessContext", "ptr", -1, "ptr")
    ; borderThickness := GetBorderThickness(hwnd)
    if (F_WindowMaxOrMin())
        WinRestore

    WinGetPos(&x, &y, &w, &h)

    hwnd := WinExist("A")
    shadowThickness := GetShadowThickness(hwnd)
    ms := F_GetMonitorAt(x + w / 2, y + h / 2)
    MonitorGetWorkArea(ms, &l, &t, &r, &b)
    w := r - l
    h := b - t

    winW := percentageW * w + 2 * shadowThickness
    winH := percentageH * h + shadowThickness
    winX := r - winW + shadowThickness  ; 右对齐
    winY := b - winH + shadowThickness  ; 下对齐

    WinMove(winX, winY, winW, winH)
    ; DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
}

/**
 * 窗口上中并修改其大小
 * @param percentageW
 * @param percentageH
 * @returns {void} 
 */
PerUpAndResizeWindow(percentageW, percentageH) {
    if F_NotActiveWin() {
        return
    }

    ; DllCall("SetThreadDpiAwarenessContext", "ptr", -1, "ptr")
    ; borderThickness := GetBorderThickness(hwnd)
    if (F_WindowMaxOrMin())
        WinRestore

    WinGetPos(&x, &y, &w, &h)

    hwnd := WinExist("A")
    shadowThickness := GetShadowThickness(hwnd)
    ms := F_GetMonitorAt(x + w / 2, y + h / 2)
    MonitorGetWorkArea(ms, &l, &t, &r, &b)
    w := r - l
    h := b - t

    winW := percentageW * w + 2 * shadowThickness
    winH := percentageH * h + shadowThickness
    winX := l + (w - winW) / 2  ; 水平居中
    winY := t  ; 上对齐

    WinMove(winX, winY, winW, winH)
    ; DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
}

/**
 * 窗口右中并修改其大小
 * @param percentageW
 * @param percentageH
 * @returns {void} 
 */
PerRightAndResizeWindow(percentageW, percentageH) {
    if F_NotActiveWin() {
        return
    }

    ; DllCall("SetThreadDpiAwarenessContext", "ptr", -1, "ptr")
    ; borderThickness := GetBorderThickness(hwnd)
    if (F_WindowMaxOrMin())
        WinRestore

    WinGetPos(&x, &y, &w, &h)

    hwnd := WinExist("A")
    shadowThickness := GetShadowThickness(hwnd)
    ms := F_GetMonitorAt(x + w / 2, y + h / 2)
    MonitorGetWorkArea(ms, &l, &t, &r, &b)
    w := r - l
    h := b - t

    winW := percentageW * w + 2 * shadowThickness
    winH := percentageH * h + shadowThickness
    winX := r - winW + shadowThickness  ; 右对齐
    winY := t + (h - winH + shadowThickness) / 2  ; 垂直居中

    WinMove(winX, winY, winW, winH)
    ; DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
}

/**
 * 窗口下中并修改其大小
 * @param percentageW
 * @param percentageH
 * @returns {void} 
 */
PerDownAndResizeWindow(percentageW, percentageH) {
    if F_NotActiveWin() {
        return
    }

    ; DllCall("SetThreadDpiAwarenessContext", "ptr", -1, "ptr")
    ; borderThickness := GetBorderThickness(hwnd)
    if (F_WindowMaxOrMin())
        WinRestore

    WinGetPos(&x, &y, &w, &h)

    hwnd := WinExist("A")
    shadowThickness := GetShadowThickness(hwnd)
    ms := F_GetMonitorAt(x + w / 2, y + h / 2)
    MonitorGetWorkArea(ms, &l, &t, &r, &b)
    w := r - l
    h := b - t

    winW := percentageW * w + 2 * shadowThickness
    winH := percentageH * h + shadowThickness
    winX := l + (w - winW) / 2  ; 水平居中
    winY := b - winH + shadowThickness ; 下对齐

    WinMove(winX, winY, winW, winH)
    ; DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
}

/**
 * 窗口左中并修改其大小
 * @param percentageW
 * @param percentageH
 * @returns {void} 
 */
PerLeftAndResizeWindow(percentageW, percentageH) {
    if F_NotActiveWin() {
        return
    }

    ; DllCall("SetThreadDpiAwarenessContext", "ptr", -1, "ptr")
    ; borderThickness := GetBorderThickness(hwnd)
    if (F_WindowMaxOrMin())
        WinRestore

    WinGetPos(&x, &y, &w, &h)

    hwnd := WinExist("A")
    shadowThickness := GetShadowThickness(hwnd)
    ms := F_GetMonitorAt(x + w / 2, y + h / 2)
    MonitorGetWorkArea(ms, &l, &t, &r, &b)
    w := r - l
    h := b - t

    winW := percentageW * w + 2 * shadowThickness
    winH := percentageH * h + shadowThickness
    winX := l - shadowThickness ; 左对齐
    winY := t + (h - winH + shadowThickness) / 2  ; 垂直居中

    WinMove(winX, winY, winW, winH)
    ; DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
}
