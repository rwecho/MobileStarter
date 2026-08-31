import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/app_scope.dart';
import '../app/runtime_models.dart';
import '../design_system/app_icon.dart';
import '../design_system/components.dart';
import '../theme/app_tokens.dart';
import '../payment/payment_controller.dart';
import '../payment/payment_scope.dart';
import '../state/async_state.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _start() {
    final payment = PaymentScope.of(context);
    final state = payment.purchaseState;
    if (state is Idle || state is Failure || state is Offline) {
      unawaitedCheckout(payment, payment.pendingPlanId ?? '');
    }
  }

  Future<void> unawaitedCheckout(
    PaymentController controller,
    String planId,
  ) async {
    await controller.checkout(planId);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final payment = PaymentScope.of(context);
    final planId = payment.pendingPlanId ?? '';
    final plan = _findPlan(app, planId);
    return Scaffold(
      appBar: AppBar(
        title: const Text('确认订阅'),
        leading: IconButton(
          icon: const AppIcon(AppIconName.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: AnimatedBuilder(
        animation: payment,
        builder: (context, _) {
          final state = payment.purchaseState;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _planCard(plan, planId),
              if (plan?.provider == 'mock')
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    '演示支付：将通过模拟渠道完成。',
                    style: TextStyle(color: Colors.orange),
                  ),
                ),
              _statePanel(state, payment, planId),
            ],
          );
        },
      ),
    );
  }

  Widget _planCard(BillingPlan? plan, String planId) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              plan?.name ?? planId,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (plan != null)
              Text(
                '${plan.priceMinor / 100} ${plan.currency} · ${plan.interval}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
          ],
        ),
      ),
    );
  }

  Widget _statePanel(
    AsyncState<OrderView> state,
    PaymentController payment,
    String planId,
  ) {
    return switch (state) {
      Idle() || Loading() => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      ),
      Success(:final data) => switch (data.status) {
        OrderStatus.success => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppIcon(AppIconName.check, color: AppColors.success, size: 48),
            const SizedBox(height: 8),
            Text('订阅成功（订单 ${data.id}）', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            AppButton(label: '完成', onPressed: () => context.pop()),
          ],
        ),
        OrderStatus.failed => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppIcon(AppIconName.alert, color: AppColors.error, size: 48),
            const SizedBox(height: 8),
            const Text('订阅验证失败，请重试。', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            AppButton(
              label: '重试',
              onPressed: () => unawaitedCheckout(payment, planId),
            ),
          ],
        ),
        _ => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        ),
      },
      Failure(:final message) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(message, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
          AppButton(
            label: '重试',
            onPressed: () => unawaitedCheckout(payment, planId),
          ),
        ],
      ),
      Offline() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('网络不可用，请检查连接后重试。'),
          const SizedBox(height: 12),
          AppButton(
            label: '重试',
            onPressed: () => unawaitedCheckout(payment, planId),
          ),
        ],
      ),
      Unauthorized() => const Center(child: Text('登录已过期，请重新登录。')),
      Empty() => const SizedBox.shrink(),
    };
  }

  BillingPlan? _findPlan(AppController app, String planId) {
    for (final p in app.config?.plans ?? const <BillingPlan>[]) {
      if (p.id == planId) return p;
    }
    return null;
  }
}
