#Requires AutoHotkey v2.0

/**
 * 判断窗口是否为有效的可激活窗口
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

        ; 基础过滤：如果不可见，或者如果是子窗口，排除
        if !(style & WS_VISIBLE) || (style & WS_CHILD)
            return false

        ; 如果没有标题，排除
        if (WinGetTitle(hwnd) == "")
            return false

        ; 精细化处理 Cloak 状态
        cloakVal := GetCloakValue(hwnd)

        ; 如果 cloaked == 1 (DWM_CLOAKED_APP)，说明是程序启动后的预加载/后台隐藏（如命令面板）
        ; 这种窗口通常无论你在哪个桌面，它都不会显示出来，应该排除
        if (cloakVal == 1)
            return false

        ; 注意：如果在当前桌面，cloakVal 是 0
        ; 如果在其他桌面，cloakVal 是 2 DWM_CLOAKED_SHELL
        ; 这两种情况都视为“有效窗口”

        ; 样式过滤，必须可调大小，或者至少两个按钮（即使是隐藏的）
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
 * 如果活动窗口【具有 WS_POPUP 样式同时不能调节窗口大小】或者【具有 WS_POPUPWINDOW 样式且不能调整大小】，则是一个抢夺了焦点的弹出窗口，通常，这些窗口具有提示、警告作用，或者是部分高优先级系统组件菜单，又或是一些具有奇怪逻辑的组件（比如微信、微信的的表情面板）。当它们出现并抢夺了焦点时，自动激活功能应该停止，以确保这些窗口出现在前台，让用户处理
 */
ActiveWindowIsPopUp() {
    activeStyle := WinGetStyle("A")
    if (activeStyle & 0x80000000 && !(activeStyle & 0x40000) || activeStyle & 0x80880000 && !(activeStyle & 0x40000)) {
        return true
    }
}

/**
 * 判断 hwnd 是否是弹出窗口
 */
IsPopUp(hwnd) {
    style := WinGetStyle(hwnd)
    if (style & 0x80000000 && !(style & 0x40000) || style & 0x80880000 && !(style & 0x40000)) {
        return true
    }
}

IsTopmost(hwnd) {
    style := WinGetStyle(hwnd)
    if (style & 0x8) {
        return true
    }
}
