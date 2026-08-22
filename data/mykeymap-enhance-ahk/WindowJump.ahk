#WinActivateForce

#Include ./LoggerLib/Logger.ahk
#Include ./VDLib/VD.ahk
#Include ./WindowStyleLib/WindowStyle.ahk

class WindowJumpDebug {
    static mode := false
}

#Include ../mykeymap-enhance-ahk/PinYinLib/IbPinyin.ahk

; 全局配置
global WindowJumpPinyinPartialMatch := true
global WindowJumpShortcutLabel := "【软件】"
global WindowJumpBookmarkLabel := "【书签】"
global WindowJumpVSCodeLabel := "【VSCode】"

global VRTX_BASE := A_Temp "\VRTX"
global WindowJumpPrevActiveHwnd := 0

UpdateTheme()
InitShortcuts()

; 初始化：确保 VRTX 目录存在
InitShortcuts() {
    static initialized := false
    if initialized
        return
    initialized := true
    global VRTX_BASE
    if !DirExist(VRTX_BASE) {
        DirCreate(VRTX_BASE)
    }
}

; 递归获取目录下所有 .lnk 和 .url 文件
GetAllShortcutFiles(dir) {
    files := []
    if !DirExist(dir)
        return files
    Loop Files, dir "\*.lnk", "F"
        files.Push(A_LoopFileFullPath)
    Loop Files, dir "\*.url", "F"
        files.Push(A_LoopFileFullPath)
    Loop Files, dir "\*", "D" {
        subFiles := GetAllShortcutFiles(A_LoopFileFullPath)
        for _, f in subFiles
            files.Push(f)
    }
    return files
}

; 搜索窗口（默认模式）
SearchWindows(query) {
    results := []
    searchLower := StrLower(query)
    bak_DetectHiddenWindows := A_DetectHiddenWindows
    A_DetectHiddenWindows := true
    for hwnd in WinGetList() {
        try {
            if (!IsValidWindow(hwnd))
                continue
            desktopNum := VD.getDesktopNumOfWindow("ahk_id " . hwnd)
            if (desktopNum < 1)
                continue
            process := WinGetProcessName(hwnd)
            title := WinGetTitle(hwnd)
            fullText := StrLower("[" . process . "] " . title)
            if (query == "") {
                score := 1
            } else {
                score := FuzzyScore(searchLower, fullText)
            }
            if (score > 0) {
                desktopInfo := " [桌面" . desktopNum . "]"
                results.Push({
                    score: score,
                    text: desktopInfo . " [" . process . "] " . title,
                    hwnd: hwnd,
                    isShortcut: false,
                    isAdmin: false,
                    iconProcess: process
                })
            }
        }
    }
    A_DetectHiddenWindows := bak_DetectHiddenWindows
    return results
}

; 搜索 VRTX 指定类别
SearchVRTXCategory(query, category, label) {
    global VRTX_BASE
    results := []
    searchLower := StrLower(query)
    targetDir := VRTX_BASE "\" category
    if !DirExist(targetDir)
        return results
    allFiles := GetAllShortcutFiles(targetDir)
    for _, fullPath in allFiles {
        SplitPath(fullPath, &fileName)
        name := StrReplace(fileName, ".lnk", "")
        name := StrReplace(name, ".url", "")
        if (query == "") {
            score := 1
        } else {
            fullText := StrLower(name)
            score := FuzzyScore(searchLower, fullText)
        }
        if (score > 0) {
            results.Push({
                score: score,
                text: label . " " . name,
                hwnd: fullPath,
                isShortcut: true,
                isAdmin: false,
                iconProcess: ""
            })
            results.Push({
                score: score - 1,
                text: "【管理员】" . label . " " . name,
                hwnd: fullPath,
                isShortcut: true,
                isAdmin: true,
                iconProcess: ""
            })
        }
    }
    return results
}

; 主入口
WindowJump(pinyinPartialMatch := "") {
    global WindowJumpPinyinPartialMatch
    if (pinyinPartialMatch !== "") {
        WindowJumpPinyinPartialMatch := pinyinPartialMatch
    }
    UpdateTheme()
    InitShortcuts()

    static MyGui := 0
    static hIL := 0
    static iconCache := Map()
    static shortcutCache := Map()
    static lastTheme := ""
    static lastAccent := ""

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

        if (themeChanged || accentChanged) {
            MyGui.Destroy()
            MyGui := 0
            hIL := 0
            iconCache := Map()
            shortcutCache := Map()
        }
        lastTheme := currentTheme
        lastAccent := currentAccent

        if (MyGui) {
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

    MyGui.Add("Text", "x25 y15 h30 c" . AccentColor, "快速跳转 | Delete 关闭窗口")

    EditBox := MyGui.Add("Edit", "x20 y45 w560 h22 vSearchInput -E0x200 Background" . ListViewBg)

    hIL := IL_Create(10, 5, 0)

    ResultList := MyGui.Add("ListView", "x20 y95 w560 r14 -Multi -Hdr -E0x200 vResultList +LV0x140 Background" .
        ListViewBg . " c" . FontColor, ["Display", "HWND", "IsShortcut", "IsAdmin"])

    ResultList.SetImageList(hIL)
    ResultList.ModifyCol(1, 540)
    ResultList.ModifyCol(2, 0)
    ResultList.ModifyCol(3, 0)
    ResultList.ModifyCol(4, 0)

    RefreshAllWindows(ResultList, hIL, iconCache)

    EditBox.OnEvent("Change", (obj, *) => ScheduleSearch(obj, MyGui["ResultList"], hIL, &iconCache, &shortcutCache))
    ResultList.OnEvent("DoubleClick", (obj, row) => ActivateWin(obj, row))

    HotIfWinActive("ahk_id " . MyGui.Hwnd)
    Hotkey("Escape", (*) => CancelSwitcher(MyGui), "On")
    Hotkey("Down", (*) => MoveLVSelection(MyGui["ResultList"], "Down"), "On")
    Hotkey("Up", (*) => MoveLVSelection(MyGui["ResultList"], "Up"), "On")
    Hotkey("Enter", (*) => HandleEnter(MyGui), "On")
    Hotkey("Delete", (*) => CloseSelectedWindow(MyGui["ResultList"]), "On")

    SetTimer () => CheckWinFocus(MyGui), 100

    MyGui.Show("w600 h450 Center")
}

CloseSelectedWindow(LV) {
    row := LV.GetNext(0, "Focused")
    if (row == 0) {
        row := LV.GetNext(0)
    }
    if (row == 0 && LV.GetCount() > 0) {
        row := 1
    }
    if (row > 0) {
        hwnd := LV.GetText(row, 2)
        isShortcut := LV.GetText(row, 3) = "1"
        if (hwnd && !isShortcut) {
            ; 临时开启 DetectHiddenWindows，保证可以跨虚拟桌面关闭软件窗口
            DetectHiddenWindows(true)
            PostMessage(0x10, 0, 0, , "ahk_id " . hwnd)
            ; 恢复默认设置
            DetectHiddenWindows(false)
            LV.Delete(row)
            if (LV.GetCount() > 0) {
                nextRow := (row > LV.GetCount()) ? LV.GetCount() : row
                LV.Modify(nextRow, "Select Focus Vis")
            }
        }
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
    global WindowJumpShortcutLabel, WindowJumpBookmarkLabel, WindowJumpVSCodeLabel
    rawInput := EditObj.Value
    LV.Delete()

    ; 检测 VRTX 是否可用（目录存在）
    vrtxAvailable := DirExist(VRTX_BASE)

    mode := "window"
    searchQuery := rawInput

    ; 仅当 VRTX 可用时才处理前缀
    if (vrtxAvailable) {
        prefixMap := Map("b ", "bookmark", "s ", "shortcut", "v ", "vscode")
        for prefix, m in prefixMap {
            if (SubStr(rawInput, 1, StrLen(prefix)) = prefix) {
                mode := m
                searchQuery := Trim(SubStr(rawInput, StrLen(prefix) + 1))
                break
            }
        }
    }

    results := []
    if (mode = "window") {
        results := SearchWindows(searchQuery)
    } else if (mode = "bookmark") {
        results := SearchVRTXCategory(searchQuery, "Bookmarks", WindowJumpBookmarkLabel)
    } else if (mode = "shortcut") {
        results := SearchVRTXCategory(searchQuery, "Shortcuts", WindowJumpShortcutLabel)
    } else if (mode = "vscode") {
        results := SearchVRTXCategory(searchQuery, "VSCode", WindowJumpVSCodeLabel)
    }

    if (results.Length > 0) {
        ; 排序
        loop results.Length {
            i := A_Index
            while (i > 1 && results[i - 1].score < results[i].score) {
                temp := results[i]
                results[i] := results[i - 1]
                results[i - 1] := temp
                i--
            }
        }
        maxShow := Min(results.Length, 30)
        loop maxShow {
            res := results[A_Index]
            iconIdx := 1
            if (res.isShortcut) {
                if (shortcutCache.Has(res.hwnd)) {
                    iconIdx := shortcutCache[res.hwnd]
                } else {
                    iconIdx := GetFileIconIndex(res.hwnd, hIL)
                    shortcutCache[res.hwnd] := iconIdx
                }
            } else {
                if (res.iconProcess != "") {
                    iconIdx := GetIconIndexByProcess(res.iconProcess, hIL, iconCache)
                }
            }
            LV.Add("Icon" . iconIdx, res.text, res.hwnd, res.isShortcut ? "1" : "0",
                res.isAdmin ? "1" : "0")
        }
    }

    if (LV.GetCount() > 0) {
        LV.Modify(1, "Select Focus")
    }
}

CancelSwitcher(guiObj) {
    global WindowJumpPrevActiveHwnd
    guiObj.Hide()
    try {
        if (WindowJumpPrevActiveHwnd && WinExist("ahk_id " . WindowJumpPrevActiveHwnd)
        && WindowJumpPrevActiveHwnd != guiObj.Hwnd) {
            DllCall("AllowSetForegroundWindow", "int", -1)
            Sleep 50
            WinActivate("ahk_id " . WindowJumpPrevActiveHwnd)
            if (!WinActive("ahk_id " . WindowJumpPrevActiveHwnd)) {
                Sleep 50
                WinActivate("ahk_id " . WindowJumpPrevActiveHwnd)
            }
        }
    } catch Error as e {
        LogError(e, , WindowJumpDebug.mode)
    }
}

CheckWinFocus(guiObj) {
    if !WinExist("ahk_id " . guiObj.Hwnd) {
        return
    }
    if !WinActive("ahk_id " . guiObj.Hwnd) {
        guiObj.Hide()
    }
}

RefreshAllWindows(LV, hIL, iconCache) {
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
                }
                desktopInfo := " [桌面" . desktopNum . "]"
                title := WinGetTitle(hwnd)
                process := WinGetProcessName(hwnd)
                iconIdx := GetIconIndexByProcess(process, hIL, iconCache)
                LV.Add("Icon" . iconIdx, desktopInfo . " [" . process . "] " . title, hwnd)
                windowCount++
            }
        }
    }
    A_DetectHiddenWindows := bak_DetectHiddenWindows
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
    return iconIdx
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

UpdateTheme() {
    global BgColor, FontColor, AccentColor, ListViewBg, IsDarkMode, FontSize
    try {
        IsDarkMode := RegRead("HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize",
            "AppsUseLightTheme") == 0
    } catch {
        IsDarkMode := false
    }
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
