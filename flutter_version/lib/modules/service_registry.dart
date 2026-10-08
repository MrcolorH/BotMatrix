import 'package:flutter/foundation.dart';
import '../core/models/telegram_models.dart';
import '../core/services/log_service.dart';
import '../core/services/storage_service.dart';
import '../core/services/telegram_bot_client.dart';
import 'base_module.dart';
import 'twitter/twitter_module.dart';

/// 机器人服务注册中心
/// 集中注册与管理所有可用的服务插槽。未来新增任何功能，仅需在此添加实例，UI 将全自动动态渲染。
class ServiceRegistry extends ChangeNotifier {
  final List<BotServiceModule> _modules = [];

  List<BotServiceModule> get modules => List.unmodifiable(_modules);

  int get enabledCount => _modules.where((m) => m.isEnabled).length;

  ServiceRegistry() {
    // 默认内置核心功能 1: Twitter / X 视频解析服务
    register(TwitterModule());

    // 💡 未来新增扩展槽位（例如 YouTube 解析、AI 智能助手等）：
    // register(YouTubeModule());
    // register(AiChatModule());
  }

  void register(BotServiceModule module) {
    if (!_modules.any((m) => m.id == module.id)) {
      _modules.add(module);
      notifyListeners();
    }
  }

  Future<void> initAll(StorageService storage) async {
    for (final module in _modules) {
      await module.init(storage);
    }
    notifyListeners();
  }

  Future<void> saveModuleSettings(BotServiceModule module, StorageService storage) async {
    await module.saveSettings(storage);
    notifyListeners();
  }

  /// 将收到的普通消息分发给所有匹配的启用模块
  Future<void> dispatchMessage(
    TelegramMessage message,
    TelegramBotClient botClient,
    LogService logger,
  ) async {
    bool handled = false;
    for (final module in _modules) {
      if (module.isEnabled && module.canHandle(message)) {
        handled = true;
        try {
          await module.handleMessage(message, botClient, logger);
        } catch (e, st) {
          logger.error(module.name, '处理消息异常: $e');
          debugPrint('$e\n$st');
        }
      }
    }

    if (!handled) {
      final text = message.text ?? '';
      // 如果是命令 /start
      if (text.startsWith('/start')) {
        await _sendWelcomeMessage(message, botClient);
      } else {
        logger.info('Dispatcher', '收到未被任何模块匹配的消息: $text');
      }
    }
  }

  /// 将内联按钮点击事件分发给相应模块
  Future<void> dispatchCallbackQuery(
    TelegramCallbackQuery query,
    TelegramBotClient botClient,
    LogService logger,
  ) async {
    for (final module in _modules) {
      if (module.isEnabled) {
        try {
          await module.handleCallbackQuery(query, botClient, logger);
        } catch (e) {
          logger.error(module.name, '处理回调按钮异常: $e');
        }
      }
    }
  }

  Future<void> _sendWelcomeMessage(
    TelegramMessage message,
    TelegramBotClient botClient,
  ) async {
    final sb = StringBuffer();
    sb.writeln('👋 <b>你好！欢迎使用 TGBot 服务工作站。</b>\n');
    sb.writeln('📱 <b>运行状态</b>：部署在本地安卓设备上 (7×24 后台常驻)。');
    sb.writeln('🧩 <b>当前已启用服务</b>：');
    for (final m in _modules) {
      if (m.isEnabled) {
        sb.writeln('• ✅ <b>${m.name}</b>');
      }
    }
    sb.writeln('\n⚡️ 直接向我发送对应的内容链接即可开始使用！');

    await botClient.sendMessage(
      message.chat.id,
      sb.toString(),
      disableWebPagePreview: true,
    );
  }
}
