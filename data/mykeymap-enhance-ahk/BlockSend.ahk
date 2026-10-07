#Requires AutoHotkey v2.0

#Include ./LoggerLib/Logger.ahk

class BlockSendDebug {
    static mode := false
}

BlockSend(text) {
    ; 备份当前剪贴板内容，以免丢失用户之前复制的东西
    ClipSaved := ClipboardAll()

    try {
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
    } finally {
        ; 恢复必须放在 finally：超时的 return 或中途抛出的异常都不能跳过一次恢复，
        ; 否则用户原有的剪贴板内容会被这次调用永久覆盖。
        ; Sleep 是给目标程序留出读取剪贴板的时间，放在恢复之前。
        Sleep 100
        A_Clipboard := ClipSaved
    }
}
