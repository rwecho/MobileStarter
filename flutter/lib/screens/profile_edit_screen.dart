import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: Theme.of(context).colorScheme.surface,
                backgroundImage: _avatarImage,
                child: _avatarImage == null
                    ? const Icon(Icons.person, size: 32)
                    : null,
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppButton(
                      label: '选择头像',
                      icon: AppIconName.user,
                      onPressed: _pickAvatar,
                    ),
                    const SizedBox(height: AppSpacing.x2),
                    TextField(
                      controller: avatarUrl,
                      decoration: const InputDecoration(labelText: '头像 URL'),
                      keyboardType: TextInputType.url,
                    ),
                  ],
                ),
              ),
            ],
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

  ImageProvider? get _avatarImage {
    final value = avatarUrl.text.trim();
    if (value.isEmpty) return null;
    if (value.startsWith('data:')) {
      final comma = value.indexOf(',');
      if (comma <= 0) return null;
      try {
        return MemoryImage(base64Decode(value.substring(comma + 1)));
      } catch (_) {
        return null;
      }
    }
    return NetworkImage(value);
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final selection = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 78,
    );
    if (selection == null || !mounted) return;
    // image_picker has already resized/compressed to JPEG; wrap as a data URL
    // and persist via updateProfile (no separate upload endpoint, like RN).
    final bytes = await selection.readAsBytes();
    setState(() {
      avatarUrl.text = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    });
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
