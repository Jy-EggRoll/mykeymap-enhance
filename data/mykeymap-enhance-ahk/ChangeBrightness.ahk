#Requires AutoHotkey v2.0

#Include ./MonitorLib/Monitor.ahk

; 亮度一律按显示器设备名（形如 \\.\DISPLAY2）定位，不用编号。
; 设备名尾号由系统按设备分配，与桌面上的屏幕数量、枚举顺序都没有对应关系：内屏关闭、
; 只剩外接屏时，这块外接屏仍然是 DISPLAY2，而 SysGet(80) 只会数到 1，把尾号当数组下标就会越界。
; 反过来，MonitorLib 的 GetMonitorHandle 只用设备名做子串匹配，传尾号数字可能一个都匹配不上，
; 一旦匹配不到它就会回退到主屏，调节于是落到了另一块屏上。
; 所以这里一律传完整设备名，空串表示主屏。

; Monitor 实例本身不存状态，枚举结果缓存在类里的 static 变量中，整个模块共用一个实例即可。
monitorCol := Monitor()

; 读取亮度：Display 为显示器设备名，空串表示主屏。
; 返回含 Minimum、Current、Maximum 的 Map，两条路都读不到时返回空串。
GetBrightness(Display := "") {
    global monitorCol
    try {
        return monitorCol.GetBrightness(Display)
    } catch Error {
        ; DDC/CI 读不到时改走 WMI，见下面的说明。
    }
    ; WMI 只暴露内置屏的背光，也没有最小值和最大值，这里按 0 到 100 处理；
    ; 只取第一个实例，多个内置屏时其余的不参与。
    ; 外接屏不支持 DDC/CI 时，这条回退路径读到的是内置屏的亮度，属于已知局限。
    try {
        for property in ComObjGet("winmgmts:\\.\root\WMI").ExecQuery("SELECT * FROM WmiMonitorBrightness") {
            return Map("Minimum", 0, "Current", property.CurrentBrightness, "Maximum", 100)
        }
    } catch Error {
    }
    return ""
}

; 写入亮度：Display 为显示器设备名，空串表示主屏，timeout 是 WMI 回退路径的超时秒数。
; 返回实际生效的路径 "DDC" 或 "WMI"，两条路都写不进去时返回空串。
SetBrightness(brightness, Display := "", timeout := 1) {
    global monitorCol
    try {
        monitorCol.SetBrightness(brightness, Display)
        return "DDC"
    } catch Error {
        ; 同 GetBrightness，DDC/CI 不通时改走 WMI，这条回退路径只作用于内置屏。
    }
    try {
        for property in ComObjGet("winmgmts:\\.\root\WMI").ExecQuery("SELECT * FROM WmiMonitorBrightnessMethods") {
            property.WmiSetBrightness(timeout, brightness)
            return "WMI"
        }
    } catch Error {
    }
    return ""
}

; 鼠标所在显示器的设备名，没有命中任何屏时返回空串。
DisplayAtMouse() {
    global monitorCol
    ; 热键和定时器每次都会新开线程，每个新线程的坐标模式都会回到默认的活动窗口客户区坐标，
    ; 只依赖别的脚本在启动阶段设置过的模式，切换窗口后就会把鼠标位置算偏，所以这里显式指定。
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mouseX, &mouseY)
    monitors := monitorCol.EnumDisplayMonitors()
    if (!IsObject(monitors)) {
        return ""
    }
    for info in monitors {
        if (mouseX >= info["Left"] && mouseX < info["Right"] && mouseY >= info["Top"] && mouseY < info["Bottom"]) {
            return info["Name"]
        }
    }
    return ""
}

; 提示文案里的短名：设备名形如 \\.\DISPLAY2，只保留末尾的 DISPLAY2。
DisplayLabel(Display) {
    return RegExReplace(Display, "^.*\\", "")
}

; 调节结果和异常一律走 ToolTip：热键触发的报错弹窗会抢走焦点，打断正在进行的输入。
ShowBrightnessTip(text, delay := 1000) {
    ToolTip(text)
    SetTimer(ToolTip, -delay)
}

; 加减亮度共用同一条路径，delta 的符号决定方向。
AdjustBrightness(delta) {
    Display := DisplayAtMouse()
    if (Display = "") {
        ShowBrightnessTip("鼠标不在任何显示器上，无法调节亮度", 3000)
        return
    }
    label := DisplayLabel(Display)
    setting := GetBrightness(Display)
    if (!IsObject(setting)) {
        ShowBrightnessTip("读不到 " label " 的亮度，可能不支持 DDC/CI", 3000)
        return
    }
    target := Max(setting["Minimum"], Min(setting["Current"] + delta, setting["Maximum"]))
    writePath := SetBrightness(target, Display)
    if (writePath = "") {
        ShowBrightnessTip("写入 " label " 的亮度失败，可能不支持 DDC/CI", 3000)
        return
    }
    if (writePath = "WMI") {
        ; 回退改的是内置屏的背光，此时报出鼠标所在屏的设备名会误导用户。
        ShowBrightnessTip("亮度 " target "（WMI 回退，实际调节内置屏）")
        return
    }
    ShowBrightnessTip("亮度 " target "（" label "）")
}

IncBrightness(dealt) {
    AdjustBrightness(dealt)
}

DecBrightness(dealt) {
    AdjustBrightness(-dealt)
}
