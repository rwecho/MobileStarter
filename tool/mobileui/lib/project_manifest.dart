import 'dart:convert';

final class ProjectManifest {
  const ProjectManifest({
    required this.templateVersion,
    required this.profiles,
    required this.repositoryName,
    required this.packageName,
    required this.displayName,
    required this.organization,
    required this.appId,
    required this.features,
    required this.sourceType,
    this.sourceUrl,
    this.sourceRef,
    this.sourceCommit,
  });

  final String templateVersion;
  final List<String> profiles;
  final String repositoryName;
  final String packageName;
  final String displayName;
  final String organization;
  final String appId;
  final List<String> features;
  final String sourceType;
  final String? sourceUrl;
  final String? sourceRef;
  final String? sourceCommit;

  String encode() => const JsonEncoder.withIndent('  ').convert({
    'templateVersion': templateVersion,
    'profile': profiles.length == 1 ? profiles.single : 'all',
    'profiles': profiles,
    'repositoryName': repositoryName,
    'packageName': packageName,
    'displayName': displayName,
    'organization': organization,
    'appId': appId,
    'features': features,
    'templateSource': {
      'type': sourceType,
      if (sourceUrl != null) 'url': sourceUrl,
      if (sourceRef != null) 'ref': sourceRef,
      if (sourceCommit != null) 'commit': sourceCommit,
    },
  });
}
