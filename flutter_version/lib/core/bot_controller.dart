import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../modules/service_registry.dart';
import 'models/telegram_models.dart';
import 'services/log_service.dart';
import 'services/storage_service.dart';
import 'services/telegram_bot_client.dart';

@pragma('vm:entry-point')
void startForegroundCallback() {
  FlutterForegroundTask.setTaskHandler(BotKeepAliveTaskHandler());
}

class BotKeepAliveTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onReceiveData(Object data) {}

  @override
  void onNotificationButtonPressed(String id) {}

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }

  @override
  void onNotificationDismissed() {}
}

class BotController extends ChangeNotifier {
  final StorageService storage;
  final ServiceRegistry registry;
  final LogService logger;

  TelegramBotClient? _client;
  TelegramUser? _botUser;
  CancelToken? _cancelToken;

  bool _isRunning = false;
  bool _isBusy = false;
  String? _lastError;
  int _totalProcessed = 0;
  DateTime? _startedAt;
  Timer? _uptimeTimer;
  Duration _uptime = Duration.zero;

  bool get isRunning => _isRunning;
  bool get isBusy => _isBusy;
  TelegramUser? get botUser => _botUser;
  String? get lastError => _lastError;
  int get totalProcessed => _totalProcessed;
  Duration get uptime => _uptime;

  BotController({
    required this.storage,
    required this.registry,
    required this.logger,
  });

  /// 测试 Token 有效性
  Future<TelegramUser> testToken(String token) async {
    final client = TelegramBotClient(token: token);
    return await client.getMe();
  }

  /// 启动机器人长轮询与前台保活服务
  Future<void> start() async {
    final token = storage.botToken.trim();
    if (token.isEmpty) {
      _lastError = '请先填写 Telegram Bot Token';
      logger.error('Bot', '启动失败：未配置 Bot Token');
      notifyListeners();
      return;
    }

    _isBusy = true;
    _lastError = null;
    notifyListeners();

    try {
      logger.info('Bot', '正在连接 Telegram 服务器验证 Token...');
      _client = TelegramBotClient(token: token);
      _botUser = await _client!.getMe();

      logger.success('Bot', '认证成功！机器人: @${_botUser!.username} (${_botUser!.firstName})');

      // 清除可能存在的旧 Webhook，保证 getUpdates 长轮询正常工作
      await _client!.deleteWebhook();

      // 启动 Android 前台保活服务与通知
      await _startForegroundService(_botUser!.displayName);

      _isRunning = true;
      _startedAt = DateTime.now();
      _uptimeTimer?.cancel();
      _uptimeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_startedAt != null) {
          _uptime = DateTime.now().difference(_startedAt!);
          notifyListeners();
        }
      });

      _cancelToken = CancelToken();
      // 启动异步轮询
      _runPollingLoop();

      logger.info('Bot', '🤖 机器人后台监听中，已启用 ${registry.enabledCount} 个服务模块');
    } catch (e) {
      _isRunning = false;
      _lastError = e.toString();
      logger.error('Bot', '启动失败: $e');
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  /// 停止机器人
  Future<void> stop() async {
    _isBusy = true;
    notifyListeners();

    try {
      logger.info('Bot', '正在停止 Telegram 机器人服务...');
      _cancelToken?.cancel('Manual Stop');
      _uptimeTimer?.cancel();
      _uptime = Duration.zero;
      _startedAt = null;

      await FlutterForegroundTask.stopService();
      _isRunning = false;
      logger.info('Bot', '服务已安全停止');
    } catch (e) {
      logger.error('Bot', '停止时出现异常: $e');
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  /// Telegram 消息轮询主循环
  Future<void> _runPollingLoop() async {
    int offset = 0;
    while (_isRunning && _client != null) {
      try {
        final updates = await _client!.getUpdates(
          offset: offset,
          timeout: 20,
          cancelToken: _cancelToken,
        );

        for (final update in updates) {
          offset = update.updateId + 1;
          _totalProcessed++;

          if (update.message != null) {
            // 分发普通消息
            unawaited(registry.dispatchMessage(update.message!, _client!, logger));
          } else if (update.callbackQuery != null) {
            // 分发内联按钮回调
            unawaited(registry.dispatchCallbackQuery(update.callbackQuery!, _client!, logger));
          }
        }
      } on DioException catch (de) {
        if (CancelToken.isCancel(de)) {
          break;
        }

        final statusCode = de.response?.statusCode;
        final responseData = de.response?.data;
        String? desc;
        if (responseData is Map && responseData['description'] != null) {
          desc = responseData['description'].toString();
        }

        if (statusCode == 409) {
          logger.warn(
            'Bot',
            '⚠️ 409 冲突：检测到此 Bot Token 正在其他地方被使用（例如手机 Termux、电脑后台仍有运行中的 Python 脚本，或旧连接尚未断开）。同一 Token 只能有一个活跃实例！[5秒后重试]',
          );
          await Future.delayed(const Duration(seconds: 5));
        } else {
          final errorMsg = desc ?? (de.message != null && de.message!.isNotEmpty ? de.message! : '网络请求失败');
          logger.warn('Bot', '网络轮询波动 ($errorMsg) [2秒后重试]');
          await Future.delayed(const Duration(seconds: 2));
        }
      } catch (e) {
        if (!_isRunning) break;
        logger.error('Bot', '轮询异常: $e');
        await Future.delayed(const Duration(seconds: 3));
      }
    }
  }

  Future<void> _startForegroundService(String botName) async {
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.restartService();
      } else {
        await FlutterForegroundTask.startService(
          serviceId: 1001,
          notificationTitle: '🤖 TGBot Hub 运行中 ($botName)',
          notificationText: '已在线 · ${registry.enabledCount} 个服务模块已就绪',
          callback: startForegroundCallback,
        );
      }
    } catch (e) {
      logger.warn('KeepAlive', '前台服务保活启动提示: $e');
    }
  }

  @override
  void dispose() {
    _uptimeTimer?.cancel();
    _cancelToken?.cancel();
    super.dispose();
  }
}
