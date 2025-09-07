#Include ./Monitor.ahk

global currentIndex := 1
global previousMonCount := SysGet(80)

InitMonitors() {
    global monitors := []
    global monitorCol := Monitor()
    global monCount := SysGet(80)

    ; 获取已使用的显示器数量
    loop monCount {
        monIndex := A_Index

        ; 获取显示器当前亮度
        brightness := GetBrightness(monIndex)

        m := Map()
        m["brightness"] := brightness
        monitors.Push(m)
    }
}

; 获取屏幕亮度
GetBrightness(monIndex) {
    global monitorCol
    brightness := ""
    try {
        brightness := monitorCol.GetBrightness(monIndex)["Current"]
    } catch Error as e {
        ; 使用wmi获取亮度
        for property in ComObjGet("winmgmts:\\.\root\WMI").ExecQuery("SELECT * FROM WmiMonitorBrightness")
            brightness := property.CurrentBrightness
    }
    return brightness
}

; 设置屏幕亮度
SetBrightness(brightness, monIndex, timeout := 1) {
    global monitorCol
    try {
        monitorCol.SetBrightness(brightness, monIndex)
    } catch Error as e {
        ; 使用wmi设置亮度
        for property in ComObjGet("winmgmts:\\.\root\WMI").ExecQuery("SELECT * FROM WmiMonitorBrightnessMethods")
            property.WmiSetBrightness(timeout, brightness)
    }
}

; 上一个显示屏
PreviousMonitor() {
    InitMonitors()
    global currentIndex
    if (currentIndex > 1) {
        currentIndex--
        ToolTip("屏幕编号为 " currentIndex)
        SetTimer(ToolTip, -1000)
    } else {
        ToolTip("屏幕编号为 " currentIndex)
        SetTimer(ToolTip, -1000)
    }
}

; 下一个显示屏
NextMonitor() {
    InitMonitors()
    global currentIndex
    global monCount
    if (currentIndex < monCount) {
        currentIndex++
        ToolTip("屏幕编号为 " currentIndex)
        SetTimer(ToolTip, -1000)
    } else {
        ToolTip("屏幕编号为 " currentIndex)
        SetTimer(ToolTip, -1000)
    }
}

; 加亮度
IncBrightness(dealt) {
    InitMonitors()
    global monCount
    global monitors
    global currentIndex
    global previousMonCount
    if (previousMonCount != monCount) {
        ToolTip("显示器配置变更 请立即重启 MyKeymap 以保证亮度设置正确")
        SetTimer(ToolTip, -3000)
        return
    }
    m := monitors.Get(currentIndex)
    val := m["brightness"] + dealt
    if val > 100 {
        val := 100
    }
    SetBrightness(val, currentIndex)
    m["brightness"] := val
    ToolTip("当前亮度是 " m["brightness"] " 屏幕编号为 " currentIndex)
    SetTimer(ToolTip, -1000)
    previousMonCount := monCount
}

; 减亮度
DecBrightness(dealt) {
    InitMonitors()
    global monCount
    global monitors
    global currentIndex
    global previousMonCount
    if (previousMonCount != monCount) {
        ToolTip("显示器配置变更 请立即重启 MyKeymap 以保证亮度设置正确")
        SetTimer(ToolTip, -3000)
        return
    }
    m := monitors.Get(currentIndex)
    val := m["brightness"] - dealt
    if val < 0 {
        val := 0
    }
    SetBrightness(val, currentIndex)
    m["brightness"] := val
    ToolTip("当前亮度是 " m["brightness"] " 屏幕编号为 " currentIndex)
    SetTimer(ToolTip, -1000)
    previousMonCount := monCount
}
