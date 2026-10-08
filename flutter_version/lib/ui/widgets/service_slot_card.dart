import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/storage_service.dart';
import '../../modules/base_module.dart';
import '../../modules/service_registry.dart';

class ServiceSlotCard extends StatefulWidget {
  final BotServiceModule module;

  const ServiceSlotCard({super.key, required this.module});

  @override
  State<ServiceSlotCard> createState() => _ServiceSlotCardState();
}

class _ServiceSlotCardState extends State<ServiceSlotCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final module = widget.module;
    final storage = context.read<StorageService>();
    final registry = context.read<ServiceRegistry>();

    final customSettingsWidget = module.buildSettingsWidget(context, () {
      registry.saveModuleSettings(module, storage);
    });

    final bool hasCustomSettings = customSettingsWidget != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: module.isEnabled
                        ? colorScheme.primaryContainer
                        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    module.icon,
                    size: 24,
                    color: module.isEnabled
                        ? colorScheme.primary
                        : colorScheme.outline,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        module.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        module.isEnabled ? '✅ 服务已启用' : '⚪️ 服务已停用',
                        style: TextStyle(
                          fontSize: 12,
                          color: module.isEnabled ? Colors.green : colorScheme.outline,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: module.isEnabled,
                  onChanged: (bool newVal) {
                    setState(() {
                      module.isEnabled = newVal;
                    });
                    registry.saveModuleSettings(module, storage);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              module.description,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            if (hasCustomSettings) ...[
              const SizedBox(height: 10),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Row(
                    children: [
                      Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isExpanded ? '收起模块专属配置' : '展开模块专属配置',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: customSettingsWidget,
                ),
                crossFadeState: _isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
