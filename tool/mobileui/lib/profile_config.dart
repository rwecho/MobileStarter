import 'dart:convert';
import 'dart:io';

import 'command_runner.dart';

final class ProfileConfig {
  const ProfileConfig({
    required this.id,
    required this.version,
    required this.source,
    required this.platforms,
    required this.features,
    required this.workflows,
    required this.excludedDirectories,
  });

  final String id;
  final String version;
  final String source;
  final List<String> platforms;
  final List<String> features;
  final List<String> workflows;
  final Set<String> excludedDirectories;

  factory ProfileConfig.read(Directory templateRoot, String id) {
    final file = File(_join(templateRoot.path, 'profiles', id, 'profile.json'));
    if (!file.existsSync()) {
      throw MobileUiUsageException('profile "$id" is not available');
    }
    final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
    return ProfileConfig(
      id: json['id'] as String,
      version: json['version'].toString(),
      source: json['source'] as String,
      platforms: _strings(json['platforms']),
      features: _strings(json['features']),
      workflows: _strings(json['workflows']),
      excludedDirectories: _strings(json['excludedDirectories']).toSet(),
    );
  }

  static List<ProfileConfig> resolve(Directory root, String selection) {
    final ids = selection == 'all'
        ? const ['flutter', 'react-native', 'arkts']
        : selection.split(',').map((value) => value.trim()).toList();
    if (ids.isEmpty || ids.any((id) => id.isEmpty)) {
      throw const MobileUiUsageException('profile must not be empty');
    }
    return ids.toSet().map((id) => ProfileConfig.read(root, id)).toList();
  }

  static List<ProfileConfig> list(Directory root) {
    final directory = Directory(_join(root.path, 'profiles'));
    if (!directory.existsSync()) return const [];
    final profiles = <ProfileConfig>[];
    for (final entity in directory.listSync()) {
      if (entity is! Directory) continue;
      final id = entity.uri.pathSegments.where((part) => part.isNotEmpty).last;
      profiles.add(ProfileConfig.read(root, id));
    }
    profiles.sort((left, right) => left.id.compareTo(right.id));
    return profiles;
  }
}

List<String> _strings(Object? value) {
  return (value as List<Object?>? ?? const []).whereType<String>().toList();
}

String _join(String first, String second, [String? third, String? fourth]) {
  return [
    first,
    second,
    third,
    fourth,
  ].whereType<String>().join(Platform.pathSeparator);
}
