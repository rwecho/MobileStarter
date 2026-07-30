import 'package:flutter/material.dart';
import '../design_system/app_icon.dart';
import '../design_system/components.dart';
import '../state/async_state.dart';
import '../theme/app_tokens.dart';

class StateGalleryScreen extends StatefulWidget {
  const StateGalleryScreen({super.key});

  @override
  State<StateGalleryScreen> createState() => _StateGalleryScreenState();
}

class _StateGalleryScreenState extends State<StateGalleryScreen> {
  int index = 0;
  final states = <AsyncState<List<String>>>[
    const Loading(),
    const Empty(),
    const Failure('服务暂时不可用'),
    const Offline(),
    const Unauthorized(),
    const Success(['状态加载成功']),
  ];

  @override
  Widget build(BuildContext context) {
    final config = _configFor(states[index]);
    return AppPage(
      title: '状态库',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(config.$1, color: AppColors.brand, size: 56),
              const SizedBox(height: AppSpacing.x4),
              Text(config.$2, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.x6),
              AppButton(
                label: '切换状态',
                onPressed: () => setState(() {
                  index = (index + 1) % states.length;
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  (AppIconName, String) _configFor(AsyncState<List<String>> state) {
    return switch (state) {
      Idle() => (AppIconName.check, '等待操作'),
      Loading() => (AppIconName.settings, '正在加载'),
      Empty() => (AppIconName.gift, '暂无数据'),
      Failure(:final message) => (AppIconName.alert, message),
      Offline() => (AppIconName.globe, '网络连接已断开'),
      Unauthorized() => (AppIconName.lock, '请先登录'),
      Success() => (AppIconName.check, '加载成功'),
    };
  }
}
