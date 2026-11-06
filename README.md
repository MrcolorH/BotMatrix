# 🌐 BotMatrix (多平台智能机器人控制中枢与工作站)

[![Release](https://img.shields.io/github/v/release/MrcolorH/BotMatrix?color=blue)](https://github.com/MrcolorH/BotMatrix/releases/latest)
[![macOS Native](https://img.shields.io/badge/macOS-SwiftUI%20%7C%20TG%20%2B%20QQ-orange.svg)](macos_version)
[![Flutter](https://img.shields.io/badge/Android-Flutter%203.x-blue.svg)](flutter_version)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**BotMatrix** 是一款现代化、高性能的多平台机器人控制中枢与工作站。从最初的单一 Telegram 机器人升级拓展为集 **Telegram** 与 **QQ** 双平台驱动、**本地 AI 大模型终端调度**、**全网视频智能嗅探解析**、**每日晨报定时推送**与**动态插件市场**于一体的综合智能自动化中枢。

针对桌面与移动端不同场景，本项目提供两个深度打磨的专属形态：

- 🍎 **macOS 原生控制中枢**：采用 Swift 6 & SwiftUI 纯原生打造，开箱支持 Telegram + QQ 双机器人并行接入、反重力 (AGY) 本地 AI 大模型对话调度、全网视频解析、晨报订阅、NapCat OneBot 框架无感集成与双模权限防护。
- 📱 **Android 独立 App 版**：基于 Flutter 与原生 Android 前台服务构建，手机独立安装，7×24 小时后台保活运行，专注 Telegram 机器人的全网视频解析与交互。

> [!IMPORTANT]
> **🌐 网络环境提示（反重力 AI 与代理配置）**：
> - **使用反重力 (AGY) AI 必须挂魔法**：由于 AGY 本地 AI 底层调用 Google / Gemini 相关大模型链路，**Mac 宿主机必须开启魔法 / 科学上网环境（推荐使用 Clash / Surge / Quantumult X 的 TUN 虚拟网卡模式或全局系统代理）**，否则 AGY CLI 无法连通服务并会出现超时报错。
> - **海外平台与国内平台**：Telegram Bot 长轮询及 Twitter / YouTube 视频解析同样需走代理链路；QQ 机器人与中国大陆视频解析（Bilibili、抖音等）均原生支持国内直连。

---

## 📁 核心架构与仓库目录

```text
.
├── macos_version/     # 🍎 macOS 原生桌面工作站 (SwiftUI 原生架构，双端 Bot + AI 智能中枢)
│   ├── build/TGBot.app    # 独立免安装 macOS App Bundle (双击即开)
│   ├── build_app.sh       # 一键 Release 编译与代码签名脚本
│   ├── Sources/           # 原生 Swift 源码
│   │   ├── Core/          # TG/QQ 控制器、NapCat 服务、存储与会话管理
│   │   ├── Modules/       # AI 调度 (AgyModule)、全网视频解析、晨报推送、动态插件
│   │   └── UI/            # 现代 SwiftUI 侧边栏与控制台视图
│   └── README.md          # macOS 版专属开发与功能手册
│
├── flutter_version/   # 📱 Flutter 安卓移动端 App (纯 Dart 异步驱动 + Android 原生前台保活)
│   ├── android/       # Android 原生前台服务与系统保活唤醒配置
│   ├── lib/           # 核心控制器、Telegram 客户端、模块插槽卡片
│   ├── build_apks.sh  # 一键分架构编译脚本 (arm64-v8a / armeabi-v7a)
│   └── README.md      # Android 版专属开发与使用文档
│
├── LICENSE            # MIT 开源许可证
└── README.md          # 仓库总览索引 (当前文件)
```

---

## ⚖️ 平台版本特性横向对比

| 核心特性 | 🍎 macOS 原生工作站 (`macos_version`) | 📱 Android 移动端 App (`flutter_version`) |
| :--- | :--- | :--- |
| **支持平台** | Telegram + QQ (双机器人并行监听) | Telegram |
| **开发架构** | Swift 6 / SwiftUI (macOS 13.0+) | Flutter 3.x / Dart (Android 8.0+) |
| **内存与体积** | 仅约 2 MB 单文件 App，极速瞬开 | 独立 APK 约 18 MB，无需依赖额外运行环境 |
| **AI 对话集成** | 🤖 深度集成本地反重力 (AGY) CLI 远程调度 | — |
| **QQ 生态支持** | 🐧 内置 NapCat OneBot 协议栈与图形化快捷扫码登录 | — |
| **全网视频解析** | 🎬 Twitter/X、TikTok/抖音、B站、YouTube 自动识别 | 🐦 Twitter/X 视频最高画质智能解析 |
| **防社死设计** | 🛡️ 封面与文字双重剧透遮罩、一键可逆折叠、超时自隐 | 🪟 简洁卡片直发 |
| **定时任务** | ☀️ 每日 60s 晨报广播（支持 TG 频道/群组与 QQ 好友/群） | — |
| **扩展能力** | 🧩 运行时热重载脚本插件系统与插件市场 | 🧩 静态插槽式模块化总线 |
| **权限防护** | 👑 系统所有者 (Master Admin) + 沙箱白名单严格隔离 | ⚙️ 统一管理员 Token 配置 |
| **后台运行** | 菜单栏托盘常驻 + 后台静默持续轮询 | 原生前台常驻通知栏 + CPU 唤醒锁 (WakeLock) |

---

## 🚀 快速上手指南

### 🍎 1. macOS 原生应用（桌面推荐）

1. **直接启动**：
   - 运行位于 [`macos_version/build/TGBot.app`](macos_version/build/TGBot.app) 的桌面应用；
   - 或在终端输入：
     ```bash
     open macos_version/build/TGBot.app
     ```
2. **多端配置**：
   - **Telegram**：在设置页填写 Bot Token，点击「启动 Telegram」；
   - **QQ 机器人**：进入 QQ 设置页，支持一键拉起 NapCat 扫码快捷登录；
   - **本地 AI 调度**：配置 AGY 路径与会话预设人设，即可在 TG/QQ 中随时 `@机器人` 或发送 `/ai <问题>` 进行远程 AI 交互；
   - **系统所有者**：填入管理员 User ID，解锁宿主终端状态读取与高级维护能力。
3. 👉 详见：[`macos_version/README.md`](macos_version/README.md)

---

### 📱 2. Android 独立 App（移动随身）

1. **获取与安装**：
   - 可在 [GitHub Releases 页面](https://github.com/MrcolorH/BotMatrix/releases) 下载安装包；
   - 或在 `flutter_version` 目录执行打包：
     ```bash
     cd flutter_version
     ./build_apks.sh
     ```
2. **配置与使用**：
   - 打开 App，在设置面板中填入 Telegram Bot Token；
   - 点击首页 **【启动机器人服务】**；
   - 向机器人发送推文链接，即可秒级获取高清无水印视频。
3. 👉 详见：[`flutter_version/README.md`](flutter_version/README.md)

---

## 📄 开源许可证

本项目基于 [MIT License](LICENSE) 协议开源。仅供技术学习交流与个人自动化工作流使用。
