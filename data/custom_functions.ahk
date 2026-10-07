; 自定义的函数写在这个文件里，然后能在 MyKeymap 中调用

; 使用如下写法，来加载当前目录下的其他 AutoHotKey v2 脚本
; #Include ../data/test.ahk

OnMessage(0x007E, WM_DISPLAYCHANGE_Handler)

WM_DISPLAYCHANGE_Handler(wParam, lParam, msg, hwnd) {
    SetTimer(MyKeymapReload, -5000)  ; 显示器变化后 5 秒重新加载 MyKeymap 脚本，确保显示的稳定
    ; 这里不能写 return 0：OnMessage 回调返回整数会被立刻当作消息回复，
    ; 消息不再继续处理，注册在同一消息号上的其他回调（包括宿主 MyKeymap 的）会被挡掉；
    ; 裸 return 返回空值，消息照常往下传递。
    return
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

; 自启动项（所有自启动函数统一在此调用，确保每个只执行一次）
AutoActivateWindow()
AutoWindowColorBorder()
