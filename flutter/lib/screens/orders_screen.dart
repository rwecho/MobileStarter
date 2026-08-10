import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../app/runtime_models.dart';
import '../design_system/components.dart';
import '../state/async_state.dart';
import '../theme/app_tokens.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  AsyncState<List<OrderView>> state = const Loading();
  bool requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!requested) {
      requested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
  }

  Future<void> _load() async {
    setState(() => state = const Loading());
    final controller = AppScope.of(context);
    final success = await controller.loadOrders();
    if (!mounted) return;
    setState(() {
      final items = controller.orders;
      state = success
          ? items.isEmpty
                ? const Empty()
                : Success(items)
          : Failure(controller.consumeError() ?? '订单加载失败');
    });
  }

  @override
  Widget build(BuildContext context) => AppPage(
    title: '订单管理',
    child: switch (state) {
      Loading() => const Center(child: CircularProgressIndicator()),
      Empty() => const Center(child: Text('暂无订单')),
      Failure(:final message) => _Retry(message: message, retry: _load),
      Success(:final data) => ListView(
        padding: const EdgeInsets.all(AppSpacing.x4),
        children: data
            .map(
              (order) => AppCard(
                child: ListTile(
                  title: Text(order.planId),
                  subtitle: Text(order.status.name),
                  trailing: Text(
                    '${order.currency} ${(order.amountMinor / 100).toStringAsFixed(2)}',
                  ),
                ),
              ),
            )
            .toList(),
      ),
      _ => const SizedBox.shrink(),
    },
  );
}

class _Retry extends StatelessWidget {
  const _Retry({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        const SizedBox(height: AppSpacing.x3),
        AppButton(label: '重试', onPressed: retry),
      ],
    ),
  );
}
