import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design_system/app_icon.dart';
import '../design_system/components.dart';
import '../design_system/feedback.dart';
import '../theme/app_tokens.dart';

enum SettingsUtilityKind { storage, permissions, about }

class SettingsUtilityScreen extends StatefulWidget {
  const SettingsUtilityScreen({required this.kind, super.key});

  final SettingsUtilityKind kind;

  @override
  State<SettingsUtilityScreen> createState() => _SettingsUtilityScreenState();
}

class _SettingsUtilityScreenState extends State<SettingsUtilityScreen> {
  bool busy = false;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: _title(widget.kind),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.x4),
        children: switch (widget.kind) {
          SettingsUtilityKind.storage => _storage(),
          SettingsUtilityKind.permissions => _permissions(),
          SettingsUtilityKind.about => _about(),
        },
      ),
    );
  }

  List<Widget> _storage() => [
    const AppCard(
      child: AppListTile(label: '可再生成缓存', value: '遥测待上传队列'),
    ),
    const SizedBox(height: AppSpacing.x3),
    const Text('清理不会删除登录凭证、个人设置或离线配置。'),
    const SizedBox(height: AppSpacing.x4),
    AppButton(
      label: busy ? '清理中…' : '清理缓存',
      onPressed: busy ? null : _clearCache,
    ),
  ];

  List<Widget> _permissions() => const [
    AppCard(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppIcon(AppIconName.lock),
            SizedBox(height: AppSpacing.x3),
            Text('系统权限按需申请'),
            SizedBox(height: AppSpacing.x2),
            Text('相机、相册、通知与麦克风权限只会在相关功能需要时请求。'),
          ],
        ),
      ),
    ),
  ];

  List<Widget> _about() => const [
    AppCard(
      child: Column(
        children: [
          AppListTile(label: '产品', value: 'MobileStarter'),
          AppListTile(label: '版本', value: '1.0.0 (1)'),
          AppListTile(label: '平台模板', value: 'Flutter'),
        ],
      ),
    ),
  ];

  Future<void> _clearCache() async {
    setState(() => busy = true);
    await SharedPreferencesAsync().remove('mobileui.telemetry.queue');
    if (!mounted) return;
    setState(() => busy = false);
    showAppToast(context, '可再生成缓存已清理');
  }
}

String _title(SettingsUtilityKind kind) => switch (kind) {
  SettingsUtilityKind.storage => '存储与缓存',
  SettingsUtilityKind.permissions => '权限管理',
  SettingsUtilityKind.about => '关于与版本',
};
