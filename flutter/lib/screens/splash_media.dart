import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:video_player/video_player.dart';

import '../app/runtime_models.dart';
import '../theme/app_tokens.dart';

// SplashScreen 的媒体辅助 widget——从 launch_screens.dart 拆出，
// 服从 CI 350 行硬上限；仅供闪屏内部使用。

/// 右上角胶囊跳过按钮（开屏广告标准形态：半透明深底 + 白字 + 倒计时）
class SplashSkipCapsule extends StatelessWidget {
  const SplashSkipCapsule({
    super.key,
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
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 全屏媒体背景：视频（videoUrl）> 图片（imageUrl cover）> 品牌 fallback。
/// 媒体加载期间透出 app 背景色（由父 Scaffold 提供），避免黑屏。
class SplashMedia extends StatelessWidget {
  const SplashMedia({super.key, required this.splash});

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
              errorBuilder: (_, _, _) => SplashFallback(splash: splash),
            )
          : SplashFallback(splash: splash);
      return SplashVideo(url: video, fallback: imageWidget);
    }
    if (image != null && image.isNotEmpty) {
      return Image.network(
        image,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        semanticLabel: '闪屏图片',
        errorBuilder: (_, _, _) => SplashFallback(splash: splash),
      );
    }
    return SplashFallback(splash: splash);
  }
}

/// 全屏视频：静音自动循环播放（iOS 自动播放需静音）。初始化期间显示 app 背景色，
/// 初始化失败回退到 fallback widget（图片/插画）。
class SplashVideo extends StatefulWidget {
  const SplashVideo({super.key, required this.url, required this.fallback});

  final String url;
  final Widget fallback;

  @override
  State<SplashVideo> createState() => _SplashVideoState();
}

class _SplashVideoState extends State<SplashVideo> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          _controller.setLooping(true);
          _controller.setVolume(0);
          _controller.play();
          setState(() => _initialized = true);
        })
        .catchError((Object _) {
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
      return SizedBox.expand(
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: const SizedBox.shrink(),
        ),
      );
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

/// 无媒体时的品牌 fallback：内置插画 + 活动文案
class SplashFallback extends StatelessWidget {
  const SplashFallback({super.key, required this.splash});

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
            style: const TextStyle(
              color: AppColors.brand,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.x2),
          Text(
            splash.title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.x2),
          Text(
            splash.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
