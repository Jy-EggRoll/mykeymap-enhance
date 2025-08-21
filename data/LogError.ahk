#Requires AutoHotkey v2.0

; 错误日志函数：将错误详情写入日志文件
LogError(ErrorObj, logFilePath := "ErrorLog.txt") {
    ; 格式化当前时间（年-月-日 时:分:秒）
    currentTime := FormatTime(, "yyyy-MM-dd HH:mm:ss")

    ; 构建日志内容（包含完整错误信息）
    logContent := "[" currentTime "]`n"
    logContent .= "错误消息：" ErrorObj.Message "`n"
    logContent .= "错误位置：" ErrorObj.File "（第 " ErrorObj.Line " 行）`n"
    logContent .= "相关对象：" ErrorObj.What "`n"
    logContent .= "额外信息：" ErrorObj.Extra "`n"
    logContent .= "----------`n"  ; 分隔符

    ; 检查并处理过大的日志文件
    if FileExist(logFilePath) {
        fileSize := FileGetSize(logFilePath)
        if (fileSize > 1024 * 1024) {  ; 大于 1 MiB 直接删除，避免占用用户过大的空间
            FileDelete(logFilePath)
        }
    }

    ; 写入日志文件（若文件不存在则自动创建）
    FileAppend logContent, logFilePath, "UTF-8"  ; 使用UTF-8编码，避免中文乱码
}
