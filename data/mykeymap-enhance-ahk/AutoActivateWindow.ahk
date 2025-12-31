#Requires AutoHotkey v2.0

#Include Logger.ahk

class AutoActivateWindowDebug {
    static mode := false
}

AutoActivateWindowDebug.mode := false  ; 是否启用开发模式，设为 true 会打开控制台并显示调试信息

; 全局变量用于跟踪自动激活功能的状态
autoActivateEnabled := false
windowStates := Map()  ; 窗口状态映射表
mousePos := [0, 0]  ; 鼠标位置记录
pendingActivation := false  ; 待激活状态标志
lastActiveWindowClass := ""  ; 记录上一次激活窗口的类名，用于检测任务栏切换

/**
 * 窗口状态类，用于记录每个窗口的信息
 */
class WindowState {
    __New(hwnd) {
        this.hwnd := hwnd
        this.mouseVisited := false  ; 鼠标是否访问过此窗口
    }
}

/**
 * 切换自动激活窗口的开启状态，是一个开关函数
 * @param pollingTime 轮询时间，默认为 50 ms
 */
AutoActivateWindow(pollingTime := 50) {
    global autoActivateEnabled

    if (!autoActivateEnabled) {
        ; 当前未激活，执行启动逻辑
        SetTimer(ActivateWindowUnderMouse, pollingTime)  ; 启动主要逻辑定时器
        SetTimer(MaintainWindowStates, pollingTime)  ; 启动窗口状态维护定时器

        ; 初始化现有窗口状态，将当前所有窗口标记为已访问
        InitializeExistingWindows()

        ; 初始化上一次激活窗口的类名
        global lastActiveWindowClass
        try {
            lastActiveWindowClass := WinGetClass("A")
        } catch Error as e {
            lastActiveWindowClass := ""
            LogError(e, , AutoActivateWindowDebug.mode)
        }

        autoActivateEnabled := true
        LogInfo("窗口自动激活已启动", , AutoActivateWindowDebug.mode)
    } else {
        ; 当前已激活，执行停止逻辑
        SetTimer(ActivateWindowUnderMouse, 0)  ; 停止主要逻辑定时器
        SetTimer(MaintainWindowStates, 0)  ; 停止窗口状态维护定时器
        autoActivateEnabled := false

        ; 清空窗口状态记录
        global windowStates
        global lastActiveWindowClass
        windowStates := Map()
        lastActiveWindowClass := ""
        LogInfo("窗口自动激活已停止", , AutoActivateWindowDebug.mode)
    }
}

/**
 * 初始化现有窗口状态，将所有当前窗口标记为已访问
 * 这样脚本启动时不会因为现有窗口而被阻断
 */
InitializeExistingWindows() {
    global windowStates

    try {
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
        LogError(e, , AutoActivateWindowDebug.mode)
    }
}

/**
 * 维护窗口状态列表
 * - 检查并移除已不存在的窗口
 * - 发现新窗口并添加到列表
 * - 检查是否有未访问的窗口，如有则禁用自动激活
 */
MaintainWindowStates() {
    global windowStates, autoActivateEnabled

    try {
        ; 获取当前所有可见窗口
        currentWindows := []

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
                    LogInfo("发现新窗口，添加到跟踪列表：[" WinGetTitle(hwnd) "] [" WinGetClass(hwnd) "] [" hwnd "]", ,
                    AutoActivateWindowDebug.mode)
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
            LogInfo("从列表中移除了 " hwnd " 窗口，因为它已不存在", , AutoActivateWindowDebug.mode)
        }

        ; 移除不再处于前台的未访问窗口
        for hwnd, state in windowStates {
            if (!state.mouseVisited && WinExist(hwnd)) {
                if (WinExist("A") != hwnd) {
                    state.mouseVisited := true
                    LogInfo("窗口已不在前台，标记为已访问：[" WinGetTitle(hwnd) "] [" WinGetClass(hwnd) "] [" hwnd "]", ,
                    AutoActivateWindowDebug.mode)
                }
            }
        }

    } catch Error as e {
        LogError(e, , AutoActivateWindowDebug.mode)
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
                ; LogInfo("发现未访问窗口，自动激活功能被禁用：[" WinGetTitle(hwnd) "] [" WinGetClass(hwnd) "] [" hwnd "]", , AutoActivateWindowDebug.mode)
                return false
            }
        }
        return true
    } catch Error as e {
        LogError(e, , AutoActivateWindowDebug.mode)
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

        ; 检查窗口样式
        style := WinGetStyle(hwnd)

        if (style & 0x40000) {  ; 如果可以调整大小，通常才是正常的窗口，这是目前判断常规窗口最有效的方式，其列表和 Windows 任务栏上显示出来的窗口高度一致
            ; LogInfo("识别到有效窗口：[" WinGetTitle(hwnd) "] [" WinGetClass(hwnd) "] [" hwnd "]", , AutoActivateWindowDebug.mode)
            return true
        }

        ; LogInfo("识别到无效窗口：[" WinGetTitle(hwnd) "] [" WinGetClass(hwnd) "] [" hwnd "]", , AutoActivateWindowDebug.mode)
        return false
    } catch Error as e {
        LogError(e, , AutoActivateWindowDebug.mode)
        return false
    }
}

/**
 * 实际执行激活操作的函数
 * @param timeoutInput 激活的输入等待时间，默认为 50 ms
 * @param mouseMovementAmplitude 鼠标静止容错幅度，默认为正负 10 像素
 */
ActivateWindowUnderMouse(timeoutInput := 50, mouseMovementAmplitude := 10) {
    global mousePos, windowStates, pendingActivation, lastActiveWindowClass

    MouseGetPos(&mouseX, &mouseY, &targetID)
    try {
        ; 检测用户手动切换窗口
        ; 核心逻辑：焦点从任务栏或任务列表 -> 窗口 = 用户手动激活
        currentActiveID := WinExist("A")
        if (currentActiveID) {
            try {
                currentActiveClass := WinGetClass("A")

                ; 检测焦点切换：从任务栏切换到普通窗口
                if (lastActiveWindowClass == "Shell_TrayWnd" && currentActiveClass != "Shell_TrayWnd") {
                    ; 用户通过任务栏激活了一个窗口
                    ; 将这个新激活的窗口标记为"未访问"，阻止自动激活干扰
                    if (IsValidWindow(currentActiveID)) {
                        if (windowStates.Has(currentActiveID)) {
                            windowStates[currentActiveID].mouseVisited := false
                            LogInfo("【从任务栏手动打开】标记为未访问窗口：" WinGetTitle(currentActiveID), , AutoActivateWindowDebug.mode)
                        }
                    }
                }

                ; 检测用户通过任务列表激活了一个窗口
                if (lastActiveWindowClass == "XamlExplorerHostIslandWindow" && currentActiveClass !=
                    "XamlExplorerHostIslandWindow") {
                    ; 用户通过任务列表激活了一个窗口
                    ; 将这个新激活的窗口标记为"未访问"，阻止自动激活干扰
                    if (IsValidWindow(currentActiveID)) {
                        if (windowStates.Has(currentActiveID)) {
                            windowStates[currentActiveID].mouseVisited := false
                            LogInfo("【从任务列表手动打开】标记为未访问窗口：" WinGetTitle(currentActiveID), , AutoActivateWindowDebug.mode
                            )
                        }
                    }
                }

                ; 更新上一次激活窗口的类名
                lastActiveWindowClass := currentActiveClass
            }
            catch Error as e {
                LogError(e, , AutoActivateWindowDebug.mode)
            }
        }

        ; 更新鼠标悬停窗口的访问状态
        if (targetID && WinExist(targetID) && IsValidWindow(targetID)) {
            if (windowStates.Has(targetID)) {
                ; 如果窗口在跟踪列表中，标记为已访问
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
        A_TimeIdle >= timeoutInput) {
            ; 鼠标位置在 pollingTime ms 内发生了明显移动，且有 timeoutInput ms 的时间没有移动了，则启用“待激活”模式
            pendingActivation := true
            mousePos := [mouseX, mouseY]  ; 立即更新位置
        }

        ; 如果处于待激活模式
        if (pendingActivation) {
            if (JudgeActivate(targetID)) {
                WinActivate(targetID)
            }
            ; 不论激活是否成功，都重置待激活状态
            pendingActivation := false
        }
    }
    catch Error as e {
        LogError(e, , AutoActivateWindowDebug.mode)
    }
}

/**
 * 判断是否激活的函数，能处理更多样和复杂的情况，舍弃了一长串逻辑判断的方式
 */
JudgeActivate(targetID) {
    if (WinExist("A") == 0) {  ; 确保有激活窗口，抑制不必要的错误写入
        return false
    }

    if (WinExist("A") == targetID) {  ; 如果目标窗口已经是激活窗口，则不需要激活
        return false
    }

    activeClass := WinGetClass("A")
    activeStyle := WinGetStyle("A")

    excludeCondition := WinGetClass("A") == "AutoHotkeyGUI" && WinGetProcessName("A") == "MyKeymap.exe"

    win10RightMenu := WinExist("ahk_class #32768")

    if (excludeCondition || win10RightMenu) {
        return false
    }

    ; 特殊的类名
    static specialActiveClass := Map(
        "Progman", true,  ; 桌面，保证用户点击桌面后，功能仍正常
        "WorkerW", true,  ; 桌面的层
        "Shell_TrayWnd", true,  ; 任务栏，保证用户点击任务栏后，功能仍正常
        "ApplicationFrameWindow", true  ; 设置，保证用户点击了设置后，功能仍正常
    )

    if (activeStyle & 0x80000000 && !(activeStyle & 0x40000) || activeStyle & 0x80880000 && !(activeStyle & 0x40000)) {
        ; 如果活动窗口【具有 WS_POPUP 样式同时不能调节窗口大小】或者【具有 WS_POPUPWINDOW 样式且不能调整大小】，则是一个抢夺了焦点的弹出窗口，通常，这些窗口具有提示、警告作用，或者是部分高优先级系统组件菜单，又或是一些具有奇怪逻辑的组件（比如微信、微信的的表情面板）。当它们出现并抢夺了焦点时，自动激活功能应该停止，以确保这些窗口出现在前台，让用户处理
        if (specialActiveClass.Has(activeClass)) {  ; 在这些窗口中，也有一些异类，比如设置、桌面，在点击这些地方后，激活的窗口将具有 popup 属性，此时激活其他窗口功能会被终止，这是不应该的，所以做了二次处理
            if (WinExist("ahk_class Xaml_WindowedPopupClass")) {  ; 防止 Windows 徽标键右键菜单因失去焦点而消失，适用于点击或触发 Win + x 的情况
                return false
            }
            if (WinGetClass(targetID) == "Xaml_WindowedPopupClass") {
                return false
            }
            return true
        }
        return false
    }

    if (IsValidWindow(targetID)) {  ; 逻辑复用
        return true
    }
    return false
}

ShowDebugTooltip() {  ; 该函数应该被加入 README 中，作为辅助调试工具，目前有一个通用调试工具，但其是一个独立脚本，需要考虑集成性，但是目前通过 ToolTip 调用必要信息也是足够优雅的
    global windowStates, autoActivateEnabled

    info := ""
    info .= "窗口总数: " windowStates.Count "`n"

    unvisitedCount := 0
    for hwnd, state in windowStates {
        if (!state.mouseVisited && WinExist(hwnd)) {
            unvisitedCount++
            try {
                title := WinGetTitle(hwnd)
                className := WinGetClass(hwnd)
                info .= "未访问：" title "`n"  ; 只展示标题，这最具有辨识度，防止其他信息干扰用户
            } catch Error as e {
                info .= "未访问: 未知窗口`n"
                LogError(e, , AutoActivateWindowDebug.mode)
            }
        }
    }

    if (unvisitedCount == 0) {
        info .= "所有窗口已访问"
    } else {
        info .= "未访问窗口数: " unvisitedCount
    }

    ToolTip(info)
    SetTimer(ToolTip, -3000)  ; 防止遮挡太久
}

; 启动时自动启用该功能
AutoActivateWindow()