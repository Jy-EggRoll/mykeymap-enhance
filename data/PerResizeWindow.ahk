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
 * @param {string} winTitle AHK中的WinTitle
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

    hwnd := WinExist("A")
    shadowThickness := GetShadowThickness(hwnd)
    ; borderThickness := GetBorderThickness(hwnd)

    if (F_WindowMaxOrMin())
        WinRestore

    WinGetPos(&x, &y, &w, &h)

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

    hwnd := WinExist("A")
    shadowThickness := GetShadowThickness(hwnd)
    ; borderThickness := GetBorderThickness(hwnd)
    if (F_WindowMaxOrMin())
        WinRestore

    WinGetPos(&x, &y, &w, &h)

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

    hwnd := WinExist("A")
    shadowThickness := GetShadowThickness(hwnd)
    ; borderThickness := GetBorderThickness(hwnd)
    if (F_WindowMaxOrMin())
        WinRestore

    WinGetPos(&x, &y, &w, &h)

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

    hwnd := WinExist("A")
    shadowThickness := GetShadowThickness(hwnd)
    ; borderThickness := GetBorderThickness(hwnd)
    if (F_WindowMaxOrMin())
        WinRestore

    WinGetPos(&x, &y, &w, &h)

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

    hwnd := WinExist("A")
    shadowThickness := GetShadowThickness(hwnd)
    ; borderThickness := GetBorderThickness(hwnd)
    if (F_WindowMaxOrMin())
        WinRestore

    WinGetPos(&x, &y, &w, &h)

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

    hwnd := WinExist("A")
    shadowThickness := GetShadowThickness(hwnd)
    ; borderThickness := GetBorderThickness(hwnd)
    if (F_WindowMaxOrMin())
        WinRestore

    WinGetPos(&x, &y, &w, &h)

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

    hwnd := WinExist("A")
    shadowThickness := GetShadowThickness(hwnd)
    ; borderThickness := GetBorderThickness(hwnd)
    if (F_WindowMaxOrMin())
        WinRestore

    WinGetPos(&x, &y, &w, &h)

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

    hwnd := WinExist("A")
    shadowThickness := GetShadowThickness(hwnd)
    ; borderThickness := GetBorderThickness(hwnd)
    if (F_WindowMaxOrMin())
        WinRestore

    WinGetPos(&x, &y, &w, &h)

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

    hwnd := WinExist("A")
    shadowThickness := GetShadowThickness(hwnd)
    ; borderThickness := GetBorderThickness(hwnd)
    if (F_WindowMaxOrMin())
        WinRestore

    WinGetPos(&x, &y, &w, &h)

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
