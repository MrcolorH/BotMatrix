import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/models/log_entry.dart';
import '../../core/services/log_service.dart';

class LogConsoleView extends StatefulWidget {
  const LogConsoleView({super.key});

  @override
  State<LogConsoleView> createState() => _LogConsoleViewState();
}

class _LogConsoleViewState extends State<LogConsoleView> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_autoScroll && _scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    }
  }

  Color _getLevelColor(LogLevel level) {
    switch (level) {
      case LogLevel.info:
        return const Color(0xFF60A5FA); // Blue
      case LogLevel.warning:
        return const Color(0xFFFBBF24); // Amber
      case LogLevel.error:
        return const Color(0xFFF87171); // Red
      case LogLevel.success:
        return const Color(0xFF34D399); // Green
    }
  }

  @override
  Widget build(BuildContext context) {
    final logService = context.watch<LogService>();
    final logs = logService.logs;

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.terminal_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '实时运行日志 (${logs.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      tooltip: _autoScroll ? '已启用自动滚屏' : '已暂停自动滚屏',
                      icon: Icon(
                        _autoScroll ? Icons.vertical_align_bottom_rounded : Icons.pause_circle_outline,
                        size: 20,
                        color: _autoScroll ? Theme.of(context).colorScheme.primary : null,
                      ),
                      onPressed: () {
                        setState(() {
                          _autoScroll = !_autoScroll;
                        });
                      },
                    ),
                    IconButton(
                      tooltip: '复制所有日志',
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      onPressed: logs.isEmpty
                          ? null
                          : () {
                              Clipboard.setData(ClipboardData(text: logService.exportToString()));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('📋 日志已复制到剪贴板'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                    ),
                    IconButton(
                      tooltip: '清空日志',
                      icon: const Icon(Icons.delete_sweep_outlined, size: 20),
                      onPressed: logs.isEmpty ? null : logService.clear,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              height: 220,
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF090D16),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: logs.isEmpty
                  ? const Center(
                      child: Text(
                        '暂无日志输出，启动服务后将在此显示实时状态。',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        final item = logs[index];
                        final levelColor = _getLevelColor(item.level);

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: SelectableText.rich(
                            TextSpan(
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11.5,
                                height: 1.35,
                              ),
                              children: [
                                TextSpan(
                                  text: '${item.formattedTime} ',
                                  style: const TextStyle(color: Color(0xFF64748B)),
                                ),
                                TextSpan(
                                  text: '[${item.prefix}] ',
                                  style: TextStyle(
                                    color: levelColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(
                                  text: '[${item.tag}] ',
                                  style: const TextStyle(color: Color(0xFF94A3B8)),
                                ),
                                TextSpan(
                                  text: item.message,
                                  style: const TextStyle(color: Color(0xFFE2E8F0)),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
