import 'package:flutter/material.dart';
import '../app/app_scope.dart';
import '../design_system/components.dart';
import '../navigation/app_route.dart';
import '../support/support_controller.dart';
import '../support/support_scope.dart';
import '../theme/app_tokens.dart';

class NewSupportTicketScreen extends StatefulWidget {
  const NewSupportTicketScreen({super.key});

  @override
  State<NewSupportTicketScreen> createState() => _NewSupportTicketScreenState();
}

class _NewSupportTicketScreenState extends State<NewSupportTicketScreen> {
  final subject = TextEditingController();
  final message = TextEditingController();
  String category = 'technical';
  String severity = 'normal';

  @override
  void dispose() {
    subject.dispose();
    message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = SupportScope.of(context);
    return AppPage(
      title: '联系客服',
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) => ListView(
          padding: const EdgeInsets.all(AppSpacing.x4),
          children: [
            ChoiceGroup(
              value: category,
              options: const {
                'account': '账号与登录',
                'billing': '会员与支付',
                'technical': '功能故障',
                'privacy': '隐私与数据',
                'suggestion': '产品建议',
              },
              onChanged: (value) => setState(() => category = value),
            ),
            const SizedBox(height: AppSpacing.x4),
            ChoiceGroup(
              value: severity,
              options: const {'normal': '普通', 'high': '较高', 'urgent': '紧急'},
              onChanged: (value) => setState(() => severity = value),
            ),
            const SizedBox(height: AppSpacing.x4),
            TextField(
              controller: subject,
              decoration: const InputDecoration(labelText: '问题标题'),
              maxLength: 100,
            ),
            TextField(
              controller: message,
              decoration: const InputDecoration(
                labelText: '问题详情',
                hintText: '请勿填写密码或验证码',
              ),
              maxLength: 2000,
              maxLines: 6,
            ),
            if (controller.lastError != null)
              Text(
                controller.lastError!,
                style: const TextStyle(color: AppColors.error),
              ),
            AppButton(
              label: controller.busy ? '提交中…' : '提交工单',
              onPressed: () => _submit(controller),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(SupportController controller) async {
    if (subject.text.trim().length < 4 || message.text.trim().length < 4) {
      return;
    }
    final success = await controller.createTicket(
      category: category,
      severity: severity,
      subject: subject.text.trim(),
      message: message.text.trim(),
    );
    if (success && mounted) {
      AppScope.of(context).navigate(AppRoute.supportTicket);
    }
  }
}

class ProductFeedbackScreen extends StatefulWidget {
  const ProductFeedbackScreen({super.key});

  @override
  State<ProductFeedbackScreen> createState() => _ProductFeedbackScreenState();
}

class _ProductFeedbackScreenState extends State<ProductFeedbackScreen> {
  final title = TextEditingController();
  final body = TextEditingController();
  String category = 'suggestion';
  int rating = 5;

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = SupportScope.of(context);
    return AppPage(
      title: '产品反馈',
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) => ListView(
          padding: const EdgeInsets.all(AppSpacing.x4),
          children: [
            ChoiceGroup(
              value: category,
              options: const {
                'suggestion': '产品建议',
                'experience': '体验问题',
                'feature_request': '功能需求',
                'other': '其他',
              },
              onChanged: (value) => setState(() => category = value),
            ),
            const SizedBox(height: AppSpacing.x4),
            Slider(
              value: rating.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              label: '$rating 分',
              onChanged: (value) => setState(() => rating = value.round()),
            ),
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: '反馈标题'),
              maxLength: 100,
            ),
            TextField(
              controller: body,
              decoration: const InputDecoration(labelText: '反馈详情'),
              maxLength: 3000,
              maxLines: 6,
            ),
            if (controller.lastError != null)
              Text(
                controller.lastError!,
                style: const TextStyle(color: AppColors.error),
              ),
            AppButton(
              label: controller.busy ? '提交中…' : '提交反馈',
              onPressed: () => _submit(controller),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(SupportController controller) async {
    if (title.text.trim().length < 4 || body.text.trim().length < 4) return;
    final success = await controller.submitFeedback(
      category: category,
      title: title.text.trim(),
      body: body.text.trim(),
      rating: rating,
    );
    if (success && mounted) AppScope.of(context).back();
  }
}

class ChoiceGroup extends StatelessWidget {
  const ChoiceGroup({
    required this.value,
    required this.options,
    required this.onChanged,
    super.key,
  });

  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      children: options.entries
          .map(
            (item) => ListTile(
              title: Text(item.value),
              trailing: Text(value == item.key ? '已选择' : ''),
              onTap: () => onChanged(item.key),
            ),
          )
          .toList(),
    ),
  );
}
