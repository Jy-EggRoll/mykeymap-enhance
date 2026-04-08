#Requires AutoHotkey v2.0

; -----------------------------------------------------------------------------
; WindowFeatureLib.ahk
; 负责独立的窗口特征信息获取函数。
; 可作为插件被 GUI 脚本引入，而不包含任何 GUI 或自动执行逻辑。
; -----------------------------------------------------------------------------

GetWindowFeatureInfo(hwnd, bSlow := false) {
    obj := {
        hwnd: hwnd,
        Title: WinGetTitle("ahk_id " hwnd),
        Class: WinGetClass("ahk_id " hwnd),
        Process: WinGetProcessName("ahk_id " hwnd),
        Style: WinGetStyle("ahk_id " hwnd),
        StyleInfo: "",
        BorderInfo: "",
        VisibleText: "",
        AllText: ""
    }

    obj.StyleInfo := GetWindowStyleInfo(obj.Style)
    obj.BorderInfo := GetWindowBorderInfo(hwnd)
    obj.VisibleText := WinGetTextFast(hwnd, false)
    obj.AllText := WinGetTextFast(hwnd, true)

    return obj
}

GetControlClassNNInfo(hwnd := "A", hCtl := "", x := "", y := "") {
    if (hwnd = "" || hwnd = "A")
        hwnd := WinExist("A")

    if (!hCtl) {
        if (x = "" || y = "") {
            CoordMode "Mouse", "Screen"
            tmpX := x, tmpY := y
            MouseGetPos(&tmpX, &tmpY, &mouseWin, &hCtl, 2)
            x := tmpX, y := tmpY
            if (hwnd = "" || hwnd = "A")
                hwnd := mouseWin
        }
    }

    controlInfo := {
        hwnd: hwnd,
        ControlHwnd: hCtl,
        ClassNN: "",
        Text: "",
        X: "",
        Y: "",
        W: "",
        H: "",
        ScreenX: x,
        ScreenY: y
    }

    if (hCtl) {
        controlInfo.ClassNN := ControlGetClassNN(hCtl)
        controlInfo.Text := ControlGetText(hCtl)
        ControlGetPos(&tmpX, &tmpY, &tmpW, &tmpH, hCtl, "ahk_id " hwnd)
        controlInfo.X := tmpX
        controlInfo.Y := tmpY
        controlInfo.W := tmpW
        controlInfo.H := tmpH
    }

    return controlInfo
}

GetControlClassNNText(hwnd := "A", hCtl := "", x := "", y := "") {
    return FormatControlClassNNInfo(GetControlClassNNInfo(hwnd, hCtl, x, y))
}

GetWindowAllClassNNText(hwnd := "A", detect_hidden := false) {
    controls := WinGetControlsHwnd("ahk_id " hwnd)
    if !IsObject(controls)
        return "未发现控件"

    text := ""
    count := 0

    loop controls.Length {
        hCtl := controls[A_Index]
        if !detect_hidden && !DllCall("IsWindowVisible", "ptr", hCtl)
            continue

        classNN := ControlGetClassNN(hCtl)
        ctrlText := ControlGetText(hCtl)
        ctrlText := SubStr(RegExReplace(ctrlText, "\s+", " "), 1, 40)
        text .= classNN " => " ctrlText "`n"
        count++
    }

    if (count = 0)
        return "未发现控件"

    return "Total controls: " count "`n`n" . SubStr(text, 1, -1)
}

FormatControlClassNNInfo(controlInfo) {
    if !controlInfo.ControlHwnd
        return "未发现控件"

    text := SubStr(RegExReplace(controlInfo.Text, "\s+", " "), 1, 40)
    return "ClassNN: " controlInfo.ClassNN "`n"
        . "Text: " text "`n"
        . "Pos: " controlInfo.X "," controlInfo.Y " Size: " controlInfo.W "x" controlInfo.H
}

ShowControlClassNNTooltip(hwnd := "A", x := "", y := "", duration := 1500) {
    info := GetControlClassNNInfo(hwnd, x, y)
    ToolTip(FormatControlClassNNInfo(info), info.ScreenX + 20, info.ScreenY + 20)
    if (duration > 0)
        SetTimer(() => ToolTip(""), -duration)
    return info
}

WinGetTextFast(hwnd, detect_hidden := false) {
    controls := WinGetControlsHwnd("ahk_id " hwnd)
    if !IsObject(controls) {
        return ""
    }

    static WINDOW_TEXT_SIZE := 32767 ; Defined in AutoHotkey source.
    buf := Buffer(WINDOW_TEXT_SIZE * 2, 0)
    text := ""

    loop controls.Length {
        hCtl := controls[A_Index]
        if !detect_hidden && !DllCall("IsWindowVisible", "ptr", hCtl)
            continue
        if !DllCall("GetWindowText", "ptr", hCtl, "Ptr", buf.ptr, "int", WINDOW_TEXT_SIZE)
            continue

        text .= StrGet(buf) "`r`n"
    }
    return text
}

GetWindowBorderInfo(hwnd) {
    DWMWA_EXTENDED_FRAME_BOUNDS := 9
    DWMWA_VISIBLE_FRAME_BORDER_THICKNESS := 37
    borderInfo := ""

    try {
        WinGetPos(&winX, &winY, &winW, &winH, "ahk_id " hwnd)
        WinGetClientPos(&clientX, &clientY, &clientW, &clientH, "ahk_id " hwnd)

        extendedRect := Buffer(16, 0)
        result1 := DllCall("dwmapi\DwmGetWindowAttribute",
            "ptr", hwnd,
            "uint", DWMWA_EXTENDED_FRAME_BOUNDS,
            "ptr", extendedRect,
            "uint", 16,
            "int")

        if (result1 == 0) {
            extLeft := NumGet(extendedRect, 0, "int")
            extTop := NumGet(extendedRect, 4, "int")
            extRight := NumGet(extendedRect, 8, "int")
            extBottom := NumGet(extendedRect, 12, "int")
            extWidth := extRight - extLeft
            extHeight := extBottom - extTop

            borderInfo .= "--- Window Size & Border Info ---`n"
            borderInfo .= "WinGetPosSize: " winW " * " winH "`n"
            borderInfo .= "WinGetClientPosSize: " clientW " * " clientH "`n"
            borderInfo .= "PlusExtendedFrameSize: " extWidth " * " extHeight "`n"

            leftBorder := clientX - extLeft
            topBorder := clientY - extTop
            rightBorder := extRight - (clientX + clientW)
            bottomBorder := extBottom - (clientY + clientH)

            borderInfo .= "BorderThickness: [Left: " leftBorder "] [Top: " topBorder "] [Right: " rightBorder "] [Bottom: " bottomBorder "]`n"

            shadowLeft := extLeft - winX
            shadowTop := extTop - winY
            shadowRight := (winX + winW) - extRight
            shadowBottom := (winY + winH) - extBottom

            borderInfo .= "ShadowThickness: [Left: " shadowLeft "] [Top: " shadowTop "] [Right: " shadowRight "] [Bottom: " shadowBottom "]`n"
        }

        borderThickness := Buffer(4, 0)
        result2 := DllCall("dwmapi\DwmGetWindowAttribute",
            "ptr", hwnd,
            "uint", DWMWA_VISIBLE_FRAME_BORDER_THICKNESS,
            "ptr", borderThickness,
            "uint", 4,
            "int")

        if (result2 == 0) {
            thickness := NumGet(borderThickness, 0, "uint")
            borderInfo .= "VisibleFrameBorderThickness: " thickness " pixels`n"
        }
    } catch Error as e {
        borderInfo .= "--- Window Size & Border Info ---`n"
        borderInfo .= "Error getting border info: " e.Message "`n"
    }

    return borderInfo
}

GetWindowStyleInfo(Style) {
    WindowStyles := [{ Name: "WS_BORDER", Hex: 0x800000, Desc: "Thin-line border" }, { Name: "WS_POPUP", Hex: 0x80000000,
        Desc: "Pop-up window" }, { Name: "WS_CAPTION", Hex: 0xC00000, Desc: "Title bar" }, { Name: "WS_CLIPSIBLINGS",
            Hex: 0x4000000, Desc: "Clips child windows" }, { Name: "WS_DISABLED", Hex: 0x8000000, Desc: "Initially disabled" }, { Name: "WS_DLGFRAME",
                Hex: 0x400000, Desc: "Dialog box border" }, { Name: "WS_GROUP", Hex: 0x20000, Desc: "First in group" }, { Name: "WS_HSCROLL",
                    Hex: 0x100000, Desc: "Horizontal scroll bar" }, { Name: "WS_MAXIMIZE", Hex: 0x1000000, Desc: "Initially maximized" }, { Name: "WS_MAXIMIZEBOX",
                        Hex: 0x10000, Desc: "Maximize button" }, { Name: "WS_MINIMIZE", Hex: 0x20000000, Desc: "Initially minimized" }, { Name: "WS_MINIMIZEBOX",
                            Hex: 0x20000, Desc: "Minimize button" }, { Name: "WS_OVERLAPPED", Hex: 0x0, Desc: "Overlapped window" }, { Name: "WS_OVERLAPPEDWINDOW",
                                Hex: 0xCF0000, Desc: "Standard window" }, { Name: "WS_POPUPWINDOW", Hex: 0x80880000,
                                    Desc: "Pop-up with border" }, { Name: "WS_SIZEBOX", Hex: 0x40000, Desc: "Sizing border (resize)" }, { Name: "WS_SYSMENU",
                                        Hex: 0x80000, Desc: "System menu" }, { Name: "WS_TABSTOP", Hex: 0x10000, Desc: "Tab stop control" }, { Name: "WS_THICKFRAME",
                                            Hex: 0x40000, Desc: "Thick frame (resize)" }, { Name: "WS_VSCROLL", Hex: 0x200000,
                                                Desc: "Vertical scroll bar" }, { Name: "WS_VISIBLE", Hex: 0x10000000,
                                                    Desc: "Initially visible" }, { Name: "WS_CHILD", Hex: 0x40000000,
                                                        Desc: "Child window" }
    ]

    styleText := "--- Window Styles ---`n"
    styleText .= "Style: 0x" . Format("{:X}", Style) . "`n"

    for styleData in WindowStyles {
        if (Style & styleData.Hex) {
            if (styleData.Hex = 0x0) {
                if (!(Style & 0x80000000) && !(Style & 0x40000000)) {
                    styleText .= "● " . styleData.Name . " (0x" . Format("{:X}", styleData.Hex) . ")`n"
                } else {
                    styleText .= "○ " . styleData.Name . " (0x" . Format("{:X}", styleData.Hex) . ")`n"
                }
            } else {
                styleText .= "● " . styleData.Name . " (0x" . Format("{:X}", styleData.Hex) . ")`n"
            }
        } else {
            styleText .= "○ " . styleData.Name . " (0x" . Format("{:X}", styleData.Hex) . ")`n"
        }
    }

    return styleText
}
