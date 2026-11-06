import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'widgets/bot_config_card.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('机器人与系统设置', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // 1. Telegram Bot Token 核心配置 (单独放置在此)
            const BotConfigCard(),
            const SizedBox(height: 16),

            // 2. 7x24 小时后台保活设置
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.battery_saver_rounded, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          '7×24 小时后台保活配置',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '安卓系统在长时间锁屏息屏时可能会限制网络或挂起 CPU。开启白名单能保障机器人时刻在线。',
                      style: TextStyle(fontSize: 13, color: colorScheme.outline, height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.security_update_good_rounded, size: 18),
                        label: const Text('前往申请电池优化白名单 (无限制)'),
                        onPressed: () async {
                          await FlutterForegroundTask.requestIgnoreBatteryOptimization();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 3. 关于与使用指南
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          '关于 TGBot Hub',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '版本：v1.0.0 (Flutter Standalone Edition)\n'
                      '作者：MrcolorH (@MrcolorH)\n'
                      '开源：https://github.com/MrcolorH/TGBot\n'
                      '架构：纯 Dart 高性能异步事件驱动 + 原生前台保活服务\n'
                      '特性：插槽式模块化设计，预留无限功能扩展槽位。',
                      style: TextStyle(fontSize: 13, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
