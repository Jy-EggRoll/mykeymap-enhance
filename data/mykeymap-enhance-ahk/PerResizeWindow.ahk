#Requires AutoHotkey v2.0

#Include ./LoggerLib/Logger.ahk

class PerResizeWindowDebug {
    static mode := false
}
; F_ 前缀用于避开 MyKeymap 内置函数的同名冲突，本身没有其他含义

/**
 * 活动窗口不存在或是桌面时返回 true，否则返回 false
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
 * 查询窗口的最大化或最小化状态，参数写法与 `WinGetMinMax` 一致
 * @param {string} winTitle AHK 中的 WinTitle
 * @returns {number} 0 表示普通窗口，1 表示最大化，-1 表示最小化
 */
F_WindowMaxOrMin(winTitle := "A") {
    return WinGetMinMax(winTitle)
}

/**
 * 返回给定坐标落在哪台显示器上
 * @param x 屏幕横坐标
 * @param y 屏幕纵坐标
 * @param {number} default 坐标不在任何显示器内时返回的编号
 * @returns {number} 显示器编号
 */
F_GetMonitorAt(x, y, default := 1) {
    ; 上界用 `MonitorGetCount()`，而不是 `SysGet(80)`：`MonitorGet` 的编号域是前者，
    ; SM_CMONITORS 不含未参与桌面的显示器，两者可能不等，用它当上界会漏屏
    m := MonitorGetCount()
    loop m {
        MonitorGet(A_Index, &l, &t, &r, &b)
        if (x >= l && x <= r && y >= t && y <= b)
            return A_Index
    }
    return default
}

; DWM 的阴影画在窗口矩形之外，若直接按工作区尺寸摆放，可见边框会与工作区边界差一个阴影厚度。
; GetShadowThickness 量出这段厚度，摆放函数据此让窗口矩形在左、右、下三边各向外多撑一点，
; 可见边框因此贴着工作区边界；上边沿用不加补偿的做法

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

/**
 * 按网格数量与网格索引，把活动窗口摆到工作区对应的位置
 *
 * @param {number} gridNum 网格数量，取 2、3、4、9
 * 2：水平分屏（h1 左半屏、h2 右半屏）或垂直分屏（v1 上半屏、v2 下半屏）
 * 3：水平分屏（h1、h2、h3 各占左中右 1/3）或垂直分屏（v1、v2、v3 各占上中下 1/3）
 * 4：2 × 2 网格，索引 1-4 依次为左上、右上、左下、右下
 * 9：3 × 3 网格，索引 1-9 从左上到右下逐行排列
 * @param {number|string} gridIndex 网格索引，标识窗口落在网格中的哪一格
 * gridNum 为 4 或 9 时取数字 1-4 或 1-9
 * gridNum 为 2 时取 "h1"、"h2" 或 "v1"、"v2"
 * gridNum 为 3 时取 "h1"、"h2"、"h3" 或 "v1"、"v2"、"v3"
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
    ; 两次半屏按键之间允许的最大间隔，单位毫秒，改为 0 即关闭组合
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
     * @returns {object|string} 命中组合时返回由横向边与纵向边组成的数组，否则返回空字符串
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

        ; 文档只说明 `A_TickCount` 是系统启动以来的毫秒数、上限 49.7 天，没有约定回绕之后
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
 * @param {string} anchor 锚点名，取 `SplitAnchor.edges` 的键
 * @param percentageW 目标宽度占工作区的比例
 * @param percentageH 目标高度占工作区的比例
 * @returns {void}
 */
PerResizeApplyLayout(anchor, percentageW, percentageH) {
    if F_NotActiveWin() {
        return
    }

    ; 组合判定只需要窗口句柄，不需要位置，所以刻意放在 `WinRestore` 之前：
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
    ; case 与 `SplitAnchor.edges` 必须一一对应。锚点表里加了新的边名却忘了加 case 时，
    ; 直接抛错比让 winX、winY 以「变量未赋值」的形式在 `WinMove` 处报错更容易定位；
    ; 这里是代码内部的不变式被破坏，与 `SnapWindow` 那种用户传参错误不同，故不做 ToolTip 提示
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

; 以下九个函数是给外部调用的摆放接口，只把锚点名转交给 `PerResizeApplyLayout`。
; 两个参数是目标宽高占工作区的比例，调用会直接改写窗口大小，与只挪位置的 `SnapWindow` 不同
PerLeftUpAndResizeWindow(percentageW, percentageH) {
    PerResizeApplyLayout("LeftUp", percentageW, percentageH)
}

PerUpAndResizeWindow(percentageW, percentageH) {
    PerResizeApplyLayout("Up", percentageW, percentageH)
}

PerRightUpAndResizeWindow(percentageW, percentageH) {
    PerResizeApplyLayout("RightUp", percentageW, percentageH)
}

PerLeftAndResizeWindow(percentageW, percentageH) {
    PerResizeApplyLayout("Left", percentageW, percentageH)
}

PerCenterAndResizeWindow(percentageW, percentageH) {
    PerResizeApplyLayout("Center", percentageW, percentageH)
}

PerRightAndResizeWindow(percentageW, percentageH) {
    PerResizeApplyLayout("Right", percentageW, percentageH)
}

PerLeftDownAndResizeWindow(percentageW, percentageH) {
    PerResizeApplyLayout("LeftDown", percentageW, percentageH)
}

PerDownAndResizeWindow(percentageW, percentageH) {
    PerResizeApplyLayout("Down", percentageW, percentageH)
}

PerRightDownAndResizeWindow(percentageW, percentageH) {
    PerResizeApplyLayout("RightDown", percentageW, percentageH)
}

/**
 * 把活动窗口平移到它所在显示器工作区的某条边缘，只挪位置，不改变宽高
 *
 * 与上面的 Per*AndResizeWindow 系列的差别是：那些函数会按比例改写宽高，是「重新排版」；
 * 本函数保留用户已经调好的窗口大小，只做贴边对齐，因此宽高一律不参与计算。
 * 边缘取的是 `MonitorGetWorkArea` 的工作区，已经排除任务栏，所以贴上去不会压在任务栏底下。
 *
 * @param {string} edge 贴边方向，取 "Left" / "Right" / "Up" / "Down"
 * @returns {void}
 */
SnapWindow(edge) {
    if F_NotActiveWin() {
        return
    }

    if F_WindowMaxOrMin() {
        ; 最大化窗口的「位置」由系统托管，`WinMove` 对它的平移不会生效；
        ; 最小化窗口虽然 `WinMove` 明确不支持移动，但 `WinGetMinMax` 返回 -1 同样为真，会落到这个分支。
        ; 这里刻意不调用 `WinRestore`：还原会把宽高改回普通窗口的尺寸，与「纯平移」的约定冲突，
        ; 所以只提示用户自己先还原，再重新触发一次贴边
        ToolTip("窗口处于最大化或最小化状态`n请先将其还原为普通窗口，再执行贴边操作")
        SetTimer(ToolTip, -3000)
        return
    }

    WinGetPos(&x, &y, &w, &h)

    hwnd := WinExist("A")
    shadowThickness := GetShadowThickness(hwnd)

    ; 与 Per* 系列一致，用窗口中心所在显示器作为目标显示器；
    ; 副显示器的工作区坐标可能是负数，故不假设 l、t 从 0 开始，全部用实际返回值计算
    ms := F_GetMonitorAt(x + w / 2, y + h / 2)
    MonitorGetWorkArea(ms, &l, &t, &r, &b)

    ; 阴影补偿沿用 Per* 系列的符号约定：DWM 的阴影画在窗口矩形之外，
    ; 左、右、下三条边要让窗口矩形越过工作区边界一个阴影厚度，可见边框才与工作区边界对齐；
    ; 上边沿用现有做法不加补偿。`WinMove` 省略宽高即不改变该维度尺寸，故这里只传 x、y 两个参数
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

    ; 已知风险：`WinMove` 文档写明，缩放比例不同的多显示器环境下，窗口跨屏后系统会按新所在
    ; 显示器的缩放重算位置与大小，实际落地结果可能偏离本函数的请求值。
    ; 这里不做移动后的二次校正：那需要先 `WinGetPos` 读回真实位置再补偿一次，还得判断偏差
    ; 来自 DPI 重缩放还是窗口自身限制，改造成本高于当前收益
}
