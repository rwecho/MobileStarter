import 'dart:convert';
import 'dart:io';

import 'arguments.dart';

final class DoctorCommand {
  int run(List<String> values) {
    final project = Directory(CommandArguments(values).option('project'));
    final issues = <String>[];
    final metadata = File(_join(project.path, '.mobileui', 'template.json'));
    final manifest = _readManifest(metadata, issues);
    final profiles = _profiles(manifest);
    if (profiles.isEmpty && metadata.existsSync()) {
      issues.add('unsupported or missing profiles');
    }
    for (final profile in profiles) {
      _checkProfile(project, profile, manifest, issues);
    }
    if (issues.isNotEmpty) {
      for (final issue in issues) {
        stderr.writeln('[FAIL] $issue');
      }
      return 1;
    }
    stdout.writeln('[OK] MobileUI project metadata');
    stdout.writeln('[OK] Profile structures: ${profiles.join(', ')}');
    stdout.writeln('[OK] Product identity replacement');
    stdout.writeln('[OK] No copied ArkTS signing credentials');
    return 0;
  }

  Map<String, Object?> _readManifest(File file, List<String> issues) {
    if (!file.existsSync()) {
      issues.add('missing .mobileui/template.json');
      return const {};
    }
    try {
      return jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
    } on FormatException {
      issues.add('invalid .mobileui/template.json');
      return const {};
    }
  }

  List<String> _profiles(Map<String, Object?> manifest) {
    final profiles = (manifest['profiles'] as List<Object?>?)
        ?.whereType<String>()
        .toList();
    if (profiles != null) return profiles;
    final legacy = manifest['profile'] as String?;
    return legacy == null ? const [] : [legacy];
  }

  void _checkProfile(
    Directory project,
    String profile,
    Map<String, Object?> manifest,
    List<String> issues,
  ) {
    final required = switch (profile) {
      'flutter' => [
        'flutter/pubspec.yaml',
        'flutter/lib/main.dart',
        '.github/workflows/flutter-ci.yml',
      ],
      'react-native' => [
        'react-native/package.json',
        'react-native/App.tsx',
        '.github/workflows/react-native-ci.yml',
      ],
      'arkts' => [
        'arkts/oh-package.json5',
        'arkts/AppScope/app.json5',
        '.github/workflows/arkts-ci.yml',
      ],
      'server' => [
        'server/package.json',
        'server/next.config.ts',
        '.github/workflows/server-ci.yml',
      ],
      'biz-server' => [
        'biz-server/package.json',
        'biz-server/prisma/schema.prisma',
        '.github/workflows/biz-server-ci.yml',
      ],
      _ => <String>[],
    };
    if (required.isEmpty) {
      issues.add('unsupported profile "$profile"');
      return;
    }
    for (final relative in required) {
      final path = _fromSlash(project.path, relative);
      if (!File(path).existsSync()) issues.add('missing $path');
    }
    final root = Directory(_join(project.path, profile));
    if (root.existsSync()) _checkMarkers(root, profile, manifest, issues);
  }

  void _checkMarkers(
    Directory root,
    String profile,
    Map<String, Object?> manifest,
    List<String> issues,
  ) {
    const markers = {
      'flutter': [
        'com.mobileui.mobileui_flutter',
        'package:mobilestarter_flutter',
      ],
      'react-native': [
        'mobilestarter-react-native',
        'com.mobileui.mobilestarter',
      ],
      'arkts': ['com.mobilestarter.template', 'storePassword', 'keyPassword'],
      'server': ['com.mobileui.mobilestarter', 'zhongbei-auth'],
      'biz-server': ['zhongbei-biz'],
    };
    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !_isTextFile(entity.path)) continue;
      if (entity.path.split(Platform.pathSeparator).contains('node_modules')) {
        continue;
      }
      final String content;
      try {
        content = entity.readAsStringSync();
      } on FormatException {
        continue;
      } on FileSystemException {
        continue;
      }
      for (final marker in markers[profile] ?? const <String>[]) {
        if (content.contains(marker)) {
          issues.add('stale or sensitive marker "$marker" in ${entity.path}');
        }
      }
    }
    if (profile == 'flutter') _checkFlutterPackage(root, manifest, issues);
  }

  void _checkFlutterPackage(
    Directory root,
    Map<String, Object?> manifest,
    List<String> issues,
  ) {
    final packageName = manifest['packageName'] as String?;
    final pubspec = File(_join(root.path, 'pubspec.yaml'));
    if (pubspec.existsSync() &&
        packageName != null &&
        !pubspec.readAsStringSync().startsWith('name: $packageName')) {
      issues.add('Flutter package name does not match manifest');
    }
  }
}

bool _isTextFile(String path) {
  const extensions = {
    '.dart',
    '.yaml',
    '.yml',
    '.json',
    '.json5',
    '.xml',
    '.plist',
    '.kts',
    '.kt',
    '.md',
    '.ts',
    '.tsx',
    '.ets',
  };
  return extensions.any(path.endsWith);
}

String _fromSlash(String root, String relative) {
  return [root, ...relative.split('/')].join(Platform.pathSeparator);
}

String _join(String first, String second, [String? third]) {
  return [
    first,
    second,
    third,
  ].whereType<String>().join(Platform.pathSeparator);
}
