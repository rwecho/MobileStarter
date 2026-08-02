import 'dart:io';

import '../lib/command_runner.dart';

Future<void> main(List<String> arguments) async {
  final runner = MobileUiCommandRunner(
    templateRoot: File.fromUri(Platform.script).parent.parent.parent.parent,
  );
  exitCode = await runner.run(arguments);
}
