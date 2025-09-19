#Requires AutoHotkey v2.0

#Include LogError.ahk

; 全局变量用于跟踪自动激活功能的状态
global autoActivateEnabled := false
global mousePos := [0, 0]

/**
 * 切换自动激活窗口的开启状态，是一个开关函数
 * @param pollingTime 轮询时间，默认为 20 ms
 */
AutoActivateWindow(pollingTime := 20) {
    global autoActivateEnabled

    if (!autoActivateEnabled) {
        ; 当前未激活，执行启动逻辑
        SetTimer(ActivateWindowUnderMouse, pollingTime)  ; 启动定时器，给予用户选择轮询时间的自由度，轮询时间越长，对于进入“待激活”模式的鼠标移动幅度的允许范围就越大
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
 * @param timeoutMouse 激活的鼠标等待时间，默认为 100 ms
 * @param mouseMovementAmplitude 鼠标移动幅度，默认为正负 50 像素
 */
ActivateWindowUnderMouse(timeoutMouse := 100, mouseMovementAmplitude := 50) {
    global mousePos
    MouseGetPos(&mouseX, &mouseY, &targetID)
    try {
        static pendingActivation := false
        if ((Abs(mouseX - mousePos[1]) > mouseMovementAmplitude || Abs(mouseY - mousePos[2]) > mouseMovementAmplitude) &&
        A_TimeIdleMouse >= timeoutMouse) {  ; 宽高 2 * mouseMovementAmplitude px 区域的点击容错
            ; 鼠标位置在 pollingTime ms 内发生了明显移动，且有 timeoutMouse ms 的时间没有移动了，则启用“待激活”模式
            pendingActivation := true
            ; ToolTip("启动待激活模式")
            ; SetTimer(ToolTip, -1000)
            mousePos := [mouseX, mouseY]  ; 立即更新位置
        }

        ; 如果处于“待激活”模式
        if (pendingActivation) {
            ; ToolTip(pendingActivation)
            ; SetTimer(ToolTip, -1000)
            if (JudgeActivate(targetID)) {
                WinActivate(targetID)
                ; ToolTip("已触发激活")
                ; SetTimer(ToolTip, -1000)
            }
            ; 不论激活是否成功，都重置待激活状态
            pendingActivation := false
        }
    }
    catch Error as e {
        ; ToolTip(e.Message)
        ; SetTimer(ToolTip, -1000)
    }
}

/**
 * 判断是否激活的函数，能处理更多样和复杂的情况，舍弃了一长串逻辑判断的方式
 */
JudgeActivate(targetID) {

    ; 将所有 WinGet 函数的结果存储在变量中，避免重复调用，提高性能
    existA := WinExist("A")
    traywndPopupExist := WinExist("ahk_class Xaml_WindowedPopupClass")
    processNameA := WinGetProcessName("A")
    classTarget := WinGetClass(targetID)
    classA := WinGetClass("A")
    titleA := WinGetTitle("A")
    processNameTarget := WinGetProcessName(targetID)
    styleA := WinGetStyle("A")
    styleTarget := WinGetStyle(targetID)

    if (existA == 0) {  ; 确保有激活窗口，抑制不必要的错误写入
        return false
    }

    ; 使用静态 Map 存储需要排除的进程名，只在脚本第一次运行时创建一次
    ; 此项目前专注于处理“失去焦点就会关闭”的窗口
    static ExcludedProcessNameA := Map(
        ; "StartMenuExperienceHost.exe", true,  ; 排除开始菜单的右键菜单
        ; "SearchHost.exe", true,  ; 排除 Win 11 开始菜单
        ; "SearchApp.exe", true,  ; 排除 Win 10 开始菜单
        ; "ShellHost.exe", true,  ; 排除控制面板等（和 Win + a 启动的一致）
        ; "ShellExperienceHost.exe", true,  ; 排除消息面板（和 Win + n 启动的一致）
        "MyKeymap.exe", true,  ; 排除 MyKeymap 的部分窗口，如亮度调节窗口
        "Listary.exe", true  ; 排除 Listary 的搜索窗口
    )
    if (ExcludedProcessNameA.Has(processNameA)) {
        return false
    }

    ; ; 使用静态 Map 存储需要排除的 target 类名
    ; static ExcludedClassTarget := Map(
    ;     "Progman", true,  ; 排除桌面
    ;     "AutoHotkeyGUI", true  ; 排除 InputTip 的悬浮提示
    ; )
    ; if (ExcludedClassTarget.Has(classTarget)) {
    ;     return false
    ; }

    ; 使用静态 Map 存储需要排除的 A 类名
    static ExcludedClassA := Map(
        "Progman", true,  ; 桌面，保证用户点击桌面后，功能仍正常
        "Shell_TrayWnd", true,  ; 任务栏，保证用户点击任务栏后，功能仍正常
        "ApplicationFrameWindow", true  ; 设置，保证用户点击了设置后，功能仍正常
    )

    if (styleA & 0x80000000 && !(styleA & 0x40000) || styleA & 0x80880000 && !(styleA & 0x40000)) {
        ; 如果活动窗口【具有 WS_POPUP 样式同时不能调节窗口大小】或者【具有 WS_POPUPWINDOW 样式且不能调整大小】，则是一个抢夺了焦点的弹出窗口，通常，这些窗口具有提示、警告作用，或者是部分高优先级系统组件菜单，又或是一些具有奇怪逻辑的组件（比如微信、微信的的表情面板）。当它们出现并抢夺了焦点时，自动激活功能应该停止，以确保这些窗口出现在前台，让用户处理
        if (ExcludedClassA.Has(classA)) {  ; 在这些窗口中，也有一些异类，比如设置、桌面，在点击这些地方后，激活的窗口将具有 popup 属性，此时激活其他窗口功能会被终止，这是不应该的，所以做了二次处理
            if (traywndPopupExist) {  ; 防止 Windows 徽标键右键菜单因失去焦点而消失，适用于点击或触发 Win + x 的情况
                return false
            }
            return true
        }
        return false
    }

    ;【记录：一些高优先级的窗口拥有高度一致的特性，这些特性出现在开始菜单、桌面、浏览器部分弹出窗口上】
    /**
     *     ○ WS_BORDER (0x800000)
     *     ● WS_POPUP (0x80000000)
     *     ○ WS_CAPTION (0xC00000)
     *     ● WS_CLIPSIBLINGS (0x4000000)
     *     ○ WS_DISABLED (0x8000000)
     *     ○ WS_DLGFRAME (0x400000)
     *     ○ WS_GROUP (0x20000)
     *     ○ WS_HSCROLL (0x100000)
     *     ○ WS_MAXIMIZE (0x1000000)
     *     ○ WS_MAXIMIZEBOX (0x10000)
     *     ○ WS_MINIMIZE (0x20000000)
     *     ○ WS_MINIMIZEBOX (0x20000)
     *     ○ WS_OVERLAPPED (0x0)
     *     ○ WS_OVERLAPPEDWINDOW (0xCF0000)
     *     ● WS_POPUPWINDOW (0x80880000)
     *     ○ WS_SIZEBOX (0x40000)
     *     ○ WS_SYSMENU (0x80000)
     *     ○ WS_TABSTOP (0x10000)
     *     ○ WS_THICKFRAME (0x40000)
     *     ○ WS_VSCROLL (0x200000)
     *     ● WS_VISIBLE (0x10000000)
     *     ○ WS_CHILD (0x40000000)
     */

    if (styleTarget & 0x40000) {  ; 如果可以调整大小，通常才是正常的窗口
        return true
    }
    return false
}
