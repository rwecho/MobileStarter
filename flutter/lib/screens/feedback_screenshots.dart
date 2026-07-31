import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../design_system/app_icon.dart';
import '../design_system/components.dart';
import '../support/support_models.dart';
import '../theme/app_tokens.dart';

class FeedbackScreenshots extends StatelessWidget {
  const FeedbackScreenshots({
    required this.items,
    required this.onChanged,
    super.key,
  });

  static const maxCount = 3;
  final List<FeedbackScreenshot> items;
  final ValueChanged<List<FeedbackScreenshot>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '问题截图（可选）',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text('${items.length}/$maxCount'),
          ],
        ),
        const SizedBox(height: AppSpacing.x2),
        Text(
          '最多 3 张，请避开密码、验证码等敏感信息。',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.x3),
        if (items.isNotEmpty)
          Wrap(
            spacing: AppSpacing.x3,
            runSpacing: AppSpacing.x3,
            children: [
              for (var index = 0; index < items.length; index++)
                _ScreenshotPreview(
                  item: items[index],
                  onRemove: () => onChanged([
                    ...items.take(index),
                    ...items.skip(index + 1),
                  ]),
                ),
            ],
          ),
        if (items.isNotEmpty) const SizedBox(height: AppSpacing.x3),
        OutlinedButton(
          onPressed: items.length >= maxCount ? null : _pick,
          child: const Text('添加截图'),
        ),
      ],
    );
  }

  Future<void> _pick() async {
    final selected = await ImagePicker().pickMultiImage(
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 68,
    );
    if (selected.isEmpty) return;
    final additions = <FeedbackScreenshot>[];
    for (final file in selected.take(maxCount - items.length)) {
      final bytes = await file.readAsBytes();
      additions.add(
        FeedbackScreenshot(
          fileName: _normalizedName(file.name),
          mimeType: _mimeType(file.name),
          data: 'data:${_mimeType(file.name)};base64,${base64Encode(bytes)}',
        ),
      );
    }
    onChanged([...items, ...additions]);
  }
}

class _ScreenshotPreview extends StatelessWidget {
  const _ScreenshotPreview({required this.item, required this.onRemove});

  final FeedbackScreenshot item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final bytes = base64Decode(item.data.substring(item.data.indexOf(',') + 1));
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.control),
          child: Image.memory(
            Uint8List.fromList(bytes),
            width: 96,
            height: 96,
            fit: BoxFit.cover,
            semanticLabel: item.fileName,
          ),
        ),
        Positioned(
          top: -10,
          right: -10,
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            shape: const CircleBorder(),
            child: AppIconButton(
              label: '移除截图',
              icon: AppIconName.close,
              onPressed: onRemove,
            ),
          ),
        ),
      ],
    );
  }
}

String _mimeType(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}

String _normalizedName(String name) {
  if (name.length <= 120) return name;
  final dot = name.lastIndexOf('.');
  final extension = dot < 0 ? '' : name.substring(dot);
  return '${name.substring(0, 120 - extension.length)}$extension';
}
