#Requires AutoHotkey v2.0

#NoTrayIcon
#SingleInstance force
SetWorkingDir A_ScriptDir
CoordMode "Pixel", "Screen"
DetectHiddenWindows(true)

#Include ./WindowFeatureLib.ahk

global oGui
global txtNotFrozen := ""
global txtFrozen := ""
global lastTargetWin := 0
global lastTargetCtrl := 0
global moduleOptions := ["WindowInfo", "ClassNN", "AllClassNN", "BorderInfo", "StyleInfo"]

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
    oGui.Add("Text", "w760 r1 vCtrl_Freeze", "")
    oGui.Add("Checkbox", "yp+20 xp+20 h15 w240 Left vCtrl_FollowMouse", "跟随鼠标 (可按 Ctrl 暂停刷新)")
    oGui.Add("DropDownList", "yp+20 xp w240 vCtrl_ModuleSelect", moduleOptions)
    oGui.Add("Edit", "xm w760 r38 ReadOnly -Wrap vCtrl_Content")

    oGui.Show("NoActivate")
    oGui["Ctrl_ModuleSelect"].Value := 1

    SetTimer Update, 250
}

WinSpySize(GuiObj, MinMax, Width, Height) {
    global oGui

    if !IsObject(oGui)
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

    if !IsObject(oGui)
        return

    Ctrl_FollowMouse := oGui["Ctrl_FollowMouse"].Value
    CoordMode "Mouse", "Screen"
    MouseGetPos(&msX, &msY, &msWin, &msCtrl, 2) ; get ClassNN and hWindow
    actWin := WinExist("A")

    if (Ctrl_FollowMouse) {
        curWin := msWin, curCtrl := msCtrl
        if curWin
            lastTargetWin := curWin, lastTargetCtrl := curCtrl
    } else {
        if (actWin != oGui.hwnd) {
            curWin := actWin
            curCtrl := ControlGetFocus()
            lastTargetWin := curWin
            lastTargetCtrl := curCtrl
        } else {
            curWin := lastTargetWin
            curCtrl := lastTargetCtrl
        }
    }

    if !curWin || !WinExist("ahk_id " curWin)
        return

    curCtrlClassNN := ""
    try curCtrlClassNN := ControlGetClassNN(curCtrl)

    t1 := WinGetTitle("ahk_id " curWin), t2 := WinGetClass("ahk_id " curWin)
    if (curWin = oGui.hwnd || t2 = "MultitaskingViewFrame") { ; Our Gui || Alt-tab
        UpdateText("Ctrl_Freeze", txtFrozen)
        return
    }

    module := oGui["Ctrl_ModuleSelect"].Value
    if IsNumber(module)
        module := moduleOptions[module]
    UpdateText("Ctrl_Freeze", txtNotFrozen)
    t3 := WinGetProcessName()

    moduleText := ""
    switch module {
        case "WindowInfo":
            moduleText := "Title: " WinGetTitle("ahk_id " curWin) "`n"
            . "ahk_class " WinGetClass("ahk_id " curWin) "`n"
            . "ahk_exe " t3
        case "ClassNN":
            moduleText := GetControlClassNNText(curWin, curCtrl)
        case "AllClassNN":
            moduleText := GetWindowAllClassNNText(curWin, false)
        case "BorderInfo":
            moduleText := GetWindowBorderInfo(curWin)
        case "StyleInfo":
            Style := WinGetStyle("ahk_id " curWin)
            moduleText := GetWindowStyleInfo(Style)
    }

    UpdateText("Ctrl_Content", moduleText)
}

; Unlike using a pure GuiControl, this function causes the text of the
; controls to be updated only when the text has changed, preventing periodic
; flickering (especially on older systems).

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

suspend_timer() {
    global oGui
    SetTimer Update, 0
    UpdateText("Ctrl_Freeze", txtFrozen)
}

~*Shift::
~*Ctrl:: suspend_timer()

~*Ctrl up::
~*Shift up:: SetTimer Update, 250