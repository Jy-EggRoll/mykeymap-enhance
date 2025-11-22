#Requires AutoHotkey v2.0

#Include Logger.ahk

class BlockSendDebug {
    static mode := false
}

BSend(text) {
    A_Clipboard := text
    LogInfo("成功发送文本：" text, , BlockSendDebug.mode)
    Send("^v")
}
