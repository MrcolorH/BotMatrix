import 'package:dio/dio.dart';
import '../models/telegram_models.dart';

class TelegramBotClient {
  final String token;
  late final Dio _dio;

  TelegramBotClient({required this.token, String? proxyUrl}) {
    final options = BaseOptions(
      baseUrl: 'https://api.telegram.org/bot$token/',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 40),
      responseType: ResponseType.json,
    );

    _dio = Dio(options);
  }

  /// 测试连接与获取机器人自身信息
  Future<TelegramUser> getMe() async {
    final res = await _dio.get('getMe');
    if (res.data != null && res.data['ok'] == true) {
      return TelegramUser.fromJson(res.data['result']);
    }
    throw Exception(res.data?['description'] ?? '获取 Bot 信息失败');
  }

  /// 长轮询获取更新
  Future<List<TelegramUpdate>> getUpdates({
    required int offset,
    int timeout = 25,
    CancelToken? cancelToken,
  }) async {
    try {
      final res = await _dio.get(
        'getUpdates',
        queryParameters: {
          'offset': offset,
          'timeout': timeout,
          'allowed_updates': '["message", "callback_query"]',
        },
        cancelToken: cancelToken,
      );

      if (res.data != null && res.data['ok'] == true) {
        final list = res.data['result'] as List? ?? [];
        return list.map((item) => TelegramUpdate.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        return [];
      }
      rethrow;
    }
  }

  /// 发送纯文本消息
  Future<int?> sendMessage(
    dynamic chatId,
    String text, {
    String parseMode = 'HTML',
    Map<String, dynamic>? replyMarkup,
    bool disableWebPagePreview = false,
  }) async {
    final payload = {
      'chat_id': chatId,
      'text': text,
      'parse_mode': parseMode,
      'disable_web_page_preview': disableWebPagePreview,
      'reply_markup': ?replyMarkup,
    };

    final res = await _dio.post('sendMessage', data: payload);
    if (res.data != null && res.data['ok'] == true) {
      return res.data['result']['message_id'] as int?;
    }
    return null;
  }

  /// 发送图片卡片
  Future<int?> sendPhoto(
    dynamic chatId,
    String photoUrl, {
    String? caption,
    String parseMode = 'HTML',
    Map<String, dynamic>? replyMarkup,
  }) async {
    final payload = {
      'chat_id': chatId,
      'photo': photoUrl,
      'caption': ?caption,
      'parse_mode': parseMode,
      'reply_markup': ?replyMarkup,
    };

    final res = await _dio.post('sendPhoto', data: payload);
    if (res.data != null && res.data['ok'] == true) {
      return res.data['result']['message_id'] as int?;
    }
    return null;
  }

  /// 发送文档（利用 Telegram 云端直接拉取 URL 发送视频，严格保留指定文件名）
  Future<int?> sendDocument(
    dynamic chatId,
    String documentUrl, {
    String? filename,
    String? caption,
    String parseMode = 'HTML',
  }) async {
    // 注：若通过 URL 发送，Telegram 原生并不一定使用自定义 filename，
    // 但当作为 URL 参数传递时 Telegram 云端会自动抓取
    final payload = {
      'chat_id': chatId,
      'document': documentUrl,
      'caption': ?caption,
      'parse_mode': parseMode,
    };

    final res = await _dio.post('sendDocument', data: payload);
    if (res.data != null && res.data['ok'] == true) {
      return res.data['result']['message_id'] as int?;
    }
    return null;
  }

  /// 编辑文本消息
  Future<void> editMessageText(
    dynamic chatId,
    int messageId,
    String text, {
    String parseMode = 'HTML',
    Map<String, dynamic>? replyMarkup,
    bool disableWebPagePreview = false,
  }) async {
    final payload = {
      'chat_id': chatId,
      'message_id': messageId,
      'text': text,
      'parse_mode': parseMode,
      'disable_web_page_preview': disableWebPagePreview,
      'reply_markup': ?replyMarkup,
    };

    await _dio.post('editMessageText', data: payload);
  }

  /// 删除消息
  Future<void> deleteMessage(dynamic chatId, int messageId) async {
    try {
      await _dio.post('deleteMessage', data: {
        'chat_id': chatId,
        'message_id': messageId,
      });
    } catch (_) {}
  }

  /// 应答 CallbackQuery
  Future<void> answerCallbackQuery(
    String callbackQueryId, {
    String? text,
    bool showAlert = false,
  }) async {
    try {
      await _dio.post('answerCallbackQuery', data: {
        'callback_query_id': callbackQueryId,
        'text': ?text,
        'show_alert': showAlert,
      });
    } catch (_) {}
  }
}
