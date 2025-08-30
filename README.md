---
title: 项目介绍——my-keymap
description: 
date: 2025-08-14
lastmod: 2025-08-29
image: 
categories:
    - 项目
tags:
    - MyKeymap
    - AutoHotkey
    - GitHub
weight: 
---

## 仓库链接

<https://github.com/Jy-EggRoll/my-keymap/>

## 使用方法

将本仓库中 `data` 目录中各子文件放入 MyKeymap 的 `data` 目录下即可，之后各个函数可以根据您的需要被 MyKeymap 调用。

> [!WARNING]
>
> 如果您不希望自己的设置被覆盖为我的设置，请勿替换 `config.json` 文件。

`custom_function.ahk` 仅保留和官方一样的接口，负责导入我的各个模块，本身不提供任何实际功能，所以如果希望体验全部功能，请加入全部的 ahk 文件。

## 引言

使用 [MyKeymap](https://github.com/xianyukang/MyKeymap) 已经有相当长一段时间了，学习了一部分 [AutoHotkey](https://github.com/AutoHotkey/AutoHotkey) 后，我也能独立编写一些脚本了。目前，这些脚本大都无需搭配 MyKeymap，可以直接由 AHK 调用。

值得注意的是，通过 MyKeymap 的强大扩展能力来使用我的函数是最佳实践。我的所有函数均未分配快捷键，若您需要直接通过 AHK 调用，请自行修改代码分配快捷键。

## 自定义函数表

|函数名|参数说明|功能|最佳实践|
|-|-|-|-|
|DragWindow()|无参数|直接拖动任意非最大化窗口（无需点击标题栏）|绑定到前置键+鼠标左键，例如 <kbd>Caps</kbd> + 鼠标左键|
ResizeWindow()|无参数|直接调整任意非最大化窗口的大小（无需定位到边框），窗口会被划分为 9 个区域，拖动对应区域即可完成调节，上手一试便知|绑定到前置键+鼠标右键，例如 <kbd>Caps</kbd> + 鼠标右键|
|PerCenterAndResizeWindow(percentageW, percentageH)|小数，宽度占屏幕的比例（0-1），高度占屏幕的比例（0-1）|调整窗口大小并居中，智能适应不同分辨率屏幕的不同缩放系数|自定义快捷键|
|Per*AndResizeWindow(percentageW, percentageH)|小数，宽度占屏幕的比例（0-1），高度占屏幕的比例（0-1）|* 替换为 Left、Down、Right、Up、LeftUp、LeftDown、RightUp、RightDown，负责分屏和边角|前四个功能完全替换默认的 <kbd>Win</kbd> + 方向键，后四个替换为合适的快捷键|
AutoActivateWindow()|无参数|开关函数，未启动时调用则启动，已启动调用则停止，默认随 MyKeymap 启动|绑定一个快捷键方便随时启停|
|IncBrightness(dealt)|整数，一个百分比值，如 5|增加屏幕亮度，默认为 1 号显示器，每次 MyKeymap 启动重置为 1 号显示器|自定义为合适的快捷键|
|DecBrightness(dealt)|整数，一个百分比值，如 5|降低屏幕亮度，默认为 1 号显示器，每次 MyKeymap 启动重置为 1 号显示器|自定义为合适的快捷键|
|NextMonitor()|无参数|调整下一个显示器的亮度，只要 MyKeymap 不重启，锁定的显示器就不会再变|自定义为合适的快捷键|
|PreviousMonitor()|无参数|调整下一个显示器的亮度，只要 MyKeymap 不重启，锁定的显示器就不会再变|自定义为合适的快捷键|

## 额外说明

### DragWindow & ResizeWindow

两款函数核心功能受 [AltSnap](https://github.com/RamonUnch/AltSnap) 启发，实现上参考了 AHK 官方的示例脚本。

### PerCenterAndResizeWindow

针对官方函数“硬编码像素值（如 800 × 600）”的小缺陷，该函数通过“比例参数”实现智能适配。

### 分屏与定位的 8 个拓展函数

为替代 Windows 原生分屏，新增 8 个窗口控制函数，分别是：窗口置于上下左右四个半屏以及四个边角。

### AutoActivateWindow

解决“激活窗口的心智负担”：鼠标悬停处自动激活窗口，无需纠结“点链接会误触、点资源管理器怕选到文件、点代码编辑器会改变输入焦点”。

- **防误触**：仅当鼠标**静置 500 ms** 时激活窗口，移动过程中绝不触发，彻底避免操作干扰
- **全场景兼容**：修复桌面、浏览器、文件资源管理器和开始菜单中的右键菜单 bug，实现“露出边边角角就能激活”

### 亮度调节函数

不显示调节界面，更加沉浸。

## 关于作者

个人网站：<https://eggroll.pages.dev/>

也欢迎浏览作者在 GitHub 上的其他项目。

祝您使用愉快。
