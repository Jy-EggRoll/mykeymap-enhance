#Requires AutoHotkey v2.0

#Include LogError.ahk

; 全局变量用于跟踪自动激活功能的状态
global autoActivateEnabled := false

/**
 * 切换自动激活窗口的开启状态，是一个开关函数
 */
AutoActivateWindow() {
    global autoActivateEnabled

    if (!autoActivateEnabled) {
        ; 当前未激活，执行启动逻辑
        SetTimer(ActivateWindowUnderMouse, 50)  ; 启动定时器，每 50 ms 检查一次，对性能的影响微乎其微
        autoActivateEnabled := true
        ToolTip("自动激活窗口已启动")
        SetTimer(ToolTip, -1000)  ; 1 秒后隐藏提示
    } else {
        ; 当前已激活，执行停止逻辑
        SetTimer(ActivateWindowUnderMouse, 0)  ; 停止定时器
        autoActivateEnabled := false
        ToolTip("自动激活窗口已停止")
        SetTimer(ToolTip, -1000)  ; 1 秒后隐藏提示
    }
}

/**
 * 实际执行激活操作的函数
 * @param timeout 激活的触发等待时间，默认为 500 ms
 */
ActivateWindowUnderMouse(timeout := 500) {
    MouseGetPos , , &targetID
    try {
        if (A_TimeIdleMouse >= timeout && JudgeActivate(targetID)) {
            WinActivate(targetID)
        }
    }
    catch Error as e {
        LogError(e, "AutoActivateWindow_Error.log")  ; 写入错误日志，避免打扰用户
    }
}

/**
 * 判断是否激活的函数，能处理更多样和复杂的情况，舍弃了一长串逻辑判断的方式
 */
JudgeActivate(targetID) {
    if (WinGetProcessName("A") == "StartMenuExperienceHost.exe" ||  ; 排除开始菜单的右键菜单
        WinGetProcessName("A") == "SearchHost.exe" ||  ; 排除 Win 11 开始菜单
        WinGetProcessName("A") == "SearchApp.exe" ||  ; 排除 Win 10 开始菜单
        WinGetProcessName("A") == "ShellHost.exe" ||  ; 排除控制面板等（和 Win + a 启动的一致）
        WinGetProcessName("A") == "ShellExperienceHost.exe" ||  ; 排除消息面板（和 Win + n 启动的一致）
        WinGetProcessName("A") == "MyKeymap.exe" ||  ; 排除 MyKeymap 的部分窗口
        WinGetProcessName("A") == "Listary.exe"
    ) {  ; 排除 Listary 的搜索窗口
        return false
    }
    if (WinGetClass(targetID) == "Progman" ||  ; 排除桌面，鼠标移到桌面上就激活桌面是非必要的
        WinGetClass("A") == "Qt691QWindowPopupDropShadowSaveBits"  ; Sandboxie 的托盘右键窗口，这个窗口比较特殊，必须独立排除
    ) {
        return false
    }
    if (WinGetTitle("A") == "") {  ; 如果当前激活的窗口没有 title，一般可以认为是软件内的特殊窗口，应该被排除，比如浏览器 Ctrl + f 触发的搜索小窗口等
        return false
    }
    if (WinGetTitle(targetID) == "") {  ; 如果当前鼠标下的窗口没有 title，一般可以认为是软件内的特殊窗口，应该被排除，比如浏览器的右键菜单等
        return false
    }
    if (WinGetProcessName(targetID) == WinGetProcessName("A")) {  ; 鼠标下的窗口进程名和现在激活的进程名一致
        if (WinGetClass(targetID) != WinGetClass("A")) {  ; 若鼠标下的类名和激活的类名不一致，可能是触发了小的次级窗口，比如文件管理器右键菜单，应该被排除
            return false
            ; 如果二者的类名和进程名均一致，通常可以认为就是同一软件的多窗口情况，比如打开的多个浏览器独立窗口、多个文件管理器独立窗口
        }
    }
    return true
}
