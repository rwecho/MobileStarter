import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../app/runtime_models.dart';
import '../design_system/components.dart';
import '../theme/app_tokens.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final documents = AppScope.of(context).config?.legal ?? const [];
    return AppPage(
      title: '协议与政策',
      child: documents.isEmpty
          ? const Center(child: Text('当前 App 尚未配置协议文档。'))
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.x4),
              itemCount: documents.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.x3),
              itemBuilder: (context, index) {
                final document = documents[index];
                return AppCard(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.x4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          document.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.x2),
                        Text('版本 ${document.revision}'),
                        const SizedBox(height: AppSpacing.x3),
                        SelectableText(document.content),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({required this.type, super.key});

  final String type;

  @override
  Widget build(BuildContext context) {
    final documents = AppScope.of(context).config?.legal ?? const [];
    final document = _findDocument(documents, type);
    return AppPage(
      title: document?.title ?? _fallbackTitle(type),
      child: document == null
          ? const Center(child: Text('当前 App 尚未配置该协议文档。'))
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.x4),
              children: [
                Text('版本 ${document.revision}'),
                const SizedBox(height: AppSpacing.x3),
                SelectableText(document.content),
              ],
            ),
    );
  }
}

LegalDocument? _findDocument(List<LegalDocument> documents, String type) {
  for (final document in documents) {
    if (document.type == type) return document;
  }
  return null;
}

String _fallbackTitle(String type) => type == 'privacy' ? '隐私政策' : '用户协议';
