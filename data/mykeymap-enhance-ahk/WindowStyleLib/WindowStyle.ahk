#Requires AutoHotkey v2.0

/**
 * 判断窗口是否为有效的可激活窗口
 */
IsValidWindow(hwnd) {
    try {
        style := WinGetStyle(hwnd)

        ; 1. 基础过滤：必须可见且非子窗口
        if !(style & 0x10000000) || (style & 0x40000000)
            return false

        ; 2. 标题过滤
        if (WinGetTitle(hwnd) == "")
            return false

        ; 3. 核心：精细化处理 Cloak 状态
        cloakVal := GetCloakValue(hwnd)

        ; 如果 cloaked == 1 (DWM_CLOAKED_APP)，说明是程序启动后的预加载/后台隐藏（如命令面板）
        ; 这种窗口通常无论你在哪个桌面，它都不会显示出来，应该排除。
        if (cloakVal == 1)
            return false

        ; 注意：如果你在当前桌面，cloakVal 是 0
        ; 如果在其他桌面，cloakVal 是 2 (DWM_CLOAKED_SHELL)
        ; 这两种情况我们都视为“有效窗口”

        ; 4. 样式过滤
        return (style & 0x00C00000) || (style & 0x00040000)
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
