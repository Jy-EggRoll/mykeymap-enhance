#Requires AutoHotkey v2.0

/**
 * 以窗口中心为基准缩放窗口
 * @param {number} percent 缩放比例增量，0.1 表示放大一成
 */
ScaleWindow(percent) {
    activeHwnd := WinExist("A")
    if !activeHwnd
        return

    ; 最大化窗口的宽高由系统决定，缩放没有意义
    if (WinGetMinMax(activeHwnd) != 0)
        return

    WinGetPos &x, &y, &w, &h, activeHwnd

    centerX := x + (w / 2)
    centerY := y + (h / 2)

    ; 取整：窗口坐标只接受整数，小数会被截断，宽高在相邻两个像素间来回跳会看到抖动
    newW := Round(Max(100, w * (1 + percent)))
    newH := Round(Max(100, h * (1 + percent)))

    ; 缩放时中心点不动，由新尺寸反推左上角
    newX := Round(centerX - (newW / 2))
    newY := Round(centerY - (newH / 2))

    WinMove newX, newY, newW, newH, activeHwnd
}
