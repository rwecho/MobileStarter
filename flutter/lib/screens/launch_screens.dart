import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../app/app_scope.dart';
import '../design_system/components.dart';
import '../navigation/app_route.dart';
import '../theme/app_tokens.dart';

class LogoScreen extends StatelessWidget {
  const LogoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final appName = controller.config?.appName ?? 'MobileStarter';
    return Scaffold(
      body: InkWell(
        onTap: () => controller.navigate(AppRoute.promo),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _LogoMark(),
              const SizedBox(height: AppSpacing.x4),
              Text(
                appName,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.x2),
              const Text(
                '轻触继续',
                style: TextStyle(color: AppColors.secondaryText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PromoScreen extends StatelessWidget {
  const PromoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final campaign = controller.config?.splash;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (campaign?.skippable != false)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => controller.replaceAll(AppRoute.home),
                    child: const Text('跳过'),
                  ),
                ),
              const Spacer(),
              _CampaignImage(imageUrl: campaign?.imageUrl),
              const SizedBox(height: AppSpacing.x6),
              Text(
                campaign?.title ?? '让每次使用都更简单',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.x2),
              Text(
                campaign?.description ?? '正在读取最新活动内容。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              AppButton(
                label: campaign?.actionLabel ?? '立即体验',
                onPressed: () => controller.replaceAll(AppRoute.home),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CampaignImage extends StatelessWidget {
  const _CampaignImage({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return SvgPicture.asset(
        'assets/illustrations/promo.svg',
        height: 220,
        semanticsLabel: '活动宣传插图',
      );
    }
    return Image.network(
      imageUrl!,
      height: 220,
      fit: BoxFit.contain,
      semanticLabel: '活动宣传图片',
      errorBuilder: (_, _, _) => SvgPicture.asset(
        'assets/illustrations/promo.svg',
        height: 220,
        semanticsLabel: '活动宣传备用插图',
      ),
    );
  }
}

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: '首次引导',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x6),
          child: AppButton(
            label: '完成引导',
            onPressed: () => AppScope.of(context).replaceAll(AppRoute.home),
          ),
        ),
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: .78,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.brand,
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        child: Center(
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.small),
            ),
          ),
        ),
      ),
    );
  }
}
