#Requires AutoHotkey v2.0

ReadFileToInput(filePath) {
    if !FileExist(filePath) {
        ToolTip("错误: 文件不存在 " . filePath)
        SetTimer(ToolTip, -1000)
        return
    }

    fileSize := FileGetSize(filePath)
    if (fileSize > 10240) {
        ToolTip("错误: 不允许读取超过 10KB 的文本")
        SetTimer(ToolTip, -1000)
        return
    }

    try {
        fileContent := FileRead(filePath)
        if RegExMatch(fileContent, "[\r\n]") {
            ToolTip("错误: 不允许读取含多行内容的文本")
            SetTimer(ToolTip, -1000)
            return
        }
        SendText(fileContent)
    } catch Error as err {
        MsgBox("读取失败: " . err.Message)
    }
}
