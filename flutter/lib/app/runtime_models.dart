import '../payment/payment_models.dart';

part 'runtime_activity_models.dart';

typedef JsonMap = Map<String, Object?>;

final class RuntimeConfig {
  const RuntimeConfig({
    required this.version,
    required this.appName,
    required this.tagline,
    required this.splash,
    required this.features,
    required this.settingsPolicy,
    required this.tiers,
    required this.plans,
    required this.legal,
  });

  factory RuntimeConfig.fromJson(JsonMap json) {
    final brand = JsonMap.from(json['brand']! as Map);
    final splashJson = json['splash'];
    return RuntimeConfig(
      version: json['version']! as int,
      appName: brand['appName']! as String,
      tagline: brand['tagline']! as String,
      splash: splashJson == null
          ? null
          : SplashCampaign.fromJson(JsonMap.from(splashJson as Map)),
      features: Map<String, bool>.from(json['features']! as Map),
      settingsPolicy: (json['settingsPolicy']! as Map).map(
        (key, value) => MapEntry(
          key as String,
          SettingPolicy.fromJson(JsonMap.from(value as Map)),
        ),
      ),
      tiers: (json['tiers']! as List)
          .map((value) => MembershipTier.fromJson(JsonMap.from(value as Map)))
          .toList(growable: false),
      plans: (json['plans']! as List)
          .map((value) => BillingPlan.fromJson(JsonMap.from(value as Map)))
          .toList(growable: false),
      legal: (json['legal']! as List)
          .map((value) => LegalDocument.fromJson(JsonMap.from(value as Map)))
          .toList(growable: false),
    );
  }

  final int version;
  final String appName;
  final String tagline;
  final SplashCampaign? splash;
  final Map<String, bool> features;
  final Map<String, SettingPolicy> settingsPolicy;
  final List<MembershipTier> tiers;
  final List<BillingPlan> plans;
  final List<LegalDocument> legal;
}

final class SplashCampaign {
  const SplashCampaign({
    required this.id,
    required this.title,
    required this.description,
    required this.badge,
    required this.actionLabel,
    required this.imageUrl,
    required this.videoUrl,
    required this.linkUrl,
    required this.skippable,
    required this.durationSeconds,
  });

  factory SplashCampaign.fromJson(JsonMap json) => SplashCampaign(
    id: json['id']! as String,
    title: json['title']! as String,
    description: json['description']! as String,
    badge: json['badge']! as String,
    actionLabel: json['actionLabel']! as String,
    imageUrl: json['imageUrl'] as String?,
    videoUrl: json['videoUrl'] as String?,
    linkUrl: json['linkUrl'] as String?,
    skippable: json['skippable']! as bool,
    durationSeconds: json['durationSeconds']! as int,
  );

  final String id;
  final String title;
  final String description;
  final String badge;
  final String actionLabel;
  final String? imageUrl;
  final String? videoUrl;
  final String? linkUrl;
  final bool skippable;
  final int durationSeconds;
}

final class SettingPolicy {
  const SettingPolicy({required this.visible, required this.userMutable});

  factory SettingPolicy.fromJson(JsonMap json) => SettingPolicy(
    visible: json['visibility'] == 'visible',
    userMutable: json['mutability'] == 'user',
  );

  final bool visible;
  final bool userMutable;
}

final class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.username,
    required this.displayName,
    required this.bio,
    required this.avatarUrl,
    required this.tierId,
    required this.settings,
    required this.emailVerified,
    required this.consentVersion,
    required this.hasEmail,
  });

  factory AppUser.fromJson(JsonMap json) => AppUser(
    id: json['id']! as String,
    // 可空：手机号/华为登录未绑定邮箱；hasEmail=false 时 UI 不展示 email。
    email: json['email'] as String?,
    username: json['username']! as String,
    displayName: json['displayName']! as String,
    bio: json['bio']! as String,
    avatarUrl: json['avatarUrl'] as String?,
    tierId: json['tierId']! as String,
    settings: JsonMap.from(json['settings']! as Map),
    emailVerified: json['emailVerified'] == true,
    consentVersion: json['consentVersion'] as String?,
    hasEmail: json['hasEmail'] == true,
  );

  final String id;
  final String? email;
  final String username;
  final String displayName;
  final String bio;
  final String? avatarUrl;
  final String tierId;
  final JsonMap settings;
  final bool emailVerified;
  final String? consentVersion;
  final bool hasEmail;

  AppUser copyWith({
    String? displayName,
    String? bio,
    String? avatarUrl,
    JsonMap? settings,
  }) => AppUser(
    id: id,
    email: email,
    username: username,
    displayName: displayName ?? this.displayName,
    bio: bio ?? this.bio,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    tierId: tierId,
    settings: settings ?? this.settings,
    emailVerified: emailVerified,
    consentVersion: consentVersion,
    hasEmail: hasEmail,
  );
}

final class MembershipTier {
  const MembershipTier({
    required this.id,
    required this.name,
    required this.summary,
    required this.recommended,
    required this.entitlements,
  });

  factory MembershipTier.fromJson(JsonMap json) => MembershipTier(
    id: json['id']! as String,
    name: json['name']! as String,
    summary: json['summary']! as String,
    recommended: json['recommended']! as bool,
    entitlements: List<String>.from(json['entitlements']! as List),
  );

  final String id;
  final String name;
  final String summary;
  final bool recommended;
  final List<String> entitlements;
}

final class BillingPlan {
  const BillingPlan({
    required this.id,
    required this.tierId,
    required this.name,
    required this.interval,
    required this.priceMinor,
    required this.currency,
    required this.provider,
    this.storeProductMapping,
  });

  factory BillingPlan.fromJson(JsonMap json) => BillingPlan(
    id: json['id']! as String,
    tierId: json['tierId']! as String,
    name: json['name']! as String,
    interval: json['interval']! as String,
    priceMinor: json['priceMinor']! as int,
    currency: json['currency']! as String,
    provider: json['provider']! as String,
    storeProductMapping: json['storeProductMapping'] == null
        ? null
        : StoreProductMapping.fromJson(JsonMap.from(json['storeProductMapping']! as Map)),
  );

  final String id;
  final String tierId;
  final String name;
  final String interval;
  final int priceMinor;
  final String currency;
  final String provider;
  final StoreProductMapping? storeProductMapping;
}

final class SessionView {
  const SessionView({
    required this.id,
    required this.deviceName,
    required this.current,
  });
  factory SessionView.fromJson(JsonMap json) => SessionView(
    id: json['id']! as String,
    deviceName: json['deviceName']! as String,
    current: json['current']! as bool,
  );
  final String id;
  final String deviceName;
  final bool current;
}

final class NotificationView {
  const NotificationView({
    required this.id,
    required this.title,
    required this.body,
    required this.read,
    this.route,
  });
  factory NotificationView.fromJson(JsonMap json) => NotificationView(
    id: json['id']! as String,
    title: json['title']! as String,
    body: json['body']! as String,
    read: json['readAt'] != null,
    route: json['route'] as String?,
  );
  final String id;
  final String title;
  final String body;
  final bool read;
  final String? route;
}

enum OrderStatus { pending, processing, success, failed, refunded }

OrderStatus _parseOrderStatus(String s) {
  return OrderStatus.values.firstWhere(
    (e) => e.name == s,
    orElse: () => OrderStatus.pending,
  );
}

final class OrderView {
  const OrderView({
    required this.id,
    required this.planId,
    required this.status,
    required this.amountMinor,
    required this.currency,
    this.provider,
    this.storeTransactionId,
    this.expiresAt,
  });
  factory OrderView.fromJson(JsonMap json) => OrderView(
    id: json['id']! as String,
    planId: json['planId']! as String,
    status: _parseOrderStatus(json['status']! as String),
    amountMinor: json['amountMinor']! as int,
    currency: json['currency']! as String,
    provider: json['provider'] as String?,
    storeTransactionId: json['storeTransactionId'] as String?,
    expiresAt: json['expiresAt'] as String?,
  );
  final String id;
  final String planId;
  final OrderStatus status;
  final int amountMinor;
  final String currency;
  final String? provider;
  final String? storeTransactionId;
  final String? expiresAt;
}
