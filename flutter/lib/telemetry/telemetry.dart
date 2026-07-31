import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

typedef TelemetryProperties = Map<String, Object>;

final class TelemetryConfig {
  const TelemetryConfig({
    this.enabled = true,
    this.backendEnabled = true,
    this.firebaseEnabled = false,
    this.analyticsEnabled = false,
    this.crashlyticsEnabled = false,
    this.configVersion = 0,
  });

  final bool enabled;
  final bool backendEnabled;
  final bool firebaseEnabled;
  final bool analyticsEnabled;
  final bool crashlyticsEnabled;
  final int configVersion;
}

final class Telemetry {
  static const _maxQueue = 200;
  static const _maxFirebaseQueue = 100;
  static const _batchSize = 25;
  static const _queueKey = 'mobileui.telemetry.queue';
  static const _anonymousKey = 'mobileui.telemetry.anonymousId';
  static const _sessionTokenKey = 'mobileui.sessionToken';
  static const _apiBase = String.fromEnvironment(
    'MOBILEUI_API_URL',
    defaultValue: 'http://localhost:3210',
  );
  // app_id（租户）必须通过 --dart-define=MOBILEUI_APP_ID 显式配置，未配置即报错，
  // 避免混入不可预测的 app_id；启动期统一校验见 main()。
  static const _appIdValue = String.fromEnvironment('MOBILEUI_APP_ID');
  static String get _appId {
    if (_appIdValue.isEmpty) {
      throw StateError(
        'MOBILEUI_APP_ID 未配置：请使用 --dart-define=MOBILEUI_APP_ID=<app-id> 启动，不能为空。',
      );
    }
    return _appIdValue;
  }

  // environment（development/staging/production 等）同样必须显式配置，未配置即报错。
  static const _appEnvironmentValue = String.fromEnvironment('MOBILEUI_APP_ENVIRONMENT');
  static String get _appEnvironment {
    if (_appEnvironmentValue.isEmpty) {
      throw StateError(
        'MOBILEUI_APP_ENVIRONMENT 未配置：请使用 --dart-define=MOBILEUI_APP_ENVIRONMENT=<env> 启动，不能为空。',
      );
    }
    return _appEnvironmentValue;
  }

  final _queue = <Map<String, Object?>>[];
  final _firebaseQueue = <Map<String, Object?>>[];
  final _secure = const FlutterSecureStorage();
  final _sessionId = _id('session');
  TelemetryConfig _config = const TelemetryConfig();
  String _anonymousId = '';
  String? _screen;
  DateTime _screenStarted = DateTime.now();
  Timer? _flushTimer;
  Timer? _persistTimer;
  bool _hydrated = false;
  bool _flushing = false;
  bool _firebaseDraining = false;
  int _retry = 0;

  Future<void> configure(TelemetryConfig config) async {
    _config = config;
    if (!_hydrated) {
      _hydrated = true;
      await _hydrate().catchError((_) {});
    }
    _scheduleFlush(Duration.zero);
    if (config.firebaseEnabled) {
      unawaited(_configureFirebase());
      _scheduleFirebaseDrain();
    }
  }

  void screen(String name) {
    if (_screen == name) return;
    if (_screen case final previous?) {
      track('screen_leave', {
        'screen_id': previous,
        'duration_ms': DateTime.now().difference(_screenStarted).inMilliseconds,
      }, previous);
    }
    _screen = name;
    _screenStarted = DateTime.now();
    track('screen_view', {'screen_id': name}, name);
  }

  void track(
    String name, [
    TelemetryProperties properties = const {},
    String? screen,
  ]) {
    if (!_config.enabled) return;
    final event = <String, Object?>{
      'eventId': _id('evt'),
      'name': name,
      'screenId': screen ?? _screen,
      'occurredAt': DateTime.now().toUtc().toIso8601String(),
      'configVersion': _config.configVersion,
      'properties': properties,
    };
    if (_config.backendEnabled) {
      if (_queue.length >= _maxQueue) _queue.removeAt(0);
      _queue.add(event);
      _schedulePersist();
      _scheduleFlush(const Duration(seconds: 2));
    }
    if (_config.firebaseEnabled && _config.analyticsEnabled) {
      if (_firebaseQueue.length >= _maxFirebaseQueue) {
        _firebaseQueue.removeAt(0);
      }
      _firebaseQueue.add(event);
      _scheduleFirebaseDrain();
    }
  }

  void report(Object error, StackTrace? stack) {
    final message = error.toString();
    final stackText = stack?.toString() ?? '';
    track('app_error', {
      'error_name': error.runtimeType.toString(),
      'error_message': message.substring(
        0,
        min(200, message.length),
      ),
      if (stackText.isNotEmpty)
        'error_stack': stackText.substring(0, min(200, stackText.length)),
    });
    if (_config.firebaseEnabled && _config.crashlyticsEnabled) {
      unawaited(
        FirebaseCrashlytics.instance
            .recordError(error, stack, fatal: false)
            .catchError((_) {}),
      );
    }
  }

  Future<void> _hydrate() async {
    final storage = SharedPreferencesAsync();
    _anonymousId = await storage.getString(_anonymousKey) ?? _id('anonymous');
    await storage.setString(_anonymousKey, _anonymousId);
    final raw = await storage.getString(_queueKey);
    final stored = raw == null ? <Object?>[] : jsonDecode(raw) as List<Object?>;
    _queue.insertAll(
      0,
      stored.whereType<Map>().map((item) => Map<String, Object?>.from(item)),
    );
    if (_queue.length > _maxQueue) {
      _queue.removeRange(0, _queue.length - _maxQueue);
    }
  }

  void _scheduleFlush(Duration delay) {
    if (_flushing || _flushTimer != null || _queue.isEmpty) return;
    _flushTimer = Timer(delay, () {
      _flushTimer = null;
      unawaited(_flush());
    });
  }

  Future<void> _flush() async {
    if (_flushing || _queue.isEmpty || !_config.backendEnabled) return;
    _flushing = true;
    final batch = _queue.take(_batchSize).toList(growable: false);
    try {
      final token = await _secure.read(key: _sessionTokenKey) ?? '';
      final response = await http
          .post(
            Uri.parse('$_apiBase/api/v1/telemetry/events'),
            headers: {
              'content-type': 'application/json',
              'x-app-id': _appId,
              'x-app-environment': _appEnvironment,
              'x-platform': _platform,
              'x-app-version': '1.0.0',
              if (token.isNotEmpty) 'authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'anonymousId': _anonymousId.isEmpty
                  ? 'anonymous-pending'
                  : _anonymousId,
              'sessionId': _sessionId,
              'events': batch,
            }),
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('telemetry rejected');
      }
      _queue.removeRange(0, batch.length);
      _retry = 0;
      _schedulePersist();
    } catch (_) {
      _retry = min(_retry + 1, 4);
    } finally {
      _flushing = false;
      if (_queue.isNotEmpty) {
        final seconds = const [2, 5, 15, 30, 60][_retry];
        _scheduleFlush(Duration(seconds: seconds + Random().nextInt(2)));
      }
    }
  }

  void _schedulePersist() {
    if (_persistTimer != null) return;
    _persistTimer = Timer(const Duration(seconds: 1), () {
      _persistTimer = null;
      final snapshot = jsonEncode(_queue.take(_maxQueue).toList());
      unawaited(
        SharedPreferencesAsync()
            .setString(_queueKey, snapshot)
            .catchError((_) {}),
      );
    });
  }

  Future<void> _configureFirebase() async {
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(
        _config.analyticsEnabled,
      );
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        _config.crashlyticsEnabled,
      );
    } catch (_) {
      // Per-App Firebase files are optional in the reusable template.
    }
  }

  void _scheduleFirebaseDrain() {
    if (_firebaseDraining || _firebaseQueue.isEmpty) return;
    _firebaseDraining = true;
    Timer.run(() => unawaited(_drainFirebase()));
  }

  Future<void> _drainFirebase() async {
    final events = _firebaseQueue.take(10).toList(growable: false);
    _firebaseQueue.removeRange(0, events.length);
    try {
      for (final event in events) {
        await FirebaseAnalytics.instance.logEvent(
          name: 'mui_${event['name']}',
          parameters: Map<String, Object>.from(event['properties']! as Map),
        );
      }
    } catch (_) {
      // The self-hosted sink remains canonical.
    } finally {
      _firebaseDraining = false;
      if (_firebaseQueue.isNotEmpty) {
        Timer(const Duration(seconds: 2), _scheduleFirebaseDrain);
      }
    }
  }

  static String _id(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(0x3FFFFFFF)}';

  static String get _platform {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios',
      TargetPlatform.android => 'android',
      _ => 'web',
    };
  }
}

final telemetry = Telemetry();
