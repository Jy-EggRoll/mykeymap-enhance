; 自定义的函数写在这个文件里，然后能在 MyKeymap 中调用

; 使用如下写法，来加载当前目录下的其他 AutoHotKey v2 脚本
; #Include ../data/test.ahk

; 设置窗口操作的延迟时间为 10 ms，拖动可以达到 100 帧
SetWinDelay 10

; 设置鼠标坐标模式为相对于屏幕（而非活动窗口）
CoordMode "Mouse"

; 窗口拖动函数：按住指定按键时拖动窗口
DragWindow() {
    ; 获取初始鼠标位置和当前鼠标所在窗口的 ID
    MouseGetPos &X1, &Y1, &ID

    ; 检查窗口是否处于最大化状态，最大化窗口不允许拖动
    if WinGetMinMax(ID)
        return

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
    ; 检查窗口是否最大化，最大化窗口不允许调整大小
    if WinGetMinMax(ID)
        return

    WinGetPos &WinX1, &WinY1, &WinW, &WinH, ID

    ; 计算窗口的1/3宽度和高度，用于划分9个区域
    thirdW := WinW / 3
    thirdH := WinH / 3

    ; 确定鼠标所在的水平区域 (1=左, 2=中, 3=右)
    if (X1 < WinX1 + thirdW)
        horizontalRegion := 1
    else if (X1 < WinX1 + 2 * thirdW)
        horizontalRegion := 2
    else
        horizontalRegion := 3

    ; 确定鼠标所在的垂直区域 (1=上, 2=中, 3=下)
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

        ; 获取当前鼠标位置（X2,Y2）
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

        ; 根据9个区域的不同逻辑进行调整
        if (horizontalRegion = 1) {
            ; 左区域：调整左边框
            newX := WinX1 + deltaX
            newW := WinW - deltaX
        }
        else if (horizontalRegion = 3) {
            ; 右区域：调整右边框
            newW := WinW + deltaX
        }
        ; 中间水平区域不调整宽度（除非是中间区域使用四区逻辑）

        if (verticalRegion = 1) {
            ; 上区域：调整上边框
            newY := WinY1 + deltaY
            newH := WinH - deltaY
        }
        else if (verticalRegion = 3) {
            ; 下区域：调整下边框
            newH := WinH + deltaY
        }
        ; 中间垂直区域不调整高度（除非是中间区域使用四区逻辑）

        ; 中间区域(2,2)使用原有的四区逻辑
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

/**
 * 窗口居中并修改其大小
 * @param percentage
 * @returns {void} 
 */
PerCenterAndResizeWindow(percentage) {
    if NotActiveWin() {
        return
    }

    ; 在 mousemove 时需要 PER_MONITOR_AWARE (-3), 否则当两个显示器有不同的缩放比例时, mousemove 会有诡异的漂移
    ; 在 winmove 时需要 UNAWARE (-1), 这样即使写死了窗口大小为 1200x800, 系统会帮你缩放到合适的大小
    DllCall("SetThreadDpiAwarenessContext", "ptr", -1, "ptr")

    WinExist("A")
    if (WindowMaxOrMin())
        WinRestore

    WinGetPos(&x, &y, &w, &h)

    ms := GetMonitorAt(x + w / 2, y + h / 2)
    MonitorGetWorkArea(ms, &l, &t, &r, &b)
    w := r - l
    h := b - t

    winW := percentage * w
    winH := percentage * h
    winX := l + (w - winW) / 2
    winY := t + (h - winH) / 2

    WinMove(winX, winY, winW, winH)
    DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
}
