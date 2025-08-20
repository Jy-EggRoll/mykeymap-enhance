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

    DllCall("SetThreadDpiAwarenessContext", "ptr", -1, "ptr")

    WinExist("A")
    if (F_WindowMaxOrMin())
        WinRestore

    WinGetPos(&x, &y, &w, &h)

    ms := F_GetMonitorAt(x + w / 2, y + h / 2)
    MonitorGetWorkArea(ms, &l, &t, &r, &b)
    w := r - l
    h := b - t

    winW := percentageW * w
    winH := percentageH * h
    winX := l + (w - winW) / 2
    winY := t + (h - winH) / 2

    WinMove(winX, winY, winW, winH)
    DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
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

    DllCall("SetThreadDpiAwarenessContext", "ptr", -1, "ptr")

    WinExist("A")
    if (F_WindowMaxOrMin())
        WinRestore

    WinGetPos(&x, &y, &w, &h)

    ms := F_GetMonitorAt(x + w / 2, y + h / 2)
    MonitorGetWorkArea(ms, &l, &t, &r, &b)
    w := r - l
    h := b - t

    winW := percentageW * w
    winH := percentageH * h
    winX := l  ; 左对齐
    winY := t  ; 上对齐

    WinMove(winX, winY, winW, winH)
    DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
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

    DllCall("SetThreadDpiAwarenessContext", "ptr", -1, "ptr")

    WinExist("A")
    if (F_WindowMaxOrMin())
        WinRestore

    WinGetPos(&x, &y, &w, &h)

    ms := F_GetMonitorAt(x + w / 2, y + h / 2)
    MonitorGetWorkArea(ms, &l, &t, &r, &b)
    w := r - l
    h := b - t

    winW := percentageW * w
    winH := percentageH * h
    winX := l  ; 左对齐
    winY := b - winH  ; 下对齐

    WinMove(winX, winY, winW, winH)
    DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
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

    DllCall("SetThreadDpiAwarenessContext", "ptr", -1, "ptr")

    WinExist("A")
    if (F_WindowMaxOrMin())
        WinRestore

    WinGetPos(&x, &y, &w, &h)

    ms := F_GetMonitorAt(x + w / 2, y + h / 2)
    MonitorGetWorkArea(ms, &l, &t, &r, &b)
    w := r - l
    h := b - t

    winW := percentageW * w
    winH := percentageH * h
    winX := r - winW  ; 右对齐
    winY := t  ; 上对齐

    WinMove(winX, winY, winW, winH)
    DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
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

    DllCall("SetThreadDpiAwarenessContext", "ptr", -1, "ptr")

    WinExist("A")
    if (F_WindowMaxOrMin())
        WinRestore

    WinGetPos(&x, &y, &w, &h)

    ms := F_GetMonitorAt(x + w / 2, y + h / 2)
    MonitorGetWorkArea(ms, &l, &t, &r, &b)
    w := r - l
    h := b - t

    winW := percentageW * w
    winH := percentageH * h
    winX := r - winW  ; 右对齐
    winY := b - winH  ; 下对齐

    WinMove(winX, winY, winW, winH)
    DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
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

    DllCall("SetThreadDpiAwarenessContext", "ptr", -1, "ptr")

    WinExist("A")
    if (F_WindowMaxOrMin())
        WinRestore

    WinGetPos(&x, &y, &w, &h)

    ms := F_GetMonitorAt(x + w / 2, y + h / 2)
    MonitorGetWorkArea(ms, &l, &t, &r, &b)
    w := r - l
    h := b - t

    winW := percentageW * w
    winH := percentageH * h
    winX := l + (w - winW) / 2  ; 水平居中
    winY := t  ; 上对齐

    WinMove(winX, winY, winW, winH)
    DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
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

    DllCall("SetThreadDpiAwarenessContext", "ptr", -1, "ptr")

    WinExist("A")
    if (F_WindowMaxOrMin())
        WinRestore

    WinGetPos(&x, &y, &w, &h)

    ms := F_GetMonitorAt(x + w / 2, y + h / 2)
    MonitorGetWorkArea(ms, &l, &t, &r, &b)
    w := r - l
    h := b - t

    winW := percentageW * w
    winH := percentageH * h
    winX := r - winW  ; 右对齐
    winY := t + (h - winH) / 2  ; 垂直居中

    WinMove(winX, winY, winW, winH)
    DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
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

    DllCall("SetThreadDpiAwarenessContext", "ptr", -1, "ptr")

    WinExist("A")
    if (F_WindowMaxOrMin())
        WinRestore

    WinGetPos(&x, &y, &w, &h)

    ms := F_GetMonitorAt(x + w / 2, y + h / 2)
    MonitorGetWorkArea(ms, &l, &t, &r, &b)
    w := r - l
    h := b - t

    winW := percentageW * w
    winH := percentageH * h
    winX := l + (w - winW) / 2  ; 水平居中
    winY := b - winH  ; 下对齐

    WinMove(winX, winY, winW, winH)
    DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
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

    DllCall("SetThreadDpiAwarenessContext", "ptr", -1, "ptr")

    WinExist("A")
    if (F_WindowMaxOrMin())
        WinRestore

    WinGetPos(&x, &y, &w, &h)

    ms := F_GetMonitorAt(x + w / 2, y + h / 2)
    MonitorGetWorkArea(ms, &l, &t, &r, &b)
    w := r - l
    h := b - t

    winW := percentageW * w
    winH := percentageH * h
    winX := l  ; 左对齐
    winY := t + (h - winH) / 2  ; 垂直居中

    WinMove(winX, winY, winW, winH)
    DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
}
