#Requires AutoHotkey v2.0

/**
 * 判断窗口是否属于可以自动激活的有效窗口
 */
IsValidWindow(hwnd) {
    static WS_POPUP := 0x80000000
    static WS_BORDER := 0x800000
    static WS_CAPTION := 0xC00000
    static WS_CLIPSIBLINGS := 0x4000000
    static WS_DISABLED := 0x8000000
    static WS_DLGFRAME := 0x400000
    static WS_GROUP := 0x20000
    static WS_HSCROLL := 0x100000
    static WS_MAXIMIZE := 0x1000000
    static WS_MAXIMIZEBOX := 0x10000
    static WS_MINIMIZE := 0x20000000
    static WS_MINIMIZEBOX := 0x20000
    static WS_OVERLAPPED := 0x0
    static WS_OVERLAPPEDWINDOW := 0xCF0000
    static WS_POPUPWINDOW := 0x80880000
    static WS_SIZEBOX := 0x40000
    static WS_SYSMENU := 0x80000
    static WS_TABSTOP := 0x10000
    static WS_THICKFRAME := 0x40000
    static WS_VSCROLL := 0x200000
    static WS_VISIBLE := 0x10000000
    static WS_CHILD := 0x40000000
    try {
        style := WinGetStyle(hwnd)

        ; 不可见或属于子窗口的一律排除
        if !(style & WS_VISIBLE) || (style & WS_CHILD)
            return false

        ; 标题为空的窗口没有可供用户识别的标志，排除
        if (WinGetTitle(hwnd) == "")
            return false

        ; 读取 DWM 的 cloak 值
        cloakVal := GetCloakValue(hwnd)

        ; 1（DWM_CLOAKED_APP）表示窗口被程序自己隐藏，例如预加载、收起的命令面板，
        ; 这类窗口在任何桌面上都不显示，排除
        if (cloakVal == 1)
            return false

        ; 0 表示窗口就在当前桌面，2（DWM_CLOAKED_SHELL）表示它在别的虚拟桌面上；
        ; 后者切回那个桌面就能看到，仍算有效窗口

        ; 可调整大小的窗口，或同时带最大化与最小化按钮样式的窗口，才算有效
        return (style & WS_SIZEBOX) || ((style & WS_MAXIMIZEBOX) && (style & WS_MINIMIZEBOX))
    } catch {
        return false
    }
}

GetCloakValue(hwnd) {
    cloaked := 0
    ; DWMWA_CLOAKED = 14
    DllCall("dwmapi\DwmGetWindowAttribute", "ptr", hwnd, "uint", 14, "uint*", &cloaked, "uint", 4)
    return cloaked
}

/**
 * 判断活动窗口是不是抢占了焦点的弹出窗口
 *
 * 判定条件是带 WS_POPUP 样式且不能调整大小，或带 WS_POPUPWINDOW 样式且不能调整大小。
 * 这类窗口多为提示与警告，也可能是系统组件菜单，或微信表情面板这类行为特殊的窗口。
 * 它们抢到焦点时应当暂停自动激活，先把焦点留给用户处理当前窗口。
 */
ActiveWindowIsPopUp() {
    activeStyle := WinGetStyle("A")
    if (activeStyle & 0x80000000 && !(activeStyle & 0x40000) || activeStyle & 0x80880000 && !(activeStyle & 0x40000)) {
        return true
    }
}

/**
 * 判断指定窗口是不是抢占焦点的弹出窗口，判定条件与 ActiveWindowIsPopUp 相同
 */
IsPopUp(hwnd) {
    style := WinGetStyle(hwnd)
    if (style & 0x80000000 && !(style & 0x40000) || style & 0x80880000 && !(style & 0x40000)) {
        return true
    }
}

IsTopmost(hwnd) {
    try {
        exStyle := WinGetExStyle(hwnd)
        if (exStyle & 0x8)
            return true
    } catch {
    }
    return false
}
