import 'dart:io';

// smoke_test 的文件系统/git/断言辅助——从 smoke_test.dart 拆出
// 以服从 CI 350 行硬上限（源架构检查同时覆盖 .dart 测试文件）。

void expectTrue(bool condition, String message) {
  if (!condition) throw StateError(message);
}

String joinPath(
  String first,
  String second, [
  String? third,
  String? fourth,
  String? fifth,
]) {
  return [
    first,
    second,
    third,
    fourth,
    fifth,
  ].whereType<String>().join(Platform.pathSeparator);
}

void expectFileContains(
  Directory project,
  String relativePath,
  String expected,
  String message,
) {
  final path = relativePath.split('/');
  final file = File([project.path, ...path].join(Platform.pathSeparator));
  expectTrue(file.readAsStringSync().contains(expected), message);
}

void expectFileNotContains(
  Directory project,
  String relativePath,
  String forbidden,
  String message,
) {
  final path = relativePath.split('/');
  final file = File([project.path, ...path].join(Platform.pathSeparator));
  expectTrue(!file.readAsStringSync().contains(forbidden), message);
}

void copyFixture(Directory source, Directory target) {
  target.createSync(recursive: true);
  for (final name in const ['profiles', 'flutter', 'react-native', 'arkts']) {
    copyDirectory(
      Directory(joinPath(source.path, name)),
      Directory(joinPath(target.path, name)),
    );
  }
  final workflows = Directory(joinPath(source.path, '.github', 'workflows'));
  copyDirectory(
    workflows,
    Directory(joinPath(target.path, '.github', 'workflows')),
  );
}

void copyDirectory(Directory source, Directory target) {
  target.createSync(recursive: true);
  for (final entity in source.listSync()) {
    final name = entity.uri.pathSegments.where((part) => part.isNotEmpty).last;
    if ({
      '.git',
      '.dart_tool',
      'node_modules',
      'node_modules.incomplete-20260729',
      'build',
      '.hvigor',
      '.idea',
      '.expo',
      'dist',
      'dist-final',
      'dist-verify',
      'Pods',
    }.contains(name))
      continue;
    if (name.contains('.incomplete-')) continue;
    final destination = joinPath(target.path, name);
    if (entity is Directory) {
      copyDirectory(entity, Directory(destination));
    } else if (entity is File && !name.endsWith('.log')) {
      entity.copySync(destination);
    }
  }
}

void gitRun(Directory directory, List<String> arguments) {
  final result = Process.runSync(
    'git',
    arguments,
    workingDirectory: directory.path,
  );
  if (result.exitCode != 0) throw StateError(result.stderr.toString());
}
