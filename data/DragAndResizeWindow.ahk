#Requires AutoHotkey v2.0

; 设置窗口操作的延迟时间为 10 ms，拖动可以达到 100 帧
SetWinDelay 10

CoordMode "Mouse"

#Include PerResizeWindow.ahk

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
                ; ToolTip("✅ 已转换为窗口化，现在可以调整大小了")
                ; SetTimer(ToolTip, -1500)
                return
            } else {
                ; 按键按下且鼠标移动了：这是拖动，提示用户
                ToolTip("窗口处于最大化状态`n为避免闪烁，请先单击（触发键+右键）将其转为窗口化")
                SetTimer(ToolTip, -2000)
                return
            }
        } else {
            ; 按键已释放：单击
            WinActivate("ahk_id " ID)
            PerCenterAndResizeWindow(1, 1)
            ; ToolTip("✅ 已转换为窗口化，现在可以调整大小了")
            ; SetTimer(ToolTip, -1500)
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
}
