#Requires AutoHotkey v2.0

#Include ./LoggerLib/Logger.ahk
#Include ./WindowStyleLib/WindowStyle.ahk

#WinActivateForce  ; 快速连续激活同一窗口会闪烁，这是 AHK 的已知问题

global lastActiveID := ""

class AutoActivateWindowDebug {
    static mode := false
}

; 自动激活功能的运行状态
autoActivateEnabled := false
windowStates := Map()  ; 窗口句柄到 WindowState 的映射
mousePos := [0, 0]  ; 上一次参与判定的鼠标坐标
pendingActivation := false  ; 本轮输入空闲与位移条件是否已满足
lastActiveWindowClass := ""  ; 上一次激活窗口的类名

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
 * 开启或关闭自动激活，重复调用即切换状态
 * @param {integer} pollingTime 轮询时间，默认为 20 ms
 */
AutoActivateWindow(pollingTime := 20) {
    global autoActivateEnabled

    if (!autoActivateEnabled) {
        SetTimer(ActivateWindowUnderMouse, pollingTime)  ; 启动主要逻辑定时器
        SetTimer(MaintainWindowStates, pollingTime)  ; 启动窗口状态维护定时器

        InitializeExistingWindows()

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
        SetTimer(ActivateWindowUnderMouse, 0)  ; 停止主要逻辑定时器
        SetTimer(MaintainWindowStates, 0)  ; 停止窗口状态维护定时器
        autoActivateEnabled := false

        ; 清空状态记录，下次启动时不沿用上一轮的访问标记
        global windowStates
        global lastActiveWindowClass
        windowStates := Map()
        lastActiveWindowClass := ""
        LogInfo("窗口自动激活已停止", , AutoActivateWindowDebug.mode)
    }
}

/**
 * 把启动时已存在的窗口全部标记为已访问
 *
 * 不这样做的话，启动瞬间所有已存在窗口都会被判为未访问，自动激活会一直处于停用状态
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
                    state.mouseVisited := true
                    windowStates[hwnd] := state
                }
            }
        }
    } catch Error as e {
        LogError(e, , AutoActivateWindowDebug.mode)
    }
}

/**
 * 每个轮询周期对齐一次窗口列表：新出现的窗口记为未访问，已消失的窗口从列表移除
 *
 * 未访问标记只能由鼠标移入或窗口离开前台这两条路解除，后者在这里处理
 */
MaintainWindowStates() {
    global windowStates, autoActivateEnabled

    try {
        currentWindows := []

        windowList := WinGetList()

        currentWindowsMap := Map()
        loop windowList.Length {
            hwnd := windowList[A_Index]
            if (WinExist(hwnd) && IsValidWindow(hwnd)) {
                currentWindowsMap[hwnd] := true

                ; 新窗口默认未访问，等鼠标移上去才算看过
                if (!windowStates.Has(hwnd)) {
                    windowStates[hwnd] := WindowState(hwnd)
                    LogInfo("发现新窗口，添加到跟踪列表：[" WinGetTitle(hwnd) "] [" WinGetClass(hwnd) "] [" hwnd "]", ,
                    AutoActivateWindowDebug.mode)
                }
            }
        }

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

        ; 未访问窗口如果一直不在前台，它的标记就会长期挡着自动激活，
        ; 因此不再处于前台的窗口一并记为已访问
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
 * 有未访问窗口时返回 false，此时整个自动激活停用
 *
 * 未访问标记在鼠标移入该窗口、或该窗口不再处于前台时解除
 */
CheckForUnvisitedWindows() {
    global windowStates, autoActivateEnabled

    try {
        for hwnd, state in windowStates {
            if (!state.mouseVisited && WinExist(hwnd)) {
                ; 找到第一个未访问窗口就提前返回
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
 * 轮询入口：系统输入空闲达到 timeoutInput，且鼠标相对上次记录位置移动超过
 * mouseMovementAmplitude 时，激活鼠标下的窗口
 * @param {integer} timeoutInput 触发前要求的系统输入空闲时间，毫秒，默认为 100
 * @param {integer} mouseMovementAmplitude 允许的偏移幅度，像素，默认为 10
 */
ActivateWindowUnderMouse(timeoutInput := 100, mouseMovementAmplitude := 10) {
    global mousePos, windowStates, pendingActivation, lastActiveWindowClass, lastActiveID

    pendingActivation := false

    MouseGetPos(&mouseX, &mouseY, &targetID)

    try {
        currentActiveID := WinExist("A")
        if (currentActiveID && currentActiveID != lastActiveID) {
            ; 只要 ID 变了，说明焦点发生了转移
            if (windowStates.Has(currentActiveID) && IsValidWindow(currentActiveID)) {
                windowStates[currentActiveID].mouseVisited := false
                LogInfo("检测到焦点切换，标记为未访问：" WinGetTitle(currentActiveID), , AutoActivateWindowDebug.mode)
            }
            lastActiveID := currentActiveID
        }

        ; 鼠标停在哪个窗口上，就把那个窗口算作已访问
        if (targetID && windowStates.Has(targetID) && IsValidWindow(targetID)) {
            windowStates[targetID].mouseVisited := true
        }

        ; 存在未访问窗口，或用户正按着左右键，都不触发激活
        if (!CheckForUnvisitedWindows() || GetKeyState("LButton", "P") || GetKeyState("RButton", "P")) {
            pendingActivation := false
            return
        }

        ; 输入空闲够久且鼠标移动过，才说明用户确实想换到鼠标下的窗口
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
 * 决定这一次是否真的激活目标窗口
 *
 * 弹窗、右键菜单、桌面与任务栏会短暂抢走焦点，这时不该再激活鼠标下的窗口，
 * 否则会打断用户正在做的事
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

    ; 这些系统窗口点击后会带走焦点，必须放行，否则自动激活当场终止
    static specialActiveClass := Map(
        "Progman", true,  ; 桌面，保证用户点击桌面后，功能仍正常
        "WorkerW", true,  ; 桌面的层
        "Shell_TrayWnd", true,  ; 任务栏，保证用户点击任务栏后，功能仍正常
        "ApplicationFrameWindow", true  ; 设置，保证用户点击了设置后，功能仍正常
    )

    if (ActiveWindowIsPopUp()) {
        ; 设置、桌面这类窗口被点击后会带上弹出窗口样式，直接按弹出窗口放行会让自动激活
        ; 就此终止，因此对它们单独放行类名
        if (specialActiveClass.Has(activeClass)) {
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

    if (IsValidWindow(targetID)) {  ; 目标窗口本身合法才激活
        return true
    }
    return false
}

ShowDebugTooltip() {  ; 调试用：手动调用时用 ToolTip 汇总窗口状态
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
                info .= "未访问：" title "`n"  ; 只取标题，类名与窗口句柄对用户没有辨识度
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

; 本文件不自启动，由 custom_functions.ahk 统一调用