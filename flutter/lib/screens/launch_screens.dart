import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:video_player/video_player.dart';
import '../app/app_controller.dart';
import '../app/app_scope.dart';
import '../app/runtime_models.dart';
import '../design_system/components.dart';
import '../navigation/app_route.dart';
import '../theme/app_tokens.dart';

// ── Splash screen ─────────────────────────────────────────────────────────
// 统一三端启动体验：原生 logo → 品牌闪屏 → home。闪屏仅在「在线且有 splash 配置」
// 时展示（全屏媒体 + 右上角胶囊跳过 + 倒计时）；离线或未配置 → 直接进首页。
//
// 阶段：
//  1. loading：logo + appName + tagline + 加载指示 + "加载中…"
//     等待「最短展示 1s AND 初始 bootstrap 完成」（8s 兜底防 fetch 挂死）
//  2. bootstrap 完成后判断：splash==null 或 离线 → 直进首页；
//     在线且有 splash → 预加载媒体 → 品牌闪屏（倒计时用 durationSeconds）→ home

const Duration _kMinLogoDelay = Duration(seconds: 1);
const Duration _kMaxSplashWait = Duration(seconds: 8);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late AppController _controller;
  Timer? _minTimer;
  Timer? _maxTimer;
  Timer? _countdownTimer;
  bool _listening = false;
  bool _minElapsed = false;
  bool _advancing = false;
  bool _done = false;
  int? _countdown; // null = loading 阶段；非空 = 品牌闪屏阶段

  @override
  void initState() {
    super.initState();
    _minTimer = Timer(_kMinLogoDelay, () {
      if (!mounted) return;
      setState(() => _minElapsed = true);
      _maybeAdvance();
    });
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
    }
  }

  void _onChanged() {
    if (!mounted) return;
    _maybeAdvance();
  }

  void _maybeAdvance() {
    if (_advancing || _countdown != null) return; // 已进入闪屏或正在推进
    if (!_minElapsed || !_controller.bootstrapped) return;
    final splash = _controller.config?.splash;
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
      await precacheImage(NetworkImage(splash.imageUrl!), context)
          .catchError((Object _) => const <Object>[]);
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
    _controller.replaceAll(AppRoute.home);
  }

  @override
  void dispose() {
    if (_listening) _controller.removeListener(_onChanged);
    _minTimer?.cancel();
    _maxTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.x1),
              Text(
                config?.tagline ?? '',
                style: const TextStyle(color: AppColors.secondaryText, fontSize: 14),
              ),
              const SizedBox(height: AppSpacing.x5),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brand),
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
          Positioned.fill(child: _SplashMedia(splash: splash)),
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
                  child: _SkipCapsule(
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
  }
}

// 右上角胶囊跳过按钮（开屏广告标准形态：半透明深底 + 白字 + 倒计时）
class _SkipCapsule extends StatelessWidget {
  const _SkipCapsule({
    required this.countdown,
    required this.canSkip,
    required this.onSkip,
  });

  final int countdown;
  final bool canSkip;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '跳过闪屏，剩余 $countdown 秒',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: canSkip ? onSkip : null,
          child: Container(
            constraints: const BoxConstraints(minHeight: 36, minWidth: 72),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0x66000000),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              canSkip ? '$countdown s 跳过' : '$countdown s',
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}

// 全屏媒体背景：视频（videoUrl）> 图片（imageUrl cover）> 品牌 fallback。
// 媒体加载期间透出 app 背景色（由父 Scaffold 提供），避免黑屏。
class _SplashMedia extends StatelessWidget {
  const _SplashMedia({required this.splash});

  final SplashCampaign splash;

  @override
  Widget build(BuildContext context) {
    final video = splash.videoUrl;
    final image = splash.imageUrl;
    if (video != null && video.isNotEmpty) {
      // 视频 → 失败回退图片 → 图片失败回退插画
      final imageWidget = (image != null && image.isNotEmpty)
          ? Image.network(
              image,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              semanticLabel: '闪屏图片',
              errorBuilder: (_, _, _) => _SplashFallback(splash: splash),
            )
          : _SplashFallback(splash: splash);
      return _SplashVideo(url: video, fallback: imageWidget);
    }
    if (image != null && image.isNotEmpty) {
      return Image.network(
        image,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        semanticLabel: '闪屏图片',
        errorBuilder: (_, _, _) => _SplashFallback(splash: splash),
      );
    }
    return _SplashFallback(splash: splash);
  }
}

// 全屏视频：静音自动循环播放（iOS 自动播放需静音）。初始化期间显示 app 背景色，
// 初始化失败回退到 fallback widget（图片/插画）。
class _SplashVideo extends StatefulWidget {
  const _SplashVideo({required this.url, required this.fallback});

  final String url;
  final Widget fallback;

  @override
  State<_SplashVideo> createState() => _SplashVideoState();
}

class _SplashVideoState extends State<_SplashVideo> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller.initialize().then((_) {
      if (!mounted) return;
      _controller.setLooping(true);
      _controller.setVolume(0);
      _controller.play();
      setState(() => _initialized = true);
    }).catchError((Object _) {
      if (mounted) setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return widget.fallback;
    if (!_initialized) {
      // 初始化中：显示 app 背景色，避免黑屏
      return SizedBox.expand(child: ColoredBox(color: Theme.of(context).colorScheme.surface, child: const SizedBox.shrink()));
    }
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _controller.value.size.width,
          height: _controller.value.size.height,
          child: VideoPlayer(_controller),
        ),
      ),
    );
  }
}

// 无媒体时的品牌 fallback：内置插画 + 活动文案
class _SplashFallback extends StatelessWidget {
  const _SplashFallback({required this.splash});

  final SplashCampaign splash;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(AppSpacing.x6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/illustrations/promo.svg',
            height: 200,
            semanticsLabel: '活动宣传插图',
          ),
          const SizedBox(height: AppSpacing.x4),
          Text(
            splash.badge,
            style: const TextStyle(color: AppColors.brand, fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.x2),
          Text(splash.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.x2),
          Text(
            splash.description,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.secondaryText, fontSize: 14),
          ),
        ],
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
