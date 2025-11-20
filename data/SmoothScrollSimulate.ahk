#Requires AutoHotkey v2.0

LastMouseX := 0
LastMouseY := 0

; 滚轮消息发送函数，在大多数软件中有效，部分软件无效，如文件资源管理器
PostMW(deltay, deltax := 0) {
    MouseGetPos(&x, &y, &id, &control)

    ; 计算修饰键状态
    Modifiers := 0x8 * (GetKeyState("Ctrl") ? 1 : 0)
    | 0x1 * (GetKeyState("LButton") ? 1 : 0)
    | 0x10 * (GetKeyState("MButton") ? 1 : 0)
    | 0x2 * (GetKeyState("RButton") ? 1 : 0)
    | 0x4 * (GetKeyState("Shift") ? 1 : 0)
    | 0x20 * (GetKeyState("XButton1") ? 1 : 0)
    | 0x40 * (GetKeyState("XButton2") ? 1 : 0)

    if (deltay != 0) {
        PostMessage(0x20A, deltay << 16 | Modifiers, y << 16 | x, , "ahk_id " id)
    }
    if (deltax != 0) {
        PostMessage(0x20E, deltax << 16 | Modifiers, y << 16 | x, , "ahk_id " id)
    }
}

; 精确滚动函数
SmoothScrollSimulate() {
    global LastMouseX, LastMouseY

    MouseGetPos(&startX, &startY)
    LastMouseX := startX
    LastMouseY := startY

    try {
        ; 持续跟随直到右键释放
        while (GetKeyState("RButton", "P")) {
            MouseGetPos(&currentX, &currentY)

            deltaX := currentX - LastMouseX
            deltaY := currentY - LastMouseY

            if (Abs(deltaX) >= 1 || Abs(deltaY) >= 1) {
                ; Y轴移动控制垂直滚动
                if (Abs(deltaY) >= 1) {
                    PostMW(deltaY)
                }
                ; X轴移动控制水平滚动
                if (Abs(deltaX) >= 1) {
                    PostMW(0, -deltaX)  ;使水平方向滚动也和直觉一致
                }

                LastMouseX := currentX
                LastMouseY := currentY
            }

            Sleep(10)  ; 添加适当延时控制响应频率
        }
    } catch Error as e {
        LogError(e, , DEBUGMODE)
    }
}
