#Requires AutoHotkey v2.0

class QuickSwitchExplorerDebug {
    static mode := false
}

#Include ./LoggerLib/Logger.ahk
#Include ./BlockSend.ahk

global QuickSwitchMenu
global quickSwitchItemMap := Map()
global quickSwitchItemNum := 0
global targetDialogHwnd := 0

QuickSwitchExplorer() {
    global

    try {
        if (WinGetClass("A") != "#32770") {
            ToolTip("仅在打开/保存对话框中可用")
            SetTimer(ToolTip, -2000)
            return
        }
    } catch Error as e {
        LogError(e, , QuickSwitchExplorerDebug.mode)
    }

    targetDialogHwnd := WinExist("A")

    quickSwitchItemNum := 0
    quickSwitchItemMap := Map()

    QuickSwitchMenu := Menu()

    try {
        shellWindows := ComObject("Shell.Application").Windows
        for window in shellWindows {
            try folder := window.Document.Folder.Self.Path
            if (folder && !quickSwitchItemMap.Has(folder)) {
                QuickSwitchAddItem(folder, "shell32.dll", 5)
            }
        }
        if (quickSwitchItemMap.Count > 0) {
            QuickSwitchMenu.Add()
        }
    } catch as e {
        ToolTip("无法获取资源管理器路径")
        SetTimer(ToolTip, -2000)
    }

    if (quickSwitchItemMap.Count == 0) {
        ToolTip("未找到已打开的资源管理器窗口")
        SetTimer(ToolTip, -2000)
        return
    }

    QuickSwitchMenu.Show()
}

QuickSwitchAddItem(folder, menuIcon, menuIconNum := 1) {
    global
    quickSwitchItemNum += 1
    itemLabel := "&" . quickSwitchItemNum . " " . folder
    QuickSwitchMenu.Add(itemLabel, QuickSwitchNavigateWrapper)
    QuickSwitchMenu.SetIcon(itemLabel, menuIcon, menuIconNum)
    quickSwitchItemMap[folder] := itemLabel
}

QuickSwitchNavigateWrapper(ItemName, ItemPos, MyMenu) {
    folderPath := RegExReplace(ItemName, "S)^&\d+ ")
    QuickSwitchNavigate(folderPath)
    QuickSwitchMenu.Delete()
}

QuickSwitchNavigate(folderPath) {
    global targetDialogHwnd

    ; 使用保存的窗口句柄
    if (targetDialogHwnd = 0) {
        targetDialogHwnd := WinExist("A")
    }

    hwnd := "ahk_id " . targetDialogHwnd

    ; 激活
    WinActivate hwnd
    Sleep 100
    if (RegExMatch(folderPath, "S)^.:\\") || RegExMatch(folderPath, "S)^\\\\file")) {
        SendInput("!d")
        Sleep 100
        SendInput("^a")
        Sleep 100
        SendInput("{Backspace}")
        Sleep 100
        BSend(folderPath)
        LogInfo("发送了" . folderPath, , QuickSwitchExplorerDebug.mode)
        Sleep 100
        SendInput("{Enter}")
        LogInfo("完成", , QuickSwitchExplorerDebug.mode)
    }
}

ControlExist(control, winTitle := "A") {
    try {
        ControlGetText "", control, winTitle
        return true
    }
    return false
}

QuickSwitchGetProcessPath(exeName) {
    try {
        if (WinExist("ahk_exe " . exeName)) {
            return WinGetProcessPath("ahk_exe " . exeName)
        }
    }
    return ""
}
