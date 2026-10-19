#Requires AutoHotkey v2.0

#Include ./LoggerLib/Logger.ahk

class PerResizeWindowDebug {
    static mode := false
}
; F 开头的函数是内置于 MyKeymap 的函数，为了保持本脚本独立性且避免函数冲突，故采用这样的方式，没有额外的意义

/**
 * 没有活动窗口或是桌面返回 true，不是则反之返回 false
 */
F_NotActiveWin() {
    return F_IsDesktop() || not WinExist("A")
}

/**
 * 判断当前窗口是不是桌面
 */
F_IsDesktop() {
    return WinActive("Program Manager ahk_class Progman") || WinActive("ahk_class WorkerW")
}

/**
 * 当前窗口是最大化还是最小化
 * @param {string} winTitle AHK 中的 WinTitle
 * @returns {number} 
 */
F_WindowMaxOrMin(winTitle := "A") {
    return WinGetMinMax(winTitle)
}

/**
 * 获取当前焦点在哪个显示器上
 * @param x 窗口 x 轴的长度
 * @param y 窗口 y 轴的长度
 * @param {number} default 显示器下标
 * @returns {string|number} 匹配的显示器下标
 */
F_GetMonitorAt(x, y, default := 1) {
    ; 上界用 MonitorGetCount()，而不是 SysGet(80)：MonitorGet 的编号域是前者，
    ; SM_CMONITORS 不含未参与桌面的显示器，两者可能不等，用它当上界会漏屏
    m := MonitorGetCount()
    loop m {
        MonitorGet(A_Index, &l, &t, &r, &b)
        if (x >= l && x <= r && y >= t && y <= b)
            return A_Index
    }
    return default
}

; 注意：以下各函数不能保证窗口的边框紧贴显示器边框，这是 Windows 的已知问题
; 修复是可行的，请查找 WinMoveEx()，但是受限于各种窗口的实现方式有区别，缩放的处理也不太统一，这不是完美的解决方案

; 修复 2025-09-06：完美修复了窗口边框与显示器边框的贴合问题

GetShadowThickness(hwnd) {
    DWMWA_EXTENDED_FRAME_BOUNDS := 9
    try {
        WinGetPos(&winX, &winY, &winW, &winH, "ahk_id " hwnd)
        extendedRect := Buffer(16, 0)
        if (DllCall("dwmapi\DwmGetWindowAttribute", "ptr", hwnd, "uint", DWMWA_EXTENDED_FRAME_BOUNDS, "ptr", extendedRect, "uint", 16, "int") == 0) {
            extBottom := NumGet(extendedRect, 12, "int")
            return (winY + winH) - extBottom
        }
    } catch Error as e {
        LogError(e, , PerResizeWindowDebug.mode)
    }
    return 0
}

; GetBorderThickness(hwnd) {
;     ; DWM 属性常量
;     DWMWA_EXTENDED_FRAME_BOUNDS := 9  ; 扩展框架边界
;     DWMWA_VISIBLE_FRAME_BORDER_THICKNESS := 37  ; 可见边框厚度

;     ; borderInfo := ""

;     try {
;         ; 获取窗口的常规位置和大小
;         WinGetPos(&winX, &winY, &winW, &winH, "ahk_id " hwnd)
;         WinGetClientPos(&clientX, &clientY, &clientW, &clientH, "ahk_id " hwnd)

;         ; 获取扩展框架边界 (RECT 结构)
;         extendedRect := Buffer(16, 0)  ; RECT 结构需要 16 字节
;         result1 := DllCall("dwmapi\DwmGetWindowAttribute",
;             "ptr", hwnd,
;             "uint", DWMWA_EXTENDED_FRAME_BOUNDS,
;             "ptr", extendedRect,
;             "uint", 16,
;             "int")

;         if (result1 == 0) {
;             ; extLeft := NumGet(extendedRect, 0, "int")
;             ; extTop := NumGet(extendedRect, 4, "int")
;             ; extRight := NumGet(extendedRect, 8, "int")
;             extBottom := NumGet(extendedRect, 12, "int")
;             ; extWidth := extRight - extLeft
;             ; extHeight := extBottom - extTop

;             ; borderInfo .= "--- Window Size & Border Info ---`n"
;             ; borderInfo .= "WinGetPosSize: " winW " * " winH "`n"
;             ; borderInfo .= "WinGetClientPosSize: " clientW " * " clientH "`n"
;             ; borderInfo .= "PlusExtendedFrameSize: " extWidth " * " extHeight "`n"

;             ; 计算边框厚度
;             ; leftBorder := clientX - extLeft
;             ; topBorder := clientY - extTop
;             ; rightBorder := extRight - (clientX + clientW)
;             bottomBorder := extBottom - (clientY + clientH)

;             ; borderInfo .= "BorderThickness: [Left: " leftBorder "] [Top: " topBorder "] [Right: " rightBorder "] [Bottom: " bottomBorder "]`n"

;             ; 计算阴影厚度 (WinGet 窗口边界与扩展边界的差异)
;             ; shadowLeft := extLeft - WinX
;             ; shadowTop := extTop - WinY
;             ; shadowRight := (winX + winW) - extRight
;             ; shadowBottom := (winY + winH) - extBottom

;             ; borderInfo .= "ShadowThickness: [Left: " shadowLeft "] [Top: " shadowTop "] [Right: " shadowRight "] [Bottom: " shadowBottom "]`n"
;         }

;         ; ; 尝试获取可见边框厚度
;         ; borderThickness := Buffer(4, 0)  ; UINT 类型需要 4 字节
;         ; result2 := DllCall("dwmapi\DwmGetWindowAttribute",
;         ;     "ptr", hwnd,
;         ;     "uint", DWMWA_VISIBLE_FRAME_BORDER_THICKNESS,
;         ;     "ptr", borderThickness,
;         ;     "uint", 4,
;         ;     "int")

;         ; if (result2 == 0) {
;         ;     thickness := NumGet(borderThickness, 0, "uint")
;         ;     ; borderInfo .= "VisibleFrameBorderThickness: " thickness " pixels`n"
;         ; }

;     } catch Error as e {
;         ; borderInfo .= "--- Window Size & Border Info ---`n"
;         ; borderInfo .= "Error getting border info: " e.Message "`n"
;     }

;     return bottomBorder  ; 返回底部边框厚度作为结果，三个边框的值没有见到不同的时候
; }

/**
 * 根据指定的网格数量和网格索引，将当前活动窗口调整到屏幕对应位置并设置相应大小
 * 支持多种分屏布局（2 格、3 格、4 格、9 格），不同网格数量对应不同的屏幕分割方式
 * @param {number} gridNum - 网格数量，决定分屏布局模式，支持的值：2、3、4、9
 * 
 * 2：两格布局，支持水平分割（h1 左半屏、h2 右半屏）和垂直分割（v1 上半屏、v2 下半屏）
 * 
 * 3：三格布局，支持水平分割（h1 左 1/3、h2 中 1/3、h3 右 1/3）和垂直分割（v1 上 1/3、v2 中 1/3、v3 下 1/3）
 * 
 * 4：四格布局（2 * 2 网格），索引 1-4 分别对应左上、右上、左下、右下
 * 
 * 9：九格布局（3 * 3 网格），索引 1-9 对应从左上到右下的 3 * 3 网格位置
 * 
 * @param {number|string} gridIndex - 网格索引，标识窗口在当前网格布局中的位置
 * 
 * 当 gridNum 为 4 或 9 时，取值为数字 1-4 或 1-9，对应网格中的具体位置
 * 
 * 当 gridNum 为 2 时，取值为字符串 "h1"、"h2"（水平分割）或 "v1"、"v2"（垂直分割）
 * 
 * 当 gridNum 为 3 时，取值为字符串 "h1"、"h2"、"h3"（水平分割）或 "v1"、"v2"、"v3"（垂直分割）
 */
SplitScreen(gridNum, gridIndex) {
    switch gridNum {
        case 4:
        {
            switch gridIndex {
                case 1:
                {
                    PerLeftUpAndResizeWindow(0.5, 0.5)
                }
                case 2:
                {
                    PerRightUpAndResizeWindow(0.5, 0.5)
                }
                case 3:
                {
                    PerLeftDownAndResizeWindow(0.5, 0.5)
                }
                case 4:
                {
                    PerRightDownAndResizeWindow(0.5, 0.5)
                }
            }
        }
        case 9:
        {
            switch gridIndex {
                case 1:
                {
                    PerLeftUpAndResizeWindow(0.334, 0.334)
                }
                case 2:
                {
                    PerUpAndResizeWindow(0.334, 0.334)
                }
                case 3:
                {
                    PerRightUpAndResizeWindow(0.334, 0.334)
                }
                case 4:
                {
                    PerLeftAndResizeWindow(0.334, 0.334)
                }
                case 5:
                {
                    PerCenterAndResizeWindow(0.334, 0.334)
                }
                case 6:
                {
                    PerRightAndResizeWindow(0.334, 0.334)
                }
                case 7:
                {
                    PerLeftDownAndResizeWindow(0.334, 0.334)
                }
                case 8:
                {
                    PerDownAndResizeWindow(0.334, 0.334)
                }
                case 9:
                {
                    PerRightDownAndResizeWindow(0.334, 0.334)
                }
            }
        }
        case 2:
        {
            switch gridIndex {
                case "h1":
                {
                    PerLeftAndResizeWindow(0.5, 1)
                }
                case "h2":
                {
                    PerRightAndResizeWindow(0.5, 1)
                }
                case "v1":
                {
                    PerUpAndResizeWindow(1, 0.5)
                }
                case "v2":
                {
                    PerDownAndResizeWindow(1, 0.5)
                }
            }
        }
        case 3:
        {
            switch gridIndex {
                case "h1":
                {
                    PerLeftAndResizeWindow(0.334, 1)
                }
                case "h2":
                {
                    PerCenterAndResizeWindow(0.334, 1)
                }
                case "h3":
                {
                    PerRightAndResizeWindow(0.334, 1)
                }
                case "v1":
                {
                    PerUpAndResizeWindow(1, 0.334)
                }
                case "v2":
                {
                    PerCenterAndResizeWindow(1, 0.334)
                }
                case "v3":
                {
                    PerDownAndResizeWindow(1, 0.334)
                }
            }
        }
    }
}

/**
 * 窗口居中并修改其大小
 * @param percentageW
 * @param percentageH
 * @returns {void} 
 */
PerCenterAndResizeWindow(percentageW, percentageH) {
    if F_NotActiveWin() {
        return
    }

    ; DllCall("SetThreadDpiAwarenessContext", "ptr", -1, "ptr")
    ; borderThickness := GetBorderThickness(hwnd)

    if (F_WindowMaxOrMin())
        WinRestore

    WinGetPos(&x, &y, &w, &h)

    hwnd := WinExist("A")
    shadowThickness := GetShadowThickness(hwnd)

    ms := F_GetMonitorAt(x + w / 2, y + h / 2)
    MonitorGetWorkArea(ms, &l, &t, &r, &b)
    w := r - l
    h := b - t

    winW := percentageW * w + 2 * shadowThickness
    winH := percentageH * h + shadowThickness
    winX := l + (w - winW) / 2
    winY := t + (h - winH + shadowThickness) / 2

    WinMove(winX, winY, winW, winH)
    ; DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
}

/**
 * 窗口左上并修改其大小
 * @param percentageW
 * @param percentageH
 * @returns {void} 
 */
PerLeftUpAndResizeWindow(percentageW, percentageH) {
    if F_NotActiveWin() {
        return
    }

    ; DllCall("SetThreadDpiAwarenessContext", "ptr", -1, "ptr")
    ; borderThickness := GetBorderThickness(hwnd)
    if (F_WindowMaxOrMin())
        WinRestore

    WinGetPos(&x, &y, &w, &h)

    hwnd := WinExist("A")
    shadowThickness := GetShadowThickness(hwnd)
    ms := F_GetMonitorAt(x + w / 2, y + h / 2)
    MonitorGetWorkArea(ms, &l, &t, &r, &b)
    w := r - l
    h := b - t

    winW := percentageW * w + 2 * shadowThickness
    winH := percentageH * h + shadowThickness
    winX := l - shadowThickness  ; 左对齐
    winY := t  ; 上对齐

    WinMove(winX, winY, winW, winH)
    ; DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
}

/**
 * 窗口左下并修改其大小
 * @param percentageW
 * @param percentageH
 * @returns {void} 
 */
PerLeftDownAndResizeWindow(percentageW, percentageH) {
    if F_NotActiveWin() {
        return
    }

    ; DllCall("SetThreadDpiAwarenessContext", "ptr", -1, "ptr")
    ; borderThickness := GetBorderThickness(hwnd)
    if (F_WindowMaxOrMin())
        WinRestore

    WinGetPos(&x, &y, &w, &h)

    hwnd := WinExist("A")
    shadowThickness := GetShadowThickness(hwnd)
    ms := F_GetMonitorAt(x + w / 2, y + h / 2)
    MonitorGetWorkArea(ms, &l, &t, &r, &b)
    w := r - l
    h := b - t

    winW := percentageW * w + 2 * shadowThickness
    winH := percentageH * h + shadowThickness
    winX := l - shadowThickness  ; 左对齐
    winY := b - winH + shadowThickness  ; 下对齐

    WinMove(winX, winY, winW, winH)
    ; DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
}

/**
 * 窗口右上并修改其大小
 * @param percentageW
 * @param percentageH
 * @returns {void} 
 */
PerRightUpAndResizeWindow(percentageW, percentageH) {
    if F_NotActiveWin() {
        return
    }

    ; DllCall("SetThreadDpiAwarenessContext", "ptr", -1, "ptr")
    ; borderThickness := GetBorderThickness(hwnd)
    if (F_WindowMaxOrMin())
        WinRestore

    WinGetPos(&x, &y, &w, &h)

    hwnd := WinExist("A")
    shadowThickness := GetShadowThickness(hwnd)
    ms := F_GetMonitorAt(x + w / 2, y + h / 2)
    MonitorGetWorkArea(ms, &l, &t, &r, &b)
    w := r - l
    h := b - t

    winW := percentageW * w + 2 * shadowThickness
    winH := percentageH * h + shadowThickness
    winX := r - winW + shadowThickness ; 右对齐
    winY := t  ; 上对齐

    WinMove(winX, winY, winW, winH)
    ; DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
}

/**
 * 窗口右下并修改其大小
 * @param percentageW
 * @param percentageH
 * @returns {void} 
 */
PerRightDownAndResizeWindow(percentageW, percentageH) {
    if F_NotActiveWin() {
        return
    }

    ; DllCall("SetThreadDpiAwarenessContext", "ptr", -1, "ptr")
    ; borderThickness := GetBorderThickness(hwnd)
    if (F_WindowMaxOrMin())
        WinRestore

    WinGetPos(&x, &y, &w, &h)

    hwnd := WinExist("A")
    shadowThickness := GetShadowThickness(hwnd)
    ms := F_GetMonitorAt(x + w / 2, y + h / 2)
    MonitorGetWorkArea(ms, &l, &t, &r, &b)
    w := r - l
    h := b - t

    winW := percentageW * w + 2 * shadowThickness
    winH := percentageH * h + shadowThickness
    winX := r - winW + shadowThickness  ; 右对齐
    winY := b - winH + shadowThickness  ; 下对齐

    WinMove(winX, winY, winW, winH)
    ; DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
}

/**
 * 窗口上中并修改其大小
 * @param percentageW
 * @param percentageH
 * @returns {void} 
 */
PerUpAndResizeWindow(percentageW, percentageH) {
    if F_NotActiveWin() {
        return
    }

    ; DllCall("SetThreadDpiAwarenessContext", "ptr", -1, "ptr")
    ; borderThickness := GetBorderThickness(hwnd)
    if (F_WindowMaxOrMin())
        WinRestore

    WinGetPos(&x, &y, &w, &h)

    hwnd := WinExist("A")
    shadowThickness := GetShadowThickness(hwnd)
    ms := F_GetMonitorAt(x + w / 2, y + h / 2)
    MonitorGetWorkArea(ms, &l, &t, &r, &b)
    w := r - l
    h := b - t

    winW := percentageW * w + 2 * shadowThickness
    winH := percentageH * h + shadowThickness
    winX := l + (w - winW) / 2  ; 水平居中
    winY := t  ; 上对齐

    WinMove(winX, winY, winW, winH)
    ; DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
}

/**
 * 窗口右中并修改其大小
 * @param percentageW
 * @param percentageH
 * @returns {void} 
 */
PerRightAndResizeWindow(percentageW, percentageH) {
    if F_NotActiveWin() {
        return
    }

    ; DllCall("SetThreadDpiAwarenessContext", "ptr", -1, "ptr")
    ; borderThickness := GetBorderThickness(hwnd)
    if (F_WindowMaxOrMin())
        WinRestore

    WinGetPos(&x, &y, &w, &h)

    hwnd := WinExist("A")
    shadowThickness := GetShadowThickness(hwnd)
    ms := F_GetMonitorAt(x + w / 2, y + h / 2)
    MonitorGetWorkArea(ms, &l, &t, &r, &b)
    w := r - l
    h := b - t

    winW := percentageW * w + 2 * shadowThickness
    winH := percentageH * h + shadowThickness
    winX := r - winW + shadowThickness  ; 右对齐
    winY := t + (h - winH + shadowThickness) / 2  ; 垂直居中

    WinMove(winX, winY, winW, winH)
    ; DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
}

/**
 * 窗口下中并修改其大小
 * @param percentageW
 * @param percentageH
 * @returns {void} 
 */
PerDownAndResizeWindow(percentageW, percentageH) {
    if F_NotActiveWin() {
        return
    }

    ; DllCall("SetThreadDpiAwarenessContext", "ptr", -1, "ptr")
    ; borderThickness := GetBorderThickness(hwnd)
    if (F_WindowMaxOrMin())
        WinRestore

    WinGetPos(&x, &y, &w, &h)

    hwnd := WinExist("A")
    shadowThickness := GetShadowThickness(hwnd)
    ms := F_GetMonitorAt(x + w / 2, y + h / 2)
    MonitorGetWorkArea(ms, &l, &t, &r, &b)
    w := r - l
    h := b - t

    winW := percentageW * w + 2 * shadowThickness
    winH := percentageH * h + shadowThickness
    winX := l + (w - winW) / 2  ; 水平居中
    winY := b - winH + shadowThickness ; 下对齐

    WinMove(winX, winY, winW, winH)
    ; DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
}

/**
 * 窗口左中并修改其大小
 * @param percentageW
 * @param percentageH
 * @returns {void} 
 */
PerLeftAndResizeWindow(percentageW, percentageH) {
    if F_NotActiveWin() {
        return
    }

    ; DllCall("SetThreadDpiAwarenessContext", "ptr", -1, "ptr")
    ; borderThickness := GetBorderThickness(hwnd)
    if (F_WindowMaxOrMin())
        WinRestore

    WinGetPos(&x, &y, &w, &h)

    hwnd := WinExist("A")
    shadowThickness := GetShadowThickness(hwnd)
    ms := F_GetMonitorAt(x + w / 2, y + h / 2)
    MonitorGetWorkArea(ms, &l, &t, &r, &b)
    w := r - l
    h := b - t

    winW := percentageW * w + 2 * shadowThickness
    winH := percentageH * h + shadowThickness
    winX := l - shadowThickness ; 左对齐
    winY := t + (h - winH + shadowThickness) / 2  ; 垂直居中

    WinMove(winX, winY, winW, winH)
    ; DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
}

/**
 * 把活动窗口平移到它所在显示器工作区的某条边缘，只挪位置，不改变宽高
 *
 * 与上面的 Per*AndResizeWindow 系列的差别是：那些函数会按比例改写宽高，是「重新排版」；
 * 本函数保留用户已经调好的窗口大小，只做贴边对齐，因此宽高一律不参与计算。
 * 边缘取的是 MonitorGetWorkArea 的工作区，已经排除任务栏，所以贴上去不会压在任务栏底下。
 *
 * @param {string} edge 贴边方向，取 "Left" / "Right" / "Up" / "Down"
 * @returns {void}
 */
SnapWindow(edge) {
    if F_NotActiveWin() {
        return
    }

    if F_WindowMaxOrMin() {
        ; 最大化窗口的「位置」由系统托管，WinMove 对它的平移不会生效；
        ; 最小化窗口虽然 WinMove 明确不支持移动，但 WinGetMinMax 返回 -1 同样为真，会落到这个分支。
        ; 这里刻意不调用 WinRestore：还原会把宽高改回普通窗口的尺寸，与「纯平移」的约定冲突，
        ; 所以只提示用户自己先还原，再重新触发一次贴边
        ToolTip("窗口处于最大化或最小化状态`n请先将其还原为普通窗口，再执行贴边操作")
        SetTimer(ToolTip, -3000)
        return
    }

    WinGetPos(&x, &y, &w, &h)

    hwnd := WinExist("A")
    shadowThickness := GetShadowThickness(hwnd)

    ; 与 Per* 系列一致，用窗口中心所在显示器作为目标显示器；
    ; 副屏的工作区坐标可能是负数，故不假设 l、t 从 0 开始，全部用实际返回值计算
    ms := F_GetMonitorAt(x + w / 2, y + h / 2)
    MonitorGetWorkArea(ms, &l, &t, &r, &b)

    ; 阴影补偿沿用 Per* 系列的符号约定：DWM 的阴影画在窗口矩形之外，
    ; 左、右、下三条边要让窗口矩形越过工作区边界一个阴影厚度，可见边框才与工作区边界对齐；
    ; 上边沿用现有做法不加补偿。WinMove 省略宽高即不改变该维度尺寸，故这里只传 x、y 两个参数
    ;
    ; 合法取值的列表只在这一处 switch 里出现，校验交给 default：另写一份 if 四连判断会让
    ; 「支持哪些方向」和「怎么判断方向」变成两份需要同步维护的列表，加方向时容易漏改一处。
    ; 代价是取值非法时会先执行上面几句读取并把窗口位置、阴影、工作区都取出来，这些调用只读、
    ; 无副作用，只是多算几次，比两份列表逐渐不一致更划算。
    ; switch 省略 CaseSense 时字符串比较区分大小写，所以这里传 "left" 会走 default 提示参数错误。
    ; default 里不抛异常，避免热键线程被中断后用户只看到「按键没反应」
    switch edge {
        case "Left":
            WinMove(l - shadowThickness, y)
        case "Right":
            WinMove(r - w + shadowThickness, y)
        case "Up":
            WinMove(x, t)
        case "Down":
            WinMove(x, b - h + shadowThickness)
        default:
            ToolTip("SnapWindow 的 edge 参数只接受 Left、Right、Up、Down 之一，当前值为 " edge)
            SetTimer(ToolTip, -3000)
    }

    ; 已知风险：WinMove 文档写明，在缩放比例不同的多显示器环境下，窗口跨屏后系统会按其
    ; 新所在显示器的缩放重新计算位置与大小，实际落地结果可能偏离本函数的请求值。
    ; 第一版不做移动后的二次校正，因为那需要先 WinGetPos 读回真实位置再补偿一次，
    ; 还得判断偏差是来自 DPI 重缩放还是窗口自身限制，复杂度与收益不成比例；
    ; 待收到混合 DPI 环境下的实际反馈后再决定是否补校正
}
