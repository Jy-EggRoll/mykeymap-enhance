#Requires AutoHotkey v2.0

/**
 * @function SetTaskbarCombine
 * @description 优雅地切换所有显示器的任务栏合并状态。
 * @param {String} mode - 可选值: "Always" (始终合并), "Never" (从不合并)。为空则自动翻转当前状态。
 */
SetTaskbarCombine(mode := "") {
    ; 定义配置路径与键名
    ; TaskbarGlomLevel 控制主屏幕任务栏行为
    ; MMTaskbarGlomLevel 控制所有副屏幕（Multi-Monitor）的任务栏行为
    path := "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    mainKey := "TaskbarGlomLevel"
    multiKey := "MMTaskbarGlomLevel"

    ; 状态读取与逻辑判定
    try {
        ; 读取当前主屏合并状态：0 (始终合并), 1 (满时合并), 2 (从不合并)
        current := RegRead("HKCU\" . path, mainKey)
    } catch {
        ; 若注册表项不存在（极少见），默认为系统初始值 0
        current := 0
    }

    ; 计算目标值：
    ; 如果 mode 为空，则在 0 和 2 之间翻转；如果指定了 mode，则映射为对应数值
    target := (mode = "") ? (current = 0 ? 2 : 0) : (mode = "Always" ? 0 : 2)

    ; 写入注册表
    ; 注意：RegWrite 在 v2 中的参数顺序为 (值, 类型, 键路径, 键名)
    ; 修改注册表仅改变了持久化配置，UI 界面此时并不会感知到变化
    RegWrite(target, "REG_DWORD", "HKCU\" . path, mainKey)
    RegWrite(target, "REG_DWORD", "HKCU\" . path, multiKey)

    ; 广播系统设置更改消息
    ; 原理：向操作系统所有顶级窗口发送 WM_SETTINGCHANGE 消息
    ; 资源管理器 (Explorer.exe) 监听此消息，并在收到特定字符串时重新加载其配置

    HWND_BROADCAST := 0xffff  ; 代表所有顶级窗口
    WM_SETTINGCHANGE := 0x001A  ; 系统设置更改的消息 ID
    SMTO_ABORTIFHUNG := 0x0002  ; 如果某个窗口卡死，不等待，直接跳过，防止脚本挂起
    result := 0

    ; 使用 SendMessageTimeout 而非 SendMessage，是为了保证脚本的健壮性
    ; "TraySettings" 是告诉 Explorer 专门刷新任务栏（托盘）部分的配置
    DllCall("user32\SendMessageTimeoutW",
        "Ptr", HWND_BROADCAST,
        "UInt", WM_SETTINGCHANGE,
        "Ptr", 0,
        "Str", "TraySettings",
        "UInt", SMTO_ABORTIFHUNG,
        "UInt", 5000,           ; 5秒超时
        "Ptr*", &result)

    ; 用户反馈
    statusText := (target = 0) ? "始终合并" : "从不合并"
    ToolTip("任务栏设置已更新为" . statusText)

    ; 使用匿名函数在 3000ms (3秒) 后销毁提示框
    SetTimer () => ToolTip(), -3000
}
