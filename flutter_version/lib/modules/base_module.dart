import 'package:flutter/material.dart';
import '../core/models/telegram_models.dart';
import '../core/services/log_service.dart';
import '../core/services/storage_service.dart';
import '../core/services/telegram_bot_client.dart';

/// 机器人功能服务插槽基础协议
/// 所有扩展功能（例如 Twitter 解析、YouTube 下载、AI 对话）均实现此接口。
/// 注册进 ServiceRegistry 后，UI 将自动渲染对应卡片与独立配置，无需改动任何页面布局代码。
abstract class BotServiceModule {
  /// 唯一模块标识符，如 'twitter_resolver'
  String get id;

  /// 模块展示名称，如 'Twitter / X 视频解析'
  String get name;

  /// 模块功能简介
  String get description;

  /// 模块图标
  IconData get icon;

  /// 是否启用此功能
  bool get isEnabled;
  set isEnabled(bool value);

  /// 初始化模块配置（从本地存储读取）
  Future<void> init(StorageService storage);

  /// 保存模块专属配置
  Future<void> saveSettings(StorageService storage);

  /// 构建此模块专属设置的 UI 组件（若无需设置则返回 null）
  Widget? buildSettingsWidget(BuildContext context, VoidCallback onSettingsChanged);

  /// 路由判定：这条消息本模块是否应当响应？
  bool canHandle(TelegramMessage message);

  /// 处理文本消息业务
  Future<void> handleMessage(
    TelegramMessage message,
    TelegramBotClient botClient,
    LogService logger,
  );

  /// 处理内联键盘回调按钮点击（如 send_vid 等）
  Future<void> handleCallbackQuery(
    TelegramCallbackQuery query,
    TelegramBotClient botClient,
    LogService logger,
  );

  /// 服务启动时的回调
  Future<void> onServiceStart() async {}

  /// 服务停止时的回调
  Future<void> onServiceStop() async {}
}
