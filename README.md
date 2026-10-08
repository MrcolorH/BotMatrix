# 🎬 TGBot (Telegram 机器人服务中心)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg)](flutter_version)
[![Python](https://img.shields.io/badge/Python-3.10+-green.svg)](python_version)

本项目提供两种形态的 Telegram 机器人运行与部署方案，专注于推文视频高清解析与扩展服务：

```text
TGBot/
├── python_version/    # 🐍 Python 命令行 / Termux 守护进程版 (轻量脚本，ADB/Termux 部署)
├── flutter_version/   # 📱 Flutter 安卓独立 App 版 (带图形界面，插槽式服务拓展，一键打包 APK)
├── LICENSE            # 开源许可证 (MIT)
└── README.md          # 仓库总览索引
```

---

## 📂 版本分类与归档说明

### 1. 📱 [Flutter 独立安卓 App 版 (`flutter_version/`)](flutter_version)
- **定位**：独立的 Android APK 应用，完全脱离 Termux 命令行。
- **特性**：
  - 🎨 **图形化操作界面**：Material 3 现代界面，支持可视化输入 Telegram Bot Token 与一键连接测试。
  - 🧩 **插槽式服务架构**：将回复能力抽象为动态服务卡片（内置首期 Twitter/X 视频解析，预留未来无限扩展插槽，UI 一次成型无需重构）。
  - 🔋 **7×24 小时前台保活**：基于 Android 系统前台服务（Foreground Service）常驻通知栏，防息屏休眠与系统查杀。
  - 📦 **打包极简**：进入 `flutter_version` 目录执行 `flutter build apk --release` 即可生成安装包。
- 👉 **查看详情**：请参阅 [`flutter_version/README.md`](flutter_version/README.md)

---

### 2. 🐍 [Python 命令行 / Termux 脚本版 (`python_version/`)](python_version)
- **定位**：轻量级 Python 原生后台脚本，专用于电脑终端、Linux 服务器或安卓手机 Termux 运行。
- **特性**：
  - 🛠️ 纯 Python 3 + `python-telegram-bot` 架构。
  - 🛡️ 集成 TwitterDown API、FixTweet API 与本地 `yt-dlp` 多重兜底解析。
  - ⚡️ 提供电脑一键 ADB 推送部署脚本 (`deploy_android.sh`) 与 Termux 保活脚本 (`start.sh`)。
- 👉 **查看详情**：请参阅 [`python_version/README.md`](python_version/README.md)

---

## 📄 开源许可证

本项目基于 [MIT License](LICENSE) 开源。仅供学习交流与自动化个人存档使用。
