#WinActivateForce

#Include ./LoggerLib/Logger.ahk
#Include ./VDLib/VD.ahk
#Include ./WindowStyleLib/WindowStyle.ahk

class WindowJumpDebug {
    static mode := false
}

#Include ../mykeymap-enhance-ahk/PinYinLib/IbPinyin.ahk

; 启用拼音部分匹配：模式可以匹配拼音的开头部分，比如 su 匹配 算（suan）。
; WindowJump 参数: 控制是否启用拼音部分匹配、是否显示快捷方式 / 最近使用项，以及前缀/后缀标签模式
global WindowJumpPinyinPartialMatch := true
global WindowJumpShowShortcuts := false
global WindowJumpShowRecent := false
global WindowJumpLabelMode := "prefix" ; 支持 prefix 或 suffix
global WindowJumpShortcutLabel := " [启动] "
global WindowJumpRecentLabel := " [最近] "

global shortcutsDir := ""
global recentShortcutsDir := ""

; 打开切换器之前的前台窗口句柄，ESC / 失焦取消时用于恢复焦点
global WindowJumpPrevActiveHwnd := 0

if (WindowJumpShowShortcuts || WindowJumpShowRecent) {
    InitShortcuts()
}

UpdateTheme()

InitShortcuts() {
    static initialized := false

    if initialized {
        return
    }
    initialized := true

    global shortcutsDir, recentShortcutsDir
    shortcutsDir := A_Temp "\WindowJump_Shortcuts"
    recentShortcutsDir := A_Temp "\WindowJump_RecentShortcuts"

    LogInfo("初始化快捷方式目录：" . shortcutsDir, , WindowJumpDebug.mode)
    LogInfo("初始化最近使用目录：" . recentShortcutsDir, , WindowJumpDebug.mode)

    if DirExist(shortcutsDir) {
        loop files, shortcutsDir "\*", "FD" {
            try FileDelete(A_LoopFileFullPath)
        }
    } else {
        DirCreate(shortcutsDir)
    }

    if DirExist(recentShortcutsDir) {
        loop files, recentShortcutsDir "\*", "FD" {
            try FileDelete(A_LoopFileFullPath)
        }
    } else {
        DirCreate(recentShortcutsDir)
    }

    try {
        if DirExist(A_ProgramsCommon) {
            FileCopy(A_ProgramsCommon "\*.lnk", shortcutsDir "\", true)
        }
        if DirExist(A_Programs) {
            FileCopy(A_Programs "\*.lnk", shortcutsDir "\", true)
        }
    }

    try {
        loop files, A_AppData . "\MicroSoft\Windows\Recent\*.lnk" {
            FileGetShortcut(A_LoopFileFullPath, &target)
            ; 过滤逻辑：如果目标路径以 "ms-" 开头，或者是空的，则跳过
            if (target = "" || InStr(target, "ms-") = 1) {
                continue
            }
            FileCopy(A_LoopFileFullPath, recentShortcutsDir "\", true)
        }
        loop files, A_AppData . "MicroSoft\Office\Recent\*.lnk" {
            FileGetShortcut(A_LoopFileFullPath, &target)
            if (target = "" || InStr(target, "ms-") = 1) {
                continue
            }
            FileCopy(A_LoopFileFullPath, recentShortcutsDir "\", true)
        }
    }

    try {
        oFolder := ComObject("Shell.Application").NameSpace("shell:AppsFolder")
        if (Type(oFolder) != "String") {
            for item in oFolder.Items {
                shortcutPath := shortcutsDir "\" item.Name ".lnk"
                if !FileExist(shortcutPath) {
                    try FileCreateShortcut("shell:appsfolder\" item.Path, shortcutPath)
                }
            }
        }
    }

    LogInfo("快捷方式初始化完成", , WindowJumpDebug.mode)
}

GetShortcuts(&shortcuts) {
    global shortcutsDir
    shortcuts := []

    if !DirExist(shortcutsDir) {
        LogInfo("快捷方式目录不存在，初始化", , WindowJumpDebug.mode)
        InitShortcuts()
    }

    loop files, shortcutsDir "\*.lnk", "F" {
        try {
            name := StrReplace(A_LoopFileName, ".lnk", "")
            shortcuts.Push({ name: name, path: A_LoopFileFullPath })
        }
    }

    LogInfo("获取到 " . shortcuts.Length . " 个快捷方式", , WindowJumpDebug.mode)
}

GetRecentShortcuts(&shortcuts) {
    global recentShortcutsDir
    shortcuts := []

    if !DirExist(recentShortcutsDir) {
        LogInfo("最近使用目录不存在，初始化", , WindowJumpDebug.mode)
        InitShortcuts()
    }

    loop files, recentShortcutsDir "\*.lnk", "F" {
        try {
            name := StrReplace(A_LoopFileName, ".lnk", "")
            shortcuts.Push({ name: name, path: A_LoopFileFullPath })
        }
    }

    LogInfo("获取到 " . shortcuts.Length . " 个最近使用项", , WindowJumpDebug.mode)
}

FormatResultLabel(name, label) {
    if (WindowJumpLabelMode = "suffix") {
        return name . " " . label
    }
    return label . name
}

WindowJump(pinyinPartialMatch := "", showShortcuts := "", showRecent := "", labelMode := "", shortcutLabel := "",
    recentLabel := "") {
    global WindowJumpPinyinPartialMatch, WindowJumpShowShortcuts, WindowJumpShowRecent, WindowJumpLabelMode,
        WindowJumpShortcutLabel, WindowJumpRecentLabel
    if (pinyinPartialMatch !== "") {
        WindowJumpPinyinPartialMatch := pinyinPartialMatch
    }
    if (showShortcuts !== "") {
        WindowJumpShowShortcuts := showShortcuts
    }
    if (showRecent !== "") {
        WindowJumpShowRecent := showRecent
    }
    if (labelMode !== "") {
        WindowJumpLabelMode := labelMode
    }
    if (shortcutLabel !== "") {
        WindowJumpShortcutLabel := shortcutLabel
    }
    if (recentLabel !== "") {
        WindowJumpRecentLabel := recentLabel
    }

    UpdateTheme()

    static MyGui := 0
    static hIL := 0
    static iconCache := Map()
    static shortcutCache := Map()
    static lastTheme := ""
    static lastAccent := ""

    LogInfo("WindowJump 被调用", , WindowJumpDebug.mode)

    ; 记录打开切换器之前的前台窗口，供 ESC / 失焦取消时恢复焦点，避免误激活其他窗口
    global WindowJumpPrevActiveHwnd
    try {
        prevHwnd := WinExist("A")
        if (prevHwnd && (!MyGui || prevHwnd != MyGui.Hwnd)) {
            WindowJumpPrevActiveHwnd := prevHwnd
        }
    } catch Error as e {
        LogError(e, , WindowJumpDebug.mode)
    }

    if (MyGui) {
        global IsDarkMode, AccentColor
        currentTheme := IsDarkMode ? "dark" : "light"
        currentAccent := AccentColor
        themeChanged := (lastTheme != "" && lastTheme != currentTheme)
        accentChanged := (lastAccent != "" && lastAccent != currentAccent)

        LogInfo("检查主题变化: lastTheme=" . lastTheme . " currentTheme=" . currentTheme . " lastAccent=" . lastAccent .
            " currentAccent=" . currentAccent, , WindowJumpDebug.mode)

        if (themeChanged || accentChanged) {
            LogInfo("主题变化(" . lastTheme . "->" . currentTheme . ")，强调色变化(" . lastAccent . "->" . currentAccent .
                ")，销毁并重建 GUI", , WindowJumpDebug.mode)
            MyGui.Destroy()
            MyGui := 0
            hIL := 0
            iconCache := Map()
            shortcutCache := Map()
        }
        lastTheme := currentTheme
        lastAccent := currentAccent

        if (MyGui) {
            LogInfo("GUI 已存在，复现窗口", , WindowJumpDebug.mode)
            ; 复用路径下重新捕获前台窗口，避免 WindowJumpPrevActiveHwnd 过期
            ; （上次打开后用户可能已切换到其他窗口，ESC 恢复焦点应以当前前台为准）
            try {
                reusePrev := WinExist("A")
                if (reusePrev && reusePrev != MyGui.Hwnd) {
                    WindowJumpPrevActiveHwnd := reusePrev
                }
            } catch Error as e {
                LogError(e, , WindowJumpDebug.mode)
            }
            MyGui["SearchInput"].Value := ""
            MyGui["SearchInput"].Focus()
            RefreshAllWindows(MyGui["ResultList"], hIL, iconCache)
            MyGui.Show("Center")
            return
        }
    } else {
        global IsDarkMode, AccentColor
        lastTheme := IsDarkMode ? "dark" : "light"
        lastAccent := AccentColor
    }

    MyGui := Gui("-Caption +AlwaysOnTop +Owner +LastFound", "QuickSwitcher")
    MyGui.BackColor := BgColor
    MyGui.SetFont("s" . FontSize " c" . FontColor, "微软雅黑")

    scaleFactor := A_ScreenDPI / 96
    w_phys := 600 * scaleFactor
    h_phys := 450 * scaleFactor
    r_phys := 20 * scaleFactor
    WinSetRegion("0-0 w" . w_phys . " h" . h_phys . " r" . r_phys . "-" . r_phys, MyGui.Hwnd)

    MyGui.Add("Text", "x25 y15 h30 c" . AccentColor, "快速跳转——上下键选择，回车激活")

    EditBox := MyGui.Add("Edit", "x20 y45 w560 h22 vSearchInput -E0x200 Background" . ListViewBg)

    hIL := IL_Create(10, 5, 0)

    ResultList := MyGui.Add("ListView", "x20 y95 w560 r14 -Multi -Hdr -E0x200 vResultList +LV0x140 Background" .
        ListViewBg . " c" . FontColor, ["Display", "HWND", "IsShortcut", "IsAdmin"])

    ResultList.SetImageList(hIL)
    ResultList.ModifyCol(1, 540)
    ResultList.ModifyCol(2, 0)
    ResultList.ModifyCol(3, 0)
    ResultList.ModifyCol(4, 0)

    RefreshList(ResultList, &hIL, &iconCache, &shortcutCache)

    EditBox.OnEvent("Change", (obj, *) => ScheduleSearch(obj, MyGui["ResultList"], hIL, &iconCache, &shortcutCache))
    ResultList.OnEvent("DoubleClick", (obj, row) => ActivateWin(obj, row))

    HotIfWinActive("ahk_id " . MyGui.Hwnd)
    Hotkey("Escape", (*) => CancelSwitcher(MyGui), "On")
    Hotkey("Down", (*) => MoveLVSelection(MyGui["ResultList"], "Down"), "On")
    Hotkey("Up", (*) => MoveLVSelection(MyGui["ResultList"], "Up"), "On")
    Hotkey("Enter", (*) => HandleEnter(MyGui), "On")

    SetTimer () => CheckWinFocus(MyGui), 100

    MyGui.Show("w600 h450 Center")
}

; 逻辑处理函数

; CancelSwitcher - 取消切换器并把前台交还给打开切换器之前的窗口
; 用于 ESC 主动取消，避免隐藏 GUI 后 OS 把前台兜底给 Z-order 顶端的非预期窗口
CancelSwitcher(guiObj) {
    global WindowJumpPrevActiveHwnd
    guiObj.Hide()
    try {
        if (WindowJumpPrevActiveHwnd && WinExist("ahk_id " . WindowJumpPrevActiveHwnd)
        && WindowJumpPrevActiveHwnd != guiObj.Hwnd) {
            ; 放行前台设置权限，规避 AHK 前台锁定超时导致 WinActivate 静默失败，
            ; 失败后 OS 会把前台兜底给 Z-order 顶端的其它窗口（常是列表里选中的窗口）
            DllCall("AllowSetForegroundWindow", "int", -1)
            Sleep 50
            WinActivate("ahk_id " . WindowJumpPrevActiveHwnd)
            ; 前台锁偶发失败，重试一次以稳定恢复焦点
            if (!WinActive("ahk_id " . WindowJumpPrevActiveHwnd)) {
                Sleep 50
                WinActivate("ahk_id " . WindowJumpPrevActiveHwnd)
            }
            LogInfo("ESC 取消，恢复前台窗口: " . WindowJumpPrevActiveHwnd, , WindowJumpDebug.mode)
        }
    } catch Error as e {
        LogError(e, , WindowJumpDebug.mode)
    }
}

; CheckWinFocus - 检查窗口是否失去焦点
; 定时器回调函数，每 100ms 执行一次
; 当 GUI 不再活动时自动隐藏（用户已主动切到别的窗口，此处不强行恢复焦点）

CheckWinFocus(guiObj) {
    if !WinExist("ahk_id " . guiObj.Hwnd) {
        return
    }
    if !WinActive("ahk_id " . guiObj.Hwnd) {
        LogInfo("GUI 失去焦点，隐藏窗口", , WindowJumpDebug.mode)
        guiObj.Hide()
    }
}

RefreshList(LV, &hIL, &iconCache, &shortcutCache) {
    global BgColor, FontColor, AccentColor, ListViewBg, IsDarkMode, FontSize
    LogInfo("开始刷新窗口列表（重建模式）", , WindowJumpDebug.mode)

    LV.Delete()

    if (hIL) {
        IL_Destroy(hIL)
    }
    iconCache := Map()
    shortcutCache := Map()
    hIL := IL_Create(20, 10, 0)
    LV.SetImageList(hIL)

    windowCount := 0
    bak_DetectHiddenWindows := A_DetectHiddenWindows
    A_DetectHiddenWindows := true
    for hwnd in WinGetList() {
        try {
            if (IsValidWindow(hwnd)) {
                desktopNum := VD.getDesktopNumOfWindow("ahk_id " . hwnd)
                if (desktopNum < 1) {
                    continue
                } else {
                    desktopInfo := " [桌面" . desktopNum . "]"
                }
                process := WinGetProcessName(hwnd)
                title := WinGetTitle(hwnd)
                iconIdx := GetIconIndexByProcess(process, hIL, iconCache)
                LV.Add("Icon" . iconIdx, desktopInfo . " [" . process . "] " . title, hwnd)
                windowCount++
            }
        }
    }
    A_DetectHiddenWindows := bak_DetectHiddenWindows

    LogInfo("刷新完成，共添加 " . windowCount . " 个窗口", , WindowJumpDebug.mode)
}

RefreshAllWindows(LV, hIL, iconCache) {
    LogInfo("RefreshAllWindows: 使用现有缓存刷新列表", , WindowJumpDebug.mode)
    LV.Delete()
    windowCount := 0
    bak_DetectHiddenWindows := A_DetectHiddenWindows
    A_DetectHiddenWindows := true
    for hwnd in WinGetList() {
        try {
            if (IsValidWindow(hwnd)) {
                desktopNum := VD.getDesktopNumOfWindow("ahk_id " . hwnd)
                if (desktopNum < 1) {
                    continue
                } else {
                    desktopInfo := " [桌面" . desktopNum . "]"
                }
                title := WinGetTitle(hwnd)
                process := WinGetProcessName(hwnd)
                iconIdx := GetIconIndexByProcess(process, hIL, iconCache)
                LV.Add("Icon" . iconIdx, desktopInfo . " [" . process . "] " . title, hwnd)
                windowCount++
            }
        }
    }
    A_DetectHiddenWindows := bak_DetectHiddenWindows
    LogInfo("RefreshAllWindows 完成，共 " . windowCount . " 个窗口", , WindowJumpDebug.mode)
    if (LV.GetCount() > 0) {
        LV.Modify(1, "Select Focus")
    }
}

ScheduleSearch(EditObj, LV, hIL, &iconCache, &shortcutCache) {
    static timer := 0
    if (timer) {
        SetTimer(timer, 0)
    }
    timer := SetTimer(() => UpdateSearch(EditObj, LV, hIL, &iconCache, &shortcutCache), -20)
}

UpdateSearch(EditObj, LV, hIL, &iconCache, &shortcutCache) {
    global BgColor, FontColor, AccentColor, ListViewBg, IsDarkMode, FontSize
    LogInfo("搜索内容改变: [" . EditObj.Value . "]", , WindowJumpDebug.mode)

    currentInput := Trim(EditObj.Value)

    if (currentInput == "") {
        LogInfo("搜索框为空，显示全部窗口（使用缓存）", , WindowJumpDebug.mode)
        RefreshAllWindows(LV, hIL, iconCache)
        return
    }

    searchLower := StrLower(currentInput)
    LV.Delete()
    results := []

    bak_DetectHiddenWindows := A_DetectHiddenWindows
    A_DetectHiddenWindows := true
    for hwnd in WinGetList() {
        try {
            title := WinGetTitle(hwnd)
            process := WinGetProcessName(hwnd)

            if (!IsValidWindow(hwnd)) {
                continue
            }

            desktopNum := VD.getDesktopNumOfWindow("ahk_id " . hwnd)
            if (desktopNum < 1) {
                continue
            } else {
                desktopInfo := " [桌面" . desktopNum . "]"
            }

            fullText := StrLower("[" . process . "] " . title)
            score := FuzzyScore(searchLower, fullText)

            if (score > 0) {
                results.Push({ score: score, text: desktopInfo . " [" . process . "] " . title, hwnd: hwnd,
                    isShortcut: false, isAdmin: false })
            }
        }
    }
    A_DetectHiddenWindows := bak_DetectHiddenWindows

    if (WindowJumpShowShortcuts) {
        GetShortcuts(&shortcuts)
        LogInfo("开始匹配快捷方式，数量: " . shortcuts.Length, , WindowJumpDebug.mode)
        for shortcut in shortcuts {
            fullText := StrLower(shortcut.name)
            score := FuzzyScore(searchLower, fullText)
            if (score > 0) {
                normalText := FormatResultLabel(shortcut.name, WindowJumpShortcutLabel)
                adminText := FormatResultLabel("[管理员] " . shortcut.name, WindowJumpShortcutLabel)
                results.Push({ score: score // 2, text: normalText, hwnd: shortcut.path, isShortcut: true,
                    isAdmin: false })
                results.Push({ score: score // 2 - 1, text: adminText, hwnd: shortcut.path,
                    isShortcut: true, isAdmin: true })
            }
        }
    }

    if (WindowJumpShowRecent) {
        GetRecentShortcuts(&recentShortcuts)
        LogInfo("开始匹配最近使用项，数量: " . recentShortcuts.Length, , WindowJumpDebug.mode)
        for recent in recentShortcuts {
            fullText := StrLower(recent.name)
            score := FuzzyScore(searchLower, fullText)
            if (score > 0) {
                results.Push({ score: score // 3, text: FormatResultLabel(recent.name, WindowJumpRecentLabel), hwnd: recent
                    .path,
                    isShortcut: true, isAdmin: false })
            }
        }
    }

    LogInfo("窗口匹配 " . results.Length . " 个结果", , WindowJumpDebug.mode)

    if (results.Length > 0) {
        loop results.Length {
            i := A_Index
            while (i > 1 && results[i - 1].score < results[i].score) {
                temp := results[i]
                results[i] := results[i - 1]
                results[i - 1] := temp
                i--
            }
        }

        loop (Min(results.Length, 30)) {
            res := results[A_Index]
            if (res.isShortcut) {
                if (shortcutCache.Has(res.hwnd)) {
                    iconIdx := shortcutCache[res.hwnd]
                } else {
                    iconIdx := GetFileIconIndex(res.hwnd, hIL)
                    shortcutCache[res.hwnd] := iconIdx
                    LogInfo("快捷方式缓存未命中: path=" . res.hwnd, , WindowJumpDebug.mode)
                }
            } else {
                process := WinGetProcessName(res.hwnd)
                iconIdx := GetIconIndexByProcess(process, hIL, iconCache)
            }
            LV.Add("Icon" . iconIdx, res.text, res.hwnd, res.isShortcut ? "1" : "0",
                res.isAdmin ? "1" : "0")
        }
    }

    if (LV.GetCount() > 0) {
        LV.Modify(1, "Select Focus")
    }
}

GetIconIndexByProcess(process, hIL, iconCache) {
    if (iconCache.Has(process)) {
        return iconCache[process]
    }
    hwnd := WinExist("ahk_exe " . process)
    if (!hwnd) {
        return 1
    }
    iconIdx := GetUwpIconIndex(hwnd, hIL)
    iconCache[process] := iconIdx
    LogInfo("窗口图标缓存未命中: process=" . process . " idx=" . iconIdx, , WindowJumpDebug.mode)
    return iconIdx
}

GetIconIndex(hwnd, hIL) {
    hIcon := SendMessage(0x7F, 0, 0, hwnd, "ahk_id " . hwnd)

    if (!hIcon) {
        hIcon := DllCall(A_PtrSize == 8 ? "GetClassLongPtr" : "GetClassLong", "Ptr", hwnd, "Int", -34, "UPtr")
    }

    if (!hIcon) {
        hIcon := SendMessage(0x7F, 1, 0, hwnd, "ahk_id " . hwnd)
    }

    if (hIcon) {
        return IL_Add(hIL, "HICON:" . hIcon)
    }

    return 1
}

GetUwpIconIndex(hwnd, hIL) {
    try {
        exePath := WinGetProcessPath(hwnd)
        if exePath {
            if (StrEndsWith(exePath, "ApplicationFrameHost.exe")) {
                return GetUwpIconFromWindow(hwnd, hIL)
            }
            return GetExeIconIndex(exePath, hIL)
        }
    }
    return 1
}

GetFileIconIndex(filePath, hIL) {
    try {
        if (StrEndsWith(filePath, ".lnk")) {
            FileGetShortcut filePath, &targetPath, &workDir, &args, &desc, &iconFile, &iconNum
            if (iconFile) {
                iconPath := iconFile
                if (iconNum > 0) {
                    return IL_Add(hIL, iconPath, iconNum)
                } else {
                    return IL_Add(hIL, iconPath)
                }
            }
            if (targetPath) {
                filePath := targetPath
            }
        }
    }

    return GetExeIconIndex(filePath, hIL)
}

GetExeIconIndex(filePath, hIL) {
    try {
        fisize := A_PtrSize + 688
        fileinfo := Buffer(fisize)
        if DllCall("shell32\SHGetFileInfoW", "WStr", filePath, "UInt", 0, "Ptr", fileinfo, "UInt", fisize, "UInt",
            0x100) {
            hIcon := NumGet(fileinfo, 0, "Ptr")
            if hIcon {
                return IL_Add(hIL, "HICON:" . hIcon)
            }
        }
    }
    return IL_Add(hIL, filePath)
}

GetUwpIconFromWindow(hwnd, hIL) {
    hIcon := SendMessage(0x7F, 0, 0, hwnd, "ahk_id " . hwnd)
    if !hIcon {
        hIcon := SendMessage(0x7F, 1, 0, hwnd, "ahk_id " . hwnd)
    }
    if !hIcon {
        hIcon := DllCall(A_PtrSize == 8 ? "GetClassLongPtr" : "GetClassLong", "Ptr", hwnd, "Int", -34, "UPtr")
    }
    if hIcon {
        return IL_Add(hIL, "HICON:" . hIcon)
    }
    return 1
}

StrEndsWith(str, suffix) {
    return SubStr(str, -StrLen(suffix) + 1) = suffix
}

FuzzyScore(query, target) {
    if !(query := Trim(query)) {
        return 0
    }

    target := StrReplace(target, ".exe", "")

    totalScore := 0
    matchedTokens := 0

    tokens := StrSplit(query, " ")

    for _, token in tokens {
        if (token == "") {
            continue
        }

        tokenScore := 0

        pinyinFlags := IbPinyin_AsciiFirstLetter | IbPinyin_Ascii
        if (WindowJumpPinyinPartialMatch) {
            pinyinFlags |= IbPinyin_PatternPartial
        }

        if InStr(target, token) {
            tokenScore := 1000
            if InStr(target, token, true, 1, 1) {
                tokenScore += 200
            }
        } else if IbPinyin_Match(token, target, pinyinFlags) {
            tokenScore := 800
        }

        if (tokenScore > 0) {
            totalScore += tokenScore
            matchedTokens++
        }
    }

    if (matchedTokens < tokens.Length) {
        return 0
    }

    return totalScore
}

UpdateTheme() {
    global BgColor, FontColor, AccentColor, ListViewBg, IsDarkMode, FontSize

    LogInfo("开始更新主题", , WindowJumpDebug.mode)

    try {
        IsDarkMode := RegRead("HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize",
            "AppsUseLightTheme") == 0
    } catch {
        IsDarkMode := false
    }

    LogInfo("系统主题: " . (IsDarkMode ? "深色模式" : "浅色模式"), , WindowJumpDebug.mode)

    try {
        rawColor := RegRead("HKEY_CURRENT_USER\Software\Microsoft\Windows\DWM", "AccentColor")

        r := rawColor & 0xFF
        g := (rawColor >> 8) & 0xFF
        b := (rawColor >> 16) & 0xFF

        accentNum := (r << 16) | (g << 8) | b

        AccentColor := Format("{:06X}", accentNum)
    } catch {
        accentNum := 0x0078D7
        AccentColor := "0078D7"
    }

    if (IsDarkMode) {
        BgColor := MixColor(accentNum, 0x111111, 0.90)
        FontColor := "c6c6c6"
        ListViewBg := MixColor(accentNum, 0x111111, 0.80)
    } else {
        BgColor := MixColor(accentNum, 0xFFFFFF, 0.90)
        FontColor := "333333"
        ListViewBg := MixColor(accentNum, 0xFFFFFF, 0.80)
    }

    FontSize := 12
}

MixColor(Color1, Color2, Weight) {
    r1 := (Color1 >> 16) & 0xFF
    g1 := (Color1 >> 8) & 0xFF
    b1 := Color1 & 0xFF

    r2 := (Color2 >> 16) & 0xFF
    g2 := (Color2 >> 8) & 0xFF
    b2 := Color2 & 0xFF

    r := Round(r1 + (r2 - r1) * Weight)
    g := Round(g1 + (g2 - g1) * Weight)
    b := Round(b1 + (b2 - b1) * Weight)

    return Format("{:02X}{:02X}{:02X}", r, g, b)
}

MoveLVSelection(LV, Direction) {
    if (LV.GetCount() == 0) {
        return
    }

    row := LV.GetNext(0, "Focused")

    if (row == 0) {
        row := LV.GetNext(0)
    }

    if (Direction == "Down") {
        nextRow := (row == 0) ? 1 : Min(row + 1, LV.GetCount())
    } else {
        nextRow := (row == 0) ? LV.GetCount() : Max(row - 1, 1)
    }

    LV.Modify(0, "-Select -Focus")
    LV.Modify(nextRow, "Select Focus Vis")
}

HandleEnter(GuiObj) {
    LV := GuiObj["ResultList"]

    row := LV.GetNext(0, "Focused")

    if (row == 0) {
        row := LV.GetNext(0)
    }

    if (row == 0 && LV.GetCount() > 0) {
        row := 1
    }

    if (row > 0) {
        ActivateWin(LV, row)
    }
}

ActivateWin(LV, RowNumber) {
    try {
        hwnd := LV.GetText(RowNumber, 2)
        isShortcut := LV.GetText(RowNumber, 3) = "1"
        isAdmin := LV.GetText(RowNumber, 4) = "1"

        LogInfo("激活目标: hwnd=" . hwnd . " isShortcut=" . isShortcut . " isAdmin=" . isAdmin,
            , WindowJumpDebug.mode)

        if (hwnd) {
            if (isShortcut) {
                if (isAdmin) {
                    LV.Gui.Hide()
                    Sleep 50
                    AdminRun(hwnd)
                } else {
                    LV.Gui.Hide()
                    Sleep 50
                    UserRun(hwnd)
                }
            } else {
                global lastActiveWindowClass
                lastActiveWindowClass := "AutoHotkeyGUI"
                targetDesktopNum := VD.getDesktopNumOfWindow("ahk_id " . hwnd)
                currentDesktopNum := VD.getCurrentDesktopNum()
                if (targetDesktopNum > 0 && targetDesktopNum != currentDesktopNum) {
                    LV.Gui.Hide()
                    Sleep 50
                    VD.goToDesktopOfWindow("ahk_id " . hwnd)
                } else {
                    LV.Gui.Hide()
                    Sleep 50
                    WinActivate("ahk_id " . hwnd)
                }
            }
        }
    } catch Error as e {
        LogError(e, , WindowJumpDebug.mode)
    }
}

AdminRun(Target) {
    try {
        DllCall("Shell32\ShellExecuteW", "Ptr", 0, "Str", "runas", "Str", Target, "Ptr", 0, "Ptr", 0, "Int", 1)
    } catch as e {
        LogError("RunAsAdmin 失败: " e.Message, , WindowJumpDebug.mode)
    }
}

UserRun(Target, Args := "", WorkingDir := "") {
    try {
        shellApp := ComObject("Shell.Application")
        shellWindows := shellApp.Windows
        desktop := shellWindows.FindWindowSW(0, 0, 8, 0, 1)

        if (desktop) {
            DllCall("AllowSetForegroundWindow", "int", -1)
            desktop.Document.Application.ShellExecute(Target, Args, WorkingDir, "open", 1)
        }
    } catch Error as e {
        LogError(e, , WindowJumpDebug.mode)
    }
}

~^Alt Up:: {
    ; 判断上一次按键是否也是在 Ctrl 按下时释放的 Alt，且两次间隔小于 500 毫秒
    if (A_PriorHotkey = "~^Alt Up" && A_TimeSincePriorHotkey < 500) {
        WindowJump()
    }
}
