// notifyListeners 标了 @protected，extension 成员不在其"子类实例"白名单里。
// 这里是同 library 的 part，extension 只作用于 AppController，调用语义与
// 类内完全一致，误用面不存在，故整文件豁免。
// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
part of 'app_controller.dart';

/// AppController 的数据集合方法（sessions / notifications / orders / usage /
/// coupons / referral）——与 app_repository_http.dart 同款 part 拆分，
/// 服从 CI 350 行硬上限；私有成员经 library 级隐私共享。
extension AppControllerData on AppController {
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
}
