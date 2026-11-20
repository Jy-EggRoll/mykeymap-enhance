#Requires AutoHotkey v2.0

#Include ./LoggerLib/Logger.ahk

class BlockSendDebug {
    static mode := false
}

; 返回 true 表示粘贴成功，false 表示等待剪贴板超时
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

; 按 blockSize 分块读取文件并逐块粘贴，块与块之间留出 interChunkDelay 的间隔，
; 给目标窗口留出处理上一块的时间
; maxFileBytes 是文件大小上限，单位为字节，默认 10 MiB（10485760 字节），设为 0 表示不检查
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
