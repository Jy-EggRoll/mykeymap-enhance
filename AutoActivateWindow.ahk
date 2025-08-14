#Requires AutoHotkey v2.0

; 全局变量用于跟踪自动激活功能的状态
global autoActivateEnabled := false

/**
 * 切换自动激活窗口的开启状态，是一个开关函数
 */
AutoActivateWindow() {
    global autoActivateEnabled

    if (!autoActivateEnabled) {
        ; 当前未激活，执行启动逻辑
        SetTimer(ActivateWindowUnderMouse, 50)  ; 启动定时器，每 50 ms 检查一次
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
 */
ActivateWindowUnderMouse() {
    MouseGetPos , , &targetID
    if (A_TimeIdleMouse >= 500) {
        ; 排除了开始菜单，自动聚焦易引起开始菜单 bug
        if (targetID && targetID != WinActive("A") && WinGetTitle(targetID) && WinGetProcessName(targetID) !=
        "StartMenuExperienceHost.exe") {
            WinActivate(targetID)
        }
    }
}
