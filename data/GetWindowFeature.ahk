#Requires AutoHotkey v2.0

#NoTrayIcon
#SingleInstance force
SetWorkingDir A_ScriptDir
CoordMode "Pixel", "Screen"

global oGui

WinSpyGui()

WinSpyGui() {
    global oGui

    try TraySetIcon "./icons/logo.ico"
    DllCall("shell32\SetCurrentProcessExplicitAppUserModelID", "wstr", "AutoHotkey.WindowSpy")

    oGui := Gui("AlwaysOnTop Resize MinSize +DPIScale", "窗口特征提取器")
    oGui.OnEvent("Close", WinSpyClose)
    oGui.OnEvent("Size", WinSpySize)

    oGui.BackColor := "FFFFFF"
    oGui.SetFont("s11", "Microsoft YaHei")
    oGui.Add("Edit", "xm w640 r39 ReadOnly -Wrap vCtrl_Title")
    ; oGui.Add("Text",,"当前鼠标位置:")
    ; oGui.Add("Edit","w640 r4 ReadOnly vCtrl_MousePos")
    ; oGui.Add("Text",,"当前窗口位置:")
    ; oGui.Add("Edit","w640 r2 ReadOnly vCtrl_Pos")
    oGui.Add("Text", "w640 r1 vCtrl_Freeze", (txtNotFrozen := ""))
    oGui.Add("Checkbox", "yp+20 xp+400 h15 w240 Left vCtrl_FollowMouse", "跟随鼠标 (可按 Ctrl 暂停刷新)")

    oGui.Show("NoActivate")
    ;WinGetClientPos(&x_temp, &y_temp2, , , "ahk_id " oGui.hwnd)

    ; oGui.horzMargin := x_temp*96//A_ScreenDPI - 320 ; now using oGui.MarginX

    oGui.txtNotFrozen := txtNotFrozen       ; create properties for futur use
    oGui.txtFrozen := ""

    SetTimer Update, 250
}

WinSpySize(GuiObj, MinMax, Width, Height) {
    global oGui

    if !oGui.HasProp("txtNotFrozen") ; WinSpyGui() not done yet, return until it is
        return

    SetTimer Update, (MinMax = 0) ? 250 : 0 ; suspend updates on minimize

    ctrlW := Width - (oGui.MarginX * 2) ; ctrlW := Width - horzMargin
    list := "Title,MousePos,Ctrl,Pos,SBText,VisText,AllText,Freeze"
}

WinSpyClose(GuiObj) {
    ExitApp
}

Update() { ; timer, no params
    try TryUpdate() ; Try
}

TryUpdate() {
    global oGui

    if !oGui.HasProp("txtNotFrozen") ; WinSpyGui() not done yet, return until it is
        return

    Ctrl_FollowMouse := oGui["Ctrl_FollowMouse"].Value
    CoordMode "Mouse", "Screen"
    MouseGetPos &msX, &msY, &msWin, &msCtrl, 2 ; get ClassNN and hWindow
    actWin := WinExist("A")

    if (Ctrl_FollowMouse) {
        curWin := msWin, curCtrl := msCtrl
        WinExist("ahk_id " curWin) ; updating LastWindowFound?
    } else {
        curWin := actWin
        curCtrl := ControlGetFocus() ; get focused control hwnd from active win
    }
    curCtrlClassNN := ""
    try curCtrlClassNN := ControlGetClassNN(curCtrl)

    t1 := WinGetTitle(), t2 := WinGetClass()
    if (curWin = oGui.hwnd || t2 = "MultitaskingViewFrame") { ; Our Gui || Alt-tab
        UpdateText("Ctrl_Freeze", oGui.txtFrozen)
        return
    }

    UpdateText("Ctrl_Freeze", oGui.txtNotFrozen)
    t3 := WinGetProcessName()

    ; 获取窗口样式信息
    Style := WinGetStyle("ahk_id " curWin)

    ; 检测窗口样式特征
    StyleInfo := GetWindowStyleInfo(Style)

    ; 获取窗口边框和尺寸信息
    BorderInfo := GetWindowBorderInfo(curWin)

    dllCallCurrentActiveWindow := DllCall("GetForegroundWindow", "ptr")
    existACurrentActiveWindow := WinExist("A")

    WinDataText := "Title: " t1 "`n" ; ZZZ
        . "ahk_class " t2 "`n"
        . "ahk_exe " t3 "`n"
        . "DllCallActiveID " dllCallCurrentActiveWindow "`n"
        . "ExistActiveID " existACurrentActiveWindow "`n"
        . "`n" . BorderInfo
        . "`n" . StyleInfo

    UpdateText("Ctrl_Title", WinDataText)
    CoordMode "Mouse", "Window"
    MouseGetPos &mrX, &mrY
    CoordMode "Mouse", "Client"
    MouseGetPos &mcX, &mcY
    mClr := PixelGetColor(msX, msY, "RGB")
    mClr := SubStr(mClr, 3)

    mpText := "Screen:`t" msX ", " msY "`n"
        . "Window:`t" mrX ", " mrY "`n"
        . "Client:`t" mcX ", " mcY " (default)`n"
        . "Color:`t" mClr " (Red=" SubStr(mClr, 1, 2) " Green=" SubStr(mClr, 3, 2) " Blue=" SubStr(mClr, 5) ")"

    UpdateText("Ctrl_MousePos", mpText)

    wX := "", wY := "", wW := "", wH := ""
    WinGetPos &wX, &wY, &wW, &wH, "ahk_id " curWin
    WinGetClientPos(&wcX, &wcY, &wcW, &wcH, "ahk_id " curWin)

    wText := "Screen:`tx: " wX "`ty: " wY "`tw: " wW "`th: " wH "`n"
        . "Client:`tx: " wcX "`ty: " wcY "`tw: " wcW "`th: " wcH

    UpdateText("Ctrl_Pos", wText)
    sbTxt := ""

    loop {
        ovi := ""
        try ovi := StatusBarGetText(A_Index)
        if (ovi = "")
            break
        sbTxt .= "(" A_Index "):`t" textMangle(ovi) "`n"
    }

    sbTxt := SubStr(sbTxt, 1, -1) ; StringTrimRight, sbTxt, sbTxt, 1
    UpdateText("Ctrl_SBText", sbTxt)
    bSlow := oGui["Ctrl_IsSlow"].Value ; GuiControlGet, bSlow,, Ctrl_IsSlow

    if (bSlow) {
        DetectHiddenText False
        ovVisText := WinGetText() ; WinGetText, ovVisText
        DetectHiddenText True
        ovAllText := WinGetText() ; WinGetText, ovAllText
    } else {
        ovVisText := WinGetTextFast(false)
        ovAllText := WinGetTextFast(true)
    }

    UpdateText("Ctrl_VisText", ovVisText)
    UpdateText("Ctrl_AllText", ovAllText)
}

; ===========================================================================================
; WinGetText ALWAYS uses the "slow" mode - TitleMatchMode only affects
; WinText/ExcludeText parameters. In "fast" mode, GetWindowText() is used
; to retrieve the text of each control.
; ===========================================================================================
WinGetTextFast(detect_hidden) {
    controls := WinGetControlsHwnd()

    static WINDOW_TEXT_SIZE := 32767 ; Defined in AutoHotkey source.

    buf := Buffer(WINDOW_TEXT_SIZE * 2, 0)

    text := ""

    loop controls.Length {
        hCtl := controls[A_Index]
        if !detect_hidden && !DllCall("IsWindowVisible", "ptr", hCtl)
            continue
        if !DllCall("GetWindowText", "ptr", hCtl, "Ptr", buf.ptr, "int", WINDOW_TEXT_SIZE)
            continue

        text .= StrGet(buf) "`r`n" ; text .= buf "`r`n"
    }
    return text
}

; ===========================================================================================
; Unlike using a pure GuiControl, this function causes the text of the
; controls to be updated only when the text has changed, preventing periodic
; flickering (especially on older systems).
; ===========================================================================================
UpdateText(vCtl, NewText) {
    global oGui
    static OldText := {}
    ctl := oGui[vCtl], hCtl := Integer(ctl.hwnd)

    if (!oldText.HasProp(hCtl) Or OldText.%hCtl% != NewText) {
        ctl.Value := NewText
        OldText.%hCtl% := NewText
    }
}

textMangle(x) {
    elli := false
    if (pos := InStr(x, "`n"))
        x := SubStr(x, 1, pos - 1), elli := true
    else if (StrLen(x) > 40)
        x := SubStr(x, 1, 40), elli := true
    if elli
        x .= " (...)"
    return x
}

; 获取窗口边框和尺寸信息
GetWindowBorderInfo(hwnd) {
    ; DWM 属性常量
    DWMWA_EXTENDED_FRAME_BOUNDS := 9  ; 扩展框架边界
    DWMWA_VISIBLE_FRAME_BORDER_THICKNESS := 37  ; 可见边框厚度

    borderInfo := ""

    try {
        ; 获取窗口的常规位置和大小
        WinGetPos(&winX, &winY, &winW, &winH, "ahk_id " hwnd)
        WinGetClientPos(&clientX, &clientY, &clientW, &clientH, "ahk_id " hwnd)

        ; 获取扩展框架边界 (RECT 结构)
        extendedRect := Buffer(16, 0)  ; RECT 结构需要 16 字节
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

            ; 计算边框厚度
            leftBorder := clientX - extLeft
            topBorder := clientY - extTop
            rightBorder := extRight - (clientX + clientW)
            bottomBorder := extBottom - (clientY + clientH)

            borderInfo .= "BorderThickness: [Left: " leftBorder "] [Top: " topBorder "] [Right: " rightBorder "] [Bottom: " bottomBorder "]`n"

            ; 计算阴影厚度 (WinGet 窗口边界与扩展边界的差异)
            shadowLeft := extLeft - WinX
            shadowTop := extTop - WinY
            shadowRight := (winX + winW) - extRight
            shadowBottom := (winY + winH) - extBottom

            borderInfo .= "ShadowThickness: [Left: " shadowLeft "] [Top: " shadowTop "] [Right: " shadowRight "] [Bottom: " shadowBottom "]`n"
        }

        ; 尝试获取可见边框厚度
        borderThickness := Buffer(4, 0)  ; UINT 类型需要 4 字节
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

; 获取窗口样式信息
GetWindowStyleInfo(Style) {
    ; 定义窗口样式数据
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

    ; 检查每个样式，显示所有样式
    for styleData in WindowStyles {
        if (Style & styleData.Hex) {
            ; 特殊处理 WS_OVERLAPPED (值为0)
            if (styleData.Hex = 0x0) {
                ; WS_OVERLAPPED 只有在没有 WS_POPUP 和 WS_CHILD 时才算有效
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

suspend_timer() {
    global oGui
    SetTimer Update, 0
    UpdateText("Ctrl_Freeze", oGui.txtFrozen)
}

~*Shift::
~*Ctrl:: suspend_timer()

~*Ctrl up::
~*Shift up:: SetTimer Update, 250