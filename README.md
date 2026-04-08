---
title: 项目介绍-mykeymap-enhance
description: 我的 MyKeymap 自定义功能仓库，不依赖于 MyKeymap 就可以运行，可以视为我的自定义 AutoHotkey 库
date: 2025-08-14
lastmod: 2026-04-03
image: 
categories:
    - 项目
tags:
    - MyKeymap
    - AutoHotkey
weight: 
---

## 仓库地址

<https://github.com/Jy-EggRoll/mykeymap-enhance/>

## 使用方法

下载 Release 中的 `data.zip`，解压后将各子文件放入 MyKeymap 的 `data` 目录下即可，之后各个函数可以根据您的需要被 MyKeymap 调用。

> [!TIP]
>
> 从 1.4 版本开始，不再提供示例 json 配置，而是在 README 中提供各个函数的最佳实践的配置指导，这可以最大限度减少配置冲突的可能性，也方便您根据自己的使用习惯进行修改。

`custom_function.ahk` 仅保留和官方一样的接口，负责导入各个模块，本身不提供任何实际功能，所以如果希望体验全部功能，请加入全部的 ahk 文件，若您没有自己的自定义函数，可以安全地覆盖 `custom_function.ahk`，如果您有，请自行对比两文件的差异，并将其合并。

## 引言

使用 [MyKeymap](https://github.com/xianyukang/MyKeymap) 已经有相当长一段时间了，学习了一部分 [AutoHotkey](https://github.com/AutoHotkey/AutoHotkey) 后，我现在可以开发一些额外的功能。目前，这些脚本全部无需依赖 MyKeymap，可以直接由 AHK 调用。

不过，值得注意的是，通过 MyKeymap 的强大扩展能力来使用我的函数是最佳实践。我的所有函数均未分配快捷键，若您需要直接通过 AHK 调用，请自行修改代码分配快捷键。

## 自定义函数表

> [!TIP]
>
> 若您在手机端或较窄的 GitHub 页面上浏览此节，为了更舒适的阅读体验，请跳转至我的博客查看函数表（GitHub 不支持自定义 CSS 的表格，这会导致表格超出屏幕，排版也不美观）。文章剩余部分也是一致的，您可以直接继续浏览全文。链接如下：
>
> <https://eggroll.pages.dev/p/%E9%A1%B9%E7%9B%AE%E4%BB%8B%E7%BB%8Dmy-keymap/#%E8%87%AA%E5%AE%9A%E4%B9%89%E5%87%BD%E6%95%B0%E8%A1%A8>

<table style="width: 100%; border-collapse: collapse; table-layout: fixed;">
  <thead>
    <tr>
      <th style="width: 25%; padding: 10px; border: 2px solid; text-align: center;">函数名</th>
      <th style="width: 25%; padding: 10px; border: 2px solid; text-align: center;">参数说明</th>
      <th style="width: 25%; padding: 10px; border: 2px solid; text-align: center;">功能</th>
      <th style="width: 25%; padding: 10px; border: 2px solid; text-align: center;">最佳实践</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">SmoothScrollSimulate()</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">无参数</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">模拟平滑滚动效果，在绝大多数现代化软件中有很高的可用性，如浏览器。少数软件不支持，如 Windows 文件资源管理器。该效果触发时，可以使软件以像素为单位平滑滚动，效果近似于精确式触摸板或触摸屏，支持左右移动、对角线移动等。</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">绑定到前置键+鼠标右键（必须是右键，否则需要修改代码），例如 <kbd>Win</kbd> + 鼠标右键</td>
    </tr>
    <tr>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">DragWindow()</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">无参数</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">直接拖动任意窗口（无需点击标题栏），如果在最大化窗口上尝试调用该功能，窗口将被调整为占据全屏的普通窗口</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">绑定到前置键+鼠标左键（必须是左键，否则需要修改代码），例如 <kbd>Caps</kbd> + 鼠标左键</td>
    </tr>
    <tr>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">ResizeWindow()</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">无参数</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">直接调整任意窗口的大小（无需定位到边框），窗口会被划分为 9 个区域，拖动对应区域即可完成调节，如果在最大化窗口上尝试调用该功能，会发出提示，用户应该先使用触发键+右键单击该窗口，使之变为占据全屏的普通窗口，再进行大小调节，这是为了避免潜在的闪烁问题</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">绑定到前置键+鼠标右键（必须是右键，否则需要修改代码），例如 <kbd>Caps</kbd> + 鼠标右键</td>
    </tr>
    <tr>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">PerCenterAndResizeWindow(percentageW, percentageH)</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">小数，宽度占屏幕的比例（0-1），高度占屏幕的比例（0-1）</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">调整窗口大小并居中，智能适应不同分辨率屏幕</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">自定义快捷键</td>
    </tr>
    <tr>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">Per*AndResizeWindow(percentageW, percentageH)</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">小数，宽度占屏幕的比例（0-1），高度占屏幕的比例（0-1）</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">* 替换为 Left、Down、Right、Up、LeftUp、LeftDown、RightUp、RightDown，负责分屏和边角</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">前四个功能完全替换默认的 <kbd>Win</kbd> + 方向键，后四个替换为合适的快捷键</td>
    </tr>
    <tr>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">SplitScreen(gridNum, gridIndex)</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">gridNum：网格数量，gridIndex：实际位置</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">根据网格数量和索引将窗口调整到屏幕对应位置，支持 2、3、4、9 格分屏</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">使用 MyKeymap 的命令实现分屏，如 41、92</td>
    </tr>
    <tr>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">AutoActivateWindow(pollingTime := 20)</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">pollingTime：轮询时间，默认为 20 ms</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">开关函数。鼠标悬停处自动激活窗口，无需点击。默认随 MyKeymap 启动</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">绑定一个快捷键或指令，方便随时启停</td>
    </tr>
    <tr>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">IncBrightness(dealt)</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">整数，一个百分比值，如 5</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">增加当前选中显示器的屏幕亮度</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">自定义为合适的快捷键或指令</td>
    </tr>
    <tr>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">DecBrightness(dealt)</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">整数，一个百分比值，如 5</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">降低当前选中显示器的屏幕亮度</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">自定义为合适的快捷键或指令</td>
    </tr>
    <tr>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">NextMonitor()</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">无参数</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">切换到下一个显示器的亮度调节</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">自定义为合适的快捷键或指令</td>
    </tr>
    <tr>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">PreviousMonitor()</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">无参数</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">切换到上一个显示器的亮度调节</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">自定义为合适的快捷键或指令</td>
    </tr>
    <tr>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">WindowJump()</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">无参数</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">窗口跳转，通过模糊搜索快速切换窗口，还可以作为快捷启动器</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">自定义为合适的快捷键，如 <kbd>Alt</kbd> + <kbd>Space</kbd></td>
    </tr>
    <tr>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">QuickSwitchExplorer()</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">无参数</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">快速切换/跳转到资源管理器窗口，在打开/保存对话框中调用会弹出已打开的 Explorer 列表供选择</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">自定义为合适的快捷键，如 <kbd>Alt</kbd> + <kbd>E</kbd></td>
    </tr>
    <tr>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">AutoWindowColorBorder()</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">无参数</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">开关函数。为活动窗口添加彩色边框，置顶窗口显示特殊的 mauve 色边框。默认随 MyKeymap 启动</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">绑定一个快捷键或指令，方便随时启停</td>
    </tr>
    <tr>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">SwitchToNextColor()</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">无参数</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">切换到下一个边框颜色</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">自定义为合适的快捷键或指令</td>
    </tr>
    <tr>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">SetTaskbarCombine(mode := "")</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">可选 "Always" (始终合并) 或 "Never" (从不合并)，为空则自动翻转</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">切换所有显示器的任务栏图标合并状态，无需重启资源管理器</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">自定义为合适的快捷键或指令</td>
    </tr>
    <tr>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">ReadFileToInput(filePath)</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">文件路径</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">读取文件内容并快速输入到光标位置，适用于隐私文本（如密码）快速输入，单行文本，不超过 10KB</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">自定义为合适的快捷键</td>
    </tr>
  </tbody>
</table>

## 功能详解

### 窗口跳转 WindowJump

![窗口跳转](README/快速跳转窗口.png)

通过模糊搜索快速切换窗口，支持字母模糊匹配和中文拼音匹配（简拼/全拼）。输入关键词后，窗口会实时显示匹配的窗口列表，使用上下键选择后按回车即可切换到目标窗口。

集成系统快捷方式收纳功能，可以作为快捷方式启动器使用。当输入的关键词匹配到一个快捷方式时，按回车会直接运行该快捷方式，支持普通用户身份启动和管理员身份启动。

匹配方式：

- **模糊匹配**：输入 "co ju" 可以匹配 "code jump"
- **精确匹配**：输入窗口标题中的文字（如"文件"）
- **拼音匹配**：支持简拼（如"wj"匹配"文件"）和全拼（如"wenjian"匹配"文件"）

> [!TIP]
>
> 拼音匹配功能由 [IbPinyinLib](https://github.com/Chaoses-Ib/ib-matcher) 高性能拼音库提供支持，特此致谢。
> 虚拟桌面窗口识别功能由 [VD.ahk](https://github.com/FuPeiJiang/VD.ahk) 库提供支持，特此致谢。
>
> **新增**：拼音匹配现已支持**部分匹配**模式，可以匹配拼音的开头部分，例如输入 `su` 可以匹配「算」（suan）。

### 拖动与调节 DragWindow & ResizeWindow

两款函数核心功能受 [AltSnap](https://github.com/RamonUnch/AltSnap) 启发，实现上参考了 AHK 官方的示例脚本。

- **DragWindow**：按住拖动键并点击任意位置即可拖动窗口，无需点击标题栏
- **ResizeWindow**：将窗口划分为 9 个区域（左上/上/右上/左/中/右/左下/下/右下），拖动对应区域即可调整大小
- **吸附功能**：支持窗口与屏幕边缘、其他窗口边缘的自动吸附

效果展示：

![拖动](https://raw.githubusercontent.com/Jy-EggRoll/mykeymap-enhance/refs/heads/main/拖动.gif)

![调节](https://raw.githubusercontent.com/Jy-EggRoll/mykeymap-enhance/refs/heads/main/调节.gif)

### 比例居中 PerCenterAndResizeWindow

针对官方函数“硬编码像素值（如 800 × 600）”的小缺陷，该函数通过“比例参数”实现智能适配不同分辨率的屏幕，实现视觉效果的统一。

效果演示：

![比例居中](https://raw.githubusercontent.com/Jy-EggRoll/mykeymap-enhance/refs/heads/main/比例居中.gif)

### 分屏拓展函数 SplitScreen

根据指定的网格数量和网格索引，将当前活动窗口调整到屏幕对应位置并设置相应大小，支持多种分屏布局（2 格、3 格、4 格、9 格），不同网格数量对应不同的屏幕分割方式。

@param {number} gridNum - 网格数量，决定分屏布局模式，支持的值：2、3、4、9

2：两格布局，支持水平分割（h1 左半屏、h2 右半屏）和垂直分割（v1 上半屏、v2 下半屏）

3：三格布局，支持水平分割（h1 左 1/3、h2 中 1/3、h3 右 1/3）和垂直分割（v1 上 1/3、v2 中 1/3、v3 下 1/3）

4：四格布局（2 \* 2 网格），索引 1-4 分别对应左上、右上、左下、右下

9：九格布局（3 \* 3 网格），索引 1-9 对应从左上到右下的 3 \* 3 网格位置

@param {number|string} gridIndex - 网格索引，标识窗口在当前网格布局中的位置

当 gridNum 为 4 或 9 时，取值为数字 1-4 或 1-9，对应网格中的具体位置

当 gridNum 为 2 时，取值为字符串 "h1"、"h2"（水平分割）或 "v1"、"v2"（垂直分割）

当 gridNum 为 3 时，取值为字符串 "h1"、"h2"、"h3"（水平分割）或 "v1"、"v2"、"v3"（垂直分割）

效果演示：

![命令分屏](https://raw.githubusercontent.com/Jy-EggRoll/mykeymap-enhance/refs/heads/main/命令分屏.gif)

### 自动激活窗口 AutoActivateWindow

解决“激活窗口的心智负担”：鼠标悬停处自动激活窗口，无需纠结“点链接会误触、点资源管理器怕选到文件、点代码编辑器会改变输入焦点”。

- **用户行为识别**：仅当鼠标 **移动后再静置 100ms 以上且移动范围超过 10 \* 10px 时** 激活窗口，鼠标移动过程中绝不触发，鼠标一直静止时绝不触发。另外，当识别到存在用户从未访问过的窗口时（即从未将鼠标移动到该窗口上），自动激活窗口功能会自动停止，一旦用户访问过该窗口，自动激活就会恢复。
  - 纯鼠标操作：非常灵敏灵敏，又不至于移动时误触发，有一定的移动容错时间
  - 纯键盘操作：完全不触发自动激活
  - 在软件内点击某超链接，跳出了某窗口，但是鼠标没有大范围移动时，不会导致误触发
  - 在软件内操作，跳出了某窗口，但是出于习惯移动了鼠标，比如在微信中点开了图片，但是由于这是一个新窗口，鼠标没有移动到该窗口上，所以不会误触发
- **全场景兼容**：内置了完善的判断逻辑，桌面、浏览器、文件资源管理器和开始菜单中的右键菜单都不会被识别为窗口并误激活，功能十分稳定。

不仅如此，该功能还对软件切换做了特殊优化。不管您是从任务栏手动切换软件，还是使用窗口列表切换，新切换出来的窗口都会被加入未访问列表，避免误触发。

效果展示（中途没有完全没有点击过鼠标左键）：

![自动激活](https://raw.githubusercontent.com/Jy-EggRoll/mykeymap-enhance/refs/heads/main/自动激活.gif)

### 亮度调节 IncBrightness & DecBrightness

不显示调节界面，更加沉浸。功能与 MyKeymap 自带的一致。显示器配置变化时（如插入外接显示器）会自动重载脚本，无需手动重启。

配合 `NextMonitor()` 和 `PreviousMonitor()` 可切换调节的显示器。

### 活动窗口边框着色 AutoWindowColorBorder

> [!WARNING]
>
> 此功能依赖于 Windows 11 DWM API，在 Windows 10 上**完全无效**。

为活动窗口添加彩色边框，与自动激活窗口相辅相成，为识别激活窗口提供多一层保障。

**颜色规则**：

- 未访问窗口：采用根据 Windows 主题色计算的对比度最强、最显眼的颜色
- 已访问窗口：采用根据 Windows 主题色计算的同色调、最显眼的颜色
- 失去焦点时：非置顶窗口会消除边框，置顶窗口保留边框颜色

![着色动态效果](https://raw.githubusercontent.com/Jy-EggRoll/mykeymap-enhance/refs/heads/main/着色动态效果.gif)

使用 `SwitchToNextColor()` 切换颜色，颜色列表在代码中自定义。

### 任务栏图标合并 SetTaskbarCombine

通过修改注册表并发送广播，优雅地切换所有显示器的任务栏合并状态，无需重启资源管理器。

- **Always**：始终合并图标
- **Never**：从不合并图标
- 空参数：自动翻转当前状态

### 平滑滚动模拟 SmoothScrollSimulate（已有弃用趋势）

按住鼠标右键并移动，模拟现代化软件中的平滑滚动效果。支持：

- 垂直滚动
- 水平滚动
- 对角线移动

在绝大多数现代化软件中可用，如浏览器。少数软件不支持，如 Windows 文件资源管理器。

### 文件快速输入 ReadFileToInput

读取文件内容并快速输入到光标位置，适用于隐私文本（如密码）的快速输入。

**限制**：

- 单行文本
- 文件大小不超过 10KB

## 额外工具

### GetWindowFeature

独立的窗口信息查看工具，可以查看窗口的标题、位置、类名、控件名等详细信息，用于开发和调试。

## 关于作者

个人网站：<https://eggroll.pages.dev/>

也欢迎浏览作者在 GitHub 上的其他项目。

祝您使用愉快。

## 统计

[![统计](https://starchart.cc/Jy-EggRoll/mykeymap-enhance.svg?variant=adaptive)](https://starchart.cc/Jy-EggRoll/mykeymap-enhance)
