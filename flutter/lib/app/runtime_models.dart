typedef JsonMap = Map<String, Object?>;

final class RuntimeConfig {
  const RuntimeConfig({
    required this.version,
    required this.appName,
    required this.splash,
    required this.features,
    required this.settingsPolicy,
    required this.tiers,
    required this.plans,
    required this.legal,
  });

  factory RuntimeConfig.fromJson(JsonMap json) {
    final brand = JsonMap.from(json['brand']! as Map);
    return RuntimeConfig(
      version: json['version']! as int,
      appName: brand['appName']! as String,
      splash: SplashCampaign.fromJson(JsonMap.from(json['splash']! as Map)),
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
  final SplashCampaign splash;
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
    required this.skippable,
  });

  factory SplashCampaign.fromJson(JsonMap json) => SplashCampaign(
    id: json['id']! as String,
    title: json['title']! as String,
    description: json['description']! as String,
    badge: json['badge']! as String,
    actionLabel: json['actionLabel']! as String,
    imageUrl: json['imageUrl'] as String?,
    skippable: json['skippable']! as bool,
  );

  final String id;
  final String title;
  final String description;
  final String badge;
  final String actionLabel;
  final String? imageUrl;
  final bool skippable;
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
  });

  factory AppUser.fromJson(JsonMap json) => AppUser(
    id: json['id']! as String,
    email: json['email']! as String,
    username: json['username']! as String,
    displayName: json['displayName']! as String,
    bio: json['bio']! as String,
    avatarUrl: json['avatarUrl'] as String?,
    tierId: json['tierId']! as String,
    settings: JsonMap.from(json['settings']! as Map),
  );

  final String id;
  final String email;
  final String username;
  final String displayName;
  final String bio;
  final String? avatarUrl;
  final String tierId;
  final JsonMap settings;

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
  });

  factory BillingPlan.fromJson(JsonMap json) => BillingPlan(
    id: json['id']! as String,
    tierId: json['tierId']! as String,
    name: json['name']! as String,
    interval: json['interval']! as String,
    priceMinor: json['priceMinor']! as int,
    currency: json['currency']! as String,
    provider: json['provider']! as String,
  );

  final String id;
  final String tierId;
  final String name;
  final String interval;
  final int priceMinor;
  final String currency;
  final String provider;
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
  });
  factory NotificationView.fromJson(JsonMap json) => NotificationView(
    id: json['id']! as String,
    title: json['title']! as String,
    body: json['body']! as String,
    read: json['readAt'] != null,
  );
  final String id;
  final String title;
  final String body;
  final bool read;
}

final class OrderView {
  const OrderView({
    required this.id,
    required this.planId,
    required this.status,
    required this.amountMinor,
    required this.currency,
  });
  factory OrderView.fromJson(JsonMap json) => OrderView(
    id: json['id']! as String,
    planId: json['planId']! as String,
    status: json['status']! as String,
    amountMinor: json['amountMinor']! as int,
    currency: json['currency']! as String,
  );
  final String id;
  final String planId;
  final String status;
  final int amountMinor;
  final String currency;
}

final class LegalDocument {
  const LegalDocument({
    required this.title,
    required this.revision,
    required this.content,
  });
  factory LegalDocument.fromJson(JsonMap json) => LegalDocument(
    title: json['title']! as String,
    revision: json['revision']! as String,
    content: json['content']! as String,
  );
  final String title;
  final String revision;
  final String content;
}

final class UsageSummary {
  const UsageSummary({
    required this.sessions,
    required this.screenViews,
    required this.activeMinutes,
    required this.screens,
  });

  factory UsageSummary.fromJson(JsonMap json) => UsageSummary(
    sessions: json['sessions']! as int,
    screenViews: json['screenViews']! as int,
    activeMinutes: json['activeMinutes']! as int,
    screens: (json['screens']! as List)
        .map((value) => UsageScreen.fromJson(JsonMap.from(value as Map)))
        .toList(growable: false),
  );

  final int sessions;
  final int screenViews;
  final int activeMinutes;
  final List<UsageScreen> screens;
}

final class UsageScreen {
  const UsageScreen({
    required this.screenId,
    required this.views,
    required this.durationMs,
  });
  factory UsageScreen.fromJson(JsonMap json) => UsageScreen(
    screenId: json['screenId']! as String,
    views: json['views']! as int,
    durationMs: json['durationMs']! as int,
  );
  final String screenId;
  final int views;
  final int durationMs;
}

final class CouponView {
  const CouponView({
    required this.id,
    required this.code,
    required this.title,
    required this.discountLabel,
    required this.expiresAt,
    required this.usedAt,
  });
  factory CouponView.fromJson(JsonMap json) => CouponView(
    id: json['id']! as String,
    code: json['code']! as String,
    title: json['title']! as String,
    discountLabel: json['discountLabel']! as String,
    expiresAt: json['expiresAt'] as String?,
    usedAt: json['usedAt'] as String?,
  );
  final String id;
  final String code;
  final String title;
  final String discountLabel;
  final String? expiresAt;
  final String? usedAt;
}

final class ReferralView {
  const ReferralView({
    required this.code,
    required this.invited,
    required this.shareUrl,
  });
  factory ReferralView.fromJson(JsonMap json) => ReferralView(
    code: json['code']! as String,
    invited: json['invited']! as int,
    shareUrl: json['shareUrl']! as String,
  );
  final String code;
  final int invited;
  final String shareUrl;
}
