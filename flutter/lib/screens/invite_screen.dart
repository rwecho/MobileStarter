import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_scope.dart';
import '../app/runtime_models.dart';
import '../design_system/app_icon.dart';
import '../design_system/components.dart';
import '../design_system/feedback.dart';
import '../state/async_state.dart';
import '../theme/app_tokens.dart';

class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key});

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  AsyncState<ReferralView> state = const Idle();
  bool requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (requested) return;
    requested = true;
    _load();
  }

  @override
  Widget build(BuildContext context) => AppPage(
    title: '邀请好友',
    child: switch (state) {
      Idle() || Loading() => const Center(child: CircularProgressIndicator()),
      Empty() => const Center(child: Text('暂时无法生成邀请码。')),
      Failure(:final message) => _failure(message),
      Offline() => _failure('网络不可用，请连接后重试。'),
      Unauthorized() => const Center(child: Text('登录后才能邀请好友。')),
      Success(:final data) => _content(data),
    },
  );

  Widget _content(ReferralView referral) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.x6),
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppIcon(AppIconName.gift, color: AppColors.brand, size: 40),
              const SizedBox(height: AppSpacing.x3),
              const Text('我的邀请码'),
              SelectableText(
                referral.code,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text('已邀请 ${referral.invited} 位好友'),
              const SizedBox(height: AppSpacing.x4),
              AppButton(
                label: '复制邀请链接',
                icon: AppIconName.check,
                onPressed: () => _copy(referral.shareUrl),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _failure(String message) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        AppButton(label: '重试', onPressed: _load),
      ],
    ),
  );

  Future<void> _load() async {
    setState(() => state = const Loading());
    final controller = AppScope.of(context);
    final loaded = await controller.loadReferral();
    if (!mounted) return;
    setState(
      () => state = loaded && controller.referral != null
          ? Success(controller.referral!)
          : Failure(controller.consumeError() ?? '加载失败'),
    );
  }

  Future<void> _copy(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) showAppToast(context, '邀请链接已复制');
  }
}
