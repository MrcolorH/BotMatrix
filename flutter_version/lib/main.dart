import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:provider/provider.dart';

import 'core/bot_controller.dart';
import 'core/services/log_service.dart';
import 'core/services/storage_service.dart';
import 'modules/service_registry.dart';
import 'ui/home_page.dart';
import 'ui/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化前台保活服务通信端口
  FlutterForegroundTask.initCommunicationPort();

  // 初始化本地持久化存储
  final storage = await StorageService.init();

  // 初始化服务注册中心并加载各模块配置
  final registry = ServiceRegistry();
  await registry.initAll(storage);

  // 初始化全局日志
  final logger = LogService();
  logger.info('System', 'TGBot Hub 初始化完成');

  // 初始化全局机器人控制器
  final botController = BotController(
    storage: storage,
    registry: registry,
    logger: logger,
  );

  // 初始化前台服务基础配置
  _initForegroundService();

  runApp(
    MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storage),
        ChangeNotifierProvider<ServiceRegistry>.value(value: registry),
        ChangeNotifierProvider<LogService>.value(value: logger),
        ChangeNotifierProvider<BotController>.value(value: botController),
      ],
      child: const TGBotApp(),
    ),
  );
}

void _initForegroundService() {
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'tgbot_service_channel',
      channelName: 'TGBot 机器人后台保活服务',
      channelDescription: '保持 Telegram 机器人 7×24 小时后台运行与消息响应',
      onlyAlertOnce: true,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.nothing(),
      autoRunOnBoot: true,
      autoRunOnMyPackageReplaced: true,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );
}

class TGBotApp extends StatefulWidget {
  const TGBotApp({super.key});

  @override
  State<TGBotApp> createState() => _TGBotAppState();
}

class _TGBotAppState extends State<TGBotApp> {
  @override
  void initState() {
    super.initState();
    _requestNotificationPermission();
  }

  Future<void> _requestNotificationPermission() async {
    if (Platform.isAndroid) {
      final status = await FlutterForegroundTask.checkNotificationPermission();
      if (status != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TGBot Hub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const HomePage(),
    );
  }
}
