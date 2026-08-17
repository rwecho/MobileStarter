import 'dart:convert';

import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import 'app_icon.dart';
import 'app_icon.dart' as icon;

/// 通用资产 URL 解析 + 会话缓存（私有 bucket presigned，24h）。
/// 适用于一切 objectKey（avatar/视频/音频/文档…）。
class AssetUrls {
  AssetUrls._();

  static final Map<String, String> _cache = {};

  /// objectKey → 可显示 URL。http(s)/data: 直接透传；objectKey 换 presigned
  /// 并缓存（同一 key 会话内只请求一次）。失败返回 null（调用方显示占位）。
  static Future<String?> resolve(BuildContext context, String value) async {
    if (value.isEmpty) return null;
    if (value.startsWith('http://') || value.startsWith('https://') ||
        value.startsWith('data:')) {
      return value;
    }
    final cached = _cache[value];
    if (cached != null && cached.isNotEmpty) return cached;
    final url = await AppScope.of(context).resolveObjectUrl(value);
    if (url != null) _cache[value] = url;
    return url;
  }

  /// 加载失败（presigned 过期 >24h）时清缓存，下次重新换取。
  static void invalidate(String objectKey) {
    _cache[objectKey] = '';
  }
}

/// 头像显示：兼容 objectKey（→ presigned）/ http(s) / data: 三种历史形态。
class AvatarImage extends StatefulWidget {
  const AvatarImage({
    required this.avatarUrl,
    this.size = 88,
    super.key,
  });

  final String avatarUrl;
  final double size;

  @override
  State<AvatarImage> createState() => _AvatarImageState();
}

class _AvatarImageState extends State<AvatarImage> {
  String? resolved;
  bool failed = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  // 上传新头像后 avatarUrl 变化 → 重新 resolve（否则停留在旧图）。
  @override
  void didUpdateWidget(covariant AvatarImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avatarUrl != widget.avatarUrl) {
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final url = await AssetUrls.resolve(context, widget.avatarUrl);
    if (mounted) {
      setState(() {
        resolved = url;
        failed = url == null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (failed || resolved == null) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: AppIcon(
          icon.AppIconName.user,
          size: widget.size * 0.43,
          color: scheme.primary,
        ),
      );
    }
    final provider = _provider(resolved!);
    return CircleAvatar(
      radius: widget.size / 2,
      backgroundColor: scheme.primaryContainer,
      backgroundImage: provider,
      onBackgroundImageError: provider is NetworkImage
          ? (_, _) {
              AssetUrls.invalidate(widget.avatarUrl);
              if (mounted) setState(() => failed = true);
            }
          : null,
      child: provider == null
          ? AppIcon(
              icon.AppIconName.user,
              size: widget.size * 0.43,
              color: scheme.primary,
            )
          : null,
    );
  }

  ImageProvider? _provider(String value) {
    if (value.startsWith('data:')) {
      final comma = value.indexOf(',');
      if (comma <= 0) return null;
      try {
        return MemoryImage(base64Decode(value.substring(comma + 1)));
      } catch (_) {
        return null;
      }
    }
    return NetworkImage(value);
  }
}
