#Requires AutoHotkey v2.0

#Include ./LoggerLib/Logger.ahk

class BlockSendDebug {
    static mode := true
}

BSend(text) {
    A_Clipboard := text
    LogInfo("成功发送文本：" text, , BlockSendDebug.mode)
    Send("^v")
}
