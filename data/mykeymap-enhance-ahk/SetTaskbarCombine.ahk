#Requires AutoHotkey v2.0

/**
 * @function SetTaskbarCombine
 * @description 切换所有显示器的任务栏图标合并状态。
 * @param {String} mode - 可选值："Always"（始终合并）、"Never"（从不合并）。为空则翻转当前状态。
 */
SetTaskbarCombine(mode := "") {
    ; `TaskbarGlomLevel` 管主显示器，`MMTaskbarGlomLevel` 管所有副显示器；
    ; 只写前者的话，副显示器的任务栏不会跟着变
    path := "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    mainKey := "TaskbarGlomLevel"
    multiKey := "MMTaskbarGlomLevel"

    try {
        ; 读取主显示器当前的合并方式：0 表示始终合并、1 表示任务栏满时合并、2 表示从不合并
        current := RegRead("HKCU\" . path, mainKey)
    } catch {
        ; 键值不存在或读取失败时按 0 处理，避免翻转时把缺失当成从不合并
        current := 0
    }

    ; mode 留空表示翻转：始终合并与从不合并互相切换
    target := (mode = "") ? (current = 0 ? 2 : 0) : (mode = "Always" ? 0 : 2)

    ; `RegWrite` 的参数顺序是值在前、键路径在后，与 `RegRead` 相反，容易写反
    ; 改注册表只改变持久化配置，资源管理器此时不会感知到变化
    RegWrite(target, "REG_DWORD", "HKCU\" . path, mainKey)
    RegWrite(target, "REG_DWORD", "HKCU\" . path, multiKey)

    ; 只写注册表不会让界面立刻更新，需要广播一条系统设置变更消息
    ; 资源管理器监听此消息，收到约定的字符串后重新加载对应部分的配置

    HWND_BROADCAST := 0xffff  ; 代表所有顶级窗口
    WM_SETTINGCHANGE := 0x001A  ; 系统设置更改的消息 ID
    SMTO_ABORTIFHUNG := 0x0002  ; 目标窗口无响应时不等待，直接返回
    result := 0

    ; 用 `SendMessageTimeout` 而不是 `SendMessage`：广播时只要有一个窗口卡死，
    ; 后者会一直等下去，挂住整个脚本线程
    ; "TraySettings" 是告诉资源管理器只刷新任务栏（托盘）部分的配置
    DllCall("user32\SendMessageTimeoutW",
        "Ptr", HWND_BROADCAST,
        "UInt", WM_SETTINGCHANGE,
        "Ptr", 0,
        "Str", "TraySettings",
        "UInt", SMTO_ABORTIFHUNG,
        "UInt", 5000,           ; 单个窗口最多等 5 秒
        "Ptr*", &result)

    ; 用户反馈
    statusText := (target = 0) ? "始终合并" : "从不合并"
    ToolTip("任务栏设置已更新为" . statusText)

    ; 3 秒后关闭提示
    SetTimer () => ToolTip(), -3000
}
