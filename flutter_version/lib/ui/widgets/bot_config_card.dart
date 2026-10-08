import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/bot_controller.dart';
import '../../core/services/storage_service.dart';

class BotConfigCard extends StatefulWidget {
  const BotConfigCard({super.key});

  @override
  State<BotConfigCard> createState() => _BotConfigCardState();
}

class _BotConfigCardState extends State<BotConfigCard> {
  late final TextEditingController _tokenController;
  bool _obscureText = true;
  bool _isTesting = false;
  String? _testSuccessMsg;
  String? _testErrorMsg;

  @override
  void initState() {
    super.initState();
    final storage = context.read<StorageService>();
    _tokenController = TextEditingController(text: storage.botToken);
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      setState(() {
        _testErrorMsg = '请先输入 Bot Token';
        _testSuccessMsg = null;
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _testErrorMsg = null;
      _testSuccessMsg = null;
    });

    final bot = context.read<BotController>();
    try {
      final storage = context.read<StorageService>();
      final user = await bot.testToken(token);
      // 测试成功同时保存
      await storage.setBotToken(token);
      if (mounted) {
        setState(() {
          _testSuccessMsg = '连接成功！已验证: @${user.username} (${user.firstName})';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _testErrorMsg = '验证失败: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTesting = false;
        });
      }
    }
  }

  Future<void> _saveToken() async {
    final token = _tokenController.text.trim();
    await context.read<StorageService>().setBotToken(token);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Bot Token 已保存'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isBotRunning = context.watch<BotController>().isRunning;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.smart_toy_outlined, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Telegram 机器人配置',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '在 Telegram 官方 @BotFather 申请获得的 Bot Token (全局唯一凭据)',
              style: TextStyle(fontSize: 13, color: colorScheme.outline),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _tokenController,
              enabled: !isBotRunning,
              obscureText: _obscureText,
              decoration: InputDecoration(
                labelText: 'Bot Token',
                hintText: '形如：1234567890:ABCdefGhIJKlmNoPQRsTUVwxyZ',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.key_rounded),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility),
                      onPressed: () {
                        setState(() {
                          _obscureText = !_obscureText;
                        });
                      },
                    ),
                  ],
                ),
              ),
              onChanged: (_) {
                setState(() {
                  _testSuccessMsg = null;
                  _testErrorMsg = null;
                });
              },
            ),
            if (_testSuccessMsg != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _testSuccessMsg!,
                        style: const TextStyle(color: Colors.green, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_testErrorMsg != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.cancel_rounded, color: colorScheme.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _testErrorMsg!,
                        style: TextStyle(color: colorScheme.error, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isBotRunning || _isTesting ? null : _testConnection,
                    icon: _isTesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.network_check_rounded, size: 18),
                    label: Text(_isTesting ? '正在验证...' : '测试有效性'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: isBotRunning ? null : _saveToken,
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: const Text('保存配置'),
                  ),
                ),
              ],
            ),
            if (isBotRunning) ...[
              const SizedBox(height: 8),
              Text(
                '🔒 服务运行中已锁定 Token，停止服务后可修改。',
                style: TextStyle(fontSize: 12, color: colorScheme.outline),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
