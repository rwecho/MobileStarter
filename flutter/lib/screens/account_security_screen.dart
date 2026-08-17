import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/app_scope.dart';
import '../design_system/app_icon.dart';
import '../design_system/components.dart';
import '../navigation/app_route.dart';
import '../navigation/app_route_paths.dart';
import '../theme/app_tokens.dart';

class AccountSecurityScreen extends StatefulWidget {
  const AccountSecurityScreen({super.key});

  @override
  State<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends State<AccountSecurityScreen> {
  final current = TextEditingController();
  final next = TextEditingController();
  // 新密码字段校验/服务端错误，内联显示在字段下方（见 issue #12 模式）。
  String? nextError;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => AppPage(
        title: '账户与安全',
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.x4),
          children: [
            AppCard(
              child: Column(
                children: [
                  AppListTile(
                    label: '登录邮箱',
                    value: controller.user?.hasEmail == true
                        ? controller.user!.email!
                        : '未绑定邮箱',
                  ),
                  const AppListTile(label: '身份绑定', value: '邮箱密码'),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.x4),
            TextField(
              controller: current,
              obscureText: true,
              decoration: const InputDecoration(labelText: '当前密码'),
            ),
            const SizedBox(height: AppSpacing.x3),
            TextField(
              controller: next,
              obscureText: true,
              decoration: InputDecoration(
                labelText: '至少 8 位新密码',
                errorText: nextError,
              ),
              onChanged: (_) => setState(() => nextError = null),
            ),
            const SizedBox(height: AppSpacing.x4),
            AppButton(
              label: controller.busy ? '修改中…' : '修改密码',
              icon: AppIconName.lock,
              onPressed: controller.busy || controller.user == null
                  ? null
                  : _submit,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final controller = AppScope.of(context);
    if (next.text.length < 8) {
      setState(() => nextError = '新密码至少需要 8 位');
      return;
    }
    final changed = await controller.changePassword(current.text, next.text);
    if (!mounted) return;
    if (!changed) {
      setState(() => nextError = controller.consumeError() ?? '修改失败');
      return;
    }
    // 修改成功 → 跳登录（跳转本身即反馈，不再 toast）。
    context.go(pathFor(AppRoute.signIn));
  }

  @override
  void dispose() {
    current.dispose();
    next.dispose();
    super.dispose();
  }
}
