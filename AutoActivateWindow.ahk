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
 * 实际执行激活操作的函数，内置了排除列表
 */
ActivateWindowUnderMouse() {
    MouseGetPos , , &targetID
    if (A_TimeIdlePhysical >= 500) {

        condition :=
            WinExist("A") &&  ; 确保有活动窗口，修复按下 Win 键时的报错问题
            targetID &&  ; 确保有 ID
            targetID != WinActive("A") &&  ; 确保当前未激活
            WinGetTitle(targetID) &&  ; 确保有 title，用于排除右键菜单，避免右键菜单点击后就消失
            WinGetProcessName(targetID) != "StartMenuExperienceHost.exe" &&  ; 排除开始菜单，开始菜单在窗口自动激活时极易出现难以逆转的问题
            WinGetProcessName("A") != "MyKeymap.exe" &&  ; 排除 MyKeymap 本身，主要保证亮度调整窗口不会消失
            WinGetProcessName("A") != "Listary.exe" &&  ; 排除 Listary 的弹出窗口
            WinGetClass("A") != "Qt691QWindowPopupDropShadowSaveBits"  ; 排除 Sandboxie Plus 右键菜单

        if (condition) {
            WinActivate(targetID)
        }
    }
}
