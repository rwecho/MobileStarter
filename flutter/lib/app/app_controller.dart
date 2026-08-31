import 'dart:async';

import '../telemetry/telemetry.dart';

import 'package:flutter/foundation.dart';

import '../auth/social_auth.dart';
import '../navigation/app_route.dart';
import '../push/push_service.dart';
import '../state/async_state.dart';
import 'app_repository.dart';
import 'runtime_models.dart';

part 'app_controller_data.dart';

final class AppController extends ChangeNotifier {
  AppController(this._repository) {
    _repository.onSessionExpired = _handleSessionExpired;
  }

  final AppRepository _repository;
  AsyncState<void> _actionState = const Idle<void>();
  RuntimeConfig? _config;
  AppUser? _user;
  Map<String, bool> authProviders = const {};
  Map<String, bool> authProviderPolicy = const {};
  Map<String, Object?> authProviderConfig = const {};
  List<SessionView> sessions = const [];
  List<NotificationView> notifications = const [];
  List<OrderView> orders = const [];
  UsageSummary? usage;
  List<CouponView> coupons = const [];
  ReferralView? referral;
  String recoveryEmail = '';
  String resetToken = '';
  AppRoute? _authRedirectTarget;

  bool get signedIn => _user != null;
  bool get busy => _actionState is Loading<void>;
  AsyncState<void> get actionState => _actionState;
  RuntimeConfig? get config => _config;
  AppUser? get user => _user;
  // online：最近一次 bootstrap 是否成功拉到配置（失败即视为离线）。
  // bootstrapped：初始 bootstrap 是否完成（成功或失败）；闪屏据此判断"配置拉取完成"。
  // localReady：磁盘缓存 config 已就绪；闪屏进首页只等它、不等网络（issue #24）。
  bool _online = true;
  bool _bootstrapped = false;
  bool _localReady = false;
  bool get online => _online;
  bool get bootstrapped => _bootstrapped;
  bool get localReady => _localReady;

  /// Called by the router redirect when a signed-out user hits a protected
  /// route; remembers the target so auth screens can resume it after login.
  void setAuthRedirectTarget(AppRoute route) => _authRedirectTarget = route;

  /// Returns and clears the pre-login target (or null if none) so auth screens
  /// can `context.go(pathFor(target ?? AppRoute.home))` after a successful sign-in.
  AppRoute? consumeAuthRedirectTarget() {
    final target = _authRedirectTarget;
    _authRedirectTarget = null;
    return target;
  }

  Future<void> initialize() async {
    _actionState = const Loading<void>();
    // 冷启动只等磁盘：先读缓存 config 置 localReady（splash 据此放行），
    // 网络 bootstrap 在其后继续（issue #24：进首页不等网络）。
    if (_config == null) {
      try {
        final cached = await _repository.readCachedBootstrap();
        if (cached != null) _config = cached.config;
      } catch (_) {
        // 缓存读取失败不阻塞启动，走网络 bootstrap 兜底
      }
      _localReady = true;
      notifyListeners();
    }
    try {
      final result = await _repository.bootstrap();
      _config = result.config;
      _user = result.user;
      authProviders = result.authProviders;
      authProviderPolicy = result.authProviderPolicy;
      authProviderConfig = result.authProviderConfig;
      _syncLocale();
      _online = true;
      _actionState = const Success<void>(null);
    } on ApiException catch (error) {
      _online = false;
      _actionState = Failure(error.message);
    } catch (_) {
      _online = false;
      _actionState = const Offline();
    }
    // 仅标记初始 bootstrap 已完成（resume 轮询到此处是无害的再赋值），
    // 一旦为 true 不再回到 false，闪屏据此放行。
    _bootstrapped = true;
    notifyListeners();
  }

  Future<void> resume() => initialize();

  Future<bool> signIn(String email, String password) =>
      _authenticate(() => _repository.signIn(email, password));

  Future<bool> signUp(
    String email,
    String password,
    String username,
    String consentVersion,
  ) => _authenticate(
    () => _repository.signUp(email, password, username, consentVersion),
  );

  Future<bool> requestPhoneCode(String phone) =>
      _perform(() => _repository.requestPhoneCode(phone));

  Future<bool> verifyPhoneCode(String phone, String code) =>
      _authenticate(() => _repository.verifyPhoneCode(phone, code));

  Future<bool> socialSignIn(String provider) async {
    final payload = await acquireSocialCredential(
      provider,
      githubClientId: _providerClientId('github'),
      googleClientId: _providerClientId('google'),
    );
    if (payload == null) return false;
    return _authenticate(() => _repository.socialSignIn(payload));
  }

  String? _providerClientId(String provider) {
    final config = authProviderConfig[provider];
    if (config is Map) return config['clientId'] as String?;
    return null;
  }

  Future<bool> requestPasswordReset(String email) async {
    final success = await _perform(
      () => _repository.requestPasswordReset(email),
    );
    if (success) recoveryEmail = email;
    return success;
  }

  Future<bool> verifyPasswordReset(String code) async {
    final result = await _capture(
      () => _repository.verifyPasswordReset(recoveryEmail, code),
    );
    if (result == null) return false;
    resetToken = result;
    return true;
  }

  Future<bool> resetPassword(String password) async {
    final success = await _perform(
      () => _repository.resetPassword(resetToken, password),
    );
    if (success) {
      recoveryEmail = '';
      resetToken = '';
    }
    return success;
  }

  Future<bool> updateProfile(
    String displayName,
    String bio,
    String? avatarUrl,
  ) async {
    final result = await _capture(
      () => _repository.updateProfile(displayName, bio, avatarUrl),
    );
    if (result == null) return false;
    _user = result;
    notifyListeners();
    return true;
  }

  /// 头像上传：JPEG bytes → presigned PUT 直传 OSS → 返回对象 URL。
  /// 编辑 sheet 裁剪完成后调用；avatarUrl 存返回的 url（不再 base64）。
  Future<String?> uploadAvatar(Uint8List imageBytes) async {
    try {
      final userId = user?.id ?? 'anon';
      final path = 'avatars/$userId-${DateTime.now().millisecondsSinceEpoch}.jpg';
      final sign = await _repository.signUpload(path, 'image/png');
      await _repository.uploadToS3(sign.uploadUrl, imageBytes, 'image/png');
      return sign.url;
    } catch (_) {
      return null;
    }
  }

  /// objectKey → presigned URL（私有 bucket 24h；显示层 AssetUrls 缓存调用）。
  Future<String?> resolveObjectUrl(String objectKey) =>
      _repository.resolveObjectUrl(objectKey);

  Future<bool> saveSettings(JsonMap patch) async {
    final result = await _capture(() => _repository.saveSettings(patch));
    if (result == null || _user == null) return false;
    _user = _user!.copyWith(settings: result);
    _syncLocale();
    notifyListeners();
    return true;
  }

  void _syncLocale() {
    final language = _user?.settings['language'];
    _repository.setLocale(language == 'en-US' ? 'en-US' : 'zh-CN');
  }

  Future<bool> changePassword(String current, String next) async {
    final success = await _perform(
      () => _repository.changePassword(current, next),
    );
    if (success) await _clearSession();
    return success;
  }

  Future<bool> deleteAccount(String password) async {
    final success = await _perform(() => _repository.deleteAccount(password));
    if (success) await _clearSession();
    return success;
  }

  Future<void> signOut() async {
    await _perform(_repository.signOut);
    await _clearSession();
  }

  Future<void> signOutAll() async {
    await _perform(_repository.signOutAll);
    await _clearSession();
  }

  void _handleSessionExpired() {
    _user = null;
    // Navigation is now driven by go_router: notifying listeners re-evaluates
    // the router redirect, which sends a signed-out user on a protected route
    // back to sign-in (remembering the target via setAuthRedirectTarget).
    notifyListeners();
  }

  Future<bool> _authenticate(Future<AuthResult> Function() operation) async {
    final result = await _capture(operation);
    if (result == null) return false;
    _user = result.user;
    // 推送基线：登录成功后注册令牌；失败静默降级（PushService 内上报）。
    unawaited(PushService.start(
      register: _repository.registerPushToken,
      unregister: _repository.unregisterPushToken,
      onForeground: queuePushMessage,
    ));
    notifyListeners();
    return true;
  }

  Future<bool> _perform(Future<void> Function() operation) async =>
      await _capture(() async {
        await operation();
        return true;
      }) ??
      false;

  Future<T?> _capture<T>(Future<T> Function() operation) async {
    if (busy) return null;
    _actionState = const Loading<void>();
    notifyListeners();
    try {
      final result = await operation();
      _actionState = const Success<void>(null);
      return result;
    } on ApiException catch (error) {
      // 用户可见错误必须进遥测（app_error）——catch 分支不上报则线上查不到。
      telemetry.report(error, StackTrace.current);
      _actionState = Failure(error.message);
      return null;
    } catch (error) {
      telemetry.report(error, StackTrace.current);
      _actionState = const Offline<void>();
      return null;
    } finally {
      notifyListeners();
    }
  }

  Future<void> _clearSession() async {
    _user = null;
    unawaited(PushService.stop());
    sessions = const [];
    notifications = const [];
    orders = const [];
    usage = null;
    coupons = const [];
    referral = null;
    notifyListeners();
  }

  String? consumeError() {
    final state = _actionState;
    if (state is Failure<void>) return state.message;
    if (state is Offline<void>) return '网络不可用，请检查连接后重试';
    return null;
  }

  final List<String> _pushMessages = <String>[];

  /// 推送前台消息入队；根组件在帧回调里消费后以 toast 呈现。
  void queuePushMessage(String message) {
    _pushMessages.add(message);
    notifyListeners();
  }

  String? consumePushMessage() {
    if (_pushMessages.isEmpty) return null;
    return _pushMessages.removeAt(0);
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }
}
