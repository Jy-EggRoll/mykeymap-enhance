#Requires AutoHotkey v2.0

/**
 * 记录信息日志
 * @param str 要记录的日志内容
 * @param filePath 日志文件路径，默认 "*" 表示写入控制台
 * @param showConsole 如果控制台未打开，是否打开控制台
 */
LogInfo(str, filePath := "*", showConsole := false) {
    if !DllCall("GetStdHandle", "uint", -11, "ptr") {
        if showConsole {
            OpenConsole()
        }
        return
    }
    timestamp := Format("[" A_YYYY "-" A_MM "-" A_DD " " A_Hour ":" A_Min ":" A_Sec "]")
    FileAppend(timestamp " [info] " str "`n", filePath)
    if (filePath != "*") {
        LimitFileSize(filePath)
    }
}

/**
 * 记录错误日志
 * @param ErrorObj 错误对象
 * @param filePath 日志文件路径，默认 "*" 表示写入控制台
 * @param showConsole 如果控制台未打开，是否打开控制台
 */
LogError(ErrorObj, filePath := "*", showConsole := false) {
    if !DllCall("GetStdHandle", "uint", -11, "ptr") {
        if showConsole {
            OpenConsole()
        }
        return
    }
    timestamp := Format("[" A_YYYY "-" A_MM "-" A_DD " " A_Hour ":" A_Min ":" A_Sec "]")
    errorContent := ""
    errorContent .= "    错误消息：" ErrorObj.Message "`n"
    errorContent .= "    错误位置：" ErrorObj.File "（第 " ErrorObj.Line " 行）`n"
    errorContent .= "    相关对象：" ErrorObj.What "`n"
    errorContent .= "    额外信息：" ErrorObj.Extra "`n"
    errorContent .= "`n"
    FileAppend(timestamp " [error]`n" errorContent, filePath)
}

/**
 * 限制日志文件大小，超过指定大小则删除
 * @param filePath 日志文件路径
 * @param maxSizeInBytes 最大允许的文件大小，默认 1MiB，超过则删除
 */
LimitFileSize(filePath, maxSizeInBytes := 1024 * 1024) {
    if FileExist(filePath) {
        fileSize := FileGetSize(filePath)
        if (fileSize > maxSizeInBytes) {
            FileDelete(filePath)
        }
    }
}

OpenConsole() {
    if !DllCall("GetStdHandle", "uint", -11, "ptr")
        DllCall("AllocConsole")
}
