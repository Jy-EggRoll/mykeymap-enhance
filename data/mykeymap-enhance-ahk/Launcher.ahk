#Requires AutoHotkey v2.0

#NoTrayIcon

#SingleInstance Force

#Include ./LoggerLib/Logger.ahk

PIPE_NAME := "\\.\pipe\MyKeymapLauncher"

class LauncherDebug {
    static mode := true
}

RunLauncher() {
    global PIPE_NAME
    LogInfo("启动命名管道服务器: " PIPE_NAME, , LauncherDebug.mode)

    while true {
        try {
            pipe := DllCall("CreateNamedPipe"
                , "Str", PIPE_NAME
                , "UInt", 0x3
                , "UInt", 0
                , "UInt", 1
                , "UInt", 4096
                , "UInt", 4096
                , "UInt", 0
                , "Ptr", 0
                , "Ptr")

            if (pipe = -1 || pipe = 0) {
                LogInfo("创建管道失败", , LauncherDebug.mode)
                Sleep(1000)
                continue
            }

            LogInfo("等待连接...", , LauncherDebug.mode)
            if (DllCall("ConnectNamedPipe", "Ptr", pipe, "Ptr", 0) = 0 && A_LastError != 535) {
                DllCall("CloseHandle", "Ptr", pipe)
                continue
            }

            LogInfo("客户端已连接", , LauncherDebug.mode)

            buf := Buffer(4096, 0)
            bytesRead := 0
            DllCall("ReadFile", "Ptr", pipe, "Ptr", buf, "UInt", 4096, "UIntP", &bytesRead, "Ptr", 0)
            DllCall("DisconnectNamedPipe", "Ptr", pipe)
            DllCall("CloseHandle", "Ptr", pipe)

            if (bytesRead > 0) {
                targetPath := StrGet(buf, bytesRead, "UTF-8")
                targetPath := Trim(targetPath, "`"")
                LogInfo("收到启动请求: " targetPath, , LauncherDebug.mode)

                try {
                    Run(targetPath)
                    LogInfo("启动成功", , LauncherDebug.mode)
                } catch as e {
                    LogError(e, , LauncherDebug.mode)
                }
            }
        } catch as e {
            LogError(e, , LauncherDebug.mode)
            Sleep(1000)
        }
    }
}

LogInfo("Launcher 启动", , LauncherDebug.mode)
RunLauncher()