#Requires AutoHotkey v2.0
#SingleInstance Force

; ==============================================================================
; 全局配置
; ==============================================================================
UpdateTheme()

UpdateTheme() {
    global BgColor, FontColor, AccentColor, ListViewBg, IsDarkMode, FontSize

    ; 1. 读取深色模式状态
    try {
        IsDarkMode := RegRead("HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize",
            "AppsUseLightTheme") == 0
    } catch {
        IsDarkMode := false
    }

    ; 2. 读取 AccentColor (ABGR -> RGB 数字)
    try {
        rawColor := RegRead("HKEY_CURRENT_USER\Software\Microsoft\Windows\DWM", "AccentColor")
        ; 提取 RGB 部分并转换为数字以便计算
        ; 原始是 0xAABBGGRR，我们需要转换为数字 0xRRGGBB
        r := rawColor & 0xFF
        g := (rawColor >> 8) & 0xFF
        b := (rawColor >> 16) & 0xFF
        accentNum := (r << 16) | (g << 8) | b
        AccentColor := Format("{:06X}", accentNum)
    } catch {
        accentNum := 0x0078D7
        AccentColor := "0078D7"
    }

    ; 3. 核心算法：背景色偏移
    ; MixColor(原始强调色, 目标色, 偏移权重)
    ; 权重越大，颜色越接近目标色（越淡或越深）
    if IsDarkMode {
        BgColor := MixColor(accentNum, 0x000000, 0.90) ; 向黑色偏移 90%
        FontColor := "FFFFFF"
        ListViewBg := MixColor(accentNum, 0x000000, 0.80) ; 列表背景稍亮一点点
    } else {
        BgColor := MixColor(accentNum, 0xFFFFFF, 0.90) ; 向白色偏移 90%
        FontColor := "333333"
        ListViewBg := MixColor(accentNum, 0xFFFFFF, 0.80) ; 列表背景颜色更贴近主题色
    }

    FontSize := 12
}

WindowJump() {
    UpdateTheme()

    static MyGui := 0

    if MyGui {
        MyGui["SearchInput"].Value := ""
        MyGui["SearchInput"].Focus()
        RefreshList(MyGui["ResultList"])
        MyGui.Show("Center")
        return
    }

    MyGui := Gui("-Caption +AlwaysOnTop +Owner +LastFound", "QuickSwitcher")
    MyGui.BackColor := BgColor
    MyGui.SetFont("s" . FontSize " c" . FontColor, "微软雅黑")
    scaleFactor := A_ScreenDPI / 96

    ; 计算物理像素下的宽高和圆角
    w_phys := 600 * scaleFactor
    h_phys := 450 * scaleFactor
    r_phys := 20 * scaleFactor

    ; 应用圆角区域
    WinSetRegion("0-0 w" . w_phys . " h" . h_phys . " r" . r_phys . "-" . r_phys, MyGui.Hwnd)

    MyGui.Add("Text", "x25 y15 h30 c" . AccentColor, "快速跳转——上下键选择，回车激活，支持模糊匹配，暂不支持拼音匹配")
    EditBox := MyGui.Add("Edit", "x20 y45 w560 h22 vSearchInput -E0x200 Background" . ListViewBg)

    ; +LV0x140 确保整行高亮
    ResultList := MyGui.Add("ListView", "x20 y95 w560 r11 -Multi -Hdr -E0x200 vResultList +LV0x140 Background" .
        ListViewBg . " c" . FontColor, ["Display", "HWND"])
    ResultList.ModifyCol(1, 540)
    ResultList.ModifyCol(2, 0)

    RefreshList(ResultList)

    ; 事件绑定
    EditBox.OnEvent("Change", (obj, *) => UpdateSearch(obj, MyGui["ResultList"]))
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

; 函数：混合颜色 (Color1: 基础色, Color2: 目标色, Weight: 目标色占比 0-1)
MixColor(Color1, Color2, Weight) {
    r1 := (Color1 >> 16) & 0xFF, g1 := (Color1 >> 8) & 0xFF, b1 := Color1 & 0xFF
    r2 := (Color2 >> 16) & 0xFF, g2 := (Color2 >> 8) & 0xFF, b2 := Color2 & 0xFF

    r := Round(r1 + (r2 - r1) * Weight)
    g := Round(g1 + (g2 - g1) * Weight)
    b := Round(b1 + (b2 - b1) * Weight)

    return Format("{:02X}{:02X}{:02X}", r, g, b)
}

; 函数：在不切换焦点的情况下控制列表行的上下移动
MoveLVSelection(LV, Direction) {
    if (LV.GetCount() == 0)
        return
    ; 1. 获取当前聚焦项：必须使用全拼 "Focused"
    row := LV.GetNext(0, "Focused")

    ; 2. 如果没有聚焦项，获取第一个选中的项：根据文档，留空即代表 "Selected"
    if (row == 0) row := LV.GetNext(0)
        if (Direction == "Down") {
            nextRow := (row == 0) ? 1 : Min(row + 1, LV.GetCount())
        } else {
            nextRow := (row == 0) ? LV.GetCount() : Max(row - 1, 1)
        }

    ; 视觉清理与重设
    LV.Modify(0, "-Select -Focus")
    LV.Modify(nextRow, "Select Focus Vis")
}

; 函数：处理回车激活
HandleEnter(GuiObj) {
    LV := GuiObj["ResultList"]

    ; 优先取聚焦，其次取选中（留空）
    row := LV.GetNext(0, "Focused")
    if (row == 0) row := LV.GetNext(0)
    ; 兜底逻辑：如果什么都没选，默认第一行
        if (row == 0 && LV.GetCount() > 0)
            row := 1

    if (row > 0)
        ActivateWin(LV, row)
}

RefreshList(LV) {
    LV.Delete()
    for hwnd in WinGetList() {
        try {
            title := WinGetTitle(hwnd)
            process := WinGetProcessName(hwnd)
            style := WinGetStyle(hwnd)
            if (title != "" && (style & 0x40000) && hwnd != LV.Gui.Hwnd) {
                LV.Add(, " [" . process . "] " . title, hwnd)
            }
        }
    }
    if (LV.GetCount() > 0)
        LV.Modify(1, "Select Focus")
}

UpdateSearch(EditObj, LV) {
    currentInput := StrLower(EditObj.Value)
    LV.Delete()

    if (currentInput == "") {
        RefreshList(LV)
        return
    }

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
        ; 排序：分值高的在前
        loop (results.Length) {
            i := A_Index
            while (i > 1 && results[i - 1].score < results[i].score) {
                temp := results[i]
                results[i] := results[i - 1]
                results[i - 1] := temp
                i--
            }
        }

        ; 渲染
        loop (Min(results.Length, 30)) {
            LV.Add(, results[A_Index].text, results[A_Index].hwnd)
        }
    }

    if (LV.GetCount() > 0) {
        LV.Modify(1, "Select Focus")
    }
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
                return 0  ; 词元不完整匹配则该 target 无效
            }

            ; 只要命中了字符，就给一个较大的基础分，确保“查得到”
            tScore += 30

            ; 区分位置权重
            tScore += (found <= pEnd) ? 20 : 10

            if (lastIdx && found == lastIdx + 1) {
                consecutive++
                ; 连续匹配奖励
                tScore += (50 * consecutive)
            }

            prev := (found > 1) ? SubStr(target, found - 1, 1) : ""
            if (prev == "[" || prev == " ") {
                tScore += 40  ; 边界加分
            }

            lastIdx := found
            tIdx := found + 1
        }
        totalScore += tScore
    }
    return totalScore
}

ActivateWin(LV, RowNumber) {
    try {
        hwnd := LV.GetText(RowNumber, 2)
        if hwnd {
            WinActivate("ahk_id " . hwnd)
            LV.Gui.Hide()
        }
    } catch {
        RefreshList(LV)
    }
}
