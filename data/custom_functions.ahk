; 自定义函数写在此文件，之后可在 MyKeymap 中调用

; 加载其他 AutoHotkey v2 脚本时按下面的写法，加载进来的函数同样可被调用
; #Include ../data/test.ahk

OnMessage(0x007E, WM_DISPLAYCHANGE_Handler)

WM_DISPLAYCHANGE_Handler(wParam, lParam, msg, hwnd) {
    ; 显示器切换后系统还要重新排布窗口，先等 5 秒再重载，避免重载时显示器仍在变化
    SetTimer(MyKeymapReload, -5000)
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
#Include ../data/mykeymap-enhance-ahk/SetTaskbarCombine.ahk

; 需要随机启动的功能集中在此调用，保证每项只启动一次
AutoActivateWindow()
AutoWindowColorBorder()
