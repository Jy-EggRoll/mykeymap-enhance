---
title: MyKeymap 自定义功能
description: 
date: 2025-08-14
lastmod: 2025-08-25
image: 
categories:
    - 技术
tags:
    - MyKeymap
weight: 
---

## 仓库链接

https://github.com/Jy-EggRoll/my-keymap/

## 使用方法

将本仓库中 `data` 目录中各子文件放入 MyKeymap 的 `data` 目录下即可，之后各个函数可以根据您的需要被 MyKeymap 调用。如果您不希望自己的设置被覆盖为我的设置，请勿替换 `config.json` 文件。

`custom_function.ahk` 仅保留和官方一样的接口，负责导入我的各个模块，本身不提供任何实际功能，所以如果希望体验全部功能，请加入全部的 ahk 文件。

## 引言

使用 [MyKeymap](https://github.com/xianyukang/MyKeymap) 已经有相当长一段时间了，学习了一部分 [AutoHotkey](https://github.com/AutoHotkey/AutoHotkey) 后，我也能独立编写一些脚本了。目前，这些脚本大都无需搭配 MyKeymap，可以直接由 AHK 调用。

值得注意的是，通过 MyKeymap 的强大扩展能力来使用我的函数是最佳实践。我的所有函数均未分配快捷键，若您需要直接通过 AHK 调用，请自行修改代码分配快捷键。

## DragWindow & ResizeWindow

两款函数支持“前置键 + 鼠标键”灵活绑定（如 Caps、鼠标侧键，请在 MyKeymap 中自行绑定），核心功能受 [AltSnap](https://github.com/RamonUnch/AltSnap) 启发，实现上参考了 AHK 官方的示例脚本。

- **DragWindow()**：按下 `Caps + 左键`（若已绑定），可直接拖动任意非最大化窗口（无需点击标题栏）
- **ResizeWindow()**：触发 `Caps + 右键`（若已绑定）后，窗口被分割为 9 个虚拟区域，右键拖动对应分区即可快捷调整大小，效率远超手动拉伸边框和边角

## PerCenterAndResizeWindow

针对官方函数“硬编码像素值（如 800 × 600）”的小缺陷，该函数通过“比例参数”实现智能适配。

**核心改进**：传入小数（如 0.95, 0.9），窗口将按当前显示器的长宽自动计算尺寸并移动窗口到居中位置。

### 分屏与定位的 8 个拓展函数

为替代 Windows 原生分屏，新增 8 个窗口控制函数，分别是：窗口置于上下左右四个半屏以及四个边角，请自行浏览代码调用需要的函数。

- **调用逻辑**：个人认为的最佳实践为，彻底替换 `Win + 方向键` 的默认功能，同时开启后文的“自动激活窗口”
- **当前问题**：Windows 存在“不可见边框”，导致窗口无法完美贴边，后续将探索解决方案

## AutoActivateWindow

解决“激活窗口的心智负担”：鼠标悬停处自动激活窗口，无需纠结“点链接会误触、点资源管理器怕选到文件、点代码编辑器会改变输入区”。

- **防误触**：仅当鼠标**静置 500 ms** 时激活窗口，移动过程中绝不触发，彻底避免操作干扰
- **全场景兼容**：修复桌面、浏览器、文件资源管理器和开始菜单中的右键菜单 bug，实现“露出边边角角就能激活”

## 关于作者

个人网站：https://eggroll.pages.dev/

也欢迎浏览作者在 GitHub 上的其他项目。

祝您使用愉快。
