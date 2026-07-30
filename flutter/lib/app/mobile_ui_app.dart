import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_controller.dart';
import 'app_repository.dart';
import 'app_router.dart';
import 'app_scope.dart';
import '../support/support_controller.dart';
import '../support/support_repository.dart';
import '../support/support_scope.dart';

class MobileUiApp extends StatefulWidget {
  const MobileUiApp({super.key});

  @override
  State<MobileUiApp> createState() => _MobileUiAppState();
}

class _MobileUiAppState extends State<MobileUiApp> {
  late final AppController controller;
  final supportController = SupportController(SupportRepository());

  @override
  void initState() {
    super.initState();
    controller = AppController(AppRepository());
    controller.initialize();
  }

  @override
  void dispose() {
    controller.dispose();
    supportController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: controller,
      child: SupportScope(
        controller: supportController,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'MobileStarter',
          theme: AppTheme.light,
          home: AnimatedBuilder(
            animation: controller,
            builder: (context, child) => AppRouter.screenFor(controller.route),
          ),
        ),
      ),
    );
  }
}
