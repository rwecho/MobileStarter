import 'dart:convert';
import 'dart:io';

import '../lib/create_command.dart';
import '../lib/doctor_command.dart';
import '../lib/feature_command.dart';
import '../lib/template_command.dart';
import '../lib/update_command.dart';

Future<void> main() async {
  final templateRoot = Directory.current.parent.parent;
  final sandbox = Directory.systemTemp.createTempSync('mobileui-cli-test-');
  try {
    _expect(TemplateCommand(templateRoot).run(['list']) == 0, 'list templates');
    for (final profile in const ['flutter', 'react-native', 'arkts', 'all']) {
      await _verifyProfile(templateRoot, sandbox, profile);
    }
    await _verifyGitHubSource(templateRoot, sandbox);
    await _verifyNonEmptyProtection(templateRoot, sandbox);
    stdout.writeln('MobileUI CLI smoke test passed.');
  } finally {
    sandbox.deleteSync(recursive: true);
  }
}

Future<void> _verifyProfile(
  Directory templateRoot,
  Directory sandbox,
  String profile,
) async {
  final name = 'app-${profile.replaceAll('-', '')}';
  final exit = await CreateCommand(templateRoot).run([
    name,
    '--output',
    sandbox.path,
    '--profile',
    profile,
    '--display-name',
    'Example $profile',
    '--organization',
    'tech.zhongbei',
    '--app-id',
    'example-${profile.replaceAll('-', '')}',
  ]);
  _expect(exit == 0, '$profile create must succeed');
  final project = Directory(_join(sandbox.path, name));
  _expect(
    DoctorCommand().run(['--project', project.path]) == 0,
    '$profile doctor must succeed',
  );
  _expect(
    FeatureCommand().run(['add', 'achievements', '--project', project.path]) ==
        0,
    '$profile feature add must succeed',
  );
  _expect(
    UpdateCommand().run(['--check', '--project', project.path]) == 0,
    'local source update check must be informational',
  );
  final manifest = _manifest(project);
  final profiles = (manifest['profiles'] as List<Object?>).whereType<String>();
  final expectedCount = profile == 'all' ? 3 : 1;
  _expect(profiles.length == expectedCount, '$profile manifest profile count');
  _verifyBehavioralBaseline(project, profiles);
}

void _verifyBehavioralBaseline(Directory project, Iterable<String> profiles) {
  if (profiles.contains('flutter')) {
    _expectFileContains(
      project,
      'flutter/lib/app/app_controller_navigation.dart',
      '_pendingRoute ?? AppRoute.home',
      'Flutter ordinary login must land on home',
    );
  }
  if (profiles.contains('react-native')) {
    _expectFileContains(
      project,
      'react-native/src/state/AppStore.tsx',
      "pendingRoute ?? 'home'",
      'React Native ordinary login must land on home',
    );
  }
  if (profiles.contains('arkts')) {
    _expectFileContains(
      project,
      'arkts/entry/src/main/ets/state/AppStore.ets',
      'pendingRoute ?? AppRoute.Home',
      'ArkTS ordinary login must land on home',
    );
  }
}

void _expectFileContains(
  Directory project,
  String relativePath,
  String expected,
  String message,
) {
  final path = relativePath.split('/');
  final file = File([project.path, ...path].join(Platform.pathSeparator));
  _expect(file.readAsStringSync().contains(expected), message);
}

Future<void> _verifyGitHubSource(
  Directory templateRoot,
  Directory sandbox,
) async {
  final remote = Directory(_join(sandbox.path, 'template-remote'));
  _copyFixture(templateRoot, remote);
  _git(remote, ['init', '--quiet']);
  _git(remote, ['config', 'user.email', 'mobileui@example.invalid']);
  _git(remote, ['config', 'user.name', 'MobileUI Test']);
  _git(remote, ['add', '.']);
  _git(remote, ['commit', '--quiet', '-m', 'template']);
  _git(remote, ['branch', '-M', 'main']);

  final exit = await CreateCommand(templateRoot).run([
    'app-remote',
    '--output',
    sandbox.path,
    '--profile',
    'arkts',
    '--display-name',
    'Remote Example',
    '--organization',
    'tech.zhongbei',
    '--app-id',
    'remote-example',
    '--source',
    'github',
    '--source-url',
    remote.path,
    '--ref',
    'main',
  ]);
  _expect(exit == 0, 'remote create must succeed');
  final project = Directory(_join(sandbox.path, 'app-remote'));
  _expect(
    UpdateCommand().run(['--check', '--project', project.path]) == 0,
    'remote project must initially be current',
  );
  File(_join(remote.path, 'revision.txt')).writeAsStringSync('next\n');
  _git(remote, ['add', '.']);
  _git(remote, ['commit', '--quiet', '-m', 'next']);
  _expect(
    UpdateCommand().run(['--check', '--project', project.path]) == 2,
    'remote update must be detected',
  );
}

Future<void> _verifyNonEmptyProtection(
  Directory root,
  Directory sandbox,
) async {
  var protected = false;
  try {
    await CreateCommand(root).run([
      'app-flutter',
      '--output',
      sandbox.path,
      '--display-name',
      'Example',
      '--organization',
      'tech.zhongbei',
      '--app-id',
      'example',
    ]);
  } catch (_) {
    protected = true;
  }
  _expect(protected, 'create must protect a non-empty target');
}

Map<String, Object?> _manifest(Directory project) {
  final file = File(_join(project.path, '.mobileui', 'template.json'));
  return jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
}

void _copyFixture(Directory source, Directory target) {
  target.createSync(recursive: true);
  for (final name in const ['profiles', 'flutter', 'react-native', 'arkts']) {
    _copyDirectory(
      Directory(_join(source.path, name)),
      Directory(_join(target.path, name)),
    );
  }
  final workflows = Directory(_join(source.path, '.github', 'workflows'));
  _copyDirectory(
    workflows,
    Directory(_join(target.path, '.github', 'workflows')),
  );
}

void _copyDirectory(Directory source, Directory target) {
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
    final destination = _join(target.path, name);
    if (entity is Directory) {
      _copyDirectory(entity, Directory(destination));
    } else if (entity is File && !name.endsWith('.log')) {
      entity.copySync(destination);
    }
  }
}

void _git(Directory directory, List<String> arguments) {
  final result = Process.runSync(
    'git',
    arguments,
    workingDirectory: directory.path,
  );
  if (result.exitCode != 0) throw StateError(result.stderr.toString());
}

String _join(String first, String second, [String? third]) {
  return [
    first,
    second,
    third,
  ].whereType<String>().join(Platform.pathSeparator);
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}
