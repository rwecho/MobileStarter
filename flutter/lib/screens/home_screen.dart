import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app/app_scope.dart';
import '../design_system/app_icon.dart';
import '../design_system/components.dart';
import '../navigation/app_route.dart';
import '../navigation/app_route_paths.dart';
import '../l10n/localized_text.dart';
import '../theme/app_tokens.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final appName = controller.config?.appName ?? 'MobileStarter';
        final scheme = Theme.of(context).colorScheme;
        return Scaffold(
          backgroundColor: scheme.surface,
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizedText(context, '欢迎回来', 'Welcome back'),
                  style: const TextStyle(fontSize: 13),
                ),
                Text(appName),
              ],
            ),
            actions: [
              AppIconButton(
                label: '通知中心',
                icon: AppIconName.bell,
                onPressed: () =>
                    context.push(pathFor(AppRoute.notificationCenter)),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.x4),
            children: [
              if (controller.config?.features['membership'] != false) ...[
                _MembershipBanner(
                  onTap: () => context.push(pathFor(AppRoute.membership)),
                ),
                const SizedBox(height: AppSpacing.x5),
              ],
              _QuickActions(features: controller.config?.features ?? const {}),
              const SizedBox(height: AppSpacing.x6),
              Text(
                localizedText(context, '最近动态', 'Recent activity'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.x3),
              const AppCard(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.x4),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('模板已准备完成'),
                    subtitle: Text('三端共享页面、状态、路由与设计令牌。'),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.x3),
              const AppCard(
                child: AppListTile(
                  label: '检查全部状态',
                  value: '加载、空数据、错误、离线与未授权',
                  route: AppRoute.stateGallery,
                  icon: AppIconName.alert,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MembershipBanner extends StatelessWidget {
  const _MembershipBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: Container(
        height: 132,
        padding: const EdgeInsets.all(AppSpacing.x5),
        decoration: BoxDecoration(
          color: AppColors.brand,
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        child: const Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '会员限时体验',
                    style: TextStyle(
                      color: AppColors.surface,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '解锁高级功能与专属权益',
                    style: TextStyle(color: AppColors.surface),
                  ),
                ],
              ),
            ),
            AppIcon(AppIconName.gift, color: AppColors.surface, size: 42),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.features});

  final Map<String, bool> features;

  @override
  Widget build(BuildContext context) {
    final items = <(String, AppIconName, AppRoute, bool)>[
      (
        '会员',
        AppIconName.crown,
        AppRoute.membership,
        features['membership'] != false,
      ),
      ('优惠券', AppIconName.gift, AppRoute.coupons, features['coupons'] == true),
      (
        '通知',
        AppIconName.bell,
        AppRoute.notificationCenter,
        features['notifications'] != false,
      ),
      ('设置', AppIconName.settings, AppRoute.settings, true),
    ].where((item) => item.$4).toList();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: items
          .map(
            (item) => InkWell(
              onTap: () => context.push(pathFor(item.$3)),
              child: Column(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(AppRadii.control),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.x3),
                      child: AppIcon(item.$2, color: AppColors.brand),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x2),
                  Text(item.$1),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
