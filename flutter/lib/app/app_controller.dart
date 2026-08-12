import 'package:flutter/foundation.dart';

import '../auth/social_auth.dart';
import '../navigation/app_route.dart';
import '../state/async_state.dart';
import 'app_repository.dart';
import 'runtime_models.dart';

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
  bool _online = true;
  bool _bootstrapped = false;
  bool get online => _online;
  bool get bootstrapped => _bootstrapped;

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
    notifyListeners();
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

  Future<bool> loadSessions() async {
    final result = await _capture(_repository.sessions);
    if (result == null) return false;
    sessions = result;
    notifyListeners();
    return true;
  }

  Future<bool> revokeSession(String id) async {
    final success = await _perform(() => _repository.revokeSession(id));
    if (!success) return false;
    sessions = sessions
        .where((session) => session.id != id)
        .toList(growable: false);
    notifyListeners();
    return true;
  }

  Future<bool> loadNotifications() async {
    final result = await _capture(_repository.notifications);
    if (result == null) return false;
    notifications = result;
    notifyListeners();
    return true;
  }

  Future<bool> markNotificationsRead() async {
    final success = await _perform(_repository.markNotificationsRead);
    if (success) await loadNotifications();
    return success;
  }

  Future<bool> markNotificationRead(String id) async {
    final success = await _perform(() => _repository.markNotificationRead(id));
    if (success) await loadNotifications();
    return success;
  }

  Future<bool> deleteNotification(String id) async {
    final success = await _perform(() => _repository.deleteNotification(id));
    if (success) {
      notifications = notifications
          .where((item) => item.id != id)
          .toList(growable: false);
      notifyListeners();
    }
    return success;
  }

  Future<bool> loadOrders() async {
    final result = await _capture(_repository.orders);
    if (result == null) return false;
    orders = result;
    notifyListeners();
    return true;
  }

  Future<bool> loadUsage() async {
    final result = await _capture(_repository.usage);
    if (result == null) return false;
    usage = result;
    notifyListeners();
    return true;
  }

  Future<bool> loadCoupons() async {
    final result = await _capture(_repository.coupons);
    if (result == null) return false;
    coupons = result;
    notifyListeners();
    return true;
  }

  Future<bool> loadReferral() async {
    final result = await _capture(_repository.referral);
    if (result == null) return false;
    referral = result;
    notifyListeners();
    return true;
  }

  Future<bool> _authenticate(Future<AuthResult> Function() operation) async {
    final result = await _capture(operation);
    if (result == null) return false;
    _user = result.user;
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
      _actionState = Failure(error.message);
      return null;
    } catch (_) {
      _actionState = const Offline<void>();
      return null;
    } finally {
      notifyListeners();
    }
  }

  Future<void> _clearSession() async {
    _user = null;
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

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }
}
