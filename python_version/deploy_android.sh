#!/usr/bin/env bash
# ==============================================================================
# Telegram Twitter Video Downloader Bot - 安卓设备一键部署脚本
# 使用方法：
#   1. 电脑连接安卓设备（USB 调试或无线调试配对成功）
#   2. 确保已复制 .env.example 为 .env 并填入你的 TELEGRAM_BOT_TOKEN
#   3. 执行: bash deploy_android.sh
# ==============================================================================

set -e

echo "🚀 开始检查部署环境..."

# 1. 检查 ADB
if ! command -v adb &> /dev/null; then
    if [ -f "$HOME/Library/Android/sdk/platform-tools/adb" ]; then
        export PATH="$HOME/Library/Android/sdk/platform-tools:$PATH"
    else
        echo "❌ 未检测到 adb 工具，请先安装 Android SDK Platform-Tools 或配置 PATH。"
        exit 1
    fi
fi

# 2. 检查设备连接
DEVICE_COUNT=$(adb devices | grep -v "List" | grep "device" | wc -l | tr -d ' ')
if [ "$DEVICE_COUNT" -eq "0" ]; then
    echo "❌ 未检测到已连接的安卓设备，请确保已插线或通过 adb pair / connect 连接。"
    exit 1
fi
echo "✅ 检测到安卓设备已连接！"

# 3. 检查 .env
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    if [ -f "$SCRIPT_DIR/.env.example" ]; then
        echo "⚠️ 未找到 .env 文件，正在从 .env.example 复制，请编辑后重新运行..."
        cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
        echo "👉 请打开 $SCRIPT_DIR/.env 填入你的 TELEGRAM_BOT_TOKEN。"
        exit 1
    fi
fi

# 4. 检查是否安装 Termux
echo "📱 检查安卓端 Termux 状态..."
TERMUX_INSTALLED=$(adb shell "pm list packages | grep com.termux" || true)
if [ -z "$TERMUX_INSTALLED" ]; then
    echo "📦 正在下载并安装 Termux (arm64-v8a)..."
    APK_URL="https://github.com/termux/termux-app/releases/download/v0.118.3/termux-app_v0.118.3%2Bgithub-debug_arm64-v8a.apk"
    curl -L "$APK_URL" -o /tmp/termux.apk
    adb install -r /tmp/termux.apk
    rm -f /tmp/termux.apk
    echo "✅ Termux 安装完成！"
    adb shell "am start -n com.termux/.app.TermuxActivity"
    echo "⏳ 等待 Termux 初始化环境 (5秒)..."
    sleep 5
fi

# 5. 安装 Python 与运行依赖
echo "🐍 正在配置 Termux Python 环境..."
adb shell "run-as com.termux sh -c '
export PREFIX=/data/data/com.termux/files/usr
export PATH=\$PREFIX/bin:\$PATH
export LD_LIBRARY_PATH=\$PREFIX/lib
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y python python-pip
pip install --break-system-packages python-telegram-bot requests aiohttp yt-dlp
'"

# 6. 推送源码与配置文件
echo "📂 推送 Bot 源码与配置文件到手机..."
adb push "$SCRIPT_DIR/bot.py" /data/local/tmp/bot.py
adb push "$SCRIPT_DIR/start.sh" /data/local/tmp/start.sh
adb push "$SCRIPT_DIR/.env" /data/local/tmp/.env

adb shell "run-as com.termux sh -c '
cp /data/local/tmp/bot.py /data/data/com.termux/files/home/bot.py
cp /data/local/tmp/start.sh /data/data/com.termux/files/home/start.sh
cp /data/local/tmp/.env /data/data/com.termux/files/home/.env
chmod +x /data/data/com.termux/files/home/start.sh
'"

# 7. 加入电池优化白名单 (防止锁屏休眠)
echo "🔋 配置防休眠与白名单..."
adb shell "dumpsys deviceidle whitelist +com.termux" 2>/dev/null || true

# 8. 启动 Bot
echo "▶️ 启动 Telegram Bot..."
adb shell "run-as com.termux /data/data/com.termux/files/home/start.sh"

echo "🎉 部署完成！Bot 已经在你的安卓手机后台稳定运行。"
echo "💡 查看日志命令: adb shell \"run-as com.termux tail -f /data/data/com.termux/files/home/bot.log\""
