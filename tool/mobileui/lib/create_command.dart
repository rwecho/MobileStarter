import 'dart:io';

import 'arguments.dart';
import 'command_runner.dart';
import 'identity_rewriter.dart';
import 'profile_config.dart';
import 'project_manifest.dart';
import 'template_source.dart';

final class CreateCommand {
  const CreateCommand(this.localTemplateRoot);

  final Directory localTemplateRoot;

  Future<int> run(List<String> values) async {
    final arguments = CommandArguments(values);
    final repositoryName = arguments.positional(
      index: 0,
      label: 'repository name',
    );
    final output = Directory(arguments.option('output'));
    final profileSelection = arguments.option('profile', fallback: 'flutter');
    final displayName = arguments.option('display-name');
    final organization = arguments.option('organization');
    final appId = arguments.option('app-id');
    final source = arguments.option('source', fallback: 'local');
    final sourceUrl = arguments.option(
      'source-url',
      fallback: defaultTemplateRepository,
    );
    final sourceRef = arguments.option('ref', fallback: 'main');
    _validateIdentity(repositoryName, organization, appId);

    final resolved = await TemplateSourceResolver(
      localTemplateRoot,
    ).resolve(source: source, repository: sourceUrl, ref: sourceRef);
    try {
      final profiles = ProfileConfig.resolve(resolved.root, profileSelection);
      final target = Directory(_join(output.path, repositoryName));
      _prepareTarget(target);
      _generatePlatforms(resolved.root, target, profiles);
      final manifest = _manifest(
        repositoryName: repositoryName,
        displayName: displayName,
        organization: organization,
        appId: appId,
        profiles: profiles,
        source: resolved,
      );
      _writeProjectFiles(target, manifest);
      IdentityRewriter(manifest).rewrite(target, profiles);
      stdout.writeln('Created ${target.path}');
      stdout.writeln('Profiles: ${manifest.profiles.join(', ')}');
      stdout.writeln('Next: mobileui doctor --project "${target.path}"');
      return 0;
    } finally {
      resolved.dispose();
    }
  }

  ProjectManifest _manifest({
    required String repositoryName,
    required String displayName,
    required String organization,
    required String appId,
    required List<ProfileConfig> profiles,
    required ResolvedTemplate source,
  }) {
    final features = profiles.expand((profile) => profile.features).toSet();
    final versions = profiles.map((profile) => profile.version).toSet();
    return ProjectManifest(
      templateVersion: versions.length == 1
          ? versions.single
          : versions.join(','),
      profiles: profiles.map((profile) => profile.id).toList(),
      repositoryName: repositoryName,
      packageName: _packageName(repositoryName),
      displayName: displayName,
      organization: organization,
      appId: appId,
      features: features.toList()..sort(),
      sourceType: source.sourceType,
      sourceUrl: source.sourceUrl,
      sourceRef: source.sourceRef,
      sourceCommit: source.sourceCommit,
    );
  }

  void _generatePlatforms(
    Directory templateRoot,
    Directory target,
    List<ProfileConfig> profiles,
  ) {
    for (final profile in profiles) {
      final source = Directory(_join(templateRoot.path, profile.source));
      if (!source.existsSync()) {
        throw FileSystemException('profile source is missing', source.path);
      }
      final destination = Directory(_join(target.path, profile.source))
        ..createSync(recursive: true);
      _copyDirectory(source, destination, profile.excludedDirectories);
      for (final workflow in profile.workflows) {
        _copyWorkflow(templateRoot, workflow, target);
      }
    }
  }

  void _prepareTarget(Directory target) {
    if (target.existsSync() && target.listSync().isNotEmpty) {
      throw MobileUiUsageException('target is not empty: ${target.path}');
    }
    target.createSync(recursive: true);
  }

  void _copyWorkflow(Directory root, String name, Directory target) {
    final source = File(_join(root.path, '.github', 'workflows', name));
    final destination = File(_join(target.path, '.github', 'workflows', name));
    destination.parent.createSync(recursive: true);
    source.copySync(destination.path);
  }

  void _writeProjectFiles(Directory target, ProjectManifest manifest) {
    final metadata = File(_join(target.path, '.mobileui', 'template.json'));
    metadata.parent.createSync(recursive: true);
    metadata.writeAsStringSync('${manifest.encode()}\n');
    File(_join(target.path, 'README.md')).writeAsStringSync(
      '# ${manifest.displayName}\n\nGenerated from MobileUI '
      '${manifest.templateVersion} with ${manifest.profiles.join(', ')}.\n',
    );
    File(_join(target.path, '.gitignore')).writeAsStringSync(
      '.dart_tool/\nbuild/\nnode_modules/\n.expo/\n.hvigor/\n.idea/\n.vscode/\n'
      '**/local.properties\n**/signing-config.json\n',
    );
  }
}

void _copyDirectory(Directory source, Directory target, Set<String> excluded) {
  for (final entity in source.listSync()) {
    final name = entity.uri.pathSegments.where((part) => part.isNotEmpty).last;
    if (excluded.contains(name) || _isGeneratedFile(name)) continue;
    final destination = _join(target.path, name);
    if (entity is Directory) {
      _copyDirectory(
        entity,
        Directory(destination)..createSync(recursive: true),
        excluded,
      );
    } else if (entity is File) {
      entity.copySync(destination);
    }
  }
}

bool _isGeneratedFile(String name) {
  return name.endsWith('.log') ||
      name.contains('.incomplete-') ||
      name == '.flutter-plugins-dependencies';
}

void _validateIdentity(String repository, String organization, String appId) {
  if (!RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_-]*$').hasMatch(repository)) {
    throw const MobileUiUsageException('invalid repository name');
  }
  if (!RegExp(r'^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)+$').hasMatch(organization)) {
    throw const MobileUiUsageException('invalid reverse-domain organization');
  }
  if (!RegExp(r'^[a-z][a-z0-9-]*$').hasMatch(appId)) {
    throw const MobileUiUsageException('invalid app id');
  }
}

String _packageName(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}

String _join(String first, String second, [String? third, String? fourth]) {
  return [
    first,
    second,
    third,
    fourth,
  ].whereType<String>().join(Platform.pathSeparator);
}
