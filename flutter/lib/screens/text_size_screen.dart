import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../design_system/components.dart';
import '../design_system/feedback.dart';
import '../theme/app_tokens.dart';

class TextSizeScreen extends StatefulWidget {
  const TextSizeScreen({super.key});

  @override
  State<TextSizeScreen> createState() => _TextSizeScreenState();
}

class _TextSizeScreenState extends State<TextSizeScreen> {
  bool initialized = false;
  double scale = 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (initialized) return;
    initialized = true;
    scale =
        (AppScope.of(context).user?.settings['textScale'] as num?)
            ?.toDouble() ??
        1;
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final options = <double, String>{0.9: '较小', 1: '标准', 1.15: '较大', 1.3: '特大'};
    return AppPage(
      title: '字体大小',
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.x4),
        children: [
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.x4),
              child: Text(
                '这是当前字体大小的实时预览。',
                style: TextStyle(fontSize: 16 * scale),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.x3),
          AppCard(
            child: Column(
              children: options.entries
                  .map(
                    (entry) => ListTile(
                      title: Text(entry.value),
                      trailing: scale == entry.key ? const Text('已选择') : null,
                      onTap: () => setState(() => scale = entry.key),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.x4),
          AppButton(
            label: controller.busy ? '保存中…' : '保存字体大小',
            onPressed: controller.busy || controller.user == null
                ? null
                : _save,
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final controller = AppScope.of(context);
    final saved = await controller.saveSettings({'textScale': scale});
    if (!mounted) return;
    showAppToast(
      context,
      saved ? '字体大小已同步' : controller.consumeError() ?? '保存失败',
      error: !saved,
    );
  }
}
