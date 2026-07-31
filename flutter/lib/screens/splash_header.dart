import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

class SplashHeader extends StatelessWidget {
  const SplashHeader({
    required this.countdown,
    required this.canSkip,
    required this.onSkip,
    super.key,
  });

  final int countdown;
  final bool canSkip;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: '倒计时 $countdown',
          liveRegion: true,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$countdown',
              style: const TextStyle(
                color: AppColors.brand,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const Spacer(),
        if (canSkip) TextButton(onPressed: onSkip, child: const Text('跳过')),
      ],
    );
  }
}
