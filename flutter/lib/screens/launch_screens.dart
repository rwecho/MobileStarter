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

// ── Splash screen ─────────────────────────────────────────────────────────
// 统一三端启动体验：原生 logo → 品牌闪屏 → home。闪屏仅在「在线且有 splash 配置」
// 时展示（全屏媒体 + 右上角胶囊跳过 + 倒计时）；离线或未配置 → 直接进首页。
//
// 阶段：
//  1. loading：logo + appName + tagline + 加载指示 + "加载中…"
//     只等磁盘（controller.localReady），不等网络（8s 兜底防 fetch 挂死）。
//     AGC 冷启动时延 ≤1100ms：原生启动页渐隐已覆盖品牌停顿，App 内不再
//     强制 1s logo 展示（issue #24）。
//  2. localReady 后判断：无缓存闪屏配置 → 不等网络直接进首页（bootstrap 后台
//     继续完成）；有缓存闪屏 → 等 bootstrap 拉最新后：splash==null 或 离线 →
//     直进首页；在线且有 splash → 预加载媒体 → 品牌闪屏 → home

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
    _maxTimer = Timer(_kMaxSplashWait, _goHome);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = AppScope.of(context);
    if (!_listening) {
      _controller.addListener(_onChanged);
      _listening = true;
      // 挂载时 localReady 可能已就绪（磁盘读取早于页面挂载）：首帧后再推进
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAdvance());
    }
  }

  void _onChanged() {
    if (!mounted) return;
    _maybeAdvance();
  }

  void _maybeAdvance() {
    if (_advancing || _countdown != null) return; // 已进入闪屏或正在推进
    if (!_controller.localReady) return; // 磁盘缓存配置未读完：等 listener 触发
    final splash = _controller.config?.splash;
    if (splash == null && !_controller.bootstrapped) {
      _goHome(); // 无缓存闪屏配置：不等网络直接进首页，bootstrap 后台继续
      return;
    }
    if (!_controller.bootstrapped) return; // 有缓存闪屏 → 等 bootstrap 拉最新
    if (splash == null || !_controller.online) {
      _goHome(); // 未配置闪屏或离线 → 直接进首页
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
        _goHome();
        return;
      }
      setState(() => _countdown = _countdown! - 1);
    });
  }

  void _goHome() {
    if (_done || !mounted) return;
    _done = true;
    context.go(pathFor(AppRoute.home));
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
          // 阶段 loading：logo + appName + tagline + 加载指示 + "加载中…"
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
                  const SizedBox(height: AppSpacing.x1),
                  Text(
                    config?.tagline ?? '',
                    style: const TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 14,
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
                  const SizedBox(height: AppSpacing.x2),
                  const Text(
                    '加载中…',
                    style: TextStyle(color: AppColors.brand, fontSize: 14),
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
                        onSkip: _goHome,
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
