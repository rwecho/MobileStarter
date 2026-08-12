import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../app/runtime_models.dart';
import '../design_system/app_icon.dart';
import '../design_system/components.dart';
import '../design_system/feedback.dart';
import '../theme/app_tokens.dart';

enum PreferenceKind { notifications, general, privacy, appearance, language }

class PreferenceScreen extends StatefulWidget {
  const PreferenceScreen({required this.kind, required this.title, super.key});

  final PreferenceKind kind;
  final String title;

  @override
  State<PreferenceScreen> createState() => _PreferenceScreenState();
}

class _PreferenceScreenState extends State<PreferenceScreen> {
  bool initialized = false;
  bool enabled = true;
  String option = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (initialized) return;
    initialized = true;
    final settings = AppScope.of(context).user?.settings;
    final initial = _initial(widget.kind, settings);
    enabled = initial.$1;
    option = initial.$2;
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => AppPage(
        title: widget.title,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.x4),
          children: [
            AppCard(child: _editor()),
            const SizedBox(height: AppSpacing.x4),
            AppButton(
              label: controller.busy ? '保存中…' : '保存设置',
              icon: AppIconName.check,
              onPressed: controller.busy || controller.user == null
                  ? null
                  : _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _editor() {
    if (widget.kind == PreferenceKind.appearance) {
      return _Options(
        labels: const {'system': '跟随系统', 'light': '浅色', 'dark': '深色'},
        selected: option,
        onSelected: (value) => setState(() => option = value),
      );
    }
    if (widget.kind == PreferenceKind.language) {
      return _Options(
        labels: const {'zh-CN': '简体中文', 'en-US': 'English'},
        selected: option,
        onSelected: (value) => setState(() => option = value),
      );
    }
    return SwitchListTile(
      title: Text(_label(widget.kind)),
      value: enabled,
      onChanged: (value) => setState(() => enabled = value),
    );
  }

  Future<void> _save() async {
    final controller = AppScope.of(context);
    final saved = await controller.saveSettings(
      _patch(widget.kind, enabled, option),
    );
    if (!mounted) return;
    showAppToast(
      context,
      saved ? '设置已同步到服务端' : controller.consumeError() ?? '保存失败',
      error: !saved,
    );
  }
}

class _Options extends StatelessWidget {
  const _Options({
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  final Map<String, String> labels;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: labels.entries
          .map(
            (entry) => ListTile(
              minTileHeight: 56,
              title: Text(entry.value),
              trailing: entry.key == selected
                  ? const AppIcon(AppIconName.check, color: AppColors.brand)
                  : null,
              onTap: () => onSelected(entry.key),
            ),
          )
          .toList(),
    );
  }
}

(bool, String) _initial(PreferenceKind kind, JsonMap? settings) {
  if (kind == PreferenceKind.appearance) {
    return (true, settings?['theme'] as String? ?? 'system');
  }
  if (kind == PreferenceKind.language) {
    return (true, settings?['language'] as String? ?? 'zh-CN');
  }
  final key = switch (kind) {
    PreferenceKind.notifications => 'notificationsEnabled',
    PreferenceKind.privacy => 'analyticsEnabled',
    PreferenceKind.general => 'autoplayEnabled',
    _ => '',
  };
  return (settings?[key] != false, '');
}

JsonMap _patch(PreferenceKind kind, bool enabled, String option) =>
    switch (kind) {
      PreferenceKind.appearance => {'theme': option},
      PreferenceKind.language => {'language': option},
      PreferenceKind.notifications => {'notificationsEnabled': enabled},
      PreferenceKind.privacy => {'analyticsEnabled': enabled},
      PreferenceKind.general => {'autoplayEnabled': enabled},
    };

String _label(PreferenceKind kind) => switch (kind) {
  PreferenceKind.notifications => '允许应用内通知',
  PreferenceKind.privacy => '允许匿名使用分析',
  PreferenceKind.general => '自动播放推荐内容',
  _ => '',
};
