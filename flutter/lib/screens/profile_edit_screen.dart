import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app/app_scope.dart';
import '../design_system/app_icon.dart';
import '../design_system/components.dart';
import '../design_system/feedback.dart';
import '../theme/app_tokens.dart';
import 'avatar_editor_sheet.dart';
import 'profile_identity_card.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late final TextEditingController displayName;
  late final TextEditingController bio;
  String? avatarUrl;
  bool initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (initialized) return;
    initialized = true;
    final user = AppScope.of(context).user;
    displayName = TextEditingController(text: user?.displayName ?? '');
    bio = TextEditingController(text: user?.bio ?? '');
    avatarUrl = user?.avatarUrl;
  }

  @override
  void dispose() {
    displayName.dispose();
    bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => AppPage(
        title: '个人资料',
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.x4),
              children: [
                ProfileIdentityCard(
                  displayName: displayName.text,
                  username: controller.user?.username ?? '',
                  email: controller.user?.hasEmail == true
                      ? controller.user!.email!
                      : '未绑定邮箱',
                  bio: bio.text,
                  avatarUrl: avatarUrl,
                  onAvatarTap: _pickAvatar,
                ),
                const SizedBox(height: AppSpacing.x3),
                Text('显示名称', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.x2),
                TextField(
                  controller: displayName,
                  decoration: const InputDecoration(hintText: '请输入显示名称'),
                  maxLength: 40,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.x3),
                Text('个人简介', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.x2),
                TextField(
                  controller: bio,
                  decoration: const InputDecoration(hintText: '介绍一下自己'),
                  maxLength: 160,
                  minLines: 4,
                  maxLines: 6,
                  onChanged: (_) => setState(() {}),
                ),
                Text(
                  '用户名不可修改；头像仅在你主动选择后更新。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.x4),
                AppButton(
                  label: controller.busy ? '保存中…' : '保存资料',
                  icon: AppIconName.check,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    // 原图交给编辑 sheet 裁剪（选图时不预压缩，编辑后统一 512×512）。
    final selection = await picker.pickImage(source: ImageSource.gallery);
    if (selection == null || !mounted) return;
    final bytes = await selection.readAsBytes();
    if (!mounted) return;
    final url = await showAvatarEditorSheet(context, imageBytes: bytes);
    if (url != null && mounted) {
      setState(() => avatarUrl = url);
      // 上传完成即自动保存资料（与 ArkTS 壳一致）——只改本地 state
      // 需要再手动点「保存资料」，容易被当成"没保存"。
      final controller = AppScope.of(context);
      final ok = await controller.updateProfile(
        displayName.text.trim(),
        bio.text.trim(),
        url,
      );
      if (!mounted) return;
      showAppToast(context, ok ? '头像已更新' : '头像保存失败', error: !ok);
    }
  }

  Future<void> _save() async {
    final controller = AppScope.of(context);
    final success = await controller.updateProfile(
      displayName.text.trim(),
      bio.text.trim(),
      avatarUrl,
    );
    if (!mounted) return;
    showAppToast(
      context,
      success ? '个人资料已保存' : controller.consumeError() ?? '保存失败',
      error: !success,
    );
  }
}
