#Requires AutoHotkey v2.0

#Include ./LoggerLib/Logger.ahk
#Include ./WindowStyleLib/WindowStyle.ahk

#WinActivateForce  ; 防止在窗口快速被激活时导致闪烁，这是 ahk 的已知问题

global lastActiveID := ""

class AutoActivateWindowDebug {
    static mode := false
}

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
 * @param pollingTime 轮询时间，默认为 20 ms
 */
AutoActivateWindow(pollingTime := 20) {
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
 * 实际执行激活操作的函数
 * @param timeoutInput 激活的输入等待时间，默认为 500 ms
 * @param mouseMovementAmplitude 鼠标静止容错幅度，默认为正负 10 像素
 */
ActivateWindowUnderMouse(timeoutInput := 500, mouseMovementAmplitude := 10) {
    global mousePos, windowStates, pendingActivation, lastActiveWindowClass, lastActiveID

    pendingActivation := false

    MouseGetPos(&mouseX, &mouseY, &targetID)

    try {
        ; 检测焦点切换
        currentActiveID := WinExist("A")
        if (currentActiveID && currentActiveID != lastActiveID) {
            ; 只要 ID 变了，说明焦点发生了转移
            if (windowStates.Has(currentActiveID) && IsValidWindow(currentActiveID)) {
                windowStates[currentActiveID].mouseVisited := false
                LogInfo("检测到焦点切换，标记为未访问：" WinGetTitle(currentActiveID), , AutoActivateWindowDebug.mode)
            }
            lastActiveID := currentActiveID ; 更新记录
        }

        ; 1. 更新鼠标下的窗口状态
        if (targetID && windowStates.Has(targetID) && IsValidWindow(targetID)) {
            windowStates[targetID].mouseVisited := true
        }

        ; 2. 拦截检查：是否有未访问窗口或按键按下
        if (!CheckForUnvisitedWindows() || GetKeyState("LButton", "P") || GetKeyState("RButton", "P")) {
            pendingActivation := false
            return
        }

        ; 3. 激活逻辑：判断鼠标移动和静止状态
        if (A_TimeIdle >= timeoutInput && (Abs(mouseX - mousePos[1]) > mouseMovementAmplitude || Abs(mouseY - mousePos[
            2]) > mouseMovementAmplitude)) {
            pendingActivation := true
            mousePos := [mouseX, mouseY]
        }

        if (pendingActivation && JudgeActivate(targetID)) {
            WinActivate(targetID)
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

    excludeCondition := activeClass == "AutoHotkeyGUI"

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

    if (ActiveWindowIsPopUp()) {
        if (specialActiveClass.Has(activeClass)) {  ; 在这些窗口中，也有一些异类，比如设置、桌面，在点击这些地方后，激活的窗口将具有 popup 属性，此时激活其他窗口功能会被终止，这是不应该的，所以做了二次处理
            if (WinExist("ahk_class Xaml_WindowedPopupClass")) {  ; 防止 Windows 徽标键右键菜单因失去焦点而消失，适用于点击或触发 Win + x 的情况
                return false
            }
            if (WinGetClass(targetID) == "Xaml_WindowedPopupClass") {
                return false
            }
            return true
        }
        return false  ; 最终回退，一般不会走到这一步
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