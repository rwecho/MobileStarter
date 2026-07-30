import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../app/runtime_models.dart';
import '../design_system/components.dart';
import '../design_system/feedback.dart';
import '../state/async_state.dart';
import '../theme/app_tokens.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  AsyncState<List<NotificationView>> state = const Loading();
  bool requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!requested) {
      requested = true;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => state = const Loading());
    final controller = AppScope.of(context);
    final success = await controller.loadNotifications();
    if (!mounted) return;
    final items = controller.notifications;
    setState(
      () => state = success
          ? items.isEmpty
                ? const Empty()
                : Success(items)
          : Failure(controller.consumeError() ?? '通知加载失败'),
    );
  }

  @override
  Widget build(BuildContext context) => AppPage(
    title: '通知中心',
    child: Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: _markRead, child: const Text('全部已读')),
        ),
        Expanded(
          child: switch (state) {
            Loading() => const Center(child: CircularProgressIndicator()),
            Empty() => const Center(child: Text('暂无通知')),
            Failure(:final message) => Center(
              child: AppButton(label: message, onPressed: _load),
            ),
            Success(:final data) => ListView(
              padding: const EdgeInsets.all(AppSpacing.x4),
              children: data
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.x3),
                      child: AppCard(
                        child: Column(
                          children: [
                            ListTile(
                              title: Text(item.title),
                              subtitle: Text(item.body),
                              trailing: item.read ? null : const Text('未读'),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (!item.read)
                                  TextButton(
                                    onPressed: () => _read(item.id),
                                    child: const Text('标记已读'),
                                  ),
                                TextButton(
                                  onPressed: () => _delete(item.id),
                                  child: const Text('删除'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            _ => const SizedBox.shrink(),
          },
        ),
      ],
    ),
  );

  Future<void> _markRead() async {
    await AppScope.of(context).markNotificationsRead();
    if (mounted) await _load();
  }

  Future<void> _read(String id) async {
    await AppScope.of(context).markNotificationRead(id);
    if (mounted) await _load();
  }

  Future<void> _delete(String id) async {
    final approved = await showAppConfirm(
      context,
      title: '删除这条通知？',
      message: '删除后不会再次显示。',
      confirmLabel: '删除',
    );
    if (!approved || !mounted) return;
    await AppScope.of(context).deleteNotification(id);
    if (mounted) await _load();
  }
}
