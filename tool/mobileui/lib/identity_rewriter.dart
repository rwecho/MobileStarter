import 'dart:io';

import 'profile_config.dart';
import 'project_manifest.dart';

final class IdentityRewriter {
  const IdentityRewriter(this.manifest);

  final ProjectManifest manifest;

  void rewrite(Directory project, List<ProfileConfig> profiles) {
    for (final profile in profiles) {
      final root = Directory(_join(project.path, profile.source));
      final replacements = switch (profile.id) {
        'flutter' => _flutterReplacements(),
        'react-native' => _reactNativeReplacements(),
        'arkts' => _arkTsReplacements(),
        _ => const <String, String>{},
      };
      _replaceText(root, replacements);
      if (profile.id == 'flutter') _moveMainActivity(root);
      if (profile.id == 'arkts') _removeArkTsSigning(root);
    }
  }

  Map<String, String> _flutterReplacements() => {
    'mobilestarter_flutter': manifest.packageName,
    'Reusable MobileStarter application template':
        '${manifest.displayName} mobile application',
    'mobileui_flutter': manifest.packageName,
    'com.mobileui.mobileuiFlutter': _nativePackage,
    'com.mobileui.mobileui_flutter': _nativePackage,
    'package com.mobileui.mobileui_flutter': 'package $_nativePackage',
    'mobilestarter://oauth': '${manifest.appId}://oauth',
    "'mobilestarter'": "'${manifest.appId}'",
    '<string>mobilestarter</string>': '<string>${manifest.appId}</string>',
    'android:scheme="mobilestarter"': 'android:scheme="${manifest.appId}"',
    "'MobileStarter'": "'${manifest.displayName}'",
    '>MobileStarter<': '>${manifest.displayName}<',
  };

  Map<String, String> _reactNativeReplacements() => {
    'mobilestarter-react-native': '${manifest.packageName}-react-native',
    'com.mobileui.mobilestarter': _nativePackage,
    '"MobileStarter"': '"${manifest.displayName}"',
    '"mobilestarter"': '"${manifest.appId}"',
  };

  Map<String, String> _arkTsReplacements() => {
    'com.mobilestarter.template': _nativePackage,
    'MobileStarter reusable application template':
        '${manifest.displayName} mobile application',
    'MobileStarter': manifest.displayName,
  };

  String get _nativePackage =>
      '${manifest.organization}.${manifest.packageName}';

  void _replaceText(Directory root, Map<String, String> replacements) {
    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !_isTextFile(entity.path)) continue;
      var content = entity.readAsStringSync();
      for (final replacement in replacements.entries) {
        content = content.replaceAll(replacement.key, replacement.value);
      }
      entity.writeAsStringSync(content);
    }
  }

  void _moveMainActivity(Directory root) {
    final kotlinRoot = Directory(
      _join(root.path, 'android', 'app', 'src', 'main', 'kotlin'),
    );
    if (!kotlinRoot.existsSync()) return;
    final activities = kotlinRoot
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('MainActivity.kt'))
        .toList();
    if (activities.isEmpty) return;
    final packagePath = _nativePackage.split('.').join(Platform.pathSeparator);
    final target = File(_join(kotlinRoot.path, packagePath, 'MainActivity.kt'));
    target.parent.createSync(recursive: true);
    activities.single.copySync(target.path);
    if (activities.single.path != target.path) activities.single.deleteSync();
  }

  void _removeArkTsSigning(Directory root) {
    final profile = File(_join(root.path, 'build-profile.json5'));
    if (!profile.existsSync()) return;
    final content = profile.readAsStringSync();
    final sanitized = content
        .replaceFirst(
          RegExp(r'\s*"signingConfigs"\s*:\s*\[.*?\]\s*,', dotAll: true),
          '',
        )
        .replaceAll(RegExp(r'\s*"signingConfig"\s*:\s*"[^"]+"\s*,'), '');
    profile.writeAsStringSync(sanitized);
  }
}

bool _isTextFile(String path) {
  const extensions = {
    '.dart',
    '.yaml',
    '.yml',
    '.json',
    '.json5',
    '.html',
    '.xml',
    '.plist',
    '.pbxproj',
    '.kts',
    '.kt',
    '.xcconfig',
    '.md',
    '.ts',
    '.tsx',
    '.ets',
  };
  return extensions.any(path.endsWith);
}

String _join(
  String first,
  String second, [
  String? third,
  String? fourth,
  String? fifth,
  String? sixth,
  String? seventh,
]) {
  return [
    first,
    second,
    third,
    fourth,
    fifth,
    sixth,
    seventh,
  ].whereType<String>().join(Platform.pathSeparator);
}
