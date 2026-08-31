import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../app/app_scope.dart';
import 'splash_media.dart';
import '../app/runtime_models.dart';
import '../design_system/components.dart';
import '../navigation/app_route.dart';
import '../navigation/app_route_paths.dart';
import '../theme/app_tokens.dart';

// ── 启动门（原品牌闪屏入口）──────────────────────────────────────────────
// 本屏只是 bootstrap 等待门：原生 logo → （极短 loading）→ 分流落地。
// **默认关掉品牌闪屏**：无 config.splash 时 bootstrap 一完成立即分流——
// 已登录 → home，未登录 → signIn（认证页即落地页）。分流依赖登录态，
// 而 user 只在 bootstrap 后可知，故不做"不等网络直进首页"的快速路径
//（8s 兜底防 fetch 挂死）。仅当配置了 config.splash 且在线时才展示
// 品牌闪屏活动（可选项）。

const Duration _kMaxSplashWait = Duration(seconds: 8);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late AppController _controller;
  Timer? _maxTimer;
  Timer? _countdownTimer;
  bool _listening = false;
  bool _advancing = false;
  bool _done = false;
  int? _countdown; // null = loading 阶段；非空 = 品牌闪屏阶段

  @override
  void initState() {
    super.initState();
    // fetch 无显式超时，最长等待兜底，避免一直卡在 loading
    _maxTimer = Timer(_kMaxSplashWait, _enterApp);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = AppScope.of(context);
    if (!_listening) {
      _controller.addListener(_onChanged);
      _listening = true;
      // 挂载时 bootstrap 可能已完成（早于页面挂载）：首帧后再推进
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAdvance());
    }
  }

  void _onChanged() {
    if (!mounted) return;
    _maybeAdvance();
  }

  void _maybeAdvance() {
    if (_advancing || _countdown != null) return; // 已进入闪屏或正在推进
    if (!_controller.bootstrapped) return; // 分流需知登录态：等 bootstrap（8s 兜底）
    final splash = _controller.config?.splash;
    if (splash == null || !_controller.online) {
      _enterApp(); // 默认：未配置闪屏或离线 → 直接落地（home / 认证页）
      return;
    }
    _advancing = true;
    _preloadAndEnter(splash);
  }

  Future<void> _preloadAndEnter(SplashCampaign splash) async {
    // loading 阶段预加载图片，进入闪屏时秒显，消除等待
    if (splash.imageUrl != null && splash.imageUrl!.isNotEmpty) {
      await precacheImage(
        NetworkImage(splash.imageUrl!),
        context,
      ).catchError((Object _) => const <Object>[]);
    }
    if (!mounted || _done) return;
    setState(() => _countdown = splash.durationSeconds);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if ((_countdown ?? 0) <= 1) {
        _countdownTimer?.cancel();
        _enterApp();
        return;
      }
      setState(() => _countdown = _countdown! - 1);
    });
  }

  void _enterApp() {
    if (_done || !mounted) return;
    _done = true;
    final target = _controller.signedIn ? AppRoute.home : AppRoute.signIn;
    context.go(pathFor(target));
  }

  @override
  void dispose() {
    if (_listening) _controller.removeListener(_onChanged);
    _maxTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final config = _controller.config;
        final background = Theme.of(context).colorScheme.surface;
        if (_countdown == null) {
          // 阶段 loading：logo + appName + 转圈。bootstrap 通常几百 ms，
          // 不设最短展示时间——完成即分流，默认体验无闪屏。
          return Scaffold(
            backgroundColor: background,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _LogoMark(),
                  const SizedBox(height: AppSpacing.x4),
                  Text(
                    config?.appName ?? 'MobileStarter',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x5),
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.brand,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // countdown 非空即已确认有 splash 配置
        final splash = config!.splash!;
        final canSkip = splash.skippable != false;
        return Scaffold(
          backgroundColor: background,
          body: Stack(
            children: [
              Positioned.fill(child: SplashMedia(splash: splash)),
              Positioned(
                top: 0,
                right: 0,
                left: 0,
                child: SafeArea(
                  bottom: false,
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.x3),
                      child: SplashSkipCapsule(
                        countdown: _countdown ?? 0,
                        canSkip: canSkip,
                        onSkip: _enterApp,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
            onPressed: () => context.go(pathFor(AppRoute.home)),
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
