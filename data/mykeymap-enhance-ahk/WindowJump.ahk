; ==============================================================================
; WindowJump.ahk - 窗口快速跳转工具
; ==============================================================================
; 功能：通过模糊搜索快速切换窗口，支持中文拼音首字母匹配
; 依赖：AutoHotkey v2.0+
; 作者：EggRoll
; ==============================================================================

#Include ./LoggerLib/Logger.ahk
#Include ./AutoActivateWindow.ahk
#Include ./VD.ahk

class WindowJumpDebug {
    static mode := false
}

; #Requires AutoHotkey v2.0
; 强制脚本只能运行一个实例，如果已存在则替换
; #SingleInstance Force

; ==============================================================================
; 引入拼音库
; ==============================================================================
#Include ../mykeymap-enhance-ahk/PinYinLib/IbPinyin.ahk

; ==============================================================================
; 快捷方式管理
; ==============================================================================

; shortcutsDir 全局变量
global shortcutsDir := ""

; 初始化快捷方式目录
InitShortcuts() {
    static initialized := false

    if initialized {
        return
    }
    initialized := true

    global shortcutsDir
    shortcutsDir := A_Temp "\WindowJump_Shortcuts"

    LogInfo("初始化快捷方式目录：" . shortcutsDir, , WindowJumpDebug.mode)

    if DirExist(shortcutsDir) {
        loop files, shortcutsDir "\*", "FD" {
            try FileDelete(A_LoopFileFullPath)
        }
    } else {
        DirCreate(shortcutsDir)
    }

    try {
        if DirExist(A_ProgramsCommon) {
            FileCopy(A_ProgramsCommon "\*.lnk", shortcutsDir "\", true)
        }
        if DirExist(A_Programs) {
            FileCopy(A_Programs "\*.lnk", shortcutsDir "\", true)
        }
    }

    try {
        oFolder := ComObject("Shell.Application").NameSpace("shell:AppsFolder")
        if (Type(oFolder) != "String") {
            for item in oFolder.Items {
                shortcutPath := shortcutsDir "\" item.Name ".lnk"
                if !FileExist(shortcutPath) {
                    try FileCreateShortcut("shell:appsfolder\" item.Path, shortcutPath)
                }
            }
        }
    }

    LogInfo("快捷方式初始化完成", , WindowJumpDebug.mode)
}

; 运行脚本时立即执行一次，减少视觉闪烁
InitShortcuts()

; 获取快捷方式列表
GetShortcuts(&shortcuts) {
    global shortcutsDir
    shortcuts := []

    if !DirExist(shortcutsDir) {
        LogInfo("快捷方式目录不存在，初始化", , WindowJumpDebug.mode)
        InitShortcuts()
    }

    loop files, shortcutsDir "\*.lnk", "F" {
        try {
            name := StrReplace(A_LoopFileName, ".lnk", "")
            shortcuts.Push({ name: name, path: A_LoopFileFullPath })
        }
    }

    LogInfo("获取到 " . shortcuts.Length . " 个快捷方式", , WindowJumpDebug.mode)
}

; ==============================================================================
; 全局配置
; ==============================================================================

; 初始化主题（读取系统颜色设置）
UpdateTheme()

; ==============================================================================
; WindowJump 函数主入口
; ==============================================================================
; WindowJump()
; 窗口跳转主函数，创建搜索 GUI 并处理用户交互
; ==============================================================================

WindowJump() {
    ; 1. 更新主题颜色（根据系统深色/浅色模式和强调色动态生成 GUI 配色）
    UpdateTheme()

    ; 2. static 变量：保持 GUI 对象和图像列表句柄在函数调用间持久化
    ; MyGui: GUI 对象，0 表示尚未创建
    ; hIL: ImageList 句柄，用于存储窗口图标
    ; iconCache: 图标缓存 Map
    static MyGui := 0
    static hIL := 0
    static iconCache := Map()
    static shortcutCache := Map()
    static lastTheme := ""  ; 记录上一次的主题状态
    static lastAccent := ""  ; 记录上一次的强调色

    LogInfo("WindowJump 被调用", , WindowJumpDebug.mode)

    ; 3. 如果 GUI 已存在（复现窗口）
    if (MyGui) {
        global IsDarkMode, AccentColor
        ; 检查主题或强调色是否变化
        currentTheme := IsDarkMode ? "dark" : "light"
        currentAccent := AccentColor
        themeChanged := (lastTheme != "" && lastTheme != currentTheme)
        accentChanged := (lastAccent != "" && lastAccent != currentAccent)

        LogInfo("检查主题变化: lastTheme=" . lastTheme . " currentTheme=" . currentTheme . " lastAccent=" . lastAccent .
            " currentAccent=" . currentAccent, , WindowJumpDebug.mode)

        if (themeChanged || accentChanged) {
            LogInfo("主题变化(" . lastTheme . "->" . currentTheme . ")，强调色变化(" . lastAccent . "->" . currentAccent .
                ")，销毁并重建 GUI", , WindowJumpDebug.mode)
            MyGui.Destroy()
            MyGui := 0
            hIL := 0
            iconCache := Map()
        }
        lastTheme := currentTheme
        lastAccent := currentAccent

        if (MyGui) {
            LogInfo("GUI 已存在，复现窗口", , WindowJumpDebug.mode)
            ; 清空搜索框内容
            MyGui["SearchInput"].Value := ""
            ; 将焦点设置到搜索框，方便直接输入
            MyGui["SearchInput"].Focus()
            ; 刷新列表显示所有窗口（使用缓存）
            RefreshAllWindows(MyGui["ResultList"], hIL, iconCache)
            ; 在屏幕中心显示窗口
            MyGui.Show("Center")
            return
        }
    } else {
        global IsDarkMode, AccentColor
        lastTheme := IsDarkMode ? "dark" : "light"
        lastAccent := AccentColor
    }

    ; ==============================================================================
    ; 创建 GUI 窗口
    ; ==============================================================================
    ; Gui(Options, Title)
    ;   -Options: 控制窗口行为
    ;     -Caption: 无标题栏（仅显示内容区域）
    ;     +AlwaysOnTop: 窗口始终置顶
    ;     +Owner: 所有者窗口（配合 MyKeymap 使用）
    ;     +LastFound: 设置为"最后找到的窗口"供后续函数使用
    ;   -Title: 窗口标题
    MyGui := Gui("-Caption +AlwaysOnTop +Owner +LastFound", "QuickSwitcher")

    ; ==============================================================================
    ; 设置 GUI 样式
    ; ==============================================================================
    ; GUI.BackColor: 设置窗口背景色
    ; 根据系统主题色动态生成，确保视觉一致
    MyGui.BackColor := BgColor

    ; GUI.SetFont(Options, FontName)
    ;   -Options: 字体样式
    ;     s12: 字体大小为 12
    ;     cFFFFFF: 字体颜色（十六进制 RGB）
    ;   -FontName: 字体名称（优先使用系统默认的中文显示字体）
    MyGui.SetFont("s" . FontSize " c" . FontColor, "微软雅黑")

    ; ==============================================================================
    ; DPI 缩放计算
    ; ==============================================================================
    ; A_ScreenDPI: 获取系统 DPI 值（通常 96/120/144/192 等）
    ; 计算缩放因子，确保窗口在不同 DPI 设置下显示大小一致
    scaleFactor := A_ScreenDPI / 96
    ; 根据缩放因子计算实际窗口尺寸和圆角半径
    w_phys := 600 * scaleFactor     ; 窗口宽度（像素）
    h_phys := 450 * scaleFactor     ; 窗口高度（像素）
    r_phys := 20 * scaleFactor      ; 圆角半径（像素）

    ; ==============================================================================
    ; 设置窗口圆角
    ; ==============================================================================
    ; WinSetRegion(Shape, WinTitle, WinText, ExcludeTitle, ExcludeText)
    ;   -Shape: 区域形状定义
    ;     "0-0 w600 h450 r20-20": 从 (0,0) 开始，宽度 600 高度 450，左右上角圆角半径 20
    ;   -WinTitle: 目标窗口（这里使用 HWND 句柄）
    ; 为窗口创建圆角外观，提升视觉美感
    WinSetRegion("0-0 w" . w_phys . " h" . h_phys . " r" . r_phys . "-" . r_phys, MyGui.Hwnd)

    ; ==============================================================================
    ; 添加标题文本
    ; ==============================================================================
    ; GUI.Add(ControlType, Options, Value)
    ;   ControlType:
    ;     Text: 静态文本控件
    ;   Options:
    ;     x25 y15: 控件位置（距离左边 25px，距离顶部 15px）
    ;     h30: 控件高度 30px
    ;     cFFFFFF: 文本颜色（使用强调色）
    ;   Value: 静态文本内容
    MyGui.Add("Text", "x25 y15 h30 c" . AccentColor, "快速跳转——上下键选择，回车激活")

    ; ==============================================================================
    ; 添加搜索输入框
    ; ==============================================================================
    ; Edit: 单行输入框控件
    ;   x20 y45: 位置
    ;   w560: 宽度 560px
    ;   h22: 高度 22px
    ;   vSearchInput: 关联变量名，通过 MyGui["SearchInput"] 访问
    ;   -E0x200: 移除 Edit 控件的默认边框样式
    ;   Background: 背景色（使用列表背景色保持一致）
    EditBox := MyGui.Add("Edit", "x20 y45 w560 h22 vSearchInput -E0x200 Background" . ListViewBg)

    ; ==============================================================================
    ; 创建图像列表（ImageList）
    ; ==============================================================================
    ; IL_Create(InitialCount, GrowCount, LargeIcons)
    ;   -InitialCount: 初始容量，默认为 2
    ;   -GrowCount: 增长增量，当容量不足时每次增加的数量，默认为 5
    ;   -LargeIcons: 是否使用大图标，0=小图标，非0=大图标
    ; 返回: 图像列表的 ID（句柄），失败返回 0
    ; 创建小图标列表，初始容量 10，每次增长 5
    hIL := IL_Create(10, 5, 0)

    ; ==============================================================================
    ; 添加 ListView 控件
    ; ==============================================================================
    ; ListView: 列表视图控件，类似文件资源管理器的详细视图
    ;   x20 y95: 位置
    ;   w560: 宽度
    ;   r11: 显示 11 行
    ;   -Multi: 单选模式（不允许选择多行）
    ;   -Hdr: 隐藏列标题
    ;   -E0x200: 移除默认边框
    ;   vResultList: 关联变量名
    ;   +LV0x140: 组合样式
    ;     LVS_SINGLESEL (0x0001): 单选
    ;     LVS_SHOWSELALWAYS (0x0200): 始终显示选中项
    ;   Background/ c: 背景色和文字颜色
    ;   参数数组: 列标题（这里实际只用一列存储窗口信息，第二列隐藏存储 HWND）
    ResultList := MyGui.Add("ListView", "x20 y95 w560 r11 -Multi -Hdr -E0x200 vResultList +LV0x140 Background" .
        ListViewBg . " c" . FontColor, ["Display", "HWND", "IsShortcut"])

    ; ==============================================================================
    ; 绑定图像列表到 ListView
    ; ==============================================================================
    ; LV.SetImageList(ImageListID)
    ;   -ImageListID: IL_Create 返回的图像列表句柄
    ; 将之前创建的图像列表关联到 ListView，使其能够显示图标
    ResultList.SetImageList(hIL)

    ; ==============================================================================
    ; 配置 ListView 列
    ; ==============================================================================
    ; LV.ModifyCol(ColumnNumber, Options)
    ;   -ColumnNumber: 列序号（1 为第一列）
    ;   -Options: 列选项
    ;     540: 列宽度（像素）
    ; 设置第一列宽度为 540px（容纳窗口标题）
    ResultList.ModifyCol(1, 540)
    ResultList.ModifyCol(2, 0)
    ResultList.ModifyCol(3, 0)

    ; ==============================================================================
    ; 初始化窗口列表
    ; ==============================================================================
    ; 首次显示时，列出所有可跳转的窗口
    RefreshList(ResultList, &hIL, &iconCache, &shortcutCache)

    ; ==============================================================================
    ; 事件绑定
    ; ==============================================================================
    ; Control.OnEvent(EventName, Callback)
    ;   -EventName: 事件名称
    ;     Change: 输入框内容改变时触发
    ;     DoubleClick: 双击列表项时触发
    ;   -Callback: 回调函数
    ;     (*) => ...: 箭头函数语法（AutoHotkey v2）
    ;     obj: 触发事件的控件对象
    ;     *: 可变参数占位符（忽略额外参数）

    ; 搜索框内容改变时触发搜索更新
    EditBox.OnEvent("Change", (obj, *) => UpdateSearch(obj, MyGui["ResultList"], hIL, &iconCache, &shortcutCache))

    ; 双击列表项时激活对应窗口
    ResultList.OnEvent("DoubleClick", (obj, row) => ActivateWin(obj, row))

    ; ==============================================================================
    ; 键盘快捷键绑定
    ; ==============================================================================
    ; HotIfWinActive(WinTitle)
    ;   设置后续 Hotkey 命令的条件，仅当指定窗口活动时才响应
    ;   "ahk_id " . MyGui.Hwnd: 通过窗口句柄识别当前 GUI 窗口
    HotIfWinActive("ahk_id " . MyGui.Hwnd)

    ; ==============================================================================
    ; Hotkey(Key, Callback, Options)
    ;   -Key: 热键（可以是单键或组合键）
    ;   -Callback: 触发时执行的函数
    ;   -Options: 选项
    ;     "On": 启用该热键

    ; Escape: 隐藏窗口（退出搜索）
    Hotkey("Escape", (*) => MyGui.Hide(), "On")

    ; Down: 向下选择列表项
    Hotkey("Down", (*) => MoveLVSelection(MyGui["ResultList"], "Down"), "On")

    ; Up: 向上选择列表项
    Hotkey("Up", (*) => MoveLVSelection(MyGui["ResultList"], "Up"), "On")

    ; Enter: 确认选择并激活窗口
    Hotkey("Enter", (*) => HandleEnter(MyGui), "On")

    ; 启动失焦检测定时器，传入 GUI 对象
    SetTimer () => CheckWinFocus(MyGui), 100

    ; ==============================================================================
    ; 显示 GUI 窗口
    ; ==============================================================================
    ; GUI.Show(Options)
    ;   -Options:
    ;     w600 h450: 窗口宽高
    ;     Center: 在屏幕中央显示
    ; 显示窗口，设置宽度 600 高度 450，位于屏幕中央
    MyGui.Show("w600 h450 Center")
}

; ==============================================================================
; 逻辑处理函数
; ==============================================================================

; ==============================================================================

; ==============================================================================
; CheckWinFocus - 检查窗口是否失去焦点
; 定时器回调函数，每 200ms 执行一次
; 当 GUI 不再活动时自动隐藏
; ==============================================================================

CheckWinFocus(guiObj) {
    ; WinExist(WinTitle): 检查指定窗口是否存在
    ;   "ahk_id " . guiObj.Hwnd: 通过窗口句柄查找
    ;   返回 HWND，如果窗口不存在返回 0
    if !WinExist("ahk_id " . guiObj.Hwnd) {
        ; LogInfo("GUI 窗口不存在，停止检测", , WindowJumpDebug.mode)
        return
    }
    ; WinActive(WinTitle): 检查窗口是否处于活动状态
    ;   如果不活动，隐藏窗口
    if !WinActive("ahk_id " . guiObj.Hwnd) {
        LogInfo("GUI 失去焦点，隐藏窗口", , WindowJumpDebug.mode)
        guiObj.Hide()
    }
}

; ==============================================================================
; RefreshList - 刷新窗口列表
; ==============================================================================
; LV: ListView 控件对象
; &hIL: 图像列表句柄的引用（因为需要在函数中销毁重建）
; ==============================================================================

RefreshList(LV, &hIL, &iconCache, &shortcutCache) {
    global BgColor, FontColor, AccentColor, ListViewBg, IsDarkMode, FontSize
    LogInfo("开始刷新窗口列表（重建模式）", , WindowJumpDebug.mode)

    LV.Delete()

    if (hIL) {
        IL_Destroy(hIL)
    }
    iconCache := Map()
    shortcutCache := Map()

    hIL := IL_Create(20, 10, 0)

    LV.SetImageList(hIL)

    windowCount := 0
    bak_DetectHiddenWindows := A_DetectHiddenWindows
    A_DetectHiddenWindows := true
    for hwnd in WinGetList() {
        try {
            title := WinGetTitle(hwnd)
            process := WinGetProcessName(hwnd)
            style := WinGetStyle(hwnd)

            if (title != "" && (style & 0x40000) && hwnd != LV.Gui.Hwnd) {
                desktopNum := VD.getDesktopNumOfWindow("ahk_id " . hwnd)
                if (desktopNum > 0) {
                    desktopInfo := " [桌面" . desktopNum . "]"
                } else if (desktopNum == -1) {
                    desktopInfo := " [所有桌面]"
                } else if (desktopNum == -2) {
                    desktopInfo := " [应用所有桌面]"
                } else {
                    desktopInfo := ""
                }
                iconIdx := GetIconIndexByProcess(process, hIL, iconCache)
                LV.Add("Icon" . iconIdx, desktopInfo . " [" . process . "] " . title, hwnd, "0")
                windowCount++
            }
        }
    }
    A_DetectHiddenWindows := bak_DetectHiddenWindows

    LogInfo("刷新完成，共添加 " . windowCount . " 个窗口", , WindowJumpDebug.mode)
}

RefreshAllWindows(LV, hIL, iconCache) {
    LogInfo("RefreshAllWindows: 使用现有缓存刷新列表", , WindowJumpDebug.mode)
    LV.Delete()
    windowCount := 0
    bak_DetectHiddenWindows := A_DetectHiddenWindows
    A_DetectHiddenWindows := true
    for hwnd in WinGetList() {
        try {
            title := WinGetTitle(hwnd)
            process := WinGetProcessName(hwnd)
            style := WinGetStyle(hwnd)
            if (title != "" && (style & 0x40000) && hwnd != LV.Gui.Hwnd) {
                desktopNum := VD.getDesktopNumOfWindow("ahk_id " . hwnd)
                if (desktopNum > 0) {
                    desktopInfo := " [桌面" . desktopNum . "]"
                } else if (desktopNum == -1) {
                    desktopInfo := " [所有桌面]"
                } else if (desktopNum == -2) {
                    desktopInfo := " [应用所有桌面]"
                } else {
                    desktopInfo := ""
                }
                iconIdx := GetIconIndexByProcess(process, hIL, iconCache)
                LV.Add("Icon" . iconIdx, desktopInfo . " [" . process . "] " . title, hwnd, "0")
                windowCount++
            }
        }
    }
    A_DetectHiddenWindows := bak_DetectHiddenWindows
    LogInfo("RefreshAllWindows 完成，共 " . windowCount . " 个窗口", , WindowJumpDebug.mode)
    if (LV.GetCount() > 0) {
        LV.Modify(1, "Select Focus")
    }
}

; ==============================================================================
; UpdateSearch - 根据搜索词过滤窗口
; ==============================================================================
; EditObj: 搜索输入框对象
; LV: ListView 控件对象
; hIL: 图像列表句柄
; ==============================================================================

UpdateSearch(EditObj, LV, hIL, &iconCache, &shortcutCache) {
    global BgColor, FontColor, AccentColor, ListViewBg, IsDarkMode, FontSize
    LogInfo("搜索内容改变: [" . EditObj.Value . "]", , WindowJumpDebug.mode)

    ; 1. 获取当前搜索文本
    currentInput := Trim(EditObj.Value)

    ; 2. 如果搜索框为空，显示全部窗口（不清空缓存，只刷新列表）
    if (currentInput == "") {
        LogInfo("搜索框为空，显示全部窗口（使用缓存）", , WindowJumpDebug.mode)
        RefreshAllWindows(LV, hIL, iconCache)
        return
    }

    ; 转换为小写用于匹配
    searchLower := StrLower(currentInput)

    ; 3. 清空列表准备重新填充
    LV.Delete()

    ; 4. 存储匹配结果
    results := []

    ; ==============================================================================
    ; 遍历所有窗口进行匹配
    ; ==============================================================================
    bak_DetectHiddenWindows := A_DetectHiddenWindows
    A_DetectHiddenWindows := true
    for hwnd in WinGetList() {
        try {
            title := WinGetTitle(hwnd)
            process := WinGetProcessName(hwnd)
            style := WinGetStyle(hwnd)

            ; 过滤条件
            if (title == "" || !(style & 0x40000) || hwnd == EditObj.Gui.Hwnd) {
                continue
            }

            desktopNum := VD.getDesktopNumOfWindow("ahk_id " . hwnd)
            if (desktopNum > 0) {
                desktopInfo := " [桌面" . desktopNum . "]"
            } else if (desktopNum == -1) {
                desktopInfo := " [所有桌面]"
            } else if (desktopNum == -2) {
                desktopInfo := " [应用所有桌面]"
            } else {
                desktopInfo := ""
            }

            ; 构造搜索目标文本
            fullText := StrLower("[" . process . "] " . title)

            ; 使用 FuzzyScore 进行匹配（已集成拼音匹配）
            score := FuzzyScore(searchLower, fullText)

            ; 保留匹配结果
            if (score > 0) {
                results.Push({ score: score, text: desktopInfo . " [" . process . "] " . title, hwnd: hwnd, isShortcut: false })
            }
        }
    }
    A_DetectHiddenWindows := bak_DetectHiddenWindows

    ; 快捷方式匹配
    GetShortcuts(&shortcuts)
    LogInfo("开始匹配快捷方式，数量: " . shortcuts.Length, , WindowJumpDebug.mode)
    for shortcut in shortcuts {
        fullText := StrLower(shortcut.name)
        score := FuzzyScore(searchLower, fullText)
        if (score > 0) {
            results.Push({ score: score // 2, text: ">>> " . shortcut.name, hwnd: shortcut.path, isShortcut: true })
        }
    }

    LogInfo("窗口匹配 " . results.Length . " 个结果", , WindowJumpDebug.mode)

    ; 5. 排序结果（按分数从高到低）
    if (results.Length > 0) {
        loop results.Length {
            i := A_Index
            while (i > 1 && results[i - 1].score < results[i].score) {
                temp := results[i]
                results[i] := results[i - 1]
                results[i - 1] := temp
                i--
            }
        }

        ; 填充 ListView（限制最多显示 30 条）
        loop (Min(results.Length, 30)) {
            res := results[A_Index]
            if (res.isShortcut) {
                if (shortcutCache.Has(res.hwnd)) {
                    iconIdx := shortcutCache[res.hwnd]
                } else {
                    iconIdx := GetFileIconIndex(res.hwnd, hIL)
                    shortcutCache[res.hwnd] := iconIdx
                    LogInfo("快捷方式缓存未命中: path=" . res.hwnd, , WindowJumpDebug.mode)
                }
            } else {
                process := WinGetProcessName(res.hwnd)
                iconIdx := GetIconIndexByProcess(process, hIL, iconCache)
            }
            LV.Add("Icon" . iconIdx, res.text, res.hwnd, res.isShortcut ? "1" : "0")
        }
    }

    ; 6. 确保有选中项
    if (LV.GetCount() > 0) {
        LV.Modify(1, "Select Focus")
    }
}

; ==============================================================================
; GetIconIndex - 获取窗口图标索引
; ==============================================================================

GetIconIndexByProcess(process, hIL, iconCache) {
    if (iconCache.Has(process)) {
        return iconCache[process]
    }
    hwnd := WinExist("ahk_exe " . process)
    if (!hwnd) {
        return 1
    }
    iconIdx := GetUwpIconIndex(hwnd, hIL)
    iconCache[process] := iconIdx
    LogInfo("窗口图标缓存未命中: process=" . process . " idx=" . iconIdx, , WindowJumpDebug.mode)
    return iconIdx
}

GetIconIndex(hwnd, hIL) {
    ; ==============================================================================
    ; 方法 1: 通过 WM_GETICON 消息获取小图标
    ; ==============================================================================
    ; SendMessage(Msg, wParam, lParam, WinTitle, WinText)
    ;   -Msg: 消息ID
    ;     0x7F (WM_GETICON): 获取窗口图标
    ;   -wParam: 图标类型
    ;     0: 获取小图标 (ICON_SMALL)
    ;     1: 获取大图标 (ICON_BIG)
    ;     2: 获取小图标（如果失败则尝试大图标）
    ;   -lParam: 未使用
    ;   -返回: 图标句柄（HICON），失败返回 0
    hIcon := SendMessage(0x7F, 0, 0, hwnd, "ahk_id " . hwnd)

    ; ==============================================================================
    ; 方法 2: 失败则从窗口类获取图标
    ; ==============================================================================
    ; GetClassLongPtr / GetClassLong: 获取窗口类信息
    ;   -Ptr: 窗口句柄
    ;   -Int: 要获取的信息类型
    ;     -34 (GCL_HICONSM): 小图标（16x16）
    ;   -返回值: 图标句柄
    ; 根据系统是 32 位还是 64 位选择对应函数
    if (!hIcon) {
        hIcon := DllCall(A_PtrSize == 8 ? "GetClassLongPtr" : "GetClassLong", "Ptr", hwnd, "Int", -34, "UPtr")
    }

    ; ==============================================================================
    ; 方法 3: 仍失败则获取大图标
    ; ==============================================================================
    if (!hIcon) {
        hIcon := SendMessage(0x7F, 1, 0, hwnd, "ahk_id " . hwnd)
    }

    ; ==============================================================================
    ; 添加图标到图像列表
    ; ==============================================================================
    ; IL_Add(ImageListID, IconFileName, IconNumber)
    ;   -IconFileName: 图标文件或 "HICON:" + 句柄字符串
    ;   -IconNumber: 图标编号（对于 HICON 句柄无效，可省略）
    ;   -返回: 新图标的索引（1-based），失败返回 0
    if (hIcon) {
        return IL_Add(hIL, "HICON:" . hIcon)
    }

    ; 如果所有方法都失败，返回 1（使用默认图标）
    return 1
}

; ==============================================================================
; GetFileIconIndex - 获取文件/快捷方式图标索引
; ==============================================================================

GetFileIconIndex(filePath, hIL) {
    try {
        if (StrEndsWith(filePath, ".lnk")) {
            FileGetShortcut filePath, &targetPath, &workDir, &args, &desc, &iconFile, &iconNum
            if (iconFile) {
                iconPath := iconFile
                if (iconNum > 0) {
                    return IL_Add(hIL, iconPath, iconNum)
                } else {
                    return IL_Add(hIL, iconPath)
                }
            }
            if (targetPath) {
                filePath := targetPath
            }
        }
    }

    return GetExeIconIndex(filePath, hIL)
}

; ==============================================================================
; GetExeIconIndex - 通过 SHGetFileInfoW 获取可执行文件图标
; ==============================================================================

GetExeIconIndex(filePath, hIL) {
    try {
        fisize := A_PtrSize + 688
        fileinfo := Buffer(fisize)
        if DllCall("shell32\SHGetFileInfoW", "WStr", filePath, "UInt", 0, "Ptr", fileinfo, "UInt", fisize, "UInt",
            0x100) {
            hIcon := NumGet(fileinfo, 0, "Ptr")
            if hIcon {
                return IL_Add(hIL, "HICON:" . hIcon)
            }
        }
    }
    return IL_Add(hIL, filePath)
}

; ==============================================================================
; GetUwpIconIndex - 获取 UWP 应用图标索引
; ==============================================================================

GetUwpIconIndex(hwnd, hIL) {
    try {
        exePath := WinGetProcessPath(hwnd)

        if exePath {
            if (StrEndsWith(exePath, "ApplicationFrameHost.exe")) {
                return GetUwpIconFromWindow(hwnd, hIL)
            }
            return GetExeIconIndex(exePath, hIL)
        }
    }
    return 1
}

; ==============================================================================
; GetUwpIconFromWindow - 通过窗口获取 UWP 应用图标
; ==============================================================================
GetUwpIconFromWindow(hwnd, hIL) {
    hIcon := SendMessage(0x7F, 0, 0, hwnd, "ahk_id " . hwnd)
    if !hIcon {
        hIcon := SendMessage(0x7F, 1, 0, hwnd, "ahk_id " . hwnd)
    }
    if !hIcon {
        hIcon := DllCall(A_PtrSize == 8 ? "GetClassLongPtr" : "GetClassLong", "Ptr", hwnd, "Int", -34, "UPtr")
    }
    if hIcon {
        return IL_Add(hIL, "HICON:" . hIcon)
    }
    return 1
}

StrEndsWith(str, suffix) {
    return SubStr(str, -StrLen(suffix) + 1) = suffix
}

; ==============================================================================
; FuzzyScore - 模糊匹配评分算法
; ==============================================================================
; query: 用户输入的搜索关键词（小写）
; target: 目标文本（小写）
; 返回: 匹配分数（0 表示不匹配，正数表示匹配程度）
; ==============================================================================

FuzzyScore(query, target) {
    if !(query := Trim(query)) {
        return 0
    }

    target := StrReplace(target, ".exe", "")

    totalScore := 0
    matchedTokens := 0

    ; 词元分割（空格分割）
    tokens := StrSplit(query, " ")

    ; LogInfo("FuzzyScore: query=[" . query . "] target=[" . target . "] tokens=" . tokens.Length, , WindowJumpDebug.mode)

    ; 逐词元匹配
    for _, token in tokens {
        if (token == "") {
            continue
        }

        tokenScore := 0

        ; 方法1：词元连续匹配（完整包含）
        if InStr(target, token) {
            tokenScore := 1000
            ; 开头匹配加分
            if InStr(target, token, true, 1, 1) {
                tokenScore += 200
            }
        }
        ; 方法2：拼音匹配（简拼+全拼）
        else if IbPinyin_Match(token, target, IbPinyin_AsciiFirstLetter | IbPinyin_Ascii) {
            tokenScore := 800
        }

        if (tokenScore > 0) {
            totalScore += tokenScore
            matchedTokens++
        }
    }

    ; 所有词元都匹配才返回分数（AND 逻辑）
    if (matchedTokens < tokens.Length) {
        ; LogInfo("FuzzyScore: 未全部匹配，返回 0 (matched=" . matchedTokens . "/" . tokens.Length . ")", , WindowJumpDebug.mode)
        return 0
    }

    ; LogInfo("FuzzyScore: 匹配成功，分数=" . totalScore, , WindowJumpDebug.mode)
    return totalScore
}

; ==============================================================================
; UpdateTheme - 更新主题颜色
; ==============================================================================
; 根据系统设置（深色/浅色模式、强调色）动态生成 GUI 配色
; ==============================================================================

UpdateTheme() {
    ; 声明全局变量（在函数内修改全局变量需要先声明）
    global BgColor, FontColor, AccentColor, ListViewBg, IsDarkMode, FontSize

    LogInfo("开始更新主题", , WindowJumpDebug.mode)

    ; ==============================================================================
    ; 读取系统深色模式状态
    ; ==============================================================================
    ; RegRead(RootKey, SubKey, ValueName)
    ;   -RootKey: 根键（如 "HKEY_CURRENT_USER" 可简写为 "HKCU"）
    ;   -SubKey: 子键路径
    ;   -ValueName: 值名称
    ;   -返回: 注册表值
    ;   -try-catch: 读取失败时捕获异常
    try {
        ; 读取系统是否使用浅色主题
        ; 0 = 深色模式，1 = 浅色模式
        IsDarkMode := RegRead("HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize",
            "AppsUseLightTheme") == 0
    } catch {
        IsDarkMode := false
    }

    LogInfo("系统主题: " . (IsDarkMode ? "深色模式" : "浅色模式"), , WindowJumpDebug.mode)

    ; ==============================================================================
    ; 读取系统强调色
    ; ==============================================================================
    try {
        ; Windows DWM 强调色存储格式为 ABGR（而不是常见的 RGB）
        ; 需要转换为 RGB 格式
        rawColor := RegRead("HKEY_CURRENT_USER\Software\Microsoft\Windows\DWM", "AccentColor")

        ; 提取各颜色分量
        ; &: 按位与运算
        ; >>: 右移位运算
        r := rawColor & 0xFF          ; 红色分量（ABGR 中的 A 位置）
        g := (rawColor >> 8) & 0xFF   ; 绿色分量
        b := (rawColor >> 16) & 0xFF  ; 蓝色分量

        ; 转换为 RGB 格式的数字值
        accentNum := (r << 16) | (g << 8) | b

        ; Format(FormatStr, Args...)
        ;   -FormatStr: 格式字符串
        ;     {:06X}: 6 位十六进制，不足前补 0
        ; 将数字转换为十六进制字符串（如 0x0078D7 -> "0078D7"）
        AccentColor := Format("{:06X}", accentNum)
    } catch {
        ; 读取失败时使用默认蓝色
        accentNum := 0x0078D7
        AccentColor := "0078D7"
    }

    ; ==============================================================================
    ; 根据主题计算配色
    ; ==============================================================================
    ; MixColor: 混合颜色函数（见下文定义）
    ;   -Color1: 强调色
    ;   -Color2: 目标色（黑色或白色）
    ;   -Weight: 混合权重（0-1，越大越接近目标色）
    if (IsDarkMode) {
        ; 深色模式：背景向黑色偏移 90%
        BgColor := MixColor(accentNum, 0x111111, 0.90)
        ; 字体灰白色
        FontColor := "c6c6c6"
        ; 列表背景稍亮一点（偏移 80%）
        ListViewBg := MixColor(accentNum, 0x111111, 0.80)
    } else {
        ; 浅色模式：背景向白色偏移 90%
        BgColor := MixColor(accentNum, 0xFFFFFF, 0.90)
        ; 字体深灰色
        FontColor := "333333"
        ; 列表背景更贴近主题色（偏移 80%）
        ListViewBg := MixColor(accentNum, 0xFFFFFF, 0.80)
    }

    ; 默认字体大小 12
    FontSize := 12
}

; ==============================================================================
; MixColor - 颜色混合
; ==============================================================================
; 将两个颜色按权重混合，生成类似"莫奈色"的中间色调
; Color1, Color2: RGB 格式的颜色数字（如 0x0078D7）
; Weight: 混合权重（0-1）
; 返回: 混合后的 RGB 颜色值
; ==============================================================================

MixColor(Color1, Color2, Weight) {
    ; ==============================================================================
    ; 颜色分解
    ; ==============================================================================
    ; 从 RGB 数字中提取各分量
    ;   Color1 >> 16 & 0xFF: 红色分量
    ;   Color1 >> 8 & 0xFF: 绿色分量
    ;   Color1 & 0xFF: 蓝色分量
    r1 := (Color1 >> 16) & 0xFF
    g1 := (Color1 >> 8) & 0xFF
    b1 := Color1 & 0xFF

    r2 := (Color2 >> 16) & 0xFF
    g2 := (Color2 >> 8) & 0xFF
    b2 := Color2 & 0xFF

    ; ==============================================================================
    ; 线性插值计算混合颜色
    ; ==============================================================================
    ; result = start + (end - start) * weight
    ; Round(Number): 四舍五入取整
    r := Round(r1 + (r2 - r1) * Weight)
    g := Round(g1 + (g2 - g1) * Weight)
    b := Round(b1 + (b2 - b1) * Weight)

    ; ==============================================================================
    ; 重新组合为 RGB 字符串
    ; ==============================================================================
    ; 格式：RRGGBB（两位十六进制，不带 0x 前缀）
    return Format("{:02X}{:02X}{:02X}", r, g, b)
}

; ==============================================================================
; MoveLVSelection - 移动 ListView 选中项
; ==============================================================================
; LV: ListView 控件对象
; Direction: 移动方向（"Up" 或 "Down"）
; ==============================================================================

MoveLVSelection(LV, Direction) {
    ; 空列表则不处理
    if (LV.GetCount() == 0) {
        return
    }

    ; ==============================================================================
    ; 获取当前选中/聚焦行
    ; ==============================================================================
    ; LV.GetNext(StartRow, Options)
    ;   -StartRow: 起始行（0 表示从头开始搜索）
    ;   -Options: 选项
    ;     "Focused": 查找具有焦点焦点的行
    ;     "Selected": 查找选中的行
    ;   -返回: 找到的行号（0 表示未找到）
    row := LV.GetNext(0, "Focused")

    ; 如果没有焦点行，获取选中的第一行
    if (row == 0) {
        row := LV.GetNext(0)
    }

    ; ==============================================================================
    ; 计算下一行
    ; ==============================================================================
    ; Min(Value1, Value2): 返回较小值
    ; Max(Value1, Value2): 返回较大值
    if (Direction == "Down") {
        ; 向下：如果是第一行则移到第二行，否则向下移动一行，到达末尾则停在最后一行
        nextRow := (row == 0) ? 1 : Min(row + 1, LV.GetCount())
    } else {
        ; 向上：如果没有选中行则移到最后一行，否则向上移动一行，到达第一行则停在第一行
        nextRow := (row == 0) ? LV.GetCount() : Max(row - 1, 1)
    }

    ; ==============================================================================
    ; 取消当前选中状态
    ; ==============================================================================
    ; LV.Modify(RowNumber, Options)
    ;   -RowNumber: 0 表示所有行
    ;   -Options: -Select 取消选中，-Focus 取消焦点
    LV.Modify(0, "-Select -Focus")

    ; ==============================================================================
    ; 选中并聚焦新行
    ; ==============================================================================
    ; Select: 选中该行
    ; Focus: 设置键盘焦点到该行
    ; Vis: 确保该行可见（如果需要会滚动视图）
    LV.Modify(nextRow, "Select Focus Vis")
}

; ==============================================================================
; HandleEnter - 处理回车键
; ==============================================================================
; GUI 对象，用于获取 ListView 控件
; ==============================================================================

HandleEnter(GuiObj) {
    ; 获取 ListView 控件
    LV := GuiObj["ResultList"]

    ; 获取当前焦点行
    row := LV.GetNext(0, "Focused")

    ; 如果没有焦点行，获取选中的第一行
    if (row == 0) {
        row := LV.GetNext(0)
    }

    ; 如果仍然没有选中，但列表有内容，则选第一行
    if (row == 0 && LV.GetCount() > 0) {
        row := 1
    }

    ; 如果有选中行，激活对应窗口
    if (row > 0) {
        ActivateWin(LV, row)
    }
}

; ==============================================================================
; ActivateWin - 激活窗口
; ==============================================================================
; LV: ListView 控件对象
; RowNumber: 要激活的行号
; ==============================================================================

ActivateWin(LV, RowNumber) {
    try {
        hwnd := LV.GetText(RowNumber, 2)
        isShortcut := LV.GetText(RowNumber, 3) = "1"

        LogInfo("激活窗口: hwnd=" . hwnd . " isShortcut=" . isShortcut, , WindowJumpDebug.mode)

        if (hwnd) {
            if (isShortcut) {
                LogInfo("运行快捷方式: " . hwnd, , WindowJumpDebug.mode)
                Run(hwnd)
            } else {
                LogInfo("激活窗口: ahk_id " . hwnd, , WindowJumpDebug.mode)
                global lastActiveWindowClass
                lastActiveWindowClass := "AutoHotkeyGUI"
                targetDesktopNum := VD.getDesktopNumOfWindow("ahk_id " . hwnd)
                currentDesktopNum := VD.getCurrentDesktopNum()
                if (targetDesktopNum > 0 && targetDesktopNum != currentDesktopNum) {
                    VD.goToDesktopOfWindow("ahk_id " . hwnd)
                } else {
                    WinActivate("ahk_id " . hwnd)
                }
            }
            LV.Gui.Hide()
        }
    } catch Error as e {
        LogError(e, , WindowJumpDebug.mode)
    }
}
