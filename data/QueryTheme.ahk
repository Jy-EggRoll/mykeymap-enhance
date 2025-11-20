#Requires AutoHotkey v2.0

/**
 * 检查当前系统是否为亮色主题
 * @return {Boolean} 是否为亮色主题
 */
IsLightTheme() {
    ; 注册表路径，存储主题相关设置
    regPath := "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
    ; 要查询的键值，1=亮色，0=暗色
    valueName := "AppsUseLightTheme"

    ; 读取注册表值
    try {
        ; 尝试读取DWORD类型的值
        themeValue := RegRead(regPath, valueName, "UInt")
        ; 返回是否为亮色主题
        return themeValue = 1
    }
    catch Error as e{
        ; 发生错误时默认返回亮色
        LogError(e, , DEBUGMODE)
        return true
    }
}
