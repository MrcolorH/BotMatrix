# 🎬 Telegram Twitter/X 视频高清解析下载机器人 (TGBot)

一个轻量、高效且功能强大的 Telegram 机器人，专用于解析 Twitter / X 上的视频推文。不仅能自动提取**最高清晰度直链**与**视频文件体积**，还针对手机端下载场景进行了深度优化，解决文件名乱码问题。

无需昂贵的云服务器，**一台闲置的安卓备用手机即可 7×24 小时稳定运行**。

---

## ✨ 核心特性

- 📺 **自适应最高画质**：自动比较推文下所有画质版本，优先提取 1080p / 720p 等最高分辨率。
- 📦 **毫秒级大小探测**：通过异步 HTTP `HEAD` 请求获取远程文件体积，精准标明视频大小（如 `14.25 MB`），无需下载完整文件，零额外流量消耗。
- 🖼️ **精简卡片交互**：默认仅返回推文封面预览图、作者、文本内容与文件大小，绝不主动推送原画视频刷屏。
- 📁 **中文规范文件名**：根据推文作者与内容自动生成干净的规范中文文件名（去除特殊标点符号），并在卡片中提供**单触一键复制**，方便浏览器下载另存为时直接粘贴替换。
- 📥 **按需推送视频到 Telegram**：卡片底部配备独立按需按钮，点击后才会由 Telegram 将视频文件以中文描述推送到聊天框，不点绝不发。
- 🚀 **零设备梯子流量消耗**：Telegram 文件推送采用官方云端 URL 转发机制，视频流由 Telegram 欧美数据中心直接搬运，**全程不消耗本地安卓设备的梯子流量**。
- 🛡️ **多引擎多重保障**：
  1. 支持对接 [TwitterDown](https://twitterdown.com) 官方 API；
  2. 内置高效免 Key 引擎（FixTweet API）；
  3. 内置强大的本地 `yt-dlp` 解析兜底，确保推文在各种限制下均可稳定解析。

---

## 📁 目录结构

```text
.
├── bot.py               # 机器人核心主程序
├── deploy_android.sh    # 电脑连接安卓设备一键部署脚本 (ADB)
├── start.sh             # Termux 端后台守护启动脚本
├── requirements.txt     # Python 依赖清单
├── .env.example         # 环境变量配置模板
├── .gitignore           # Git 忽略配置
└── README.md            # 项目使用说明文档
```

---

## 🛠️ 配置说明

在运行前，请先复制配置模板并填入你的 Telegram Bot Token：

```bash
cp .env.example .env
```

编辑 `.env` 文件：
```ini
# 从 Telegram 官方 @BotFather 申请获得的 Bot Token (必填)
TELEGRAM_BOT_TOKEN=1234567890:ABCdefGhIJKlmNoPQRsTUVwxyZ

# TwitterDown 官方 API Key (可选，留空会自动使用内置免费解析引擎)
TWITTERDOWN_API_KEY=
```

---

## 📱 安卓设备部署指南

你可以使用任何一台闲置的 Android 手机（Android 7.0+，推荐 Android 11+）作为机器人的运行主机。

### 方式一：电脑一键自动化部署（推荐，极简）

本仓库提供了 `deploy_android.sh` 脚本，可通过电脑 `adb` 工具自动完成手机端 Termux 安装、Python 环境搭建、依赖安装、源码传输与后台自启。

#### 1. 准备连接
- 确保手机和电脑处于**同一个局域网 WiFi** 下；
- 手机进入【设置】➔【开发者选项】➔ 开启【无线调试】（或直接通过 USB 数据线插在电脑上）；
- 如果使用无线调试，在电脑终端执行配对与连接：
  ```bash
  # 配对 (仅首次需要，端口和配对码在手机“使用配对码配对设备”中查看)
  adb pair 192.168.x.x:配对端口 6位配对码

  # 连接 (端口在无线调试主界面查看)
  adb connect 192.168.x.x:连接端口
  ```

#### 2. 执行一键部署
确保当前电脑目录已有配好 Token 的 `.env` 文件，直接运行：
```bash
bash deploy_android.sh
```
脚本将全自动在手机上安装 Termux、搭建 Python 3 环境、安装依赖并将机器人挂载在后台常驻运行！

---

### 方式二：安卓手机本地手动部署

如果你习惯直接在手机上操作，也可以直接在手机打开 **Termux**：

1. **下载安装 Termux**：前往 [F-Droid Termux 镜像页面](https://f-droid.org/en/packages/com.termux/) 下载并安装 apk（勿用 Google Play 过时版本）。
2. **安装基础环境**：
   ```bash
   pkg update -y && pkg upgrade -y
   pkg install python git clang -y
   ```
3. **获取源码并安装依赖**：
   ```bash
   git clone https://github.com/MrcolorH/TGBot.git ~/TGBot
   cd ~/TGBot
   pip install --break-system-packages -r requirements.txt
   ```
4. **配置环境变量**：
   ```bash
   cp .env.example .env
   nano .env  # 填入你的 TELEGRAM_BOT_TOKEN，按 Ctrl+O 保存，Ctrl+X 退出
   ```
5. **防止锁屏休眠与后台启动**：
   ```bash
   chmod +x start.sh
   ./start.sh
   ```

---

## 💻 电脑或云服务器部署

如果在 Mac、Linux 服务器或 Windows 上运行：

```bash
# 1. 克隆仓库
git clone https://github.com/MrcolorH/TGBot.git
cd TGBot

# 2. 安装依赖
pip install -r requirements.txt

# 3. 配置 .env
cp .env.example .env
# 编辑 .env 填入你的 Token

# 4. 运行
python bot.py
```

---

## 🔋 安卓后台长效保活建议（非常重要）

为了让机器人 7×24 小时保持在线、锁屏不掉线，请在手机上进行以下简单设置：

1. **执行防休眠指令**：
   在 Termux 中执行 `termux-wake-lock`（`start.sh` 脚本已内置自动调用），通知栏会显示常驻图标以保持 CPU 运转。
2. **关闭系统电池优化**：
   前往手机系统【设置】➔【应用管理】➔ 找到【Termux】➔【省电策略 / 电池优化】改为 **“无限制 / 允许后台高耗电”**。
3. **后台锁定应用卡片**：
   在手机的多任务后台界面中，长按 Termux 卡片并点击 **“加锁”** 图标，防止被一键清理杀死。

---

## 📋 常用运维命令

| 操作 | 命令 |
| :--- | :--- |
| **查看实时运行日志** | `adb shell "run-as com.termux tail -f /data/data/com.termux/files/home/bot.log"` (电脑端)<br>`tail -f ~/bot.log` (手机 Termux 本地) |
| **停止机器人** | `killall python` |
| **重启机器人** | `~/TGBot/start.sh` 或 `~/start.sh` |

---

## 📄 开源许可证

本项目基于 [MIT License](LICENSE) 开源。仅供学习交流与自动化个人存档使用。
