#Requires AutoHotkey v2.0

#Include ../LoggerLib/Logger.ahk

class QueryThemeDebug {
    static mode := false
}

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
        ; 不传第三个参数：RegRead 的第三参数是"键值不存在时返回什么"，不是值类型，
        ; 值类型由注册表自身决定。若传了字符串（如 "UInt"），键值缺失时本函数会返回
        ; 该字符串、themeValue = 1 恒为假，且不再抛异常，下面的 catch 分支永远不会执行。
        themeValue := RegRead(regPath, valueName)
        ; 返回是否为亮色主题
        return themeValue = 1
    }
    catch Error as e {
        ; 发生错误时默认返回亮色
        LogError(e, , QueryThemeDebug.mode)
        return true
    }
}
