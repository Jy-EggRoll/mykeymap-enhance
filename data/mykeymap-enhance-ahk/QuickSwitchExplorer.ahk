#Requires AutoHotkey v2.0

class QuickSwitchExplorerDebug {
    static mode := true
}

#Include ./LoggerLib/Logger.ahk

global QuickSwitchMenu := Menu()
global quickSwitchItemMap := Map()
global quickSwitchItemNum := 0
global targetDialogHwnd := 0

/**
 * 主功能：获取资源管理器路径并弹出菜单
 */
QuickSwitchExplorer() {
    global

    try {
        ; 检查当前是否为标准 Windows 对话框 (Class #32770)
        if (WinGetClass("A") != "#32770") {
            ToolTip("仅在打开/保存对话框是焦点时可调用")
            SetTimer(ToolTip, -2000)
            return
        }
    } catch Error as e {
        LogError(e, , QuickSwitchExplorerDebug.mode)
        return
    }

    ; 锁定当前对话框句柄，防止菜单弹出时失去焦点
    targetDialogHwnd := WinExist("A")

    ; 重置菜单状态
    quickSwitchItemNum := 0
    quickSwitchItemMap := Map()
    QuickSwitchMenu := Menu()

    try {
        ; 通过 COM 获取所有资源管理器窗口路径
        shellWindows := ComObject("Shell.Application").Windows
        for window in shellWindows {
            try {
                folder := window.Document.Folder.Self.Path
                ; 仅允许以驱动器盘符（如 C:\）或网络共享路径（如 \\）开头的路径
                if (folder && (RegExMatch(folder, "S)^.:\\") || RegExMatch(folder, "S)^\\\\"))) {
                    if (!quickSwitchItemMap.Has(folder)) {
                        QuickSwitchAddItem(folder, "shell32.dll", 5)
                    }
                }
            }
        }

        if (quickSwitchItemMap.Count > 0) {
            QuickSwitchMenu.Add() ; 添加分割线
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

/**
 * 向菜单中添加文件夹项
 */
QuickSwitchAddItem(folder, menuIcon, menuIconNum := 1) {
    global
    quickSwitchItemNum += 1
    itemLabel := "&" . quickSwitchItemNum . "  " . folder
    QuickSwitchMenu.Add(itemLabel, QuickSwitchNavigateWrapper)
    QuickSwitchMenu.SetIcon(itemLabel, menuIcon, menuIconNum)
    quickSwitchItemMap[folder] := itemLabel
}

/**
 * 菜单回调包装器：提取路径并执行跳转
 */
QuickSwitchNavigateWrapper(ItemName, ItemPos, MyMenu) {
    ; 正则去除前缀的 "&1 " 等快捷键标识
    folderPath := RegExReplace(ItemName, "S)^&\d+  ")
    QuickSwitchNavigate(folderPath)
    QuickSwitchMenu.Delete()
}

/**
 * 核心执行：操作对话框跳转路径
 */
QuickSwitchNavigate(folderPath) {
    global targetDialogHwnd

    if (targetDialogHwnd = 0) {
        targetDialogHwnd := WinExist("A")
    }

    hwnd := "ahk_id " . targetDialogHwnd

    ; 重新激活目标对话框
    WinActivate hwnd
    if !WinWaitActive(hwnd, , 1) {
        LogError("激活失败", , QuickSwitchExplorerDebug.mode)
        return
    }

    ; 仅处理本地路径或标准网络共享路径
    if (RegExMatch(folderPath, "S)^.:\\") || RegExMatch(folderPath, "S)^\\\\")) {
        SendInput("^l")          ; 聚焦地址栏
        Sleep 50                 ; 等待 UI 响应
        loop 10 {
            count := 0
            edit2Control := 0
            try {
                controls := WinGetControls(hwnd)
                controlsList := ""
                for ctrl in controls {
                    controlsList .= ctrl . "`n"
                    if (ctrl == "Edit2") {
                        edit2Control := ControlGetHwnd(ctrl)
                    }
                }
                count++
                if (edit2Control != 0) {
                    LogInfo("经过" . count . "次，成功获取到了可输入的 Edit2 " . edit2Control, , QuickSwitchExplorerDebug.mode)
                    ; LogInfo(controlsList, , QuickSwitchExplorerDebug.mode)
                    break
                }
                Sleep 50
            }
        }
        ControlSetText(folderPath, edit2Control, hwnd)
        Sleep 50
        ControlSend("{Enter}", edit2Control, hwnd)
        LogInfo("跳转指令完成 " . folderPath, , QuickSwitchExplorerDebug.mode)
    }
}
