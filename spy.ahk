#Requires AutoHotkey v2.0

/**
 * 启动窗口监视，用于调试功能
 */
StartSpy() {
    SetTimer WatchCursor, 100

    WatchCursor() {
        MouseGetPos , , &id, &control
        ToolTip
        (
        "ahk_id: " id "
        ahk_class: " WinGetClass(id) "
        Title: " WinGetTitle(id) "
        Control: " control
        )
    }
}
