import 'package:flutter/material.dart';
import '../../core/models/telegram_models.dart';
import '../../core/models/video_parse_result.dart';
import '../../core/services/log_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/telegram_bot_client.dart';
import '../base_module.dart';
import 'twitter_resolvers.dart';

class TwitterModule extends BotServiceModule {
  @override
  final String id = 'twitter_resolver';

  @override
  final String name = 'Twitter / X 视频解析';

  @override
  final String description =
      '自动提取推文视频最高画质、体积与封面，生成规范中文文件名，支持单触复制及按需由 Telegram 推送。';

  @override
  final IconData icon = Icons.play_circle_filled_rounded;

  bool _isEnabled = true;
  @override
  bool get isEnabled => _isEnabled;
  @override
  set isEnabled(bool value) => _isEnabled = value;

  String twitterDownApiKey = '';

  // 任务简易内存缓存，用于支持内联按钮按需推送到聊天
  final Map<String, CachedVideoItem> _videoCache = {};

  @override
  Future<void> init(StorageService storage) async {
    _isEnabled = storage.isModuleEnabled(id, defaultValue: true);
    twitterDownApiKey = storage.getModuleSetting(id, 'twitterdown_api_key');
  }

  @override
  Future<void> saveSettings(StorageService storage) async {
    await storage.setModuleEnabled(id, _isEnabled);
    await storage.setModuleSetting(id, 'twitterdown_api_key', twitterDownApiKey);
  }

  @override
  Widget? buildSettingsWidget(BuildContext context, VoidCallback onSettingsChanged) {
    final keyController = TextEditingController(text: twitterDownApiKey);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        TextField(
          controller: keyController,
          decoration: const InputDecoration(
            labelText: 'TwitterDown 官方 API Key (可选)',
            hintText: '留空将全自动采用内置免费解析引擎',
            border: OutlineInputBorder(),
            isDense: true,
            prefixIcon: Icon(Icons.vpn_key_outlined),
          ),
          onChanged: (val) {
            twitterDownApiKey = val;
            onSettingsChanged();
          },
        ),
        const SizedBox(height: 6),
        Text(
          '💡 提示：内置了 FixTweet 与备用开放解析线路，无需填写 API Key 即可稳定免费使用。',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }

  @override
  bool canHandle(TelegramMessage message) {
    if (!_isEnabled) return false;
    final text = message.text ?? '';
    return TwitterResolvers.twitterRegex.hasMatch(text);
  }

  @override
  Future<void> handleMessage(
    TelegramMessage message,
    TelegramBotClient botClient,
    LogService logger,
  ) async {
    final text = message.text ?? '';
    final match = TwitterResolvers.twitterRegex.firstMatch(text);
    if (match == null) return;

    final tweetUrl = match.group(0)!;
    final statusId = match.group(1)!;
    final chatId = message.chat.id;

    logger.info('Twitter', '开始解析推文: $tweetUrl (ID: $statusId)');

    final statusMsgId = await botClient.sendMessage(
      chatId,
      '⏳ 正在解析视频与提取预览图，请稍候...',
    );

    VideoParseResult? result;
    final List<String> errors = [];

    // 1. 如果配置了 TwitterDown Key，优先使用
    if (twitterDownApiKey.isNotEmpty) {
      try {
        result = await TwitterResolvers.resolveViaTwitterDown(tweetUrl, twitterDownApiKey);
        logger.success('Twitter', 'TwitterDown 接口解析成功');
      } catch (e) {
        errors.add('TwitterDown: $e');
        logger.warn('Twitter', 'TwitterDown 失败: $e');
      }
    }

    // 2. 使用 FixTweet 引擎
    if (result == null) {
      try {
        result = await TwitterResolvers.resolveViaFxTwitter(statusId);
        logger.success('Twitter', 'FixTweet 引擎解析成功');
      } catch (e) {
        errors.add('FixTweet: $e');
        logger.warn('Twitter', 'FixTweet 失败: $e');
      }
    }

    // 3. 备用线路兜底
    if (result == null) {
      try {
        result = await TwitterResolvers.resolveViaVxTwitter(statusId);
        logger.success('Twitter', '备用线路解析成功');
      } catch (e) {
        errors.add('备用线路: $e');
        logger.warn('Twitter', '备用线路失败: $e');
      }
    }

    if (result == null || result.url.isEmpty) {
      final errSummary = errors.isNotEmpty ? errors.join(' | ') : '无视频媒体或推文受限';
      logger.error('Twitter', '推文解析失败: $errSummary');
      if (statusMsgId != null) {
        await botClient.editMessageText(
          chatId,
          statusMsgId,
          '❌ <b>解析失败</b>: $errSummary',
        );
      }
      return;
    }

    // 探测远程文件大小
    final sizeStr = result.filesize ?? await TwitterResolvers.getRemoteFileSize(result.url);
    final customFilename = TwitterResolvers.generateCustomFilename(result.author, result.title);

    // 存入缓存
    _videoCache[statusId] = CachedVideoItem(
      url: result.url,
      filename: customFilename,
      author: result.author,
      title: result.title,
      resolution: result.resolution,
      size: sizeStr,
    );

    // 构建回复文本
    final safeAuthor = _escapeHtml(result.author);
    final safeTitle = _escapeHtml(result.title);

    final replyContent = StringBuffer();
    replyContent.writeln('🎬 <b>Twitter 视频解析完成</b>\n');
    replyContent.writeln('👤 <b>发布者</b>: @$safeAuthor');
    replyContent.writeln('📺 <b>最高分辨率</b>: <code>${result.resolution}</code>');
    replyContent.writeln('📦 <b>视频大小</b>: <code>$sizeStr</code>');
    if (safeTitle.isNotEmpty) {
      replyContent.writeln('\n💬 <b>推文内容</b>: $safeTitle');
    }

    final keyboard = {
      'inline_keyboard': [
        [
          {
            'text': '🌐 浏览器直达下载 (${result.resolution} · $sizeStr)',
            'url': result.url,
          }
        ],
        [
          {
            'text': '📥 发送该视频文件到聊天 (含中文名)',
            'callback_data': 'send_vid:$statusId',
          }
        ]
      ]
    };

    bool photoSent = false;
    if (result.thumbnail != null && result.thumbnail!.isNotEmpty) {
      try {
        final photoId = await botClient.sendPhoto(
          chatId,
          result.thumbnail!,
          caption: replyContent.toString(),
          replyMarkup: keyboard,
        );
        if (photoId != null) {
          photoSent = true;
          if (statusMsgId != null) {
            await botClient.deleteMessage(chatId, statusMsgId);
          }
        }
      } catch (e) {
        logger.warn('Twitter', '发送封面图失败，将回退纯文本: $e');
      }
    }

    if (!photoSent && statusMsgId != null) {
      await botClient.editMessageText(
        chatId,
        statusMsgId,
        replyContent.toString(),
        replyMarkup: keyboard,
      );
    }
  }

  @override
  Future<void> handleCallbackQuery(
    TelegramCallbackQuery query,
    TelegramBotClient botClient,
    LogService logger,
  ) async {
    final data = query.data ?? '';
    if (!data.startsWith('send_vid:')) return;

    await botClient.answerCallbackQuery(query.id);

    final statusId = data.replaceFirst('send_vid:', '');
    final item = _videoCache[statusId];
    final chatId = query.message?.chat.id;

    if (chatId == null) return;

    if (item == null) {
      await botClient.sendMessage(chatId, '⚠️ 任务缓存已过期，请重新发送推文链接解析。');
      return;
    }

    logger.info('Twitter', '正在推送视频到聊天: ${item.filename}');
    final hintId = await botClient.sendMessage(
      chatId,
      '⏳ 正在由 Telegram 云端向聊天推送文件，稍候...',
    );

    try {
      await botClient.sendDocument(
        chatId,
        item.url,
        filename: item.filename,
        caption:
            '📁 <b>${_escapeHtml(item.filename)}</b>\n📺 <code>${item.resolution}</code> · <code>${item.size}</code>',
      );
      if (hintId != null) {
        await botClient.deleteMessage(chatId, hintId);
      }
      logger.success('Twitter', '视频成功推送到 Telegram 聊天！');
    } catch (e) {
      logger.error('Twitter', '按需推送视频文件失败: $e');
      if (hintId != null) {
        await botClient.editMessageText(
          chatId,
          hintId,
          '❌ <b>发送失败</b>（文件可能超出限制或网络中断）: $e',
        );
      }
    }
  }

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }
}
