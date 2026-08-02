import 'dart:convert';
import 'dart:io';

import 'arguments.dart';
import 'command_runner.dart';

final class UpdateCommand {
  int run(List<String> values) {
    final arguments = CommandArguments(
      values.where((value) => value != '--check').toList(),
    );
    final project = Directory(arguments.option('project'));
    final metadata = File(_join(project.path, '.mobileui', 'template.json'));
    if (!metadata.existsSync()) {
      throw const MobileUiUsageException(
        'project is missing .mobileui/template.json',
      );
    }
    return _check(metadata);
  }

  int _check(File metadata) {
    final manifest =
        jsonDecode(metadata.readAsStringSync()) as Map<String, Object?>;
    final source = manifest['templateSource'] as Map<String, Object?>?;
    if (source?['type'] != 'github') {
      stdout.writeln('[INFO] Local template source has no remote update feed.');
      return 0;
    }
    final url = source?['url'] as String?;
    final ref = source?['ref'] as String?;
    final current = source?['commit'] as String?;
    if (url == null || ref == null || current == null) {
      throw const MobileUiUsageException('incomplete GitHub template source');
    }
    final result = Process.runSync('git', ['ls-remote', url, ref, '$ref^{}']);
    if (result.exitCode != 0) {
      throw MobileUiUsageException(
        'git failed: ${result.stderr.toString().trim()}',
      );
    }
    final output = result.stdout.toString().trim();
    if (output.isEmpty) {
      throw MobileUiUsageException('template ref "$ref" was not found');
    }
    final lines = output.split('\n');
    final peeled = lines.where((line) => line.trim().endsWith('^{}'));
    final selected = peeled.isEmpty ? lines.first : peeled.first;
    final latest = selected.split(RegExp(r'\s+')).first;
    if (latest == current) {
      stdout.writeln('[OK] Template is current at ${_short(current)}.');
      return 0;
    }
    stdout.writeln('[UPDATE] ${_short(current)} -> ${_short(latest)} ($ref)');
    stdout.writeln(
      'Regenerate or review template changes before applying them.',
    );
    return 2;
  }
}

String _short(String value) =>
    value.length > 12 ? value.substring(0, 12) : value;

String _join(String first, String second, String third) {
  return [first, second, third].join(Platform.pathSeparator);
}
