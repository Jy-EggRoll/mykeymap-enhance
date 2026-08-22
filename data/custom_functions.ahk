; 自定义的函数写在这个文件里，然后能在 MyKeymap 中调用

; 使用如下写法，来加载当前目录下的其他 AutoHotKey v2 脚本
; #Include ../data/test.ahk

OnMessage(0x007E, WM_DISPLAYCHANGE_Handler)

WM_DISPLAYCHANGE_Handler(wParam, lParam, msg, hwnd) {
    SetTimer(MyKeymapReload, -5000)  ; 显示器变化后 5 秒重新加载 MyKeymap 脚本，确保显示的稳定
    return 0
}

#Include ../data/mykeymap-enhance-ahk/AutoActivateWindow.ahk
#Include ../data/mykeymap-enhance-ahk/DragAndResizeWindow.ahk
#Include ../data/mykeymap-enhance-ahk/PerResizeWindow.ahk
#Include ../data/mykeymap-enhance-ahk/ChangeBrightness.ahk
#Include ../data/mykeymap-enhance-ahk/AutoWindowColorBorder.ahk
#Include ../data/mykeymap-enhance-ahk/SmoothScrollSimulate.ahk
#Include ../data/mykeymap-enhance-ahk/BlockSend.ahk
#Include ../data/mykeymap-enhance-ahk/ReadFileToInput.ahk
#Include ../data/mykeymap-enhance-ahk/SetTaskbarCombine.ahk
#Include ../data/mykeymap-enhance-ahk/WindowJump.ahk

; 自启动项（所有自启动函数统一在此调用，确保每个只执行一次）
AutoActivateWindow()
AutoWindowColorBorder()

; 全局特殊热键绑定
; Alt 双击触发
global altIsPressed := false
global lastAltPressTime := 0

~Alt:: {
    global altIsPressed, lastAltPressTime
    if (altIsPressed)
        return
    altIsPressed := true
    if (lastAltPressTime
        && A_TickCount - lastAltPressTime <= 250
        && InStr(A_PriorKey, "Alt")) {
        WindowJump()
        lastAltPressTime := 0
    } else {
        lastAltPressTime := A_TickCount
    }
}

~Alt Up:: {
    global altIsPressed
    altIsPressed := false
}

; 全局特殊热键绑定
; Ctrl 双击触发
global ctrlIsPressed := false
global lastCtrlPressTime := 0

~Ctrl:: {
    global ctrlIsPressed, lastCtrlPressTime
    if (ctrlIsPressed)
        return
    ctrlIsPressed := true
    if (lastCtrlPressTime
        && A_TickCount - lastCtrlPressTime <= 250
        && InStr(A_PriorKey, "Control")) {
        Send("#!z")
        lastCtrlPressTime := 0
    } else {
        lastCtrlPressTime := A_TickCount
    }
}

~Ctrl Up:: {
    global ctrlIsPressed
    ctrlIsPressed := false
}
