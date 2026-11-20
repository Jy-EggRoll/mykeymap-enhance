#Requires AutoHotkey v2.0

#Include ./MonitorLib/Monitor.ahk

; 显示器以完整设备名（形如 \\.\DISPLAY2）作为标识，不使用序号。
; 后缀由系统分配，和显示器数量、枚举顺序没有固定对应关系：关闭内置显示器、只留外接显示器时，
; 该外接显示器的名称依旧是 DISPLAY2；而 `SysGet(80)` 只统计参与桌面显示的显示器，此时读出的是 1。
; 把后缀直接当数组下标用，容易越界。
; 另外 MonitorLib 的 GetMonitorHandle 按子串匹配查找显示器，只传后缀数字很可能匹配不上；
; 匹配不到时会回退到主显示器，亮度就调节到了错误的显示器上。
; 因此统一传完整设备名，空字符串表示主显示器。

; Monitor 对象本身不保存运行状态，枚举结果缓存在类的静态变量中，整个脚本共用一个实例即可。
monitorCol := Monitor()

; 读取亮度
; Display 是显示器完整设备名，空串表示主显示器
; 返回含 Minimum、Current、Maximum 的 Map；两种读取方式都失败时返回空字符串
GetBrightness(Display := "") {
    global monitorCol
    try {
        return monitorCol.GetBrightness(Display)
    } catch Error {
        ; DDC/CI 读不到时改走 WMI：外接显示器一般只支持前者，笔记本内置面板走后者
    }
    ; WMI 只能读内置显示器的背光，也不提供亮度上下限，这里统一按 0~100 区间处理；
    ; 只取查询到的第一台内置显示器，多台内置显示器的场景下其余不受支持。
    ; 外接显示器不支持 DDC/CI 时会落到这里，读到的是内置显示器的亮度，属于已知限制。
    try {
        for property in ComObjGet("winmgmts:\\.\root\WMI").ExecQuery("SELECT * FROM WmiMonitorBrightness") {
            return Map("Minimum", 0, "Current", property.CurrentBrightness, "Maximum", 100)
        }
    } catch Error {
    }
    return ""
}

; 设置亮度
; brightness 是目标亮度值；Display 是显示器完整设备名，空串表示主显示器；timeout 是 WMI 路径的超时秒数
; 成功时返回 Map：Path 标明用了哪个接口（DDC 或 WMI），Value 是最终生效的亮度；都失败时返回空字符串
SetBrightness(brightness, Display := "", timeout := 1) {
    global monitorCol
    try {
        ; `SetBrightness` 内部经 `SetSetting` 把数值限制在显示器支持的亮度区间内，并返回实际生效值
        ; 展示时必须用这个返回值，否则提示里的数值会和显示器的真实亮度不一致
        return Map("Path", "DDC", "Value", monitorCol.SetBrightness(brightness, Display))
    } catch Error {
        ; 与读取一致，DDC/CI 不可用时改走 WMI，该方式只支持内置显示器
    }
    try {
        for property in ComObjGet("winmgmts:\\.\root\WMI").ExecQuery("SELECT * FROM WmiMonitorBrightnessMethods") {
            property.WmiSetBrightness(timeout, brightness)
            ; WMI 写入后不会回读校验，直接以传入值作为生效亮度
            return Map("Path", "WMI", "Value", brightness)
        }
    } catch Error {
    }
    return ""
}

; 获取鼠标所在显示器的完整设备名；鼠标不在任何显示器范围内时返回空串
DisplayAtMouse() {
    global monitorCol
    ; 热键、定时器每次触发都会新建线程，新线程默认使用窗口客户区坐标。
    ; 如果依赖脚本初始化阶段设置的坐标模式，切换窗口后会造成鼠标位置计算偏移，因此此处显式指定屏幕坐标系。
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

; 检查显示器缓存是否还有效
; MonitorLib 的枚举结果是进程内静态缓存，显示器配置变更后要重载脚本才会刷新
; 不拿 `SysGet(80)`（SM_CMONITORS）来比：该接口只统计参与桌面显示的显示器，
; 而 `EnumDisplayMonitors` 还包含未加入桌面的显示器，复制、镜像显示时两者计数不一致，会误判
; AHK 内置的 `MonitorGetCount()` 底层直接调用 `EnumDisplayMonitors`、不读缓存，口径与 MonitorLib 一致
; 计数不一致时只做保守拦截，真正的刷新由 `data/custom_functions.ahk` 收到 `WM_DISPLAYCHANGE` 后重载完成
; 返回空字符串表示缓存有效，否则返回可以直接展示给用户的提示
MonitorCacheProblem() {
    global monitorCol
    monitors := monitorCol.EnumDisplayMonitors()
    if (!IsObject(monitors)) {
        return "无法枚举显示器"
    }
    if (MonitorGetCount() != monitors.Length) {
        return "显示器配置已变更，请稍后重试"
    }
    return ""
}

; 从 \\.\DISPLAY2 中取出 DISPLAY2：完整设备名太长，提示里只留后缀
DisplayLabel(Display) {
    return RegExReplace(Display, "^.*\\", "")
}

; 亮度调节结果与异常信息统一用 ToolTip 提示，避免弹窗抢占焦点、打断输入
ShowBrightnessTip(text, delay := 1000) {
    ToolTip(text)
    SetTimer(ToolTip, -delay)
}

; 加亮度与减亮度共用一份实现，方向由 delta 的正负决定，免得两处逻辑各改一遍
AdjustBrightness(delta) {
    ; 亮度读写、显示器枚举都可能因为驱动、COM 组件或系统调用异常报错。
    ; 热键线程中未捕获的错误会弹出对话框抢占焦点，因此整体捕获异常，仅用气泡提示反馈结果。
    try {
        problem := MonitorCacheProblem()
        if (problem != "") {
            ShowBrightnessTip(problem, 3000)
            return
        }
        Display := DisplayAtMouse()
        if (Display = "") {
            ShowBrightnessTip("鼠标不在显示器区域，无法调节亮度", 3000)
            return
        }
        label := DisplayLabel(Display)
        setting := GetBrightness(Display)
        if (!IsObject(setting)) {
            ShowBrightnessTip("读取 " label " 亮度失败，该屏幕可能不支持 DDC/CI", 3000)
            return
        }
        target := Max(setting["Minimum"], Min(setting["Current"] + delta, setting["Maximum"]))
        result := SetBrightness(target, Display)
        if (!IsObject(result)) {
            ShowBrightnessTip("设置 " label " 亮度失败，该屏幕可能不支持 DDC/CI", 3000)
            return
        }
        if (result["Path"] = "WMI") {
            ; WMI 只能调内置显示器的背光，提示里标注“内置屏”，
            ; 避免用户以为调的是鼠标所在的外接显示器
            ShowBrightnessTip("亮度 " result["Value"] "（内置屏）")
            return
        }
        ShowBrightnessTip("亮度 " result["Value"] "（" label "）")
    } catch Error as e {
        ShowBrightnessTip("亮度调节失败：" e.Message, 3000)
    }
}

IncBrightness(delta) {
    AdjustBrightness(delta)
}

DecBrightness(delta) {
    AdjustBrightness(-delta)
}
