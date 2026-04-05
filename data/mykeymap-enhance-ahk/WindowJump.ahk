#WinActivateForce

#Include ./LoggerLib/Logger.ahk
#Include ./AutoActivateWindow.ahk
#Include ./VDLib/VD.ahk
#Include ./WindowStyleLib/WindowStyle.ahk

class WindowJumpDebug {
    static mode := false
}

#Include ../mykeymap-enhance-ahk/PinYinLib/IbPinyin.ahk

UpdateTheme()

WindowJump() {
    UpdateTheme()

    static MyGui := 0
    static hIL := 0
    static iconCache := Map()
    static lastTheme := ""
    static lastAccent := ""

    LogInfo("WindowJump 被调用", , WindowJumpDebug.mode)

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
        }
        lastTheme := currentTheme
        lastAccent := currentAccent

        if (MyGui) {
            LogInfo("GUI 已存在，复现窗口", , WindowJumpDebug.mode)
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
        ListViewBg . " c" . FontColor, ["Display", "HWND"])

    ResultList.SetImageList(hIL)
    ResultList.ModifyCol(1, 540)
    ResultList.ModifyCol(2, 0)

    RefreshList(ResultList, &hIL, &iconCache)

    EditBox.OnEvent("Change", (obj, *) => ScheduleSearch(obj, MyGui["ResultList"], hIL, &iconCache))
    ResultList.OnEvent("DoubleClick", (obj, row) => ActivateWin(obj, row))

    HotIfWinActive("ahk_id " . MyGui.Hwnd)
    Hotkey("Escape", (*) => MyGui.Hide(), "On")
    Hotkey("Down", (*) => MoveLVSelection(MyGui["ResultList"], "Down"), "On")
    Hotkey("Up", (*) => MoveLVSelection(MyGui["ResultList"], "Up"), "On")
    Hotkey("Enter", (*) => HandleEnter(MyGui), "On")

    SetTimer () => CheckWinFocus(MyGui), 100

    MyGui.Show("w600 h450 Center")
}

; 逻辑处理函数

; CheckWinFocus - 检查窗口是否失去焦点
; 定时器回调函数，每 100ms 执行一次
; 当 GUI 不再活动时自动隐藏

CheckWinFocus(guiObj) {
    if !WinExist("ahk_id " . guiObj.Hwnd) {
        return
    }
    if !WinActive("ahk_id " . guiObj.Hwnd) {
        LogInfo("GUI 失去焦点，隐藏窗口", , WindowJumpDebug.mode)
        guiObj.Hide()
    }
}

RefreshList(LV, &hIL, &iconCache) {
    global BgColor, FontColor, AccentColor, ListViewBg, IsDarkMode, FontSize
    LogInfo("开始刷新窗口列表（重建模式）", , WindowJumpDebug.mode)

    LV.Delete()

    if (hIL) {
        IL_Destroy(hIL)
    }
    iconCache := Map()
    hIL := IL_Create(20, 10, 0)
    LV.SetImageList(hIL)

    windowCount := 0
    bak_DetectHiddenWindows := A_DetectHiddenWindows
    A_DetectHiddenWindows := true
    for hwnd in WinGetList() {
        try {
            if (IsValidWindow(hwnd)) {
                desktopNum := VD.getDesktopNumOfWindow("ahk_id " . hwnd)
                if (desktopNum == 0) {
                    continue
                }
                if (desktopNum > 0) {
                    desktopInfo := " [桌面" . desktopNum . "]"
                } else if (desktopNum == -1) {
                    desktopInfo := " [所有桌面]"
                } else if (desktopNum == -2) {
                    desktopInfo := " [应用所有桌面]"
                } else {
                    desktopInfo := ""
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
                if (desktopNum == 0) {
                    continue
                }
                if (desktopNum > 0) {
                    desktopInfo := " [桌面" . desktopNum . "]"
                } else if (desktopNum == -1) {
                    desktopInfo := " [所有桌面]"
                } else if (desktopNum == -2) {
                    desktopInfo := " [应用所有桌面]"
                } else {
                    desktopInfo := ""
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

ScheduleSearch(EditObj, LV, hIL, &iconCache) {
    static timer := 0
    if (timer) {
        SetTimer(timer, 0)
    }
    timer := SetTimer(() => UpdateSearch(EditObj, LV, hIL, &iconCache), -20)
}

UpdateSearch(EditObj, LV, hIL, &iconCache) {
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
            if (desktopNum == 0) {
                continue
            }
            if (desktopNum > 0) {
                desktopInfo := " [桌面" . desktopNum . "]"
            } else if (desktopNum == -1) {
                desktopInfo := " [所有桌面]"
            } else if (desktopNum == -2) {
                desktopInfo := " [应用所有桌面]"
            } else {
                desktopInfo := ""
            }

            fullText := StrLower("[" . process . "] " . title)
            score := FuzzyScore(searchLower, fullText)

            if (score > 0) {
                results.Push({ score: score, text: desktopInfo . " [" . process . "] " . title, hwnd: hwnd })
            }
        }
    }
    A_DetectHiddenWindows := bak_DetectHiddenWindows

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
            process := WinGetProcessName(res.hwnd)
            iconIdx := GetIconIndexByProcess(process, hIL, iconCache)
            LV.Add("Icon" . iconIdx, res.text, res.hwnd)
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

        if InStr(target, token) {
            tokenScore := 1000
            if InStr(target, token, true, 1, 1) {
                tokenScore += 200
            }
        } else if IbPinyin_Match(token, target, IbPinyin_AsciiFirstLetter | IbPinyin_Ascii) {
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

        LogInfo("激活窗口: ahk_id " . hwnd, , WindowJumpDebug.mode)

        if (hwnd) {
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
    } catch Error as e {
        LogError(e, , WindowJumpDebug.mode)
    }
}
