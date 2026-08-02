import 'dart:io';

import 'profile_config.dart';

final class TemplateCommand {
  const TemplateCommand(this.templateRoot);

  final Directory templateRoot;

  int run(List<String> values) {
    if (values.isNotEmpty && values.first != 'list') {
      stderr.writeln('mobileui: expected template list');
      return 64;
    }
    final profiles = ProfileConfig.list(templateRoot);
    stdout.writeln('PROFILE\tVERSION\tPLATFORMS');
    for (final profile in profiles) {
      stdout.writeln(
        '${profile.id}\t${profile.version}\t${profile.platforms.join(',')}',
      );
    }
    stdout.writeln('all\t${_combinedVersion(profiles)}\tcombined');
    return 0;
  }
}

String _combinedVersion(List<ProfileConfig> profiles) {
  final versions = profiles.map((profile) => profile.version).toSet();
  return versions.length == 1 ? versions.single : 'mixed';
}
