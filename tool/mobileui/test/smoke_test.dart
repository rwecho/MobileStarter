import 'dart:convert';
import 'dart:io';

import 'helpers.dart';

import '../lib/create_command.dart';
import '../lib/doctor_command.dart';
import '../lib/feature_command.dart';
import '../lib/template_command.dart';
import '../lib/update_command.dart';

Future<void> main() async {
  final templateRoot = Directory.current.parent.parent;
  final sandbox = Directory.systemTemp.createTempSync('mobileui-cli-test-');
  try {
    expectTrue(
      TemplateCommand(templateRoot).run(['list']) == 0,
      'list templates',
    );
    for (final profile in const [
      'flutter',
      'react-native',
      'arkts',
      'server',
      'all',
    ]) {
      await _verifyProfile(templateRoot, sandbox, profile);
    }
    await _verifyCombinedProfiles(templateRoot, sandbox);
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
  expectTrue(exit == 0, '$profile create must succeed');
  final project = Directory(joinPath(sandbox.path, name));
  expectTrue(
    DoctorCommand().run(['--project', project.path]) == 0,
    '$profile doctor must succeed',
  );
  expectTrue(
    FeatureCommand().run(['add', 'achievements', '--project', project.path]) ==
        0,
    '$profile feature add must succeed',
  );
  expectTrue(
    UpdateCommand().run(['--check', '--project', project.path]) == 0,
    'local source update check must be informational',
  );
  final manifest = _manifest(project);
  final profiles = (manifest['profiles'] as List<Object?>).whereType<String>();
  final expectedCount = profile == 'all' ? 3 : 1;
  expectTrue(
    profiles.length == expectedCount,
    '$profile manifest profile count',
  );
  _verifyBehavioralBaseline(project, profiles);
}

Future<void> _verifyCombinedProfiles(
  Directory templateRoot,
  Directory sandbox,
) async {
  const name = 'app-combined';
  final exit = await CreateCommand(templateRoot).run([
    name,
    '--output',
    sandbox.path,
    '--profile',
    'react-native,server',
    '--display-name',
    'Example Combined',
    '--organization',
    'tech.zhongbei',
    '--app-id',
    'example-combined',
  ]);
  expectTrue(exit == 0, 'combined create must succeed');
  final project = Directory(joinPath(sandbox.path, name));
  expectTrue(
    Directory(joinPath(project.path, 'server', 'src', 'app')).existsSync(),
    'combined create must copy server source tree',
  );
  expectTrue(
    File(
      joinPath(project.path, '.github', 'workflows', 'server-ci.yml'),
    ).existsSync(),
    'combined create must copy server CI workflow',
  );
  final publishWorkflow = File(
    joinPath(project.path, '.github', 'workflows', 'server-publish.yml'),
  );
  expectTrue(
    publishWorkflow.existsSync(),
    'combined create must copy publish workflow',
  );
  expectTrue(
    !publishWorkflow.readAsStringSync().contains('zhongbei-auth'),
    'server publish image must not keep the template image name',
  );
  expectTrue(
    publishWorkflow.readAsStringSync().contains('/app_combined'),
    'server publish image must follow the generated package name',
  );
  for (final route in const [
    'server/src/app/.well-known/apple-app-site-association/route.ts',
    'server/src/app/.well-known/assetlinks.json/route.ts',
  ]) {
    expectFileNotContains(
      project,
      route,
      'com.mobileui.mobilestarter',
      'deep-link route must not keep the template app id ($route)',
    );
    expectFileNotContains(
      project,
      route,
      'com.mobileui.mobileui_flutter',
      'deep-link route must not keep the template package ($route)',
    );
    expectFileContains(
      project,
      route,
      'example-combined',
      'deep-link route must follow the product app id ($route)',
    );
  }
  expectTrue(
    !Directory(joinPath(project.path, 'server', 'node_modules')).existsSync(),
    'server node_modules must not be copied',
  );
  expectTrue(
    DoctorCommand().run(['--project', project.path]) == 0,
    'combined doctor must succeed',
  );
  expectTrue(
    FeatureCommand().run(['add', 'achievements', '--project', project.path]) ==
        0,
    'combined feature add must cover every profile',
  );
  expectTrue(
    Directory(
      joinPath(project.path, 'react-native', 'src', 'features', 'achievements'),
    ).listSync().isNotEmpty,
    'combined feature must land in react-native',
  );
  expectTrue(
    Directory(
      joinPath(project.path, 'server', 'src', 'features', 'achievements'),
    ).listSync().isNotEmpty,
    'combined feature must land in server',
  );
  final manifest = _manifest(project);
  final profiles = (manifest['profiles'] as List<Object?>).whereType<String>();
  expectTrue(profiles.length == 2, 'combined manifest profile count');
  expectTrue(
    (manifest['templateSource'] as Map<String, Object?>)['commit'] != null,
    'combined manifest must record template commit',
  );
}

void _verifyBehavioralBaseline(Directory project, Iterable<String> profiles) {
  if (profiles.contains('flutter')) {
    expectFileContains(
      project,
      'flutter/lib/navigation/app_router_config.dart',
      'pathFor(AppRoute.home)',
      'Flutter route guard fallback must land on home',
    );
  }
  if (profiles.contains('react-native')) {
    expectFileContains(
      project,
      'react-native/src/state/AppStore.tsx',
      "pendingRoute ?? 'home'",
      'React Native ordinary login must land on home',
    );
    expectFileNotContains(
      project,
      '.github/workflows/react-native-publish.yml',
      'com.mobileui.mobilestarter',
      'React Native publish workflow must carry product identity',
    );
  }
  if (profiles.contains('arkts')) {
    expectFileContains(
      project,
      'arkts/entry/src/main/ets/state/AppStore.ets',
      'pendingRoute ?? AppRoute.Home',
      'ArkTS ordinary login must land on home',
    );
  }
}

Future<void> _verifyGitHubSource(
  Directory templateRoot,
  Directory sandbox,
) async {
  final remote = Directory(joinPath(sandbox.path, 'template-remote'));
  copyFixture(templateRoot, remote);
  gitRun(remote, ['init', '--quiet']);
  gitRun(remote, ['config', 'user.email', 'mobileui@example.invalid']);
  gitRun(remote, ['config', 'user.name', 'MobileUI Test']);
  gitRun(remote, ['add', '.']);
  gitRun(remote, ['commit', '--quiet', '-m', 'template']);
  gitRun(remote, ['branch', '-M', 'main']);

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
  expectTrue(exit == 0, 'remote create must succeed');
  final project = Directory(joinPath(sandbox.path, 'app-remote'));
  expectTrue(
    UpdateCommand().run(['--check', '--project', project.path]) == 0,
    'remote project must initially be current',
  );
  File(joinPath(remote.path, 'revision.txt')).writeAsStringSync('next\n');
  gitRun(remote, ['add', '.']);
  gitRun(remote, ['commit', '--quiet', '-m', 'next']);
  expectTrue(
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
  expectTrue(protected, 'create must protect a non-empty target');
}

Map<String, Object?> _manifest(Directory project) {
  final file = File(joinPath(project.path, '.mobileui', 'template.json'));
  return jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
}
