#Requires AutoHotkey v2.0

SetTimer WatchCursor, 10

WatchCursor() {
    MouseGetPos , , &id, &control
    ToolTip
    (
        "ahk_id " id "
        ahk_class " WinGetClass(id) "
        " WinGetTitle(id) "
        Control: " control
    )
}
