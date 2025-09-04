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
    MouseGetPos(, , &targetID)
    try {
        if (A_TimeIdleMouse >= timeout && JudgeActivate(targetID)) {
            WinActivate(targetID)
        }
    }
    catch Error as e {
        LogError(e, "AutoActivateWindow_Error.log")  ; 写入错误日志，避免打扰用户，这是由于本 ahk 的错误提示通常都可以被安全地忽略
    }
}

/**
 * 判断是否激活的函数，能处理更多样和复杂的情况，舍弃了一长串逻辑判断的方式
 */
JudgeActivate(targetID) {
    ; 将所有 WinGet 函数的结果存储在变量中，避免重复调用，提高性能
    existA := WinExist("A")
    processNameA := WinGetProcessName("A")
    classTarget := WinGetClass(targetID)
    classA := WinGetClass("A")
    titleA := WinGetTitle("A")
    processNameTarget := WinGetProcessName(targetID)

    if (existA == 0) {  ; 确保有激活窗口，抑制不必要的报错
        return false
    }

    ; 使用静态 Map 存储需要排除的进程名，只在脚本第一次运行时创建一次
    static ExcludedProcessNameA := Map(
        "StartMenuExperienceHost.exe", true,  ; 排除开始菜单的右键菜单
        "SearchHost.exe", true,  ; 排除 Win 11 开始菜单
        "SearchApp.exe", true,  ; 排除 Win 10 开始菜单
        "ShellHost.exe", true,  ; 排除控制面板等（和 Win + a 启动的一致）
        "ShellExperienceHost.exe", true,  ; 排除消息面板（和 Win + n 启动的一致）
        "MyKeymap.exe", true,  ; 排除 MyKeymap 的部分窗口
        "Listary.exe", true  ; 排除 Listary 的搜索窗口
    )
    if (ExcludedProcessNameA.Has(processNameA)) {
        return false
    }

    ; 使用静态 Map 存储需要排除的 target 类名
    static ExcludedClassTarget := Map(
        "Progman", true,  ; 排除桌面
        "AutoHotkeyGUI", true  ; 排除 InputTip 的悬浮提示
    )
    if (ExcludedClassTarget.Has(classTarget)) {
        return false
    }

    ; 使用静态 Map 存储需要排除的 A 类名
    static ExcludedClassA := Map(
        "Qt691QWindowPopupDropShadowSaveBits", true,  ; Sandboxie 的托盘右键窗口
        "Qt51513QWindowPopupSaveBits", true  ; PixPin 的托盘右键窗口
    )
    if (ExcludedClassA.Has(classA)) {
        return false
    }

    if (titleA == "") {  ; 如果当前激活的窗口没有 title，此情况较复杂，再加以讨论
        ; 为什么要进一步讨论？
        ; 当鼠标点击任务栏、软件窗口关闭后，都会出现“无 title”的状态
        if (processNameA == "msedge.exe") {  ; 是 Edge 浏览器中抢夺了焦点的一些次级窗口，比如 Ctrl + f 唤出的搜索框
            return false
        }
    }

    if (WinGetTitle(targetID) == "") {  ; 如果当前鼠标下的窗口没有 title，一般可以认为是软件内的特殊窗口，应该被排除，比如浏览器的右键菜单等。这些小部件不会获得焦点，只能用鼠标位置判定
        return false
    }

    if (processNameTarget == processNameA) {  ; 鼠标下的窗口进程名和现在激活的进程名一致
        if (classTarget != classA) {  ; 若鼠标下的类名和激活的类名不一致，可能是触发了小的次级窗口，比如文件管理器右键菜单，应该被排除
            return false
            ; 如果二者的类名和进程名均一致，通常可以认为就是同一软件的多窗口情况，比如打开的多个浏览器独立窗口、多个文件管理器独立窗口
        }
    }

    return true
}

AutoActivateWindow()  ; MyKeymap 启动时自动执行
