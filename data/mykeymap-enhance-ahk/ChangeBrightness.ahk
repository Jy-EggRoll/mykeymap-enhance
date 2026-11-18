#Requires AutoHotkey v2.0

#Include ./MonitorLib/Monitor.ahk

; 显示器以完整设备名（格式为 \\.\DISPLAY2）作为标识，不使用序号。
; 设备后缀由系统分配，和屏幕数量、枚举顺序没有固定对应关系：比如关闭内置屏、仅保留外接屏时，该外接屏的名称依旧是 DISPLAY2；
; 而 SysGet(80) 仅统计启用的桌面屏幕，此时读取结果为 1。若直接将后缀当作数组下标，极易发生越界。
; 另外 MonitorLib 的 GetMonitorHandle 采用子串匹配方式查找显示器，仅传入后缀数字很可能匹配失败；匹配不到时会默认回退到主屏，导致亮度调节作用在错误屏幕上。
; 因此统一传入完整设备名，传入空字符串代表主屏。

; Monitor 对象本身不保存运行状态，枚举结果缓存在类的静态变量中，整个脚本共用一个实例即可。
monitorCol := Monitor()

; 读取亮度
; Display：显示器完整设备名，空串代表主屏
; 返回包含 Minimum、Current、Maximum 的 Map；两种读取方式均失败时返回空字符串
GetBrightness(Display := "") {
    global monitorCol
    try {
        return monitorCol.GetBrightness(Display)
    } catch Error {
        ; DDC/CI 读取失败时，自动降级使用 WMI 方式读取
    }
    ; WMI 接口仅能读取内置屏幕背光，且不提供亮度上下限，这里统一按 0~100 区间处理；
    ; 只取查询到的第一个内置屏，多内置屏场景下其余屏幕不受支持。
    ; 外接屏不支持 DDC/CI 时，该降级路径读到的是内置屏亮度，属于已知限制。
    try {
        for property in ComObjGet("winmgmts:\\.\root\WMI").ExecQuery("SELECT * FROM WmiMonitorBrightness") {
            return Map("Minimum", 0, "Current", property.CurrentBrightness, "Maximum", 100)
        }
    } catch Error {
    }
    return ""
}

; 设置亮度
; brightness：目标亮度值；Display：显示器完整设备名，空串代表主屏；timeout：WMI 路径的超时秒数
; 成功返回 Map，Path 标记使用的接口（DDC / WMI）、Value 为最终生效亮度；两种写入方式均失败返回空字符串
SetBrightness(brightness, Display := "", timeout := 1) {
    global monitorCol
    try {
        ; SetSetting 会根据屏幕自身亮度区间自动限制数值并返回实际生效值，展示时应当使用该返回值，避免显示数值和屏幕真实亮度不一致
        return Map("Path", "DDC", "Value", monitorCol.SetBrightness(brightness, Display))
    } catch Error {
        ; 和 GetBrightness 逻辑一致，DDC/CI 不可用时降级到 WMI，该方式仅支持内置屏幕
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

; 获取鼠标所在显示器的完整设备名；鼠标不在任何屏幕范围内时返回空串
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

; 检查显示器缓存有效性
; MonitorLib 的枚举结果为进程内静态缓存，显示器配置变更后，需要重载脚本才会刷新缓存。
; 不使用 SysGet(80)（SM_CMONITORS）对比：该接口只统计参与桌面显示的屏幕，和 EnumDisplayMonitors 口径不同（后者包含未加入桌面的显示器），
; 在复制、镜像显示等场景下两者计数会不一致，造成误判拦截。
; AHK 内置 MonitorGetCount() 底层直接调用 EnumDisplayMonitors、不使用缓存，和 MonitorLib 枚举口径一致，适合用来校验缓存。
; 校验不一致仅做保守拦截，真正的缓存刷新由 data/custom_functions.ahk 在收到 WM_DISPLAYCHANGE 消息后自动重载脚本完成。
; 返回空字符串代表缓存有效，否则返回可直接展示给用户的提示文本
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

; 生成用于界面提示的显示器短名称，从 \\.\DISPLAY2 中提取 DISPLAY2
DisplayLabel(Display) {
    return RegExReplace(Display, "^.*\\", "")
}

; 亮度调节结果、异常信息统一通过 ToolTip 提示；避免弹窗抢占焦点、打断输入
ShowBrightnessTip(text, delay := 1000) {
    ToolTip(text)
    SetTimer(ToolTip, -delay)
}

; 亮度增减共用该函数，delta 的正负代表调节方向
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
            ; WMI 接口只能控制内置屏幕背光，提示直接标注“内置屏”，防止用户误以为调节的是鼠标所在外接屏。
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
