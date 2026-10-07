#Requires AutoHotkey v2.0

/**
 * 记录信息日志
 * @param str 要记录的日志内容
 * @param filePath 日志文件路径，默认 "*" 表示写入控制台
 * @param showConsole 如果控制台未打开，是否打开控制台
 */
LogInfo(str, filePath := "*", showConsole := false) {
    WriteLog("info", str, filePath, showConsole, 0x07)
}

/**
 * 记录警告日志
 * @param str 要记录的日志内容
 * @param filePath 日志文件路径，默认 "*" 表示写入控制台
 * @param showConsole 如果控制台未打开，是否打开控制台
 */
LogWarn(str, filePath := "*", showConsole := false) {
    WriteLog("warn", str, filePath, showConsole, 0x0E)
}

/**
 * 记录错误日志
 * @param ErrorObj 错误对象
 * @param filePath 日志文件路径，默认 "*" 表示写入控制台
 * @param showConsole 如果控制台未打开，是否打开控制台
 */
LogError(ErrorObj, filePath := "*", showConsole := false) {
    if showConsole {
        OpenConsole()
    } else if (filePath = "*") {
        return
    }

    timestamp := Format("[" A_YYYY "-" A_MM "-" A_DD " " A_Hour ":" A_Min ":" A_Sec "]")
    errorContent := timestamp " [error]`n"
    errorContent .= "    错误消息：" ErrorObj.Message "`n"
    errorContent .= "    错误位置：" ErrorObj.File "（第 " ErrorObj.Line " 行）`n"
    errorContent .= "    相关对象：" ErrorObj.What "`n"
    errorContent .= "    额外信息：" ErrorObj.Extra "`n"
    errorContent .= "`n"

    if (filePath = "*") {
        SetConsoleColor(0x0C)
        FileAppend(errorContent, filePath)
        ResetConsoleColor()
    } else {
        FileAppend(errorContent, filePath)
        LimitFileSize(filePath)
    }
}

/**
 * 记录日志并在 CMD 控制台中设置颜色
 */
WriteLog(level, str, filePath, showConsole, colorAttr) {
    if showConsole {
        OpenConsole()
    } else if (filePath = "*") {
        return
    }

    timestamp := Format("[" A_YYYY "-" A_MM "-" A_DD " " A_Hour ":" A_Min ":" A_Sec "]")
    logLine := timestamp " [" level "] " str "`n"

    if (filePath = "*") {
        SetConsoleColor(colorAttr)
        FileAppend(logLine, filePath)
        ResetConsoleColor()
    } else {
        FileAppend(logLine, filePath)
        LimitFileSize(filePath)
    }
}

/**
 * 控制台默认属性缓存
 * 必须在改色之前取值：ResetConsoleColor 若等到改色之后才首次取值，拿到的就是
 * 日志等级色，会被当作"默认色"写回，控制台颜色从此不再复位。
 */
class ConsoleColorState {
    static defaultAttr := ""
}

/**
 * 设置控制台前景颜色
 * @param attr 控制台颜色属性
 */
SetConsoleColor(attr) {
    hConsole := DllCall("GetStdHandle", "int", -11, "ptr")
    if !hConsole || hConsole = -1
        return

    ; 首次改色之前记录原始属性，供 ResetConsoleColor 还原
    if (ConsoleColorState.defaultAttr = "")
        ConsoleColorState.defaultAttr := GetConsoleTextAttribute()

    DllCall("SetConsoleTextAttribute", "ptr", hConsole, "ushort", attr)
}

/**
 * 复位控制台前景颜色
 * 还原的是首次改色之前捕获的默认属性，见 ConsoleColorState
 */
ResetConsoleColor() {
    hConsole := DllCall("GetStdHandle", "int", -11, "ptr")
    if !hConsole || hConsole = -1
        return

    if (ConsoleColorState.defaultAttr = "")
        ConsoleColorState.defaultAttr := GetConsoleTextAttribute()

    DllCall("SetConsoleTextAttribute", "ptr", hConsole, "ushort", ConsoleColorState.defaultAttr)
}

GetConsoleTextAttribute() {
    hConsole := DllCall("GetStdHandle", "int", -11, "ptr")
    if !hConsole || hConsole = -1
        return 0x07

    ; CONSOLE_SCREEN_BUFFER_INFO 的布局（2 字节对齐，共 22 字节）：
    ; dwSize(偏移 0) + dwCursorPosition(4) + wAttributes(8) + srWindow(10) + dwMaximumWindowSize(18)。
    ; 颜色属性只占 2 字节且在偏移 8；偏移 16 落在 srWindow.Bottom 上，读出来的不是颜色。
    csbi := Buffer(22)
    if DllCall("GetConsoleScreenBufferInfo", "ptr", hConsole, "ptr", csbi) {
        return NumGet(csbi, 8, "UShort")
    }

    return 0x07
}

/**
 * 打开控制台（如果尚未打开）
 */
OpenConsole() {
    handle := DllCall("GetStdHandle", "int", -11, "ptr")
    if !handle || handle = -1
        DllCall("AllocConsole")
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
