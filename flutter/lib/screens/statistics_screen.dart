import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../app/runtime_models.dart';
import '../design_system/app_icon.dart';
import '../design_system/components.dart';
import '../state/async_state.dart';
import '../theme/app_tokens.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  AsyncState<UsageSummary> state = const Idle();
  bool requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (requested) return;
    requested = true;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: '使用统计',
      child: switch (state) {
        Idle() || Loading() => const Center(child: CircularProgressIndicator()),
        Empty() => const Center(child: Text('开始使用后，这里会显示匿名聚合数据。')),
        Failure(:final message) => _Error(message: message, retry: _load),
        Offline() => _Error(message: '网络不可用，请连接后重试。', retry: _load),
        Unauthorized() => const Center(child: Text('登录后才能查看使用统计。')),
        Success(:final data) => _UsageContent(usage: data),
      },
    );
  }

  Future<void> _load() async {
    setState(() => state = const Loading());
    final controller = AppScope.of(context);
    final loaded = await controller.loadUsage();
    if (!mounted) return;
    final usage = controller.usage;
    setState(() {
      if (loaded && usage != null && usage.screens.isEmpty) {
        state = const Empty();
      } else if (loaded && usage != null) {
        state = Success(usage);
      } else {
        state = Failure(controller.consumeError() ?? '加载失败');
      }
    });
  }
}

class _UsageContent extends StatelessWidget {
  const _UsageContent({required this.usage});
  final UsageSummary usage;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.x4),
      children: [
        AppCard(
          child: Column(
            children: [
              AppListTile(label: '会话次数', value: '${usage.sessions}'),
              AppListTile(label: '页面浏览', value: '${usage.screenViews}'),
              AppListTile(label: '活跃时长', value: '${usage.activeMinutes} 分钟'),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.x3),
        ...usage.screens.map(
          (screen) => AppCard(
            child: AppListTile(
              label: screen.screenId,
              value:
                  '${screen.views} 次 · ${(screen.durationMs / 1000).round()} 秒',
            ),
          ),
        ),
      ],
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.x6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppIcon(AppIconName.alert),
          const SizedBox(height: AppSpacing.x2),
          Text(message),
          const SizedBox(height: AppSpacing.x4),
          AppButton(label: '重试', onPressed: retry),
        ],
      ),
    ),
  );
}
