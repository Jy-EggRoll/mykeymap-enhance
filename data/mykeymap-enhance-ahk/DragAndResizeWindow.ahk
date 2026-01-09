#Requires AutoHotkey v2.0

#Include Logger.ahk

class DragAndResizeWindowDebug {
    static mode := false
}

; 设置窗口操作的延迟时间为 10 ms，拖动可以达到 100 帧
SetWinDelay 10

CoordMode "Mouse"

; 光标管理类：保存和恢复光标状态（兼容其他光标管理软件，如 InputTip）
class CursorManager {
    static savedCursors := Map()
    static isSaved := false

    ; 系统光标 ID 常量
    static SystemCursorIDs := Map(
        "ARROW", 32512,
        "IBEAM", 32513,
        "WAIT", 32514,
        "CROSS", 32515,
        "UPARROW", 32516,
        "SIZENWSE", 32642,
        "SIZENESW", 32643,
        "SIZEWE", 32644,
        "SIZENS", 32645,
        "SIZEALL", 32646,
        "NO", 32648,
        "HAND", 32649,
        "APPSTARTING", 32550,
        "HELP", 32651
    )

    ; 保存当前每个类型的光标句柄
    static SaveCurrentCursors() {
        if !CursorManager.isSaved {
            ; 遍历每种光标类型，保存当前实际使用的光标句柄
            for name, id in CursorManager.SystemCursorIDs {
                ; 使用 LoadImage 获取当前系统中该类型光标的句柄
                ; 这样可以获取到 InputTip 等软件设置的光标
                hCursor := DllCall("LoadImage"
                    , "Ptr", 0                    ; hInst = NULL (系统光标)
                    , "Ptr", id                   ; 光标资源 ID
                    , "UInt", 2                   ; IMAGE_CURSOR
                    , "Int", 0                    ; 宽度(0=默认)
                    , "Int", 0                    ; 高度(0=默认)
                    , "UInt", 0x8000              ; LR_SHARED
                    , "Ptr")

                if (hCursor != 0) {
                    ; 复制光标句柄以保存
                    CursorManager.savedCursors[name] := DllCall("CopyIcon", "Ptr", hCursor, "Ptr")
                }
            }
            CursorManager.isSaved := true
        }
    }

    ; 恢复到保存的光标状态（不调用系统恢复，保持兼容性）
    static RestoreCursors() {
        if CursorManager.isSaved && CursorManager.savedCursors.Count > 0 {
            ; 使用保存的光标句柄恢复，而不是调用系统恢复 API
            for name, id in CursorManager.SystemCursorIDs {
                if CursorManager.savedCursors.Has(name) {
                    hSaved := CursorManager.savedCursors[name]
                    if (hSaved != 0) {
                        ; 复制句柄并设置
                        DllCall("SetSystemCursor", "Ptr", DllCall("CopyIcon", "Ptr", hSaved, "Ptr"), "UInt", id)
                    }
                }
            }
            CursorManager.isSaved := false
        }
    }
}

; 设置系统光标（兼容其他光标管理软件，如 InputTip）
SetSystemCursor(Cursor := "") {
    static SystemCursors := Map(
        "ARROW", 32512,
        "IBEAM", 32513,
        "WAIT", 32514,
        "CROSS", 32515,
        "UPARROW", 32516,
        "SIZENWSE", 32642,
        "SIZENESW", 32643,
        "SIZEWE", 32644,
        "SIZENS", 32645,
        "SIZEALL", 32646,
        "NO", 32648,
        "HAND", 32649,
        "APPSTARTING", 32550,
        "HELP", 32651
    )

    if (Cursor = "") {
        ; 恢复到设置之前的状态（使用保存的句柄，不调用系统恢复）
        CursorManager.RestoreCursors()
        return
    }

    if SystemCursors.Has(Cursor) {
        ; 首次设置光标时，保存当前状态（包括其他软件设置的光标，如 InputTip）
        CursorManager.SaveCurrentCursors()

        ; 直接设置新光标，不调用系统恢复
        hCursor := DllCall("LoadCursor", "Ptr", 0, "Ptr", SystemCursors[Cursor], "Ptr")
        if (hCursor != 0) {
            ; 为所有光标类型设置相同的光标
            for id in SystemCursors {
                DllCall("SetSystemCursor", "Ptr", DllCall("CopyIcon", "Ptr", hCursor, "Ptr"), "UInt", SystemCursors[id])
            }
        }
    }
}

; 窗口拖动函数：按住指定按键时拖动窗口
DragWindow() {
    ; 获取初始鼠标位置和当前鼠标所在窗口的 ID
    MouseGetPos &X1, &Y1, &ID

    ; 检查鼠标下窗口是否处于最大化状态
    ; 如果是最大化，将其恢复为占满全屏的窗口化状态，而不是恢复到之前的小窗口
    if WinGetMinMax(ID) {
        ; 先激活窗口，确保后续操作针对正确的窗口
        WinActivate("ahk_id " ID)
        ; 调用 PerCenterAndResizeWindow(1, 1) 将窗口设置为占满整个工作区的窗口化状态
        PerCenterAndResizeWindow(1, 1)
    }

    ; 获取窗口初始位置
    WinGetPos &WinX1, &WinY1, , , ID

    ; 设置四向移动光标
    SetSystemCursor("SIZEALL")

    try {
        ; 循环执行拖动逻辑，直到按键释放
        loop {
            ; 检查按键是否仍被按住，若释放则退出循环
            if !GetKeyState("LButton", "P")
                break

            ; 获取当前鼠标位置
            MouseGetPos &X2, &Y2

            ; 计算鼠标相对于初始位置的偏移量
            X2 -= X1
            Y2 -= Y1

            ; 根据初始窗口位置和鼠标偏移量，计算窗口新位置
            WinX2 := (WinX1 + X2)
            WinY2 := (WinY1 + Y2)

            ; 移动窗口到新位置（只改变位置，不改变大小）
            WinMove WinX2, WinY2, , , ID
        }
    } catch Error as e {
        LogError(e, , DragAndResizeWindowDebug.mode)
    } finally {
        SetSystemCursor("")  ; 保证光标可以恢复
    }
}

ResizeWindow() {
    MouseGetPos &X1, &Y1, &ID

    ; 如果窗口是最大化状态
    if WinGetMinMax(ID) {
        ; 等待一小段时间，通过鼠标移动判断是单击还是拖动
        initialX := X1
        initialY := Y1
        Sleep 100  ; 等待 100ms

        MouseGetPos &X2, &Y2
        mouseMoved := (Abs(X2 - initialX) > 5 || Abs(Y2 - initialY) > 5)

        ; 检查按键是否还在按下
        if GetKeyState("RButton", "P") {
            if !mouseMoved {
                ; 按键按下但鼠标未移动：等待释放，这是单击
                KeyWait "RButton"  ; 等待右键释放

                ; 单击：将最大化窗口转换为全屏窗口化
                WinActivate("ahk_id " ID)
                PerCenterAndResizeWindow(1, 1)
                return
            } else {
                ; 按键按下且鼠标移动了：这是拖动，提示用户
                ToolTip("窗口处于最大化状态`n为避免闪烁 请先单击（触发键+右键）将其转为窗口化再执行拖动操作")
                SetTimer(ToolTip, -3000)
                return
            }
        } else {
            ; 按键已释放：单击
            WinActivate("ahk_id " ID)
            PerCenterAndResizeWindow(1, 1)
            return
        }
    }

    WinGetPos &WinX1, &WinY1, &WinW, &WinH, ID

    ; 计算窗口的 1 / 3 宽度和高度，用于划分 9 个区域
    thirdW := WinW / 3
    thirdH := WinH / 3

    ; 确定鼠标所在的水平区域 (1 = 左, 2 = 中, 3 = 右)
    if (X1 < WinX1 + thirdW)
        horizontalRegion := 1
    else if (X1 < WinX1 + 2 * thirdW)
        horizontalRegion := 2
    else
        horizontalRegion := 3

    ; 确定鼠标所在的垂直区域 (1 = 上, 2 = 中, 3 = 下)
    if (Y1 < WinY1 + thirdH)
        verticalRegion := 1
    else if (Y1 < WinY1 + 2 * thirdH)
        verticalRegion := 2
    else
        verticalRegion := 3

    ; 根据区域设置合适的光标
    cursorType := ""
    if (horizontalRegion = 1 && verticalRegion = 1) {
        cursorType := "SIZENWSE"
    } else if (horizontalRegion = 3 && verticalRegion = 1) {
        cursorType := "SIZENESW"
    } else if (horizontalRegion = 1 && verticalRegion = 3) {
        cursorType := "SIZENESW"
    } else if (horizontalRegion = 3 && verticalRegion = 3) {
        cursorType := "SIZENWSE"
    } else if (horizontalRegion = 1 || horizontalRegion = 3) {
        cursorType := "SIZEWE"
    } else if (verticalRegion = 1 || verticalRegion = 3) {
        cursorType := "SIZENS"
    } else if (horizontalRegion = 2 && verticalRegion = 2) {
        cursorType := "SIZEALL"
    }

    ; 设置光标
    SetSystemCursor(cursorType)

    try {
        ; 循环执行调整大小逻辑，直到按键释放
        loop {
            ; 检查按键是否仍被按住，若释放则退出循环
            if !GetKeyState("RButton", "P")
                break

            ; 获取当前鼠标位置
            MouseGetPos &X2, &Y2
            ; 获取窗口当前的位置和大小（避免因其他操作导致的位置偏差）
            WinGetPos &WinX1, &WinY1, &WinW, &WinH, ID

            ; 计算鼠标相对于初始位置的偏移量
            deltaX := X2 - X1
            deltaY := Y2 - Y1

            ; 根据所在区域确定调整方式
            newX := WinX1
            newY := WinY1
            newW := WinW
            newH := WinH

            ; 根据 9 个区域的不同逻辑进行调整
            if (horizontalRegion = 1) {
                ; 左区域：调整左边框
                newX := WinX1 + deltaX
                newW := WinW - deltaX
            }
            else if (horizontalRegion = 3) {
                ; 右区域：调整右边框
                newW := WinW + deltaX
            }

            if (verticalRegion = 1) {
                ; 上区域：调整上边框
                newY := WinY1 + deltaY
                newH := WinH - deltaY
            }
            else if (verticalRegion = 3) {
                ; 下区域：调整下边框
                newH := WinH + deltaY
            }

            ; 中间区域四区逻辑
            if (horizontalRegion = 2 && verticalRegion = 2) {
                ; 判断鼠标在中间区域的左右（用于确定宽度调整方向）
                if (X1 < WinX1 + WinW / 2)
                    WinLeft := 1
                else
                    WinLeft := -1

                ; 判断鼠标在中间区域的上下（用于确定高度调整方向）
                if (Y1 < WinY1 + WinH / 2)
                    WinUp := 1
                else
                    WinUp := -1

                ; 应用四区逻辑
                newX := WinX1 + (WinLeft + 1) / 2 * deltaX
                newY := WinY1 + (WinUp + 1) / 2 * deltaY
                newW := WinW - WinLeft * deltaX
                newH := WinH - WinUp * deltaY
            }

            ; 应用调整后的窗口位置和大小
            WinMove newX, newY, newW, newH, ID

            ; 更新初始鼠标位置为当前位置（避免累积误差）
            X1 := X2
            Y1 := Y2
        }
    } catch Error as e {
        LogError(e, , DragAndResizeWindowDebug.mode)
    } finally {
        SetSystemCursor("")  ; 保证光标可以恢复
    }
}
