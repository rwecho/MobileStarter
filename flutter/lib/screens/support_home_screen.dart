import 'package:flutter/material.dart';
import '../app/app_scope.dart';
import '../design_system/components.dart';
import '../navigation/app_route.dart';
import '../state/async_state.dart';
import '../support/support_models.dart';
import '../support/support_scope.dart';
import '../theme/app_tokens.dart';

class SupportHomeScreen extends StatefulWidget {
  const SupportHomeScreen({super.key});

  @override
  State<SupportHomeScreen> createState() => _SupportHomeScreenState();
}

class _SupportHomeScreenState extends State<SupportHomeScreen> {
  bool loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loaded) return;
    loaded = true;
    SupportScope.of(context).loadHome();
  }

  @override
  Widget build(BuildContext context) {
    final controller = SupportScope.of(context);
    return AppPage(
      title: '帮助与反馈',
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) => ListView(
          padding: const EdgeInsets.all(AppSpacing.x4),
          children: [
            AppButton(
              label: '联系客服',
              onPressed: () =>
                  AppScope.of(context).navigate(AppRoute.supportNewTicket),
            ),
            const SizedBox(height: AppSpacing.x3),
            OutlinedButton(
              onPressed: () =>
                  AppScope.of(context).navigate(AppRoute.supportFeedback),
              child: const Text('产品反馈'),
            ),
            const SizedBox(height: AppSpacing.x5),
            Text('我的工单', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.x2),
            _TicketState(
              state: controller.tickets,
              onRetry: controller.loadHome,
            ),
            const SizedBox(height: AppSpacing.x5),
            Text('常见问题', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.x2),
            _HelpState(state: controller.help, onRetry: controller.loadHome),
          ],
        ),
      ),
    );
  }
}

class SupportTicketScreen extends StatefulWidget {
  const SupportTicketScreen({super.key});

  @override
  State<SupportTicketScreen> createState() => _SupportTicketScreenState();
}

class _SupportTicketScreenState extends State<SupportTicketScreen> {
  final reply = TextEditingController();

  @override
  void dispose() {
    reply.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = SupportScope.of(context);
    return AppPage(
      title: '工单详情',
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final state = controller.detail;
          if (state is! Success<SupportTicketDetail>) {
            return Center(child: Text(supportStateText(state)));
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.x4),
            children: [
              AppCard(
                child: ListTile(
                  title: Text(state.data.ticket.subject),
                  subtitle: Text(state.data.ticket.status),
                ),
              ),
              const SizedBox(height: AppSpacing.x4),
              ...state.data.messages.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.x3),
                  child: AppCard(
                    child: ListTile(
                      title: Text(item.body),
                      subtitle: Text(item.authorType == 'user' ? '我' : '客服'),
                    ),
                  ),
                ),
              ),
              TextField(
                controller: reply,
                decoration: const InputDecoration(labelText: '继续回复'),
                maxLength: 2000,
                maxLines: 4,
              ),
              AppButton(
                label: controller.busy ? '发送中…' : '发送回复',
                onPressed: () async {
                  if (reply.text.trim().isEmpty) return;
                  if (await controller.reply(reply.text.trim())) reply.clear();
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TicketState extends StatelessWidget {
  const _TicketState({required this.state, required this.onRetry});
  final AsyncState<List<SupportTicket>> state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (state is! Success<List<SupportTicket>>) {
      return _SupportStateMessage(state: state, onRetry: onRetry);
    }
    final data = (state as Success<List<SupportTicket>>).data;
    return AppCard(
      child: Column(
        children: data
            .map(
              (ticket) => ListTile(
                title: Text(ticket.subject),
                subtitle: Text(ticket.status),
                onTap: () async {
                  final controller = SupportScope.of(context);
                  await controller.openTicket(ticket.id);
                  if (context.mounted) {
                    AppScope.of(context).navigate(AppRoute.supportTicket);
                  }
                },
              ),
            )
            .toList(),
      ),
    );
  }
}

class _HelpState extends StatelessWidget {
  const _HelpState({required this.state, required this.onRetry});
  final AsyncState<List<HelpArticle>> state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (state is! Success<List<HelpArticle>>) {
      return _SupportStateMessage(state: state, onRetry: onRetry);
    }
    final data = (state as Success<List<HelpArticle>>).data;
    return Column(
      children: data
          .map(
            (article) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.x3),
              child: AppCard(
                child: ListTile(
                  title: Text(article.title),
                  subtitle: Text(article.body),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _SupportStateMessage<T> extends StatelessWidget {
  const _SupportStateMessage({required this.state, required this.onRetry});

  final AsyncState<T> state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.x4),
      child: Column(
        children: [
          Text(supportStateText(state)),
          if (state is Failure) ...[
            const SizedBox(height: AppSpacing.x2),
            TextButton(onPressed: onRetry, child: const Text('重新加载')),
          ],
        ],
      ),
    ),
  );
}

String supportStateText<T>(AsyncState<T> state) => switch (state) {
  Loading() => '加载中…',
  Empty() => '暂无内容',
  Failure(:final message) => message,
  Offline() => '当前离线，请联网后重试',
  Unauthorized() => '请先登录',
  _ => '暂无内容',
};
