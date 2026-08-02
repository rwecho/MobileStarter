import 'dart:io';

import 'command_runner.dart';

const defaultTemplateRepository = 'https://github.com/rwecho/MobileStarter.git';

final class ResolvedTemplate {
  const ResolvedTemplate({
    required this.root,
    required this.sourceType,
    required this.sourceUrl,
    required this.sourceRef,
    required this.sourceCommit,
    this.temporaryRoot,
  });

  final Directory root;
  final String sourceType;
  final String? sourceUrl;
  final String? sourceRef;
  final String? sourceCommit;
  final Directory? temporaryRoot;

  void dispose() {
    if (temporaryRoot?.existsSync() ?? false) {
      temporaryRoot!.deleteSync(recursive: true);
    }
  }
}

final class TemplateSourceResolver {
  const TemplateSourceResolver(this.localRoot);

  final Directory localRoot;

  Future<ResolvedTemplate> resolve({
    required String source,
    required String repository,
    required String ref,
  }) async {
    if (source == 'local') {
      return ResolvedTemplate(
        root: localRoot,
        sourceType: 'local',
        sourceUrl: null,
        sourceRef: null,
        sourceCommit: await _localCommit(localRoot),
      );
    }
    if (source != 'github') {
      throw MobileUiUsageException('unsupported template source "$source"');
    }
    return _download(repository, ref);
  }

  Future<ResolvedTemplate> _download(String repository, String ref) async {
    final temporary = Directory.systemTemp.createTempSync('mobileui-template-');
    try {
      await _git(['init', '--quiet'], temporary);
      await _git(['remote', 'add', 'origin', repository], temporary);
      await _git([
        'fetch',
        '--quiet',
        '--depth',
        '1',
        'origin',
        ref,
      ], temporary);
      await _git(['checkout', '--quiet', 'FETCH_HEAD'], temporary);
      final commit = await _git(['rev-parse', 'HEAD'], temporary);
      return ResolvedTemplate(
        root: temporary,
        sourceType: 'github',
        sourceUrl: repository,
        sourceRef: ref,
        sourceCommit: commit,
        temporaryRoot: temporary,
      );
    } catch (_) {
      if (temporary.existsSync()) temporary.deleteSync(recursive: true);
      rethrow;
    }
  }
}

Future<String?> _localCommit(Directory root) async {
  final result = await Process.run('git', [
    '-C',
    root.path,
    'rev-parse',
    'HEAD',
  ]);
  return result.exitCode == 0 ? result.stdout.toString().trim() : null;
}

Future<String> _git(List<String> arguments, Directory workingDirectory) async {
  final result = await Process.run(
    'git',
    arguments,
    workingDirectory: workingDirectory.path,
  );
  if (result.exitCode != 0) {
    final detail = result.stderr.toString().trim();
    throw MobileUiUsageException('git failed: $detail');
  }
  return result.stdout.toString().trim();
}
