#Requires AutoHotkey v2.0

#Include ./LoggerLib/Logger.ahk

class BlockSendDebug {
    static mode := false
}

; 返回 true/false 表示粘贴是否成功
BlockSend(text) {
    ClipSaved := ClipboardAll()

    try {
        A_Clipboard := ""
        A_Clipboard := text

        if !ClipWait(2) {
            ToolTip("剪贴板超时，提前终止")
            SetTimer(ToolTip, -2000)
            return false
        }

        Send("^v")
        return true
    } finally {
        Sleep 100
        A_Clipboard := ClipSaved
    }
}

; 读取文件并按块发送
; maxFileBytes 为可选的文件大小上限，单位为字节，默认 10 MB（10 * 1024 * 1024）
; 将 maxFileBytes 设为 0 表示不检查文件大小
BlockSendFile(filePath, blockSize := 2000, interChunkDelay := 200, maxFileBytes := 10 * 1024 * 1024) {
    if !FileExist(filePath) {
        ToolTip("文件不存在：" filePath)
        SetTimer(ToolTip, -2000)
        return false
    }

    file := ""
    try {
        file := FileOpen(filePath, "r", "UTF-8")
        if !file {
            ToolTip("无法打开文件：" filePath)
            SetTimer(ToolTip, -2000)
            return false
        }

        ; 仅当 maxFileBytes 大于 0 时检查文件大小
        if (maxFileBytes > 0 && file.Length > maxFileBytes) {
            ToolTip("文件超过大小上限：" file.Length " 字节（上限 " maxFileBytes " 字节）")
            SetTimer(ToolTip, -2000)
            return false
        }

        while !file.AtEOF {
            chunk := file.Read(blockSize)
            if (chunk = "")
                break

            if !BlockSend(chunk) {
                return false
            }

            if !file.AtEOF
                Sleep interChunkDelay
        }

        return true
    } finally {
        if IsObject(file)
            file.Close()
    }
}
