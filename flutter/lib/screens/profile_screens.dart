import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app/app_scope.dart';
import '../app/runtime_models.dart';
import '../design_system/app_icon.dart';
import '../design_system/components.dart';
import '../design_system/feedback.dart';
import '../navigation/app_route.dart';
import '../navigation/app_route_paths.dart';
import '../payment/payment_scope.dart';
import '../theme/app_tokens.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.signedIn) return const _SignedOutProfile();
        return AppPage(
          title: '我的',
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.x4),
            children: [
              AppCard(
                child: AppListTile(
                  label: controller.user!.displayName,
                  value: controller.user!.email,
                  icon: AppIconName.user,
                ),
              ),
              const SizedBox(height: AppSpacing.x4),
              AppCard(
                child: Column(
                  children: [
                    const AppListTile(
                      label: '个人资料',
                      route: AppRoute.profileEdit,
                      icon: AppIconName.user,
                    ),
                    const AppListTile(
                      label: '会员中心',
                      route: AppRoute.membership,
                      icon: AppIconName.crown,
                    ),
                    if (controller.config?.features['statistics'] == true)
                      const AppListTile(
                        label: '使用统计',
                        route: AppRoute.statistics,
                        icon: AppIconName.home,
                      ),
                    if (controller.config?.features['coupons'] == true)
                      const AppListTile(
                        label: '优惠券',
                        route: AppRoute.coupons,
                        icon: AppIconName.gift,
                      ),
                    if (controller.config?.features['invites'] == true)
                      const AppListTile(
                        label: '邀请好友',
                        route: AppRoute.invite,
                        icon: AppIconName.gift,
                      ),
                    const AppListTile(
                      label: '订单管理',
                      route: AppRoute.orders,
                      icon: AppIconName.gift,
                    ),
                    const AppListTile(
                      label: '设置',
                      route: AppRoute.settings,
                      icon: AppIconName.settings,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.x4),
              AppButton(
                label: '退出登录',
                destructive: true,
                onPressed: () => _signOut(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final approved = await showAppConfirm(
      context,
      title: '退出登录？',
      message: '本机仍会保留非敏感偏好设置。',
      confirmLabel: '退出',
    );
    if (!approved || !context.mounted) return;
    final controller = AppScope.of(context);
    await controller.signOut();
    if (!context.mounted) return;
    context.go(pathFor(AppRoute.home));
  }
}

class _SignedOutProfile extends StatelessWidget {
  const _SignedOutProfile();

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: '我的',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppIcon(AppIconName.user, color: AppColors.brand, size: 56),
              const SizedBox(height: AppSpacing.x4),
              Text('登录后同步你的数据', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.x2),
              Text(
                '会员、订单、优惠券与设置会安全同步。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.x6),
              AppButton(
                label: '登录或注册',
                onPressed: () => context.push(pathFor(AppRoute.signIn)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MembershipScreen extends StatefulWidget {
  const MembershipScreen({super.key});

  @override
  State<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends State<MembershipScreen> {
  String selectedPlan = '';

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final config = controller.config;
        if (config == null) {
          return AppPage(
            title: '会员中心',
            child: Center(
              child: AppButton(label: '重试', onPressed: controller.initialize),
            ),
          );
        }
        final effectivePlan = _effectivePlan(config.plans);
        final effectivePlanView = config.plans
            .where((plan) => plan.id == effectivePlan)
            .firstOrNull;
        return AppPage(
          title: '会员中心',
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.x4),
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.x6),
                decoration: BoxDecoration(
                  color: AppColors.text,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MEMBERSHIP',
                      style: TextStyle(color: AppColors.brand),
                    ),
                    const SizedBox(height: AppSpacing.x3),
                    const Text(
                      '按产品动态组合等级',
                      style: TextStyle(
                        color: AppColors.surface,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '当前包含 ${config.tiers.length} 个等级与 ${config.plans.length} 个方案。',
                      style: const TextStyle(color: AppColors.border),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.x4),
              ...config.tiers.map(
                (tier) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.x3),
                  child: AppCard(
                    child: ListTile(
                      title: Text(tier.name),
                      subtitle: Text(
                        '${tier.summary}\n${tier.entitlements.length} 项权益',
                      ),
                      trailing: controller.user?.tierId == tier.id
                          ? const Text('当前等级')
                          : tier.recommended
                          ? const Text('推荐')
                          : null,
                    ),
                  ),
                ),
              ),
              if (config.plans.isNotEmpty) ...[
                Text('可订阅方案', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.x2),
                RadioGroup<String>(
                  groupValue: effectivePlan,
                  onChanged: (value) =>
                      setState(() => selectedPlan = value ?? ''),
                  child: AppCard(
                    child: Column(
                      children: config.plans
                          .map(
                            (plan) => RadioListTile<String>(
                              value: plan.id,
                              title: Text(plan.name),
                              subtitle: Text(
                                _price(
                                  plan.priceMinor,
                                  plan.currency,
                                  plan.interval,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.x4),
                if (effectivePlanView?.provider == 'mock') ...[
                  const AppCard(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.x4),
                      child: Text('当前为演示支付，不会调用真实商店或支付渠道。'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x3),
                ],
                AppButton(
                  label: !controller.signedIn
                      ? '登录后订阅'
                      : effectivePlanView?.provider == 'mock'
                      ? '演示下单（非真实支付）'
                      : '确认订阅',
                  icon: AppIconName.crown,
                  onPressed: _confirm,
                ),
              ] else
                const Text('当前 App 暂未配置可售方案。'),
              const SizedBox(height: AppSpacing.x3),
              const AppCard(
                child: AppListTile(
                  label: '订单记录',
                  route: AppRoute.orders,
                  icon: AppIconName.gift,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirm() {
    final controller = AppScope.of(context);
    if (!controller.signedIn) {
      context.push(pathFor(AppRoute.signIn));
      return;
    }
    final planId = _effectivePlan(controller.config?.plans ?? const []);
    if (planId.isEmpty) return;
    _pushCheckout(planId);
  }

  void _pushCheckout(String planId) {
    final payment = PaymentScope.of(context);
    payment.resetPurchaseState();
    payment.pendingPlanId = planId;
    context.push(pathFor(AppRoute.checkout));
  }

  String _price(int minor, String currency, String interval) {
    final period =
        const {
          'month': '月',
          'year': '年',
          'one_time': '次',
          'lifetime': '终身',
        }[interval] ??
        interval;
    return '$currency ${(minor / 100).toStringAsFixed(2)}/$period';
  }

  String _effectivePlan(List<BillingPlan> plans) {
    if (plans.any((plan) => plan.id == selectedPlan)) return selectedPlan;
    return plans.isEmpty ? '' : plans.first.id;
  }
}
