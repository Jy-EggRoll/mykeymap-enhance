#Requires AutoHotkey v2.0

#Include LogError.ahk

; 全局变量用于跟踪自动激活功能的状态
global autoActivateEnabled := false
global mousePos := [0, 0]
global windowStates := Map()  ; 窗口状态映射表
global maintenanceTimer := 0  ; 维护定时器

/**
 * 窗口状态类，用于记录每个窗口的信息
 */
class WindowState {
    __New(hwnd) {
        this.hwnd := hwnd
        this.mouseVisited := false  ; 鼠标是否访问过此窗口
        this.lastSeen := A_TickCount  ; 最后一次发现此窗口的时间
    }
}

/**
 * 切换自动激活窗口的开启状态，是一个开关函数
 * @param pollingTime 轮询时间，默认为 20 ms
 */
AutoActivateWindow(pollingTime := 20) {
    global autoActivateEnabled, maintenanceTimer

    if (!autoActivateEnabled) {
        ; 当前未激活，执行启动逻辑
        SetTimer(ActivateWindowUnderMouse, pollingTime)  ; 启动主要逻辑定时器
        SetTimer(MaintainWindowStates, 50)  ; 启动窗口状态维护定时器，每 50 ms 执行一次

        ; 初始化现有窗口状态，将当前所有窗口标记为已访问
        InitializeExistingWindows()

        autoActivateEnabled := true
        ToolTip("自动激活窗口已启动")
        SetTimer(ToolTip, -1000)  ; 1 秒后隐藏提示
    } else {
        ; 当前已激活，执行停止逻辑
        SetTimer(ActivateWindowUnderMouse, 0)  ; 停止主要逻辑定时器
        SetTimer(MaintainWindowStates, 0)  ; 停止窗口状态维护定时器
        autoActivateEnabled := false
        ; 清空窗口状态记录
        global windowStates
        windowStates := Map()
        ToolTip("自动激活窗口已停止")
        SetTimer(ToolTip, -1000)  ; 1 秒后隐藏提示
    }
}

/**
 * 初始化现有窗口状态，将所有当前窗口标记为已访问
 * 这样脚本启动时不会因为现有窗口而被阻断
 */
InitializeExistingWindows() {
    global windowStates

    try {
        DetectHiddenWindows(false)
        windowList := WinGetList()

        loop windowList.Length {
            hwnd := windowList[A_Index]
            if (WinExist(hwnd) && IsValidWindow(hwnd)) {
                if (!windowStates.Has(hwnd)) {
                    state := WindowState(hwnd)
                    state.mouseVisited := true  ; 将现有窗口标记为已访问
                    windowStates[hwnd] := state
                }
            }
        }
    } catch Error as e {
        ; 静默处理错误
    }
}

/**
 * 维护窗口状态列表，每 50ms 执行一次
 * 1. 检查并移除已不存在的窗口
 * 2. 发现新窗口并添加到列表
 * 3. 检查是否有未访问的窗口，如有则禁用自动激活
 */
MaintainWindowStates() {
    global windowStates, autoActivateEnabled

    try {
        ; 获取当前所有可见窗口
        currentWindows := []

        ; 枚举所有顶级窗口
        DetectHiddenWindows(false)
        windowList := WinGetList()

        ; 收集当前存在的窗口
        currentWindowsMap := Map()
        loop windowList.Length {
            hwnd := windowList[A_Index]
            if (WinExist(hwnd) && IsValidWindow(hwnd)) {
                currentWindowsMap[hwnd] := true

                ; 如果是新窗口，添加到状态记录
                if (!windowStates.Has(hwnd)) {
                    windowStates[hwnd] := WindowState(hwnd)
                    ; 新窗口的 lastSeen 已在 WindowState 构造函数中设置为当前时间
                } else {
                    ; 更新已存在窗口的最后发现时间
                    windowStates[hwnd].lastSeen := A_TickCount
                }
            }
        }

        ; 移除不再存在的窗口
        toRemove := []
        for hwnd, state in windowStates {
            if (!currentWindowsMap.Has(hwnd) || !WinExist(hwnd)) {
                toRemove.Push(hwnd)
            }
        }

        for i, hwnd in toRemove {
            windowStates.Delete(hwnd)
        }

    } catch Error as e {
        ; 静默处理错误，避免影响主要功能
    }
}

/**
 * 检查是否有未被鼠标访问过的窗口
 * 如果有未访问的窗口，则完全禁用自动激活功能
 */
CheckForUnvisitedWindows() {
    global windowStates, autoActivateEnabled

    try {
        for hwnd, state in windowStates {
            if (!state.mouseVisited && WinExist(hwnd)) {
                ; 发现未访问的窗口，完全禁用自动激活
                return false
            }
        }
        return true
    } catch Error as e {
        return true
    }
}

/**
 * 判断窗口是否为有效的可激活窗口
 */
IsValidWindow(hwnd) {
    try {
        if (!WinExist(hwnd)) {
            return false
        }

        ; 检查窗口是否可见
        if (!IsWindowVisible(hwnd)) {
            return false
        }

        ; 检查窗口样式，排除一些特殊窗口
        style := WinGetStyle(hwnd)
        className := WinGetClass(hwnd)

        ; 排除桌面、任务栏等
        static excludedClasses := Map(
            "Progman", true,
            "Shell_TrayWnd", true,
            "WorkerW", true
        )

        if (excludedClasses.Has(className)) {
            return false
        }

        return true
    } catch Error as e {
        return false
    }
}

/**
 * 检查窗口是否可见
 */
IsWindowVisible(hwnd) {
    try {
        return WinGetStyle(hwnd) & 0x10000000  ; WS_VISIBLE
    } catch Error as e {
        return false
    }
}

/**
 * 实际执行激活操作的函数
 * @param timeoutMouse 激活的鼠标等待时间，默认为 100 ms
 * @param mouseMovementAmplitude 鼠标移动幅度，默认为正负 50 像素
 */
ActivateWindowUnderMouse(timeoutMouse := 100, mouseMovementAmplitude := 50) {
    global mousePos, windowStates

    MouseGetPos(&mouseX, &mouseY, &targetID)
    try {
        static pendingActivation := false

        ; 更新当前鼠标下窗口的访问状态
        if (targetID) {
            ; 如果窗口不在状态列表中，立即添加并标记为已访问
            if (!windowStates.Has(targetID) && WinExist(targetID) && IsValidWindow(targetID)) {
                state := WindowState(targetID)
                state.mouseVisited := true
                windowStates[targetID] := state
            } else if (windowStates.Has(targetID)) {
                windowStates[targetID].mouseVisited := true
            }
        }

        ; 检查是否有未访问的窗口，如果有则完全禁用自动激活
        activationAllowed := CheckForUnvisitedWindows()
        if (!activationAllowed) {
            ; 有未访问的窗口，完全禁用自动激活
            pendingActivation := false
            return
        }

        if ((Abs(mouseX - mousePos[1]) > mouseMovementAmplitude || Abs(mouseY - mousePos[2]) > mouseMovementAmplitude) &&
        A_TimeIdleMouse >= timeoutMouse) {  ; 宽高 2 * mouseMovementAmplitude px 区域的点击容错
            ; 鼠标位置在 pollingTime ms 内发生了明显移动，且有 timeoutMouse ms 的时间没有移动了，则启用"待激活"模式
            pendingActivation := true
            mousePos := [mouseX, mouseY]  ; 立即更新位置
        }

        ; 如果处于"待激活"模式
        if (pendingActivation) {
            if (JudgeActivate(targetID)) {
                WinActivate(targetID)
            }
            ; 不论激活是否成功，都重置待激活状态
            pendingActivation := false
        }
    }
    catch Error as e {
        ; 静默处理错误
    }
}

/**
 * 判断是否激活的函数，能处理更多样和复杂的情况，舍弃了一长串逻辑判断的方式
 * 完全保留原来的逻辑
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
    ; 此项目前专注于处理"失去焦点就会关闭"的窗口
    static ExcludedProcessNameA := Map(
        "MyKeymap.exe", true,  ; 排除 MyKeymap 的部分窗口，如亮度调节窗口
        "Listary.exe", true  ; 排除 Listary 的搜索窗口
    )
    if (ExcludedProcessNameA.Has(processNameA)) {
        return false
    }

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

    if (styleTarget & 0x40000) {  ; 如果可以调整大小，通常才是正常的窗口
        return true
    }
    return false
}

; 调试快捷键：Ctrl+Shift+D 显示当前窗口状态
^+d:: {
    global windowStates, autoActivateEnabled

    info := "自动激活状态: " . (autoActivateEnabled ? "启用" : "禁用") . "`n"
    info .= "窗口总数: " . windowStates.Count . "`n`n"

    unvisitedCount := 0
    for hwnd, state in windowStates {
        if (!state.mouseVisited && WinExist(hwnd)) {
            unvisitedCount++
            try {
                title := WinGetTitle(hwnd)
                className := WinGetClass(hwnd)
                info .= "未访问: " . title . " (" . className . ")`n"
            } catch {
                info .= "未访问: 未知窗口`n"
            }
        }
    }

    if (unvisitedCount == 0) {
        info .= "所有窗口已访问 ✓"
    } else {
        info .= "`n未访问窗口数: " . unvisitedCount
    }

    ToolTip(info)
    SetTimer(ToolTip, -5000)  ; 5秒后隐藏
}

; 启动时自动启用该功能
AutoActivateWindow()