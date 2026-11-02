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
        ; 必须显式指定编码：省略时按 A_FileEncoding 读取，即系统 ANSI 代码页（CP0），
        ; 无 BOM 的 UTF-8 文本会被读成乱码再被 SendText 发出去。
        fileContent := FileRead(filePath, "UTF-8")
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
