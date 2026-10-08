import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:provider/provider.dart';
import '../core/services/storage_service.dart';
import '../modules/service_registry.dart';
import 'settings_page.dart';
import 'widgets/bot_master_card.dart';
import 'widgets/log_console_view.dart';
import 'widgets/service_slot_card.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _showBatteryOptDialog(BuildContext context) async {
    final isIgnoring = await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.battery_charging_full_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Text('7×24 后台保活说明'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isIgnoring
                  ? '✅ 当前设备已允许忽略电池优化，服务在息屏状态下将得到系统保障。'
                  : '⚠️ 当前设备尚未加入电池优化白名单。为了防止系统在息屏时休眠 CPU 或冻结网络，建议点击下方按钮开启。',
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 12),
            const Text(
              '建议同时在安卓系统设置中：\n1. 锁定后台应用卡片\n2. 开启自启动权限\n3. 允许后台高耗电',
              style: TextStyle(fontSize: 12.5, color: Colors.grey, height: 1.4),
            ),
          ],
        ),
        actions: [
          if (!isIgnoring)
            FilledButton.tonal(
              onPressed: () async {
                Navigator.pop(ctx);
                await FlutterForegroundTask.requestIgnoreBatteryOptimization();
              },
              child: const Text('前往配置白名单'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'TGBot Hub',
      applicationVersion: '1.0.0 (Flutter Android)',
      applicationIcon: const Icon(Icons.smart_toy_rounded, size: 40, color: Colors.blue),
      children: const [
        Text('专为安卓备用机打造的 Telegram 机器人 7×24 小时后台运行工作站。'),
        SizedBox(height: 8),
        Text('首期搭载 Twitter / X 视频最高清晰度解析下载服务，支持插件式动态拓展。'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final registry = context.watch<ServiceRegistry>();
    final modules = registry.modules;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.smart_toy_rounded,
                size: 20,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'TGBot Hub',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '保活指南',
            icon: const Icon(Icons.battery_saver_rounded),
            onPressed: () => _showBatteryOptDialog(context),
          ),
          IconButton(
            tooltip: '机器人配置与系统设置',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
            },
          ),
          IconButton(
            tooltip: '关于',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => _showAboutDialog(context),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // 1. 全局状态与启停控制主卡片
            const BotMasterCard(),
            const SizedBox(height: 12),

            // 2. 如果未配置 Bot Token，显示轻量引导横幅
            if (context.watch<StorageService>().botToken.isEmpty) ...[
              Card(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                child: ListTile(
                  leading: Icon(Icons.vpn_key_rounded, color: theme.colorScheme.primary),
                  title: const Text(
                    '尚未配置 Telegram Bot Token',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: const Text(
                    '点击前往设置填入 Token 即可开始使用机器人',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsPage()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 3. 动态功能服务插槽区域
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.extension_rounded,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '功能服务模块 (${registry.enabledCount}/${modules.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  '插槽式扩展',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.outline,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 动态渲染所有已注册服务卡片 (未来新增模块零改动 UI)
            ...modules.map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ServiceSlotCard(module: m),
                )),

            const SizedBox(height: 10),

            // 4. 实时控制台日志
            const LogConsoleView(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
