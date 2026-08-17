import 'package:flutter/material.dart';

import '../design_system/avatar_image.dart';
import '../design_system/components.dart';
import '../theme/app_tokens.dart';

class ProfileIdentityCard extends StatelessWidget {
  const ProfileIdentityCard({
    required this.displayName,
    required this.username,
    required this.email,
    required this.bio,
    required this.avatarUrl,
    required this.onAvatarTap,
    super.key,
  });

  final String displayName;
  final String username;
  final String email;
  final String bio;
  final String? avatarUrl;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x5),
        child: Column(
          children: [
            Semantics(
              button: true,
              label: '更换头像',
              child: InkWell(
                onTap: onAvatarTap,
                customBorder: const CircleBorder(),
                child: AvatarImage(
                  avatarUrl: avatarUrl ?? '',
                  size: 96,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.x2),
            Text('点击更换头像', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.x4),
            Text(
              displayName.isEmpty ? '未设置显示名称' : displayName,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.x1),
            Text(
              '@$username · $email',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (bio.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.x4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.x3),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadii.control),
                ),
                child: Text(bio, textAlign: TextAlign.center),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
