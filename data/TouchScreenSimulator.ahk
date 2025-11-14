#Requires AutoHotkey 2.0

; ============= 全局变量 =============
PreciseScrollMode := false  ; 精确滚动模式状态
UsePrecisionTouchpad := false  ; 是否使用精确触摸板模式
UsePointerAPI := true       ; 是否优先使用Pointer API
LastMouseX := 0
LastMouseY := 0
GestureStartTime := 0
GestureDistance := 0

; ============= 精确触摸板物理模拟变量 =============
; 惯性系统
VelocityX := 0.0          ; X轴速度
VelocityY := 0.0          ; Y轴速度
LastVelocityX := 0.0      ; 上次X轴速度
LastVelocityY := 0.0      ; 上次Y轴速度
AccelerationX := 0.0      ; X轴加速度
AccelerationY := 0.0      ; Y轴加速度

; 物理参数
Friction := 0.85          ; 摩擦系数 (0-1, 越小摩擦越大)
MinVelocity := 0.1        ; 最小速度阈值
MaxVelocity := 50.0       ; 最大速度限制
InertiaDecay := 0.95      ; 惯性衰减系数
TouchSensitivity := 1.2   ; 触摸灵敏度
MomentumThreshold := 5.0  ; 动量滚动触发阈值

; 高级手势检测
ContactTime := 0          ; 接触时间
ContactPressure := 0.0    ; 模拟接触压力
ContactArea := 0.0        ; 接触面积
IsMultiTouch := false     ; 是否多点触控
GestureType := ""         ; 手势类型: "scroll", "pan", "zoom", "flick"

; 时间和采样
LastSampleTime := 0       ; 上次采样时间
SampleHistory := []       ; 位置历史记录 (用于计算速度曲线)
MaxHistorySize := 10      ; 历史记录最大长度

PostMW(deltay, deltax := 0) {
    MouseGetPos(&x, &y, &id, &control)  ; 获取鼠标所在窗口ID（2.0中使用引用传递变量）

    ; 计算修饰键状态（2.0中GetKeyState返回布尔值，需转换为1/0）
    Modifiers := 0x8 * (GetKeyState("Ctrl") ? 1 : 0)
    | 0x1 * (GetKeyState("LButton") ? 1 : 0)
    | 0x10 * (GetKeyState("MButton") ? 1 : 0)
    | 0x2 * (GetKeyState("RButton") ? 1 : 0)
    | 0x4 * (GetKeyState("Shift") ? 1 : 0)
    | 0x20 * (GetKeyState("XButton1") ? 1 : 0)
    | 0x40 * (GetKeyState("XButton2") ? 1 : 0)

    if (deltay != 0) {
        ; 2.0中PostMessage为函数形式，窗口标题使用字符串拼接
        PostMessage(0x20A, deltay << 16 | Modifiers, y << 16 | x, , "ahk_id " id)
    }
    if (deltax != 0) {
        PostMessage(0x20E, deltax << 16 | Modifiers, y << 16 | x, , "ahk_id " id)
    }
}

; ============= 精确滚动函数 =============
PreciseScrollFollow() {
    global PreciseScrollMode, LastMouseX, LastMouseY, UsePointerAPI, UsePrecisionTouchpad

    ; 根据设置选择模式
    if (UsePrecisionTouchpad) {
        PrecisionTouchpadFollow()
    } else if (UsePointerAPI) {
        PreciseScrollFollowPointer()
    } else {
        PreciseScrollFollowWheel()
    }
}

; ============= 精确触摸板模拟 =============
PrecisionTouchpadFollow() {
    global PreciseScrollMode, LastMouseX, LastMouseY, GestureStartTime, GestureDistance

    ; 获取初始位置
    MouseGetPos(&startX, &startY)
    LastMouseX := startX
    LastMouseY := startY
    GestureStartTime := A_TickCount
    GestureDistance := 0

    ; 检查触摸板参数支持
    try {
        ; 尝试检查系统是否支持精确触摸板设置
        touchpadParams := Buffer(128, 0)  ; TOUCHPAD_PARAMETERS 结构大小
        NumPut("UInt", 1, touchpadParams, 0)  ; versionNumber = TOUCHPAD_PARAMETERS_VERSION_1

        ; 尝试获取当前触摸板参数
        if (DllCall("user32.dll\SystemParametersInfoW", "UInt", 0x010C, "UInt", 128, "Ptr", touchpadParams.Ptr, "UInt",
            0)) {
            ; 系统支持精确触摸板，使用高级手势识别
            PrecisionTouchpadAdvanced(startX, startY)
        } else {
            ; 回退到基本触摸板模拟
            PrecisionTouchpadBasic(startX, startY)
        }
    } catch {
        ; API不可用，使用基本模拟
        PrecisionTouchpadBasic(startX, startY)
    }
}

; 高级精确触摸板模拟
PrecisionTouchpadAdvanced(startX, startY) {
    global PreciseScrollMode, LastMouseX, LastMouseY, GestureDistance

    ; 配置触摸板预测参数
    try {
        predictionParams := Buffer(16, 0)  ; TOUCHPREDICTIONPARAMETERS 结构
        NumPut("UInt", 16, predictionParams, 0)    ; cbSize
        NumPut("UInt", 8, predictionParams, 4)     ; dwLatency = 8ms (低延迟)
        NumPut("UInt", 16, predictionParams, 8)    ; dwSampleTime = 16ms
        NumPut("UInt", 1, predictionParams, 12)    ; bUseHWTimeStamp = true

        ; 应用预测参数以获得更流畅的体验
        DllCall("user32.dll\SetTouchPredictionParameters", "Ptr", predictionParams.Ptr)
    }

    ; 精确触摸板手势检测
    velocity := 0
    lastVelocity := 0
    smoothFactor := 0.7  ; 平滑因子

    ; 持续跟随直到右键释放
    while (GetKeyState("RButton", "P") && PreciseScrollMode) {
        MouseGetPos(&currentX, &currentY)

        ; 计算移动差值和速度
        deltaX := currentX - LastMouseX
        deltaY := currentY - LastMouseY
        deltaTime := 16  ; 假设16ms间隔

        ; 计算即时速度 (像素/秒)
        currentVelocity := Sqrt(deltaX * deltaX + deltaY * deltaY) / (deltaTime / 1000.0)

        ; 速度平滑处理
        velocity := smoothFactor * lastVelocity + (1 - smoothFactor) * currentVelocity
        lastVelocity := velocity

        ; 累计手势距离
        GestureDistance += Sqrt(deltaX * deltaX + deltaY * deltaY)

        ; 根据速度和距离进行智能手势识别
        if (Abs(deltaX) >= 1 || Abs(deltaY) >= 1) {
            ProcessPrecisionGesture(deltaX, deltaY, velocity, GestureDistance)
            LastMouseX := currentX
            LastMouseY := currentY
        }

        Sleep(8)  ; 高频率更新保持流畅性
    }
}

; 基本精确触摸板模拟
PrecisionTouchpadBasic(startX, startY) {
    global PreciseScrollMode, LastMouseX, LastMouseY

    ; 使用基本的手势识别逻辑
    while (GetKeyState("RButton", "P") && PreciseScrollMode) {
        MouseGetPos(&currentX, &currentY)

        deltaX := currentX - LastMouseX
        deltaY := currentY - LastMouseY

        if (Abs(deltaX) >= 1 || Abs(deltaY) >= 1) {
            ; 基本的滚动手势
            ProcessBasicGesture(deltaX, deltaY)
            LastMouseX := currentX
            LastMouseY := currentY
        }

        Sleep(5)
    }
}

; 处理精确手势
ProcessPrecisionGesture(deltaX, deltaY, velocity, totalDistance) {
    ; 动态调整灵敏度基于速度
    sensitivity := 1.0
    if (velocity > 100) {
        sensitivity := 2.0  ; 高速时增加灵敏度
    } else if (velocity < 20) {
        sensitivity := 0.5  ; 低速时减少灵敏度
    }

    ; 智能方向识别
    if (Abs(deltaY) > Abs(deltaX) * 1.5) {
        ; 主要垂直移动 - 垂直滚动
        scrollAmount := Round(deltaY * sensitivity)
        if (scrollAmount != 0) {
            PostMW(-scrollAmount)  ; 反转方向使其更直观
        }
    } else if (Abs(deltaX) > Abs(deltaY) * 1.5) {
        ; 主要水平移动 - 水平滚动
        scrollAmount := Round(deltaX * sensitivity)
        if (scrollAmount != 0) {
            PostMW(0, scrollAmount)
        }
    } else {
        ; 对角移动 - 混合滚动
        if (deltaY != 0) {
            PostMW(-Round(deltaY * sensitivity * 0.7))
        }
        if (deltaX != 0) {
            PostMW(0, Round(deltaX * sensitivity * 0.7))
        }
    }
}

; 处理基本手势
ProcessBasicGesture(deltaX, deltaY) {
    ; 简单的 1:1 映射
    if (deltaY != 0) {
        PostMW(-deltaY)
    }
    if (deltaX != 0) {
        PostMW(0, deltaX)
    }
}

; ============= Pointer API实现 =============
PreciseScrollFollowPointer() {
    global PreciseScrollMode, LastMouseX, LastMouseY

    ; 获取初始位置
    MouseGetPos(&startX, &startY)
    LastMouseX := startX
    LastMouseY := startY

    try {
        ; 检查是否支持触摸注入 API
        hUser32 := DllCall("LoadLibrary", "Str", "user32.dll", "Ptr")
        if (!DllCall("GetProcAddress", "Ptr", hUser32, "AStr", "InitializeTouchInjection", "Ptr")) {
            throw Error("TouchInjection API not supported")
        }

        ; 初始化触摸注入 (最多1个触摸点)
        maxTouches := 1
        if (!DllCall("user32.dll\InitializeTouchInjection", "UInt", maxTouches, "UInt", 0)) {
            throw Error("Failed to initialize touch injection")
        }

        ; 创建正确的 POINTER_TOUCH_INFO 结构
        ; POINTER_INFO (80字节) + TOUCH_FLAGS (4) + TOUCH_MASK (4) + RECT*2 (32) + orientation (4) + pressure (4) = 128字节
        touchInfo := Buffer(128, 0)

        ; === POINTER_INFO 部分 (前80字节) ===
        NumPut("UInt", 2, touchInfo, 0)        ; pointerType = PT_TOUCH (2)
        NumPut("UInt", 1, touchInfo, 4)        ; pointerId = 1
        NumPut("UInt", 1, touchInfo, 8)        ; frameId = 1
        NumPut("UInt", 0x1 | 0x4, touchInfo, 12)  ; pointerFlags = POINTER_FLAG_INCONTACT | POINTER_FLAG_FIRSTBUTTON
        NumPut("Ptr", 0, touchInfo, 16)        ; sourceDevice = NULL
        NumPut("Ptr", 0, touchInfo, 24)        ; hwndTarget = NULL (让系统决定)
        NumPut("Int", startX, touchInfo, 32)   ; ptPixelLocation.x
        NumPut("Int", startY, touchInfo, 36)   ; ptPixelLocation.y
        NumPut("Int", 0, touchInfo, 40)        ; ptHimetricLocation.x
        NumPut("Int", 0, touchInfo, 44)        ; ptHimetricLocation.y
        NumPut("Int", startX, touchInfo, 48)   ; ptPixelLocationRaw.x
        NumPut("Int", startY, touchInfo, 52)   ; ptPixelLocationRaw.y
        NumPut("Int", 0, touchInfo, 56)        ; ptHimetricLocationRaw.x
        NumPut("Int", 0, touchInfo, 60)        ; ptHimetricLocationRaw.y
        NumPut("UInt", 0, touchInfo, 64)       ; dwTime = 0 (自动时间戳)
        NumPut("UInt", 1, touchInfo, 68)       ; historyCount = 1
        NumPut("Int", 0, touchInfo, 72)        ; InputData = 0
        NumPut("UInt", 0, touchInfo, 76)       ; dwKeyStates = 0
        ; 剩余4字节: PerformanceCount 和 ButtonChangeType (设为0)

        ; === TOUCH 特定信息部分 (80字节后) ===
        NumPut("UInt", 0, touchInfo, 80)       ; touchFlags = 0
        NumPut("UInt", 0x1 | 0x2, touchInfo, 84)  ; touchMask = TOUCH_MASK_CONTACTAREA | TOUCH_MASK_ORIENTATION

        ; rcContact RECT (接触区域)
        contactSize := 10  ; 10像素接触区域
        NumPut("Int", startX - contactSize // 2, touchInfo, 88)   ; left
        NumPut("Int", startY - contactSize // 2, touchInfo, 92)   ; top
        NumPut("Int", startX + contactSize // 2, touchInfo, 96)   ; right
        NumPut("Int", startY + contactSize // 2, touchInfo, 100)  ; bottom

        ; rcContactRaw RECT (原始接触区域)
        NumPut("Int", startX - contactSize // 2, touchInfo, 104)  ; left
        NumPut("Int", startY - contactSize // 2, touchInfo, 108)  ; top
        NumPut("Int", startX + contactSize // 2, touchInfo, 112)  ; right
        NumPut("Int", startY + contactSize // 2, touchInfo, 116)  ; bottom

        NumPut("UInt", 0, touchInfo, 120)      ; orientation = 0
        NumPut("UInt", 512, touchInfo, 124)    ; pressure = 512 (默认中等压力)

        ; 注入触摸开始
        if (!DllCall("user32.dll\InjectTouchInput", "UInt", 1, "Ptr", touchInfo.Ptr)) {
            throw Error("Failed to inject touch start: " . A_LastError)
        }

        ; 持续跟随直到右键释放
        while (GetKeyState("RButton", "P") && PreciseScrollMode) {
            MouseGetPos(&currentX, &currentY)

            ; 计算移动差值
            deltaX := currentX - LastMouseX
            deltaY := currentY - LastMouseY

            ; 只有在实际移动时才发送更新
            if (Abs(deltaX) >= 2 || Abs(deltaY) >= 2) {
                ; 更新 POINTER_INFO 中的位置
                NumPut("Int", currentX, touchInfo, 32)   ; ptPixelLocation.x
                NumPut("Int", currentY, touchInfo, 36)   ; ptPixelLocation.y
                NumPut("Int", currentX, touchInfo, 48)   ; ptPixelLocationRaw.x
                NumPut("Int", currentY, touchInfo, 52)   ; ptPixelLocationRaw.y

                ; 更新接触区域
                NumPut("Int", currentX - contactSize // 2, touchInfo, 88)   ; rcContact.left
                NumPut("Int", currentY - contactSize // 2, touchInfo, 92)   ; rcContact.top
                NumPut("Int", currentX + contactSize // 2, touchInfo, 96)   ; rcContact.right
                NumPut("Int", currentY + contactSize // 2, touchInfo, 100)  ; rcContact.bottom

                NumPut("Int", currentX - contactSize // 2, touchInfo, 104)  ; rcContactRaw.left
                NumPut("Int", currentY - contactSize // 2, touchInfo, 108)  ; rcContactRaw.top
                NumPut("Int", currentX + contactSize // 2, touchInfo, 112)  ; rcContactRaw.right
                NumPut("Int", currentY + contactSize // 2, touchInfo, 116)  ; rcContactRaw.bottom

                ; 注入触摸移动
                DllCall("user32.dll\InjectTouchInput", "UInt", 1, "Ptr", touchInfo.Ptr)

                ; 更新位置
                LastMouseX := currentX
                LastMouseY := currentY
            }

            Sleep(8)
        }

        ; 注入触摸结束
        MouseGetPos(&endX, &endY)
        NumPut("UInt", 0x8, touchInfo, 12)     ; pointerFlags = POINTER_FLAG_UP
        NumPut("Int", endX, touchInfo, 32)     ; ptPixelLocation.x
        NumPut("Int", endY, touchInfo, 36)     ; ptPixelLocation.y
        NumPut("Int", endX, touchInfo, 48)     ; ptPixelLocationRaw.x
        NumPut("Int", endY, touchInfo, 52)     ; ptPixelLocationRaw.y

        DllCall("user32.dll\InjectTouchInput", "UInt", 1, "Ptr", touchInfo.Ptr)

    } catch Error as e {
        ; 如果触摸API失败，回退到滚轮模式
        PreciseScrollFollowWheel()
    }
}

; ============= 备用滚轮函数 =============
PreciseScrollFollowWheel() {
    global PreciseScrollMode, LastMouseX, LastMouseY

    ; 获取初始位置
    MouseGetPos(&startX, &startY)
    LastMouseX := startX
    LastMouseY := startY

    ; 持续跟随直到右键释放
    while (GetKeyState("RButton", "P") && PreciseScrollMode) {
        MouseGetPos(&currentX, &currentY)

        ; 计算移动差值
        deltaX := currentX - LastMouseX
        deltaY := currentY - LastMouseY

        ; 只有在实际移动时才执行滚动
        if (Abs(deltaX) >= 1 || Abs(deltaY) >= 1) {
            ; Y轴移动控制垂直滚动
            if (Abs(deltaY) >= 1) {
                PostMW(deltaY)
            }
            ; X轴移动控制水平滚动
            if (Abs(deltaX) >= 1) {
                PostMW(0, deltaX)
            }

            ; 更新位置
            LastMouseX := currentX
            LastMouseY := currentY
        }

        Sleep(1)  ; 降低延迟提高响应速度
    }
}

; ============= 热键定义 =============

; 启动/关闭精确滚动模式 (Ctrl + Alt + Z)
^!z:: {
    global PreciseScrollMode
    PreciseScrollMode := !PreciseScrollMode
}

; 切换精确触摸板模式 (Ctrl + Alt + P)
^!p:: {
    global UsePrecisionTouchpad
    UsePrecisionTouchpad := !UsePrecisionTouchpad
}

; 切换Pointer API模式 (Ctrl + Alt + X)
^!x:: {
    global UsePointerAPI
    UsePointerAPI := !UsePointerAPI
}

; 改用更可靠的右键处理方式
RButton:: {
    global PreciseScrollMode
    if (PreciseScrollMode) {
        ; 阻止默认右键行为
        PreciseScrollFollow()
    } else {
        ; 正常右键行为
        Send("{RButton}")
    }
}

; ============= 精确触摸板原生API实现 =============
PrecisionTouchpadNativeAPI() {
    global PreciseScrollMode, LastMouseX, LastMouseY

    ; 获取初始位置
    MouseGetPos(&startX, &startY)
    LastMouseX := startX
    LastMouseY := startY

    try {
        ; 检查Windows 10 1809+ 的Synthetic Pointer API支持
        hUser32 := DllCall("LoadLibrary", "Str", "user32.dll", "Ptr")
        pCreateSyntheticPointerDevice := DllCall("GetProcAddress", "Ptr", hUser32, "AStr",
            "CreateSyntheticPointerDevice", "Ptr")
        pInjectSyntheticPointerInput := DllCall("GetProcAddress", "Ptr", hUser32, "AStr", "InjectSyntheticPointerInput",
            "Ptr")

        if (!pCreateSyntheticPointerDevice || !pInjectSyntheticPointerInput) {
            throw Error("Synthetic Pointer API not available (需要Windows 10 1809+)")
        }

        ; 创建合成精确触摸板设备
        ; POINTER_INPUT_TYPE: PT_TOUCHPAD = 3
        ; POINTER_FEEDBACK_MODE: DEFAULT = 1
        hDevice := DllCall(pCreateSyntheticPointerDevice, "UInt", 3, "UInt", 2, "UInt", 1, "Ptr")

        if (!hDevice) {
            throw Error("Failed to create synthetic touchpad device: " . A_LastError)
        }

        ; 创建 POINTER_TOUCHPAD_INFO 结构 (Windows 10专用)
        ; 这是真正的精确触摸板结构，包含速度、手势等信息
        touchpadInfo := Buffer(160, 0)  ; 完整的POINTER_TOUCHPAD_INFO结构

        ; === POINTER_INFO 部分 (基础80字节) ===
        NumPut("UInt", 3, touchpadInfo, 0)        ; pointerType = PT_TOUCHPAD (3)
        NumPut("UInt", 1, touchpadInfo, 4)        ; pointerId = 1
        NumPut("UInt", 1, touchpadInfo, 8)        ; frameId = 1
        NumPut("UInt", 0x1 | 0x4, touchpadInfo, 12)  ; POINTER_FLAG_INCONTACT | POINTER_FLAG_FIRSTBUTTON
        NumPut("Ptr", hDevice, touchpadInfo, 16)  ; sourceDevice = 我们的合成设备
        NumPut("Ptr", 0, touchpadInfo, 24)        ; hwndTarget (让系统选择)
        NumPut("Int", startX, touchpadInfo, 32)   ; ptPixelLocation.x
        NumPut("Int", startY, touchpadInfo, 36)   ; ptPixelLocation.y
        NumPut("Int", 0, touchpadInfo, 40)        ; ptHimetricLocation
        NumPut("Int", 0, touchpadInfo, 44)
        NumPut("Int", startX, touchpadInfo, 48)   ; ptPixelLocationRaw
        NumPut("Int", startY, touchpadInfo, 52)
        NumPut("Int", 0, touchpadInfo, 56)        ; ptHimetricLocationRaw
        NumPut("Int", 0, touchpadInfo, 60)
        NumPut("UInt", 0, touchpadInfo, 64)       ; dwTime (自动)
        NumPut("UInt", 1, touchpadInfo, 68)       ; historyCount
        NumPut("Int", 0, touchpadInfo, 72)        ; InputData
        NumPut("UInt", 0, touchpadInfo, 76)       ; dwKeyStates

        ; === TOUCHPAD 特定部分 (80字节后) ===
        NumPut("UInt", 0, touchpadInfo, 80)       ; touchpadFlags
        NumPut("UInt", 0x1 | 0x2 | 0x8, touchpadInfo, 84)  ; touchpadMask: CONTACT | ORIENTATION | VELOCITY

        ; 接触区域 (RECT)
        contactSize := 15
        NumPut("Int", startX - contactSize, touchpadInfo, 88)   ; rcContact
        NumPut("Int", startY - contactSize, touchpadInfo, 92)
        NumPut("Int", startX + contactSize, touchpadInfo, 96)
        NumPut("Int", startY + contactSize, touchpadInfo, 100)

        NumPut("Int", startX - contactSize, touchpadInfo, 104)  ; rcContactRaw
        NumPut("Int", startY - contactSize, touchpadInfo, 108)
        NumPut("Int", startX + contactSize, touchpadInfo, 112)
        NumPut("Int", startY + contactSize, touchpadInfo, 116)

        NumPut("UInt", 0, touchpadInfo, 120)      ; orientation
        NumPut("UInt", 512, touchpadInfo, 124)    ; pressure

        ; === 关键: 速度和手势信息 (128字节后) ===
        NumPut("Float", 0.0, touchpadInfo, 128)   ; velocityX (像素/秒)
        NumPut("Float", 0.0, touchpadInfo, 132)   ; velocityY (像素/秒)
        NumPut("UInt", 1, touchpadInfo, 136)      ; gestureType: SCROLL = 1
        NumPut("Float", 1.0, touchpadInfo, 140)   ; gestureScale
        NumPut("Float", 0.0, touchpadInfo, 144)   ; gestureAngle
        NumPut("UInt", 0, touchpadInfo, 148)      ; gestureFlags

        ; 注入触摸板开始
        result := DllCall(pInjectSyntheticPointerInput, "Ptr", hDevice, "Ptr", touchpadInfo.Ptr, "UInt", 1)
        if (!result) {
            throw Error("Failed to inject touchpad start: " . A_LastError)
        }

        ; 速度计算变量
        lastTime := A_TickCount
        velocityHistory := []

        ; 持续跟随，计算真实速度和加速度
        while (GetKeyState("RButton", "P") && PreciseScrollMode) {
            MouseGetPos(&currentX, &currentY)
            currentTime := A_TickCount
            deltaTime := (currentTime - lastTime) / 1000.0  ; 转换为秒

            if (deltaTime > 0) {
                ; 计算移动差值
                deltaX := currentX - LastMouseX
                deltaY := currentY - LastMouseY

                if (Abs(deltaX) >= 1 || Abs(deltaY) >= 1) {
                    ; 计算真实速度 (像素/秒)
                    velocityX := deltaX / deltaTime
                    velocityY := deltaY / deltaTime

                    ; 速度历史记录用于平滑
                    velocityHistory.Push({ vx: velocityX, vy: velocityY, time: currentTime })
                    if (velocityHistory.Length > 5) {
                        velocityHistory.RemoveAt(1)
                    }

                    ; 计算平均速度
                    avgVelX := 0, avgVelY := 0
                    for entry in velocityHistory {
                        avgVelX += entry.vx
                        avgVelY += entry.vy
                    }
                    avgVelX /= velocityHistory.Length
                    avgVelY /= velocityHistory.Length

                    ; 更新触摸板信息
                    NumPut("Int", currentX, touchpadInfo, 32)     ; 位置
                    NumPut("Int", currentY, touchpadInfo, 36)
                    NumPut("Int", currentX, touchpadInfo, 48)     ; 原始位置
                    NumPut("Int", currentY, touchpadInfo, 52)

                    ; 更新接触区域
                    NumPut("Int", currentX - contactSize, touchpadInfo, 88)
                    NumPut("Int", currentY - contactSize, touchpadInfo, 92)
                    NumPut("Int", currentX + contactSize, touchpadInfo, 96)
                    NumPut("Int", currentY + contactSize, touchpadInfo, 100)

                    ; 关键: 更新速度信息 (这是精确触摸板的核心!)
                    NumPut("Float", avgVelX, touchpadInfo, 128)   ; velocityX
                    NumPut("Float", avgVelY, touchpadInfo, 132)   ; velocityY

                    ; 根据速度确定手势类型
                    speed := Sqrt(avgVelX * avgVelX + avgVelY * avgVelY)
                    if (speed > 100) {
                        NumPut("UInt", 2, touchpadInfo, 136)     ; FLICK gesture
                    } else {
                        NumPut("UInt", 1, touchpadInfo, 136)     ; SCROLL gesture
                    }

                    ; 注入触摸板移动 (带速度信息)
                    DllCall(pInjectSyntheticPointerInput, "Ptr", hDevice, "Ptr", touchpadInfo.Ptr, "UInt", 1)

                    LastMouseX := currentX
                    LastMouseY := currentY
                    lastTime := currentTime
                }
            }

            Sleep(5)  ; 高频更新保持流畅
        }

        ; 注入触摸板结束 (可能触发惯性滚动!)
        MouseGetPos(&endX, &endY)
        NumPut("UInt", 0x8, touchpadInfo, 12)     ; POINTER_FLAG_UP
        NumPut("Int", endX, touchpadInfo, 32)
        NumPut("Int", endY, touchpadInfo, 36)

        ; 计算最终速度用于惯性
        if (velocityHistory.Length >= 2) {
            lastEntry := velocityHistory[velocityHistory.Length]
            NumPut("Float", lastEntry.vx, touchpadInfo, 128)
            NumPut("Float", lastEntry.vy, touchpadInfo, 132)

            ; 如果速度足够大，标记为FLICK以触发惯性
            finalSpeed := Sqrt(lastEntry.vx * lastEntry.vx + lastEntry.vy * lastEntry.vy)
            if (finalSpeed > 50) {
                NumPut("UInt", 2, touchpadInfo, 136)  ; FLICK - 系统应该继续惯性滚动
            }
        }

        DllCall(pInjectSyntheticPointerInput, "Ptr", hDevice, "Ptr", touchpadInfo.Ptr, "UInt", 1)

        ; 清理设备
        DllCall("user32.dll\DestroySyntheticPointerDevice", "Ptr", hDevice)

    } catch Error as e {
        ; 回退到基本滚轮
        PreciseScrollFollowWheel()
    }
}
