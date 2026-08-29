import 'dart:io';

import 'create_command.dart';
import 'doctor_command.dart';
import 'feature_command.dart';
import 'template_command.dart';
import 'update_command.dart';

final class MobileUiCommandRunner {
  const MobileUiCommandRunner({required this.templateRoot});

  final Directory templateRoot;

  Future<int> run(List<String> arguments) async {
    if (arguments.isEmpty || arguments.first == 'help') {
      _printHelp();
      return 0;
    }

    try {
      return switch (arguments.first) {
        'create' => await CreateCommand(
          templateRoot,
        ).run(arguments.skip(1).toList()),
        'doctor' => DoctorCommand().run(arguments.skip(1).toList()),
        'feature' => FeatureCommand().run(arguments.skip(1).toList()),
        'template' => TemplateCommand(
          templateRoot,
        ).run(arguments.skip(1).toList()),
        'update' => UpdateCommand().run(arguments.skip(1).toList()),
        'version' => _printVersion(),
        _ => _unknown(arguments.first),
      };
    } on MobileUiUsageException catch (error) {
      stderr.writeln('mobileui: ${error.message}');
      return 64;
    } on FileSystemException catch (error) {
      stderr.writeln('mobileui: ${error.message}');
      return 74;
    }
  }

  int _printVersion() {
    stdout.writeln('mobileui 0.2.0');
    return 0;
  }

  int _unknown(String command) {
    stderr.writeln('mobileui: unknown command "$command"');
    _printHelp();
    return 64;
  }

  void _printHelp() {
    stdout.writeln('''
MobileUI product repository CLI

Usage:
  mobileui create <repo-name> --output <directory>
      --profile <flutter|react-native|arkts|server|all>
      --display-name <name> --organization <reverse-domain> --app-id <id>
      [--source <local|github>] [--source-url <git-url>] [--ref <tag|branch|sha>]
  mobileui doctor --project <directory>
  mobileui feature add <feature-id> --project <directory>
  mobileui template list
  mobileui update --check --project <directory>
  mobileui version

Supported profiles:
  flutter, react-native, arkts, server, all (mobile clients only)
''');
  }
}

final class MobileUiUsageException implements Exception {
  const MobileUiUsageException(this.message);

  final String message;
}
