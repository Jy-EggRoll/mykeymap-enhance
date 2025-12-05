---
title: 项目介绍——mykeymap-enhance
description: 我的 MyKeymap 自定义功能仓库，不依赖于 MyKeymap 就可以运行，可以视为我的自定义 AutoHotkey 库 | My MyKeymap custom function repository runs without relying on MyKeymap and can be considered my custom AutoHotkey library
date: 2025-08-14
lastmod: 2025-12-05
image: 
categories:
    - 项目
tags:
    - MyKeymap
    - AutoHotkey
    - GitHub
weight: 
---

## 重要说明

此文章暂时处于“不精确”的状态，因为最近有几项重大优化和改动正在开发中，预计会在 2025 年底完成，届时我会更新本文档以反映最新的状态。

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
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">描述较长，见下文，该函数是对上面两个函数的进一步封装</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">使用 MyKeymap 的命令实现分屏，如 41、92</td>
    </tr>
    <tr>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">AutoActivateWindow(pollingTime := 50)</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">pollingTime：轮询时间，默认为 50 ms</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">开关函数，未启动时调用则启动，已启动调用则停止，默认随 MyKeymap 启动</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">绑定一个快捷键或一个指令，方便随时启停</td>
    </tr>
    <tr>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">IncBrightness(dealt)</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">整数，一个百分比值，如 5</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">增加屏幕亮度，默认为 1 号显示器，每次 MyKeymap 启动重置为 1 号显示器</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">自定义为合适的快捷键或指令</td>
    </tr>
    <tr>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">DecBrightness(dealt)</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">整数，一个百分比值，如 5</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">降低屏幕亮度，默认为 1 号显示器，每次 MyKeymap 启动重置为 1 号显示器</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">自定义为合适的快捷键或指令</td>
    </tr>
    <tr>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">NextMonitor()</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">无参数</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">调整下一个显示器的亮度，只要 MyKeymap 不重启，当前被调节的显示器就不会再改变，直到触发该函数</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">自定义为合适的快捷键或指令</td>
    </tr>
    <tr>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">PreviousMonitor()</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">无参数</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">调整上一个显示器的亮度，只要 MyKeymap 不重启，当前被调节的显示器就不会再改变，直到触发该函数</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">自定义为合适的快捷键或指令</td>
    </tr>
    <tr>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">AutoWindowColorBorder()</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">无参数</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">开关函数，未启动时调用则启动，已启动调用则停止，默认随 MyKeymap 启动</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">绑定一个快捷键或一个指令，方便随时启停</td>
    </tr>
    <tr>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">SwitchToNextColor()</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">无参数</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">切换到下一个边框颜色，达到最后一个则循环到第一个，颜色列表请在代码中自定义</td>
      <td style="padding: 10px; border: 2px solid; overflow-wrap: anywhere;">自定义为合适的快捷键或指令</td>
    </tr>
  </tbody>
</table>

## 各函数最佳实践的配置方式

暂未补全。

## 额外说明

### 平滑滚动 SmoothScrollSimulate

由于作者本人深爱触摸板和触摸屏的滚动体验，遂开发了该功能以模拟现代化软件中的平滑滚动效果。由于帧率有限，录屏无法展示出真实的滚动效果，建议亲自体验。目前理论最高达 100 FPS，由于大多数软件自带了“平滑滚动”功能，实际体验会更好。

### 拖动与调节 DragWindow & ResizeWindow

两款函数核心功能受 [AltSnap](https://github.com/RamonUnch/AltSnap) 启发，实现上参考了 AHK 官方的示例脚本。

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

- **用户行为识别**：仅当鼠标 **移动后再静置 50 ms 以上且移动范围超过 10 \* 10 px 时** 激活窗口，鼠标移动过程中绝不触发，鼠标一直静止时绝不触发。另外，当识别到存在用户从未访问过的窗口时（即从未将鼠标移动到该窗口上），自动激活窗口功能会自动停止，一旦用户访问过该窗口，自动激活就会恢复。
  - 纯鼠标操作：非常灵敏灵敏，又不至于移动时误触发，有一定的移动容错时间
  - 纯键盘操作：完全不触发自动激活
  - 在软件内点击某超链接，跳出了某窗口，但是鼠标没有大范围移动时，不会导致误触发
  - 在软件内操作，跳出了某窗口，但是出于习惯移动了鼠标，比如在微信中点开了图片，但是由于这是一个新窗口，鼠标没有移动到该窗口上，所以不会误触发
- **全场景兼容**：内置了完善的判断逻辑，桌面、浏览器、文件资源管理器和开始菜单中的右键菜单都不会被识别为窗口并误激活，功能十分稳定。

不仅如此，该功能还对软件切换做了特殊优化。不管您是从任务栏手动切换软件，还是使用窗口列表切换，新切换出来的窗口都会被加入未访问列表，避免误触发。

效果展示（中途没有完全没有点击过鼠标左键）：

![自动激活](https://raw.githubusercontent.com/Jy-EggRoll/mykeymap-enhance/refs/heads/main/自动激活.gif)

### 亮度调节 IncBrightness & DecBrightness

不显示调节界面，更加沉浸。功能与 MyKeymap 自带的一致。由于不显示 GUI，显示器状态状态变化时（如插入了外接显示器）需要重启 MyKeymap，以保证功能正常（当状态变化时，尝试调用该功能会自动出现提示）。

### 活动窗口边框着色 AutoWindowColorBorder

> [!WARNING]
>
> 此功能依赖于 Windows 11 API，在 Windows 10 上 **完全无效**。

Windows 11 自带类似功能，其效果实在不能令人满意。对于第三方软件，更是常常出现失效的情况，比如微信就无法享受该效果。

我使用 AHK 调用系统核心 API，实现了该效果，对第三方软件兼容性极佳，效果也很好。

该功能默认随 MyKeymap 启动，和自动激活窗口相辅相成，为识别激活的窗口又多了一层保障。

效果展示：

![着色](https://raw.githubusercontent.com/Jy-EggRoll/mykeymap-enhance/refs/heads/main/边框着色.png)

动态效果如下（请留意紫色的边框）：

![着色动态效果](https://raw.githubusercontent.com/Jy-EggRoll/mykeymap-enhance/refs/heads/main/着色动态效果.gif)

如果颜色不合适，请使用 SwitchToNextColor() 来切换颜色，颜色列表在代码中自定义。目前颜色可以随着系统主题自动变更，深色主题对应无后缀列表，浅色主题对应 Mode2 列表。两种模式的默认边框颜色分别如下：

![深色模式-Peach](https://raw.githubusercontent.com/Jy-EggRoll/mykeymap-enhance/refs/heads/main/Peach.png)

![浅色模式](https://raw.githubusercontent.com/Jy-EggRoll/mykeymap-enhance/refs/heads/main/Mauve.png)

> [!TIP]
>
> 已有的颜色边框，其颜色不会立即随着系统主题变更而刷新。颜色列表会在主题变更后第一次创建着色边框时刷新。换言之，如果想要在修改系统主题色后立即看到当前应用的边框色的更改，请令其失去焦点再获得焦点。

该功能在特定软件上的已知问题：

在 VSCode 较新的版本中，VSCode 自己会尝试用主题设置接管窗口边框着色的功能（假如主题指定了边框色），这可能导致冲突，从而出现颜色时不时失效，甚至显示其他颜色边框的问题。

解决方法是将 VSCode 的 `window.border` 设为 `system` 而非 `default`，这样就可以始终遵循本功能的设置。

## 关于作者

个人网站：<https://eggroll.pages.dev/>

也欢迎浏览作者在 GitHub 上的其他项目。

祝您使用愉快。

## 关于 `file-link-manager-links.json`

这个是我的另一个软件建立的，维护着该仓库到我 MyKeymap 真实目录的硬链接关系，实现了开发仓库和使用仓库的分离（这有助于让我更好地管理和维护该通用仓库）。如果您不使用该软件，可以忽略此文件。该软件由 Go 语言编写，尚在开发阶段，敬请期待。

## 统计

[![统计](https://starchart.cc/Jy-EggRoll/mykeymap-enhance.svg?variant=adaptive)](https://starchart.cc/Jy-EggRoll/mykeymap-enhance)
