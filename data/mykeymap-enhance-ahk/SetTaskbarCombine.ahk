#Requires AutoHotkey v2.0

SetTaskbarCombine(mode := "") {
    path := "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    mainKey := "TaskbarGlomLevel"
    multiKey := "MMTaskbarGlomLevel"

    try {
        current := RegRead("HKEY_CURRENT_USER\" . path, mainKey)
    } catch {
        current := 0
    }

    ; 逻辑：如果不传参则翻转状态；如果传参则按参数设值
    target := (mode = "") ? (current = 0 ? 2 : 0) : (mode = "Always" ? 0 : 2)

    ; AHK v2 RegWrite 语法: RegWrite(Value, ValueType, KeyName, ValueName)
    RegWrite(target, "REG_DWORD", "HKEY_CURRENT_USER\" . path, mainKey)
    RegWrite(target, "REG_DWORD", "HKEY_CURRENT_USER\" . path, multiKey)

    ; 定义常量
    HWND_BROADCAST := 0xffff
    WM_SETTINGCHANGE := 0x001A
    SMTO_ABORTIFHUNG := 0x0002
    result := 0

    ; 执行广播通知
    DllCall("user32\SendMessageTimeout",
        "Ptr", HWND_BROADCAST,
        "UInt", WM_SETTINGCHANGE,
        "Ptr", 0,
        "Str", "TraySettings",
        "UInt", SMTO_ABORTIFHUNG,
        "UInt", 5000,
        "Ptr*", &result)

    status := (target = 0) ? "始终合并" : "从不合并"
    ToolTip("所有显示器设置已切换为" . status)
    SetTimer () => ToolTip(), -3000
}
