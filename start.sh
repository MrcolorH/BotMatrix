#!/data/data/com.termux/files/usr/bin/bash
export PREFIX=/data/data/com.termux/files/usr
export PATH=$PREFIX/bin:$PATH
export LD_LIBRARY_PATH=$PREFIX/lib
export HOME=/data/data/com.termux/files/home
cd $HOME

# 防止 Android 系统 CPU 锁屏休眠
termux-wake-lock 2>/dev/null

# 停止可能已在运行的旧实例
killall python 2>/dev/null
sleep 1

# 后台静默启动 Bot
nohup python -u bot.py > bot.log 2>&1 &
echo "=============================================="
echo "🤖 Telegram Bot 已在后台启动！"
echo "📄 查看实时日志: tail -f ~/bot.log"
echo "🛑 停止运行:     killall python"
echo "=============================================="
