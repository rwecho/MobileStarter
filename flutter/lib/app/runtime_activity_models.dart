part of 'runtime_models.dart';

final class LegalDocument {
  const LegalDocument({
    required this.type,
    required this.title,
    required this.revision,
    required this.content,
  });
  factory LegalDocument.fromJson(JsonMap json) => LegalDocument(
    type: json['type']! as String,
    title: json['title']! as String,
    revision: json['revision']! as String,
    content: json['content']! as String,
  );
  final String type;
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
