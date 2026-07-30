import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../design_system/app_icon.dart';
import '../design_system/components.dart';
import '../theme/app_tokens.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late final TextEditingController displayName;
  late final TextEditingController bio;
  late final TextEditingController avatarUrl;
  bool initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (initialized) return;
    initialized = true;
    final user = AppScope.of(context).user;
    displayName = TextEditingController(text: user?.displayName ?? '');
    bio = TextEditingController(text: user?.bio ?? '');
    avatarUrl = TextEditingController(text: user?.avatarUrl ?? '');
  }

  @override
  void dispose() {
    displayName.dispose();
    bio.dispose();
    avatarUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return AppPage(
      title: '个人资料',
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.x4),
        children: [
          AppCard(
            child: AppListTile(
              label: '用户名（不可修改）',
              value: '@${controller.user?.username ?? ''}',
            ),
          ),
          const SizedBox(height: AppSpacing.x3),
          TextField(
            controller: displayName,
            decoration: const InputDecoration(labelText: '显示名称'),
            maxLength: 40,
          ),
          const SizedBox(height: AppSpacing.x3),
          TextField(
            controller: bio,
            decoration: const InputDecoration(labelText: '个人简介'),
            maxLength: 160,
            maxLines: 3,
          ),
          const SizedBox(height: AppSpacing.x3),
          TextField(
            controller: avatarUrl,
            decoration: const InputDecoration(labelText: '头像 URL'),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: AppSpacing.x4),
          AppButton(
            label: controller.busy ? '保存中…' : '保存资料',
            icon: AppIconName.check,
            onPressed: _save,
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final controller = AppScope.of(context);
    final success = await controller.updateProfile(
      displayName.text.trim(),
      bio.text.trim(),
      avatarUrl.text.trim().isEmpty ? null : avatarUrl.text.trim(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? '个人资料已保存' : controller.consumeError() ?? '保存失败',
        ),
      ),
    );
  }
}
