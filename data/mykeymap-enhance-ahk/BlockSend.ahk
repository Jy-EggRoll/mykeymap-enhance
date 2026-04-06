#Requires AutoHotkey v2.0

#Include ./LoggerLib/Logger.ahk

class BlockSendDebug {
    static mode := false
}

BlockSend(text) {
    ; 备份当前剪贴板内容，以免丢失用户之前复制的东西
    ClipSaved := ClipboardAll()

    ; 清空并设置新内容
    A_Clipboard := ""
    A_Clipboard := text

    ; 等待剪贴板填充完成（防止由于写入延迟导致粘贴旧内容）
    if !ClipWait(2) {
        ToolTip("剪贴板超时，提前终止")
        SetTimer(ToolTip, -2000)
        return
    }

    ; 执行粘贴
    Send("^v")

    ; 恢复原始内容
    Sleep 100
    A_Clipboard := ClipSaved
}
