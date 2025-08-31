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

> [!TIP]
>
> 通过 MyKeymap 的强大扩展能力来使用我的函数是最佳实践。我的所有函数均未分配快捷键，若您需要直接通过 AHK 调用，请自行修改代码分配快捷键。

## 自定义函数表

> [!TIP]
>
> 由于 GitHub 对于自定义 CSS 的表格支持不佳，请在我的博客查看函数表。文章剩余部分也是一致的，您可以直接继续浏览全文。

<https://eggroll.pages.dev/p/%E9%A1%B9%E7%9B%AE%E4%BB%8B%E7%BB%8Dmy-keymap/#%E8%87%AA%E5%AE%9A%E4%B9%89%E5%87%BD%E6%95%B0%E8%A1%A8>

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
