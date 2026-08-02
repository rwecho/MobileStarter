import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../app/runtime_models.dart';
import '../design_system/components.dart';
import '../state/async_state.dart';
import '../theme/app_tokens.dart';

class CouponsScreen extends StatefulWidget {
  const CouponsScreen({super.key});

  @override
  State<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends State<CouponsScreen> {
  AsyncState<List<CouponView>> state = const Idle();
  bool requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (requested) return;
    requested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  Widget build(BuildContext context) => AppPage(
    title: '优惠券',
    child: switch (state) {
      Idle() || Loading() => const Center(child: CircularProgressIndicator()),
      Empty() => const Center(child: Text('当前账户暂无可用优惠券。')),
      Failure(:final message) => _Failure(message: message, retry: _load),
      Offline() => _Failure(message: '网络不可用，请连接后重试。', retry: _load),
      Unauthorized() => const Center(child: Text('登录后才能查看优惠券。')),
      Success(:final data) => ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.x4),
        itemCount: data.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.x3),
        itemBuilder: (_, index) => _CouponCard(coupon: data[index]),
      ),
    },
  );

  Future<void> _load() async {
    setState(() => state = const Loading());
    final controller = AppScope.of(context);
    final loaded = await controller.loadCoupons();
    if (!mounted) return;
    setState(() {
      if (loaded && controller.coupons.isEmpty) {
        state = const Empty();
      } else if (loaded) {
        state = Success(controller.coupons);
      } else {
        state = Failure(controller.consumeError() ?? '加载失败');
      }
    });
  }
}

class _CouponCard extends StatelessWidget {
  const _CouponCard({required this.coupon});
  final CouponView coupon;

  @override
  Widget build(BuildContext context) {
    final expired =
        coupon.expiresAt != null &&
        DateTime.parse(coupon.expiresAt!).isBefore(DateTime.now());
    final status = coupon.usedAt != null
        ? '已使用'
        : expired
        ? '已过期'
        : '可使用';
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(coupon.title, style: Theme.of(context).textTheme.titleMedium),
            Text(coupon.discountLabel),
            const SizedBox(height: AppSpacing.x2),
            Text('券码 ${coupon.code} · $status'),
          ],
        ),
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        AppButton(label: '重试', onPressed: retry),
      ],
    ),
  );
}
