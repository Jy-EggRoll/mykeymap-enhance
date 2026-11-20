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
 * 九个锚点与各自对应的两条工作区边
 *
 * 锚点名沿用公开函数的叫法：只写一条边表示另一个方向居中（"Left" 即左中，"Up" 即上中），
 * 两条都写表示角落。横向边决定 winX，纵向边决定 winY，九个位置因此共用一份算式
 */
class SplitAnchor {
    static edges := Map(
        "LeftUp", ["Left", "Up"],
        "Up", ["Center", "Up"],
        "RightUp", ["Right", "Up"],
        "Left", ["Left", "Center"],
        "Center", ["Center", "Center"],
        "Right", ["Right", "Center"],
        "LeftDown", ["Left", "Down"],
        "Down", ["Center", "Down"],
        "RightDown", ["Right", "Down"]
    )
}

/**
 * 两次半屏按键之间的衔接状态
 *
 * 只记上一次半屏调用：组成四分之一屏后立即清空，所以最多接两步；不参与组合的调用
 * 也清空，避免 1/3、1/9 分屏与四分之一屏互相干扰
 */
class SplitChain {
    ; 两次按键之间允许的最大间隔，单位毫秒，改为 0 即关闭组合
    static timeoutMs := 2000
    static hwnd := 0
    static axis := ""
    static side := ""
    static tick := 0

    /**
     * 判断本次按键能否与上一次半屏调用组成四分之一屏，并维护衔接状态
     *
     * @param {integer} hwnd 活动窗口句柄，换了窗口就不组合
     * @param {string} hSide 本次调用的横向边，取 Left、Center、Right
     * @param {string} vSide 本次调用的纵向边，取 Up、Center、Down
     * @param percentageW 本次调用的宽度比例
     * @param percentageH 本次调用的高度比例
     * @returns {object|string} 命中组合时返回 [横向边, 纵向边]，否则返回空字符串
     */
    static Combine(hwnd, hSide, vSide, percentageW, percentageH) {
        if (SplitChain.timeoutMs <= 0) {
            SplitChain.Clear()
            return ""
        }

        ; 只有给了整条边的半屏调用参与组合，判定依据是比例而不是锚点名；
        ; 锚点落在中线上时没有边可以记进状态，一并不参与
        axis := ""
        side := ""
        if (percentageW = 0.5 && percentageH = 1 && hSide != "Center") {
            axis := "h"
            side := hSide
        } else if (percentageW = 1 && percentageH = 0.5 && vSide != "Center") {
            axis := "v"
            side := vSide
        }
        if (axis = "") {
            SplitChain.Clear()
            return ""
        }

        ; 文档只说明 A_TickCount 是系统启动以来的毫秒数、上限 49.7 天，没有约定回绕之后
        ; 怎么取值。多一层 now >= tick 的比较，是为了在计数器回绕时不把过期状态当成有效状态：
        ; 回绕之后 now 小于记下的 tick，这一条不成立，本次按键就按未命中处理
        now := A_TickCount
        if (SplitChain.hwnd = hwnd && SplitChain.axis != axis
            && now >= SplitChain.tick && now - SplitChain.tick <= SplitChain.timeoutMs) {
            ; 先按下的那条边决定另一个方向，后按下的决定本方向，顺序因此无关：
            ; 先左后上与先上后左都落在左上
            if (axis = "h") {
                combo := [side, SplitChain.side]
            } else {
                combo := [SplitChain.side, side]
            }
            SplitChain.Clear()
            return combo
        }

        ; 没命中组合：同轴重复、超出间隔、换了窗口都落到这里。本次仍按绝对半屏摆放，
        ; 状态改为记下本次按键，新的两步组合从这一下重新计时
        SplitChain.hwnd := hwnd
        SplitChain.axis := axis
        SplitChain.side := side
        SplitChain.tick := now
        return ""
    }

    static Clear() {
        SplitChain.hwnd := 0
        SplitChain.axis := ""
        SplitChain.side := ""
        SplitChain.tick := 0
    }
}

/**
 * 按比例把活动窗口摆到工作区的某个锚点上
 *
 * 九个公开函数只负责给出锚点，算式集中在这里维护
 *
 * @param {string} anchor 锚点名，取 SplitAnchor.edges 的键
 * @param percentageW 目标宽度占工作区的比例
 * @param percentageH 目标高度占工作区的比例
 * @returns {void}
 */
PerResizeApplyLayout(anchor, percentageW, percentageH) {
    if F_NotActiveWin() {
        return
    }

    ; 组合判定只需要窗口句柄，不需要位置，所以刻意放在 WinRestore 之前：
    ; 最大化、最小化的窗口也能参与组合，不必先还原再判断
    hwnd := WinExist("A")
    edges := SplitAnchor.edges[anchor]
    combo := SplitChain.Combine(hwnd, edges[1], edges[2], percentageW, percentageH)
    if IsObject(combo) {
        edges := combo
        percentageW := 0.5
        percentageH := 0.5
    }

    if (F_WindowMaxOrMin())
        WinRestore

    WinGetPos(&x, &y, &w, &h)

    shadowThickness := GetShadowThickness(hwnd)

    ms := F_GetMonitorAt(x + w / 2, y + h / 2)
    MonitorGetWorkArea(ms, &l, &t, &r, &b)
    w := r - l
    h := b - t

    winW := percentageW * w + 2 * shadowThickness
    winH := percentageH * h + shadowThickness

    hSide := edges[1]
    vSide := edges[2]
    ; case 与 SplitAnchor.edges 必须一一对应。锚点表里加了新的边名却忘了加 case 时，
    ; 直接抛错比让 winX、winY 以「变量未赋值」的形式在 WinMove 处报错更容易定位；
    ; 这里是代码内部的不变式被破坏，与 SnapWindow 那种用户传参错误不同，故不做 ToolTip 提示
    switch hSide {
        case "Left":
            winX := l - shadowThickness
        case "Center":
            winX := l + (w - winW) / 2
        case "Right":
            winX := r - winW + shadowThickness
        default:
            throw Error("SplitAnchor.edges 的横向边只能取 Left、Center、Right，当前为 " hSide)
    }
    switch vSide {
        case "Up":
            winY := t
        case "Center":
            winY := t + (h - winH + shadowThickness) / 2
        case "Down":
            winY := b - winH + shadowThickness
        default:
            throw Error("SplitAnchor.edges 的纵向边只能取 Up、Center、Down，当前为 " vSide)
    }

    WinMove(winX, winY, winW, winH)
}

/**
 * 窗口左上并修改其大小
 */
PerLeftUpAndResizeWindow(percentageW, percentageH) {
    PerResizeApplyLayout("LeftUp", percentageW, percentageH)
}

/**
 * 窗口上中并修改其大小
 */
PerUpAndResizeWindow(percentageW, percentageH) {
    PerResizeApplyLayout("Up", percentageW, percentageH)
}

/**
 * 窗口右上并修改其大小
 */
PerRightUpAndResizeWindow(percentageW, percentageH) {
    PerResizeApplyLayout("RightUp", percentageW, percentageH)
}

/**
 * 窗口左中并修改其大小
 */
PerLeftAndResizeWindow(percentageW, percentageH) {
    PerResizeApplyLayout("Left", percentageW, percentageH)
}

/**
 * 窗口居中并修改其大小
 */
PerCenterAndResizeWindow(percentageW, percentageH) {
    PerResizeApplyLayout("Center", percentageW, percentageH)
}

/**
 * 窗口右中并修改其大小
 */
PerRightAndResizeWindow(percentageW, percentageH) {
    PerResizeApplyLayout("Right", percentageW, percentageH)
}

/**
 * 窗口左下并修改其大小
 */
PerLeftDownAndResizeWindow(percentageW, percentageH) {
    PerResizeApplyLayout("LeftDown", percentageW, percentageH)
}

/**
 * 窗口下中并修改其大小
 */
PerDownAndResizeWindow(percentageW, percentageH) {
    PerResizeApplyLayout("Down", percentageW, percentageH)
}

/**
 * 窗口右下并修改其大小
 */
PerRightDownAndResizeWindow(percentageW, percentageH) {
    PerResizeApplyLayout("RightDown", percentageW, percentageH)
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
