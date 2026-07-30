import 'package:flutter/material.dart';
import '../app/app_controller.dart';
import '../app/app_scope.dart';
import '../design_system/components.dart';
import '../navigation/app_route.dart';
import '../theme/app_tokens.dart';
import '../util/cache_size.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _cacheLabel = '';

  @override
  void initState() {
    super.initState();
    _loadCacheLabel();
  }

  Future<void> _loadCacheLabel() async {
    final label = formatCacheSize(await measureCacheBytes());
    if (mounted) setState(() => _cacheLabel = label);
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return AppPage(
      title: '设置',
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.x4),
        children: [
          AppCard(
            child: AppListTile(
              label: controller.user?.username ?? '未登录用户',
              value: controller.user?.email ?? '登录后同步跨设备设置',
            ),
          ),
          const SizedBox(height: AppSpacing.x5),
          const _SettingsGroup(
            title: '账户与服务',
            items: [
              ('账户与安全', AppRoute.accountSecurity, null),
              ('登录设备管理', AppRoute.devices, null),
              ('会员与订阅', AppRoute.membership, null),
            ],
          ),
          _SettingsGroup(
            title: '应用偏好',
            items: [
              ('通知设置', AppRoute.notificationSettings, null),
              ('通用设置', AppRoute.general, null),
              ('外观主题', AppRoute.appearance, '跟随系统'),
              ('语言', AppRoute.language, '简体中文'),
              ('字体大小', AppRoute.textSize, '标准'),
            ].where((item) => _visible(controller, item.$2)).toList(),
          ),
          _SettingsGroup(
            title: '隐私、存储与支持',
            items: [
              ('隐私设置', AppRoute.privacy, null),
              ('权限管理', AppRoute.permissions, null),
              ('存储与缓存', AppRoute.storage, _cacheLabel),
              ('帮助与反馈', AppRoute.helpFeedback, null),
              ('协议与政策', AppRoute.legal, null),
              ('关于与版本', AppRoute.about, '1.0.0'),
              ('注销账号', AppRoute.deleteAccount, null),
            ].where((item) => _visible(controller, item.$2)).toList(),
          ),
        ],
      ),
    );
  }

  bool _visible(AppController controller, AppRoute route) {
    final key = switch (route) {
      AppRoute.notificationSettings => 'notifications',
      AppRoute.general => 'general',
      AppRoute.appearance || AppRoute.textSize => 'appearance',
      AppRoute.language => 'language',
      AppRoute.privacy => 'analytics',
      AppRoute.deleteAccount => 'accountDeletion',
      _ => null,
    };
    return key == null ||
        controller.config?.settingsPolicy[key]?.visible != false;
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.items});
  final String title;
  final List<(String, AppRoute, String?)> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.x2),
          AppCard(
            child: Column(
              children: items
                  .map(
                    (item) => AppListTile(
                      label: item.$1,
                      route: item.$2,
                      value: item.$3,
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
