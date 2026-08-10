// Local typedef — avoids a circular import with runtime_models.dart (which
// imports this file for StoreProductMapping). Kept in sync with the one in
// runtime_models.dart.
typedef JsonMap = Map<String, Object?>;

final class StoreProductMapping {
  const StoreProductMapping({this.apple, this.google, this.hms});
  factory StoreProductMapping.fromJson(JsonMap json) => StoreProductMapping(
        apple: json['apple'] as String?,
        google: json['google'] as String?,
        hms: json['hms'] as String?,
      );
  final String? apple;
  final String? google;
  final String? hms;
}

final class StoreProduct {
  const StoreProduct({required this.storeProductId, this.title});
  final String storeProductId;
  final String? title;
}

final class PurchaseResult {
  const PurchaseResult({required this.storeProductId, required this.receipt});
  final String storeProductId;
  final Object receipt; // opaque; forwarded to server /purchases/verify
}

final class Entitlement {
  const Entitlement({required this.key, this.expiresAt});
  factory Entitlement.fromJson(JsonMap json) => Entitlement(
        key: json['key']! as String,
        expiresAt: json['expiresAt'] as String?,
      );
  final String key;
  final String? expiresAt;
}

final class Subscription {
  const Subscription({required this.planId, required this.status, this.renewAt});
  factory Subscription.fromJson(JsonMap json) => Subscription(
        planId: json['planId']! as String,
        status: json['status']! as String,
        renewAt: json['renewAt'] as String?,
      );
  final String planId;
  final String status;
  final String? renewAt;
}

final class MembershipCurrent {
  const MembershipCurrent({required this.tier, required this.entitlements, this.subscription});
  factory MembershipCurrent.fromJson(JsonMap json) => MembershipCurrent(
        tier: json['tier'] as String?,
        entitlements: (json['entitlements'] as List<Object?>? ?? const [])
            .map((e) => Entitlement.fromJson(JsonMap.from(e! as Map)))
            .toList(growable: false),
        subscription: json['subscription'] == null
            ? null
            : Subscription.fromJson(JsonMap.from(json['subscription']! as Map)),
      );
  final String? tier;
  final List<Entitlement> entitlements;
  final Subscription? subscription;
}

final class CreateOrderResult {
  const CreateOrderResult({required this.orderId, required this.storeProductId, required this.status});
  factory CreateOrderResult.fromJson(JsonMap json) => CreateOrderResult(
        orderId: json['orderId']! as String,
        storeProductId: json['storeProductId']! as String,
        status: json['status']! as String,
      );
  final String orderId;
  final String storeProductId;
  final String status;
}
