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
