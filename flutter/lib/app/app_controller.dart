import 'package:flutter/foundation.dart';

import '../navigation/app_route.dart';
import '../navigation/route_guard.dart';
import '../state/async_state.dart';
import '../telemetry/telemetry.dart';
import 'app_repository.dart';
import 'runtime_models.dart';

final class AppController extends ChangeNotifier {
  AppController(this._repository);

  final AppRepository _repository;
  final List<AppRoute> _stack = <AppRoute>[AppRoute.logo];
  AsyncState<void> _actionState = const Idle<void>();
  RuntimeConfig? _config;
  AppUser? _user;
  Map<String, bool> authProviders = const {};
  Map<String, bool> authProviderPolicy = const {};
  List<SessionView> sessions = const [];
  List<NotificationView> notifications = const [];
  List<OrderView> orders = const [];
  UsageSummary? usage;
  List<CouponView> coupons = const [];
  ReferralView? referral;
  String recoveryEmail = '';
  String resetToken = '';
  AppRoute? _pendingRoute;

  AppRoute get route => _stack.last;
  bool get canGoBack => _stack.length > 1;
  bool get signedIn => _user != null;
  bool get busy => _actionState is Loading<void>;
  AsyncState<void> get actionState => _actionState;
  RuntimeConfig? get config => _config;
  AppUser? get user => _user;

  Future<void> initialize() async {
    try {
      final result = await _repository.bootstrap();
      _config = result.config;
      _user = result.user;
      authProviders = result.authProviders;
      authProviderPolicy = result.authProviderPolicy;
      _actionState = const Success<void>(null);
    } on ApiException catch (error) {
      _actionState = Failure(error.message);
    } catch (_) {
      _actionState = const Offline();
    }
    notifyListeners();
  }

  void navigate(AppRoute route) {
    final decision = guardRoute(route, signedIn: signedIn, config: _config);
    _pendingRoute = decision.pending ?? _pendingRoute;
    _stack.add(decision.route);
    telemetry.screen(decision.route.name);
    notifyListeners();
  }

  void replaceAll(AppRoute route) {
    final decision = guardRoute(route, signedIn: signedIn, config: _config);
    _pendingRoute = decision.pending ?? _pendingRoute;
    _stack
      ..clear()
      ..add(decision.route);
    telemetry.screen(decision.route.name);
    notifyListeners();
  }

  void completeAuthentication() {
    final target = _pendingRoute ?? AppRoute.profile;
    _pendingRoute = null;
    replaceAll(target);
  }

  void back() {
    if (!canGoBack) return;
    _stack.removeLast();
    telemetry.screen(route.name);
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) =>
      _authenticate(() => _repository.signIn(email, password));

  Future<bool> signUp(String email, String password, String username) =>
      _authenticate(() => _repository.signUp(email, password, username));

  Future<bool> requestPhoneCode(String phone) =>
      _perform(() => _repository.requestPhoneCode(phone));

  Future<bool> verifyPhoneCode(String phone, String code) =>
      _authenticate(() => _repository.verifyPhoneCode(phone, code));

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
    notifyListeners();
    return true;
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

  Future<bool> purchase(String planId) async {
    final result = await _capture(() => _repository.purchase(planId));
    if (result == null) return false;
    orders = [result, ...orders.where((order) => order.id != result.id)];
    await initialize();
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
