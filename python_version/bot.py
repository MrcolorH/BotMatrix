import re
import os
import html
import asyncio
import logging
import aiohttp
import requests
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.constants import ParseMode
from telegram.ext import (
    Application,
    CommandHandler,
    MessageHandler,
    CallbackQueryHandler,
    filters,
    ContextTypes
)
import yt_dlp

# ================= 配置区域 =================
def load_env():
    """轻量级加载本地 .env 文件，避免引入额外外部依赖"""
    env_path = os.path.join(os.path.dirname(__file__), ".env")
    if os.path.exists(env_path):
        with open(env_path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, v = line.split("=", 1)
                    os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))

load_env()

TELEGRAM_BOT_TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN", "")
TWITTERDOWN_API_KEY = os.environ.get("TWITTERDOWN_API_KEY", "")

if not TELEGRAM_BOT_TOKEN:
    raise ValueError("未检测到 TELEGRAM_BOT_TOKEN，请在环境变量或 .env 文件中配置！")
# ============================================

logging.basicConfig(
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    level=logging.INFO
)
logger = logging.getLogger(__name__)

TWITTER_REGEX = re.compile(r"https?://(?:www\.)?(?:twitter|x)\.com/[a-zA-Z0-9_]+/status/(\d+)")

# 视频数据简易内存缓存，用于支持按钮按需向 TG 推送
VIDEO_CACHE = {}

def format_size(size_bytes: int) -> str:
    if not size_bytes or size_bytes <= 0:
        return "未知大小"
    if size_bytes >= 1024 * 1024 * 1024:
        return f"{size_bytes / (1024 ** 3):.2f} GB"
    elif size_bytes >= 1024 * 1024:
        return f"{size_bytes / (1024 ** 2):.2f} MB"
    else:
        return f"{size_bytes / 1024:.1f} KB"

async def get_remote_file_size(url: str) -> str:
    """通过 HEAD 请求获取远程文件大小（只拉取标头，不消耗实际流量）"""
    try:
        async with aiohttp.ClientSession() as session:
            headers = {
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
            }
            async with session.head(url, headers=headers, allow_redirects=True, timeout=10) as resp:
                length = resp.headers.get("Content-Length")
                if length and length.isdigit():
                    return format_size(int(length))
    except Exception as e:
        logger.warning(f"获取 HEAD 大小失败: {e}")
    return "未知大小"

def resolve_via_ytdlp(tweet_url: str):
    """引擎：使用 yt-dlp 本地解析"""
    ydl_opts = {
        'quiet': True,
        'no_warnings': True,
        'skip_download': True,
    }
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        info = ydl.extract_info(tweet_url, download=False)
        formats = [
            f for f in info.get('formats', [])
            if f.get('vcodec') != 'none' and f.get('url')
        ]
        if not formats:
            raise Exception("该推文中没有找到视频流。")
        
        # 挑选最高分辨率
        best = max(formats, key=lambda x: (x.get('height') or 0, x.get('width') or 0, x.get('tbr') or 0))
        height = best.get('height')
        resolution = f"{height}p" if height else "最高画质"
        filesize = best.get('filesize') or best.get('filesize_approx')
        
        return {
            'url': best['url'],
            'resolution': resolution,
            'filesize': filesize,
            'author': info.get('uploader') or info.get('channel') or "未知",
            'title': (info.get('description') or info.get('title') or "")[:150],
            'thumbnail': info.get('thumbnail')
        }

async def resolve_via_fxtwitter(status_id: str):
    """引擎：通过 FixTweet API 获取媒体信息（自动选取最高码率 MP4 与封面图）"""
    api_url = f"https://api.fxtwitter.com/status/{status_id}"
    async with aiohttp.ClientSession() as session:
        async with session.get(api_url, timeout=10) as resp:
            if resp.status != 200:
                raise Exception("FixTweet 响应异常")
            data = await resp.json()
            tweet = data.get("tweet", {})
            media = tweet.get("media", {})
            videos = media.get("videos", [])
            if not videos:
                raise Exception("未检测到视频媒体")
            
            v = videos[0]
            formats = v.get("formats", [])
            mp4_formats = [
                f for f in formats 
                if f.get("container") == "mp4" or ".mp4" in f.get("url", "")
            ]
            
            if mp4_formats:
                best_fmt = max(mp4_formats, key=lambda x: x.get("bitrate") or 0)
                best_url = best_fmt.get("url")
            else:
                best_url = v.get("url")
                
            res_str = "最高画质"
            m = re.search(r"(\d+)x(\d+)", best_url or "")
            if m:
                res_str = f"{m.group(2)}p"
            elif v.get("height"):
                res_str = f"{v.get('height')}p"
            
            return {
                'url': best_url,
                'resolution': res_str,
                'filesize': None,
                'author': tweet.get('author', {}).get('name', 'Twitter 用户'),
                'title': tweet.get('text', '')[:150],
                'thumbnail': v.get('thumbnail_url')
            }

async def resolve_via_twitterdown(tweet_url: str):
    """引擎：通过 Twitterdown 接口解析"""
    if not TWITTERDOWN_API_KEY:
        raise Exception("未配置 TWITTERDOWN_API_KEY")
    api_url = "https://twitterdown.com/api/v1/twitter"
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {TWITTERDOWN_API_KEY}"
    }
    async with aiohttp.ClientSession() as session:
        async with session.post(api_url, json={"url": tweet_url}, headers=headers, timeout=15) as resp:
            data = await resp.json()
            if data.get("code") != 0 or not data.get("data"):
                raise Exception(data.get("message", "TwitterDown 接口返回异常"))
            res_data = data["data"]
            videos = res_data.get("videos", [])
            if not videos:
                raise Exception("未获取到视频列表")
            
            def get_num(v):
                m = re.search(r"(\d+)", str(v.get("resolution", 0)))
                return int(m.group(1)) if m else 0
            
            best = max(videos, key=get_num)
            return {
                'url': best.get('url'),
                'resolution': best.get('resolution', 'HD'),
                'filesize': None,
                'author': res_data.get('username', '未知'),
                'title': res_data.get('text', '')[:150],
                'thumbnail': res_data.get('thumbnail')
            }

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    welcome = (
        "👋 <b>你好！欢迎使用推特视频解析机器人。</b>\n\n"
        "📱 <b>运行状态</b>：部署在本地安卓设备上。\n"
        "⚡️ <b>使用方法</b>：直接向我发送一条 Twitter / X 视频推文链接即可。\n"
        "✨ 我会自动为你提取视频封面、推文内容与最高画质下载直链！"
    )
    await update.message.reply_text(welcome, parse_mode=ParseMode.HTML)

async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    text = update.message.text or ""
    match = TWITTER_REGEX.search(text)
    if not match:
        await update.message.reply_text("⚠️ 请发送有效的 Twitter / X 视频推文链接（例如：<code>https://x.com/username/status/123456</code>）", parse_mode=ParseMode.HTML)
        return

    tweet_url = match.group(0)
    status_id = match.group(1)
    status_msg = await update.message.reply_text("⏳ 正在解析视频与提取预览图，请稍候...")

    result = None
    errors = []

    # 1. 尝试 TwitterDown 官方 API（如果配置了 Key）
    if TWITTERDOWN_API_KEY:
        try:
            result = await resolve_via_twitterdown(tweet_url)
        except Exception as e:
            errors.append(f"Twitterdown: {e}")

    # 2. 尝试 FixTweet 线路（快速提取视频与封面）
    if not result:
        try:
            result = await resolve_via_fxtwitter(status_id)
        except Exception as e:
            errors.append(f"FixTweet: {e}")

    # 3. 尝试本地 yt-dlp 解析兜底
    if not result:
        try:
            loop = asyncio.get_running_loop()
            result = await loop.run_in_executor(None, resolve_via_ytdlp, tweet_url)
        except Exception as e:
            errors.append(f"yt-dlp: {e}")

    if not result or not result.get("url"):
        error_details = " | ".join(errors) if errors else "无视频或链接受限"
        await status_msg.edit_text(f"❌ 解析失败：{html.escape(error_details)}")
        return

    video_url = result["url"]
    resolution = result.get("resolution", "最高画质")
    
    # 获取文件大小
    if result.get("filesize"):
        size_str = format_size(result["filesize"])
    else:
        size_str = await get_remote_file_size(video_url)

    raw_author = str(result.get("author", "未知"))
    raw_title = str(result.get("title", "")).strip()
    thumbnail_url = result.get("thumbnail")

    # 生成规范中文文件名
    clean_title = re.sub(r'https?://\S+', '', raw_title)
    clean_title = re.sub(r'[@#]\S+', '', clean_title)
    clean_title = re.sub(r'[^\w\u4e00-\u9fa5\s_-]+', '', clean_title).strip()
    clean_title = re.sub(r'\s+', '_', clean_title)[:40]
    if not clean_title:
        clean_title = "twitter_video"
    custom_filename = f"{raw_author}_{clean_title}.mp4"

    # 存入缓存供按钮按需推送使用
    VIDEO_CACHE[status_id] = {
        'url': video_url,
        'filename': custom_filename,
        'author': raw_author,
        'title': raw_title,
        'res': resolution,
        'size': size_str
    }

    author = html.escape(raw_author)
    caption_title = html.escape(raw_title)
    title_display = f"\n💬 <b>推文内容</b>: {caption_title}\n" if caption_title else ""
    safe_filename = html.escape(custom_filename)

    reply_content = (
        f"🎬 <b>Twitter 视频解析完成</b>\n\n"
        f"👤 <b>发布者</b>: @{author}\n"
        f"📺 <b>最高分辨率</b>: <code>{resolution}</code>\n"
        f"📦 <b>视频大小</b>: <code>{size_str}</code>\n"
        f"📁 <b>建议文件名（点击复制）</b>:\n<code>{safe_filename}</code>\n"
        f"{title_display}"
    )

    # 键盘布局：直达链接 + 可选的在 TG 聊天中发送文件按钮
    keyboard = InlineKeyboardMarkup([
        [InlineKeyboardButton(f"🌐 浏览器直达下载 ({resolution} · {size_str})", url=video_url)],
        [InlineKeyboardButton("📥 发送该视频文件到聊天 (含中文名)", callback_data=f"send_vid:{status_id}")]
    ])

    # 优先发送带封面预览图的卡片，若失败则发送纯文本
    photo_sent = False
    if thumbnail_url:
        try:
            await context.bot.send_photo(
                chat_id=update.effective_chat.id,
                photo=thumbnail_url,
                caption=reply_content,
                reply_markup=keyboard,
                parse_mode=ParseMode.HTML
            )
            await status_msg.delete()
            photo_sent = True
        except Exception as pe:
            logger.info(f"发送缩略图失败，回退纯文本: {pe}")

    if not photo_sent:
        await status_msg.edit_text(
            reply_content,
            reply_markup=keyboard,
            parse_mode=ParseMode.HTML,
            disable_web_page_preview=False
        )

async def handle_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """处理内联按钮点击：按需发送视频文件"""
    query = update.callback_query
    await query.answer()
    data = query.data or ""

    if data.startswith("send_vid:"):
        status_id = data.split(":", 1)[1]
        item = VIDEO_CACHE.get(status_id)
        if not item:
            await query.message.reply_text("⚠️ 任务缓存已过期，请重新发送推文链接解析。")
            return

        hint_msg = await query.message.reply_text("⏳ 正在由 Telegram 云端向聊天推送文件，稍候...")
        try:
            # 使用 send_document 发送，Telegram 客户端保存时严格保留自定义文件名
            await context.bot.send_document(
                chat_id=update.effective_chat.id,
                document=item["url"],
                filename=item["filename"],
                caption=f"📁 <b>{html.escape(item['filename'])}</b>\n📺 <code>{item['res']}</code> · <code>{item['size']}</code>",
                parse_mode=ParseMode.HTML
            )
            await hint_msg.delete()
        except Exception as e:
            logger.error(f"按需发送视频文件失败: {e}")
            await hint_msg.edit_text(f"❌ 发送失败（可能文件超出 Telegram 云端限制）: {html.escape(str(e))}")

def main():
    logger.info("Starting Telegram Bot on Android with preview image & on-demand video send...")
    app = Application.builder().token(TELEGRAM_BOT_TOKEN).build()
    app.add_handler(CommandHandler("start", start))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))
    app.add_handler(CallbackQueryHandler(handle_callback))
    
    print("🤖 Telegram Bot 已成功启动！正在监听消息...")
    app.run_polling()

if __name__ == "__main__":
    main()
