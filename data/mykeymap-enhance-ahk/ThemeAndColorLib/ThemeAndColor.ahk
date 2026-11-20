#Requires AutoHotkey v2.0

#Include ../LoggerLib/Logger.ahk

class QueryThemeDebug {
    static mode := false
}

/**
 * 检查当前系统是否为亮色主题
 * @return {Boolean} true 表示亮色，false 表示暗色
 */
IsLightTheme() {
    regPath := "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
    ; 1 表示亮色，0 表示暗色
    valueName := "AppsUseLightTheme"

    try {
        ; 不传第三个参数：`RegRead` 的第三参数是「键值不存在时返回什么」，不是值类型，
        ; 值类型由注册表自身决定。若传了字符串（如 "UInt"），键值缺失时本函数会返回
        ; 该字符串、`themeValue = 1` 恒为假，且不再抛异常，下面的 catch 分支永远不会执行
        themeValue := RegRead(regPath, valueName)
        return themeValue = 1
    }
    catch Error as e {
        ; 读取失败时退化为亮色，让调用方总能拿到确定的结果，不必再判空
        LogError(e, , QueryThemeDebug.mode)
        return true
    }
}
