import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../app/app_controller.dart';
import '../app/app_scope.dart';
import '../design_system/components.dart';
import '../navigation/app_route.dart';
import '../theme/app_tokens.dart';

// ── Logo screen ───────────────────────────────────────────────────────────
// Shows the brand logo while `AppController.initialize()` loads configuration,
// restores the session, and prepares the ad page. Navigates automatically to
// the promo screen once initialisation finishes (with a minimum display time
// so the logo is visible).

class LogoScreen extends StatefulWidget {
  const LogoScreen({super.key});

  @override
  State<LogoScreen> createState() => _LogoScreenState();
}

class _LogoScreenState extends State<LogoScreen> {
  late final AppController _controller;
  Timer? _navigateTimer;
  bool _navigating = false;

  static const _minDisplay = Duration(milliseconds: 1200);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = AppScope.of(context);
    _controller.addListener(_onControllerChanged);
    _onControllerChanged(); // in case it's already ready
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _navigateTimer?.cancel();
    super.dispose();
  }

  void _onControllerChanged() {
    if (_controller.busy || _navigateTimer != null) return;
    // Wait a minimum time so the logo registers on screen.
    _navigateTimer = Timer(_minDisplay, _go);
  }

  void _go() {
    if (_navigating || !mounted) return;
    _navigating = true;
    _controller.navigate(AppRoute.promo);
  }

  @override
  Widget build(BuildContext context) {
    final appName = _controller.config?.appName ?? 'MobileStarter';
    return Scaffold(
      body: Center(
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
          ],
        ),
      ),
    );
  }
}

// ── Promo / campaign screen ───────────────────────────────────────────────
// Displays the campaign artwork, title, and description, with a 3‑2‑1
// countdown that auto‑navigates to `home` when it reaches 0. A "跳过" button
// lets the user skip the countdown and enter immediately.

class PromoScreen extends StatefulWidget {
  const PromoScreen({super.key});

  @override
  State<PromoScreen> createState() => _PromoScreenState();
}

class _PromoScreenState extends State<PromoScreen> {
  late final AppController _controller;
  Timer? _timer;
  int _countdown = 3;
  bool _entered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = AppScope.of(context);
    if (_timer == null) _startCountdown();
  }

  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_countdown <= 1) {
        _timer?.cancel();
        _enter();
        return;
      }
      setState(() => _countdown--);
    });
  }

  void _skip() {
    _timer?.cancel();
    _enter();
  }

  void _enter() {
    if (_entered || !mounted) return;
    _entered = true;
    _controller.replaceAll(AppRoute.home);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final campaign = _controller.config?.splash;
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
                    onPressed: _skip,
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
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$_countdown',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brand,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x1),
                    Text(
                      campaign?.actionLabel ?? '秒后自动进入',
                      style: const TextStyle(color: AppColors.secondaryText),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Campaign image ────────────────────────────────────────────────────────

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

// ── Onboarding (unchanged) ────────────────────────────────────────────────

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

// ── Logo mark (shared shield‑check SVG) ───────────────────────────────────

class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/illustrations/logo.svg',
      width: 48,
      height: 48,
    );
  }
}
