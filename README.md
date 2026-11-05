# 🎬 TGBot (Telegram 机器人服务中心)

[![Release](https://img.shields.io/github/v/release/MrcolorH/TGBot?color=blue)](https://github.com/MrcolorH/TGBot/releases/latest)
[![macOS Native](https://img.shields.io/badge/macOS-SwiftUI-orange.svg)](macos_version)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg)](flutter_version)
[![Python](https://img.shields.io/badge/Python-3.10+-green.svg)](python_version)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

一个轻量、高效且功能强大的 Telegram 机器人服务中心，专注于 **Twitter / X 视频高清解析下载** 以及 **未来无限服务扩展**。

支持 **macOS 原生桌面应用**、**Android 手机独立 App** 以及 **跨平台 Python 命令行 / Termux 守护进程** 三种完整形态。

---

## 📁 仓库三版本结构一览

本项目根据不同使用场景提供三种形态的完整方案：

```text
TGBot/
├── macos_version/     # 🍎 macOS 原生桌面 UI App 版 (Swift 6 & SwiftUI 构建，全网解析/每日晨报/反重力CLI/插件热更新市场)
│   ├── build/TGBot.app    # 独立已打包的 macOS App (1.8 MB，双击即开)
│   ├── build_app.sh       # 一键编译与签名打包脚本
│   ├── Sources/           # Swift 源码 (多平台自主识别、反重力远程驱动、控制台 UI)
│   └── README.md          # macOS 版专属开发与使用文档
│
├── apk/               # 📦 已编译的独立 Android 安装包 (包含 64 位与 32 位精简版)
│   ├── TGBot_64bit_arm64.apk   # 适用现代 99% 主流安卓手机 (18.2 MB)
│   └── TGBot_32bit_arm.apk     # 适用老旧 32 位备用机 (15.8 MB)
│
├── flutter_version/   # 📱 Flutter 安卓独立 App 版 (带图形界面，插槽式服务拓展，一键打包 APK)
│   ├── android/       # Android 原生前台服务与系统保活配置
│   ├── lib/           # 纯 Dart 核心逻辑 (Telegram 客户端、Twitter 解析引擎、插槽卡片 UI)
│   ├── build_apks.sh  # 32位 / 64位 一键分架构打包脚本
│   └── README.md      # Flutter 版专属开发与使用文档
│
├── python_version/    # 🐍 Python 命令行 / Termux 守护进程版 (轻量脚本，ADB/Termux 部署)
│   ├── bot.py         # Python 核心主程序 (含 yt-dlp 强力兜底)
│   ├── deploy_android.sh  # 电脑连接安卓 ADB 一键自动化部署脚本
│   ├── start.sh       # Termux 锁屏防休眠与后台启动守护脚本
│   └── README.md      # Python 版专属使用说明
│
├── LICENSE            # MIT 开源许可证
└── README.md          # 仓库总览索引 (当前文件)
```

---

## ⚖️ 三种运行版本特性对比

| 评估维度 | 🍎 macOS 原生桌面 App 版 | 📱 Flutter 安卓独立 App 版 | 🐍 Python 命令行 / Termux 脚本版 |
| :--- | :--- | :--- | :--- |
| **运行载体** | macOS 13.0+ 桌面（Apple Silicon / Intel） | 独立 Android APK（手机直接安装运行） | Android Termux 终端 / Linux / PC / Mac |
| **操作界面** | 🎨 原生 SwiftUI 现代侧边栏 + 菜单栏托盘 | 🎨 现代化 Material 3 沉浸式图形界面 | 💻 纯终端命令行 / 日志文本流 |
| **应用体积** | ⚡️ 仅 1.7 MB (零外部运行库依赖) | 📦 约 18 MB | 🐍 需 Python 解释器与 pip 依赖包 |
| **机器人配置** | 界面图形化配置、即时验证与自动读 .env | 界面图形化输入并一键测试有效性 | 编辑 `.env` 文件写入 Token |
| **服务可扩展性** | 🧩 运行时零重启插件市场 (Hot Reload) | 🧩 插槽式卡片架构 | 编写 Python Handler 并注册 |
| **本地工具功能** | 后台静默长轮询托管与实时日志流 | 仅作为 Telegram 远程 Bot 响应 | 命令行 yt-dlp 本地下载 |
| **适用人群** | Mac 桌面用户、追求极速与零配置的用户 | 追求直观、免敲命令、移动端开箱即用 | 熟悉 Linux/Termux、追求极端定制与兜底的极客 |

---

## 🚀 快速上手指南

### 🍎 方式一：使用 macOS 原生桌面应用（Mac 用户首选）

1. **直接启动应用**：
   - 打开根目录下的 [`macos_version/build/TGBot.app`](macos_version/build/TGBot.app)；
   - 或在终端执行：
     ```bash
     open macos_version/build/TGBot.app
     ```
2. **使用说明**：
   - 在「参数设置」填入 Telegram Bot Token（若同级有 `.env` 会自动填入）；
   - 点击首页大按钮 **【启动机器人服务】** 即可开始监听；
   - 支持顶部菜单栏快捷启停，直接向 Telegram 机器人发送链接即可自动解析推送！
3. 👉 深入阅读：[`macos_version/README.md`](macos_version/README.md)

---

### 📱 方式二：使用 Flutter 安卓独立 App 版

1. **直接获取安装包**：
   - 从根目录 [`apk/`](apk/) 文件夹直接取用已编译好的安装包；
   - 或前往 [GitHub Releases 最新发布页](https://github.com/MrcolorH/TGBot/releases/latest) 下载。
   ```bash
   # 64 位主流手机安装：
   adb install -r apk/TGBot_64bit_arm64.apk
   ```
2. **启动与使用**：
   - 打开 App，点击右上角 **⚙️ 设置** 填入你的 Telegram Bot Token；
   - 点击首页大按钮 **【启动机器人服务】**；
   - 向你的机器人发送一条 Twitter/X 视频推文链接，即可秒级获取最高画质直链与按需推送视频！
3. 👉 深入阅读：[`flutter_version/README.md`](flutter_version/README.md)

---

### 🐍 方式三：使用 Python 命令行 / Termux 脚本版

1. **电脑一键 ADB 部署到手机**：
   ```bash
   cd python_version
   cp .env.example .env  # 编辑填入 TELEGRAM_BOT_TOKEN
   bash deploy_android.sh
   ```
2. **手机 Termux 本地运行**：
   ```bash
   cd python_version
   pip install -r requirements.txt
   ./start.sh
   ```
3. 👉 深入阅读：[`python_version/README.md`](python_version/README.md)

---

## 📄 开源许可证

本项目基于 [MIT License](LICENSE) 协议开源。仅供学习交流与自动化个人存档使用。
