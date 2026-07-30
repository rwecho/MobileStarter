import 'package:shared_preferences/shared_preferences.dart';

// Keys mirror AppRepository._bootstrapKey and the telemetry queue so the
// measured size reflects the regenerable cache the storage screen clears.
const _bootstrapKey = 'mobileui.bootstrap.public';
const _telemetryKey = 'mobileui.telemetry.queue';

Future<int> measureCacheBytes() async {
  final storage = SharedPreferencesAsync();
  final bootstrap = await storage.getString(_bootstrapKey) ?? '';
  final telemetry = await storage.getString(_telemetryKey) ?? '';
  return bootstrap.length + telemetry.length;
}

String formatCacheSize(int bytes) {
  if (bytes <= 0) return '0 KB';
  return '${(bytes / 1024).ceil()} KB';
}
