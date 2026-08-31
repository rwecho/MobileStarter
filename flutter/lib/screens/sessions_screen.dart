import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../app/runtime_models.dart';
import '../design_system/app_icon.dart';
import '../design_system/components.dart';
import '../design_system/feedback.dart';
import '../state/async_state.dart';
import '../theme/app_tokens.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  AsyncState<List<SessionView>> state = const Idle();
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
  Widget build(BuildContext context) {
    return AppPage(
      title: '登录设备管理',
      child: switch (state) {
        Loading() || Idle() => const Center(child: CircularProgressIndicator()),
        Empty() => const _Message(
          icon: AppIconName.user,
          title: '没有登录设备',
          message: '登录成功后，设备会显示在这里。',
        ),
        Failure(:final message) => _Message(
          icon: AppIconName.alert,
          title: '加载失败',
          message: message,
          onRetry: _load,
        ),
        Offline() => _Message(
          icon: AppIconName.alert,
          title: '当前处于离线状态',
          message: '连接网络后可查看和撤销登录设备。',
          onRetry: _load,
        ),
        Unauthorized() => const _Message(
          icon: AppIconName.lock,
          title: '请先登录',
          message: '登录后才能管理设备。',
        ),
        Success(:final data) => _SessionList(sessions: data, onRevoke: _revoke),
      },
    );
  }

  Future<void> _load() async {
    setState(() => state = const Loading());
    final controller = AppScope.of(context);
    final loaded = await controller.loadSessions();
    if (!mounted) return;
    final error = controller.consumeError();
    setState(() {
      if (loaded && controller.sessions.isEmpty) {
        state = const Empty();
      } else if (loaded) {
        state = Success(controller.sessions);
      } else if (error != null) {
        state = Failure(error);
      } else {
        state = const Offline();
      }
    });
  }

  Future<void> _revoke(String id) async {
    final controller = AppScope.of(context);
    final revoked = await controller.revokeSession(id);
    if (!mounted) return;
    if (revoked) {
      setState(() => state = Success(controller.sessions));
      return;
    }
    final message = controller.consumeError() ?? '撤销失败，请重试';
    showAppToast(context, message, error: true);
  }
}

class _SessionList extends StatelessWidget {
  const _SessionList({required this.sessions, required this.onRevoke});

  final List<SessionView> sessions;
  final ValueChanged<String> onRevoke;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.x4),
      itemCount: sessions.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.x3),
      itemBuilder: (context, index) {
        final session = sessions[index];
        return AppCard(
          child: ListTile(
            minTileHeight: 72,
            leading: const AppIcon(AppIconName.user),
            title: Text(session.deviceName),
            subtitle: Text(session.current ? '当前设备' : '已登录设备'),
            trailing: session.current
                ? null
                : TextButton(
                    onPressed: () => onRevoke(session.id),
                    child: const Text('撤销'),
                  ),
          ),
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.message,
    this.onRetry,
  });

  final AppIconName icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(icon, size: 36),
            const SizedBox(height: AppSpacing.x3),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.x2),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.x4),
              AppButton(label: '重试', onPressed: onRetry!),
            ],
          ],
        ),
      ),
    );
  }
}
