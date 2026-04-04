#Requires AutoHotkey v2.0
#SingleInstance Force

; ==============================================================================
; 全局配置
; ==============================================================================
UpdateTheme()

WindowJump() {
    UpdateTheme()
    static MyGui := 0
    static hIL := 0 ; 图像列表句柄

    if (MyGui) {
        MyGui["SearchInput"].Value := ""
        MyGui["SearchInput"].Focus()
        RefreshList(MyGui["ResultList"], &hIL)
        MyGui.Show("Center")
        return
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

    ; 初始化图标列表并绑定
    hIL := IL_Create(10, 5, 0)
    ResultList := MyGui.Add("ListView", "x20 y95 w560 r11 -Multi -Hdr -E0x200 vResultList +LV0x140 Background" .
        ListViewBg . " c" . FontColor, ["Display", "HWND"])

    ResultList.SetImageList(hIL)
    ResultList.ModifyCol(1, 540)
    ResultList.ModifyCol(2, 0)

    RefreshList(ResultList, &hIL)

    ; 事件绑定
    EditBox.OnEvent("Change", (obj, *) => UpdateSearch(obj, MyGui["ResultList"], hIL))
    ResultList.OnEvent("DoubleClick", (obj, row) => ActivateWin(obj, row))

    ; 键盘接管
    HotIfWinActive("ahk_id " . MyGui.Hwnd)
    Hotkey("Escape", (*) => MyGui.Hide(), "On")
    Hotkey("Down", (*) => MoveLVSelection(MyGui["ResultList"], "Down"), "On")
    Hotkey("Up", (*) => MoveLVSelection(MyGui["ResultList"], "Up"), "On")
    Hotkey("Enter", (*) => HandleEnter(MyGui), "On")

    MyGui.Show("w600 h450 Center")
}

; ==============================================================================
; 逻辑处理函数
; ==============================================================================

RefreshList(LV, &hIL) {
    LV.Delete()
    if (hIL) {
        IL_Destroy(hIL)
    }

    hIL := IL_Create(20, 10, 0)
    LV.SetImageList(hIL)

    for hwnd in WinGetList() {
        try {
            title := WinGetTitle(hwnd)
            process := WinGetProcessName(hwnd)
            style := WinGetStyle(hwnd)

            if (title != "" && (style & 0x40000) && hwnd != LV.Gui.Hwnd) {
                iconIdx := GetIconIndex(hwnd, hIL)
                LV.Add("Icon" . iconIdx, " [" . process . "] " . title, hwnd)
            }
        }
    }
    if (LV.GetCount() > 0) {
        LV.Modify(1, "Select Focus")
    }
}

UpdateSearch(EditObj, LV, hIL) {
    currentInput := StrLower(EditObj.Value)
    if (currentInput == "") {
        RefreshList(LV, &hIL)
        return
    }

    LV.Delete()
    results := []

    for hwnd in WinGetList() {
        try {
            title := WinGetTitle(hwnd)
            process := WinGetProcessName(hwnd)
            style := WinGetStyle(hwnd)

            if (title == "" || !(style & 0x40000) || hwnd == EditObj.Gui.Hwnd) {
                continue
            }

            fullText := StrLower("[" . process . "] " . title)
            score := FuzzyScore(currentInput, fullText)

            if (score > 0) {
                results.Push({ score: score, text: " [" . process . "] " . title, hwnd: hwnd })
            }
        }
    }

    if (results.Length > 0) {
        loop (results.Length) {
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
            iconIdx := GetIconIndex(res.hwnd, hIL)
            LV.Add("Icon" . iconIdx, res.text, res.hwnd)
        }
    }

    if (LV.GetCount() > 0) {
        LV.Modify(1, "Select Focus")
    }
}

GetIconIndex(hwnd, hIL) {
    ; 1. WM_GETICON 获取小图标
    hIcon := SendMessage(0x7F, 0, 0, hwnd, "ahk_id " . hwnd)
    ; 2. 失败则尝试从类获取
    if (!hIcon) {
        hIcon := DllCall(A_PtrSize == 8 ? "GetClassLongPtr" : "GetClassLong", "Ptr", hwnd, "Int", -34, "UPtr")
    }
    ; 3. 仍失败则获取大图标
    if (!hIcon) {
        hIcon := SendMessage(0x7F, 1, 0, hwnd, "ahk_id " . hwnd)
    }

    if (hIcon) {
        return IL_Add(hIL, "HICON:" . hIcon)
    }
    return 1
}

FuzzyScore(query, target) {
    if !(query := Trim(query)) {
        return 0
    }
    target := StrReplace(target, ".exe", "")
    totalScore := 0
    tokens := StrSplit(query, " ")
    for _, token in tokens {
        if (token == "") {
            continue
        }
        tScore := 0, tIdx := 1, lastIdx := 0, consecutive := 0
        pEnd := InStr(target, "]")
        loop StrLen(token) {
            char := SubStr(token, A_Index, 1)
            found := InStr(target, char, false, tIdx)
            if (!found) {
                return 0
            }
            tScore += 30
            tScore += (found <= pEnd) ? 20 : 10
            if (lastIdx && found == lastIdx + 1) {
                consecutive++
                tScore += (50 * consecutive)
            }
            prev := (found > 1) ? SubStr(target, found - 1, 1) : ""
            if (prev == "[" || prev == " ") {
                tScore += 40
            }
            lastIdx := found
            tIdx := found + 1
        }
        totalScore += tScore
    }
    return totalScore
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
        r := rawColor & 0xFF, g := (rawColor >> 8) & 0xFF, b := (rawColor >> 16) & 0xFF
        accentNum := (r << 16) | (g << 8) | b
        AccentColor := Format("{:06X}", accentNum)
    } catch {
        accentNum := 0x0078D7
        AccentColor := "0078D7"
    }
    if (IsDarkMode) {
        BgColor := MixColor(accentNum, 0x000000, 0.90)
        FontColor := "FFFFFF"
        ListViewBg := MixColor(accentNum, 0x000000, 0.80)
    } else {
        BgColor := MixColor(accentNum, 0xFFFFFF, 0.90)
        FontColor := "333333"
        ListViewBg := MixColor(accentNum, 0xFFFFFF, 0.80)
    }
    FontSize := 12
}

MixColor(Color1, Color2, Weight) {
    r1 := (Color1 >> 16) & 0xFF, g1 := (Color1 >> 8) & 0xFF, b1 := Color1 & 0xFF
    r2 := (Color2 >> 16) & 0xFF, g2 := (Color2 >> 8) & 0xFF, b2 := Color2 & 0xFF
    r := Round(r1 + (r2 - r1) * Weight), g := Round(g1 + (g2 - g1) * Weight), b := Round(b1 + (b2 - b1) * Weight)
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
        if (hwnd) {
            WinActivate("ahk_id " . hwnd)
            LV.Gui.Hide()
        }
    } catch {
        ; 异常时不报错
    }
}
