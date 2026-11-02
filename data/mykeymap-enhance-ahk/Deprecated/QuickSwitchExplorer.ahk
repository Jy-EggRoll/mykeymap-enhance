#Requires AutoHotkey v2.0

class QuickSwitchExplorerDebug {
    static mode := true
}

LogInfo("QuickSwitchExplorer 脚本已加载", , QuickSwitchExplorerDebug.mode)

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

    ; 临时数组用于存放抓取到的路径，以便后续反转顺序
    folderList := []

    try {
        ; 通过 COM 获取所有资源管理器窗口路径
        shellWindows := ComObject("Shell.Application").Windows
        for window in shellWindows {
            try {
                folder := window.Document.Folder.Self.Path
                ; 仅允许以驱动器盘符或网络共享路径开头的路径
                if (folder && (RegExMatch(folder, "S)^.:\\") || RegExMatch(folder, "S)^\\\\"))) {
                    ; 数组去重检查
                    isDup := false
                    for addedPath in folderList {
                        if (addedPath = folder) {
                            isDup := true
                            break
                        }
                    }
                    if (!isDup)
                        folderList.Push(folder)
                }
            }
        }

        idx := folderList.Length
        while (idx > 0) {
            QuickSwitchAddItem(folderList[idx], "shell32.dll", 5)
            idx--
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

    hwnd := targetDialogHwnd
    edit1Control := 0  ; 文件输入控件，老控件
    edit2Control := 0  ; 地址输入控件，必须先激活
    toolBarWindow323Control := 0  ; Edit2 的外层封装

    ; 重新激活目标对话框
    WinActivate hwnd
    if !WinWaitActive(hwnd, , 1) {
        LogWarn("激活失败，请重新点击一次窗口", , QuickSwitchExplorerDebug.mode)
        return
    }

    ; 仅处理本地路径或标准网络共享路径
    if (RegExMatch(folderPath, "S)^.:\\") || RegExMatch(folderPath, "S)^\\\\")) {
        try {
            try {
                edit1Control := ControlGetHwnd("Edit1", hwnd)
            } catch Error as e {
                LogWarn("Edit1 控件获取失败，可能是因为对话框类型不同", , QuickSwitchExplorerDebug.mode)
                LogError(e, , QuickSwitchExplorerDebug.mode)
            }
            try {
                toolBarWindow323Control := ControlGetHwnd("ToolbarWindow323", hwnd)
            } catch {
                LogWarn("ToolbarWindow323 获取失败，这可能不是一个现代化的资源管理器窗口", , QuickSwitchExplorerDebug.mode)
            }
            if (toolBarWindow323Control != 0) {
                try {
                    LogInfo("尝试激活地址栏以获取 Edit2 控件", , QuickSwitchExplorerDebug.mode)
                    w := 0, h := 0
                    ControlGetPos(, , &w, &h, "ToolbarWindow323", hwnd)
                    ControlClick("ToolbarWindow323", hwnd, , "Left", 1, "x" . w . " y" . h)  ; 实际点击了控件的最右下角，激活率几乎 100% 且不会误触其他按钮
                    LogInfo("已发送点击指令以激活地址栏", , QuickSwitchExplorerDebug.mode)
                    Sleep 100  ; 尝试延长等待时间，加强 Edit2 出现的稳定性
                    LogInfo("尝试获取 Edit2 控件", , QuickSwitchExplorerDebug.mode)
                    edit2Control := ControlGetHwnd("Edit2", hwnd)
                } catch {
                    LogWarn("Edit2 控件获取失败，可能是因为对话框类型不同或地址栏未正确激活", , QuickSwitchExplorerDebug.mode)
                }
            }
            if (edit2Control != 0) {
                LogInfo("成功获取 Edit2 控件，准备注入路径 " . folderPath, , QuickSwitchExplorerDebug.mode)
                ControlSetText(folderPath, edit2Control, hwnd)
                Sleep 50
                LogInfo("路径设置完成，准备注入回车指令", , QuickSwitchExplorerDebug.mode)
                ControlSend("{Enter}", edit2Control, hwnd)
                LogInfo("跳转指令完成 " . folderPath, , QuickSwitchExplorerDebug.mode)
                ToolTip("跳转成功")
                SetTimer(ToolTip, -2000)
            } else if (edit1Control != 0) {
                LogInfo("此窗口似乎只有 Edit1", , QuickSwitchExplorerDebug.mode)
                Sleep 50
                ControlSetText(folderPath, edit1Control, hwnd)
                LogInfo("普通路径设置完成 " . folderPath, , QuickSwitchExplorerDebug.mode)
                ToolTip("路径设置完成，可以直接点确定或回车")
                SetTimer(ToolTip, -2000)
            } else {
                LogWarn("未找到可用的路径输入控件", , QuickSwitchExplorerDebug.mode)
                ToolTip("无法跳转：未找到 Edit2 或 Edit1")
                SetTimer(ToolTip, -2000)
            }
        } catch Error as e {
            LogError(e, , QuickSwitchExplorerDebug.mode)
        }
    }
}

IsSpecificControlUnderMouse(Name) {
    MouseGetPos(, , , &ctrl)
    return ctrl = Name
}

/**
 * 在 DirectUIHWND1 或 Static2 上右键点击时触发菜单
 * 这些控件通常存在于 Windows 10/11 的资源管理器和文件对话框中
 */
#HotIf WinActive("ahk_class #32770") && (IsSpecificControlUnderMouse("DirectUIHWND1") || IsSpecificControlUnderMouse(
    "Static2"))
RButton::
{
    QuickSwitchExplorer()
}
; HotIf 在读到另一个 HotIf 时，状态会被重置
#HotIf

/**
 * 在打开/保存对话框激活时，按下 Tab 键也能触发菜单，直接拦截 Tab 的默认行为
 */
#HotIf WinActive("ahk_class #32770")  ; 仅在打开/保存对话框激活时有效
$Tab::
{
    QuickSwitchExplorer()
}
#HotIf