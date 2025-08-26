#Include ./Monitor.ahk

monitors := []
currentIndex := 1
monitorCol := Monitor()
monCount := SysGet(80)

InitMonitors() {
    global monitors
    global monCount

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

InitMonitors()

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
        monitorCol.setBrightness(brightness, monIndex)
    } catch Error as e {
        ; 使用wmi设置亮度
        for property in ComObjGet("winmgmts:\\.\root\WMI").ExecQuery("SELECT * FROM WmiMonitorBrightnessMethods")
            property.WmiSetBrightness(timeout, brightness)
    }
}

; 上一个显示屏
PreviousMonitor() {
    global currentIndex
    if (currentIndex > 1) {
        currentIndex--
    }
}

; 下一个显示屏
NextMonitor() {
    global currentIndex
    global monCount
    if (currentIndex < monCount) {
        currentIndex++
    }
}

; 加亮度
IncBrightness(dealt) {
    global monitors
    global currentIndex
    m := monitors.Get(currentIndex)
    val := m["brightness"] + dealt
    if val > 100 {
        val := 100
    }
    SetBrightness(val, currentIndex)
    m["brightness"] := val
}

; 减亮度
DecBrightness(dealt) {
    global monitors
    global currentIndex
    m := monitors.Get(currentIndex)
    val := m["brightness"] - dealt
    if val < 0 {
        val := 0
    }
    SetBrightness(val, currentIndex)
    m["brightness"] := val
}
