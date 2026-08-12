import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/app_scope.dart';
import '../design_system/app_icon.dart';
import '../design_system/components.dart';
import '../design_system/feedback.dart';
import '../navigation/app_route.dart';
import '../navigation/app_route_paths.dart';
import '../theme/app_tokens.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final password = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => AppPage(
        title: '注销账号',
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.x4),
          children: [
            const Text('请输入当前密码重新认证。账户、会话、通知和订单关联将被永久删除。'),
            const SizedBox(height: AppSpacing.x4),
            TextField(
              controller: password,
              obscureText: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: '当前密码'),
            ),
            const SizedBox(height: AppSpacing.x4),
            AppButton(
              label: controller.busy ? '删除中…' : '永久删除账号',
              icon: AppIconName.trash,
              destructive: true,
              onPressed: controller.busy || password.text.isEmpty
                  ? null
                  : _confirm,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirm() async {
    final approved = await showAppConfirm(
      context,
      title: '永久删除账号？',
      message: '此操作无法恢复。',
      confirmLabel: '永久删除',
    );
    if (!approved || !mounted) return;
    final controller = AppScope.of(context);
    final deleted = await controller.deleteAccount(password.text);
    if (!mounted) return;
    if (deleted) {
      context.go(pathFor(AppRoute.home));
    } else {
      showAppToast(context, controller.consumeError() ?? '删除失败', error: true);
    }
  }

  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }
}
