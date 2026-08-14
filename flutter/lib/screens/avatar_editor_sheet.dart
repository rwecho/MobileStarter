import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../design_system/components.dart';
import '../design_system/app_icon.dart';
import '../design_system/feedback.dart';
import '../theme/app_tokens.dart';

/// 头像编辑 sheet：底部 2/3 弹出，方形裁剪（InteractiveViewer 缩放/拖拽），
/// 确认后按视口换算原图方形区域 → 512×512 JPEG → 上传 OSS → 返回对象 URL。
Future<String?> showAvatarEditorSheet(
  BuildContext context, {
  required Uint8List imageBytes,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    // 约 2/3 屏高（内容区自带安全边距）。
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.72,
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _AvatarEditorSheet(imageBytes: imageBytes),
  );
}

class _AvatarEditorSheet extends StatefulWidget {
  const _AvatarEditorSheet({required this.imageBytes});

  final Uint8List imageBytes;

  @override
  State<_AvatarEditorSheet> createState() => _AvatarEditorSheetState();
}

class _AvatarEditorSheetState extends State<_AvatarEditorSheet> {
  final controller = TransformationController();
  ui.Image? image;
  double side = 320;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  Future<void> _decode() async {
    final decoded = await decodeImageFromList(widget.imageBytes);
    if (mounted) setState(() => image = decoded);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  // InteractiveViewer 的 4x4 矩阵 → 原图方形裁剪区域。
  Future<void> _confirm() async {
    final img = image;
    if (img == null || busy) return;
    setState(() => busy = true);
    try {
      // InteractiveViewer 矩阵求逆：把方形视口的左上/右下映射回图片坐标。
      final Matrix4 inverted = Matrix4.copy(controller.value)..invert();
      final p1 = MatrixUtils.transformPoint(
        inverted, ui.Offset.zero,
      );
      final p2 = MatrixUtils.transformPoint(
        inverted, ui.Offset(side, side),
      );
      // Contain 适配：显示尺寸、原图左上显示位置。
      final fit = side / (img.width <= img.height ? img.width : img.height);
      final imgW = img.width * fit;
      final imgH = img.height * fit;
      final originX = (side - imgW) / 2;
      final originY = (side - imgH) / 2;
      double cropSide = (p2.dx - p1.dx) / fit;
      if (cropSide > img.width) cropSide = img.width.toDouble();
      if (cropSide > img.height) cropSide = img.height.toDouble();
      double rx = (p1.dx - originX) / fit;
      double ry = (p1.dy - originY) / fit;
      if (rx < 0) rx = 0;
      if (ry < 0) ry = 0;
      if (rx > img.width - cropSide) rx = img.width - cropSide;
      if (ry > img.height - cropSide) ry = img.height - cropSide;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final src = Rect.fromLTWH(rx, ry, cropSide, cropSide);
      const dst = Rect.fromLTWH(0, 0, 512, 512);
      canvas.drawImageRect(img, src, dst, Paint());
      final cropped = await recorder.endRecording().toImage(512, 512);
      final data = await cropped.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('裁剪失败');
      final appController = AppScope.of(context);
      final url = await appController.uploadAvatar(
        data.buffer.asUint8List(),
      );
      if (!mounted) return;
      if (url != null) {
        Navigator.of(context).pop(url);
      } else {
        setState(() => busy = false);
        showAppToast(context, '头像上传失败，请重试', error: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => busy = false);
        showAppToast(context, '头像上传失败，请重试', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.x5,
        right: AppSpacing.x5,
        top: AppSpacing.x5,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.x5,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '编辑头像',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.x4),
          Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                side = width.clamp(200.0, 360.0).toDouble();
                return ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  child: SizedBox(
                    width: side,
                    height: side,
                    child: image == null
                        ? const Center(child: CircularProgressIndicator())
                        : InteractiveViewer(
                            transformationController: controller,
                            minScale: 1,
                            maxScale: 4,
                            boundaryMargin: const EdgeInsets.all(400),
                            constrained: false,
                            alignment: Alignment.center,
                            child: Image.memory(
                              widget.imageBytes,
                              width: side,
                              height: side,
                              fit: BoxFit.contain,
                            ),
                          ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.x2),
          const Center(
            child: Text(
              '双指缩放 · 单指拖拽调整构图',
              style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
            ),
          ),
          const SizedBox(height: AppSpacing.x4),
          Row(
            children: [
              Expanded(
                child: AppButton(label: '取消', onPressed: () => Navigator.of(context).pop()),
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: AppButton(
                  label: busy ? '上传中…' : '确认并上传',
                  icon: AppIconName.check,
                  onPressed: busy ? null : _confirm,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
