final class HelpArticle {
  const HelpArticle({
    required this.id,
    required this.title,
    required this.body,
  });

  factory HelpArticle.fromJson(Map<String, Object?> json) => HelpArticle(
    id: json['id']! as String,
    title: json['title']! as String,
    body: json['body']! as String,
  );

  final String id;
  final String title;
  final String body;
}

final class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.category,
    required this.severity,
    required this.subject,
    required this.status,
    required this.queueId,
    required this.updatedAt,
  });

  factory SupportTicket.fromJson(Map<String, Object?> json) => SupportTicket(
    id: json['id']! as String,
    category: json['category']! as String,
    severity: json['severity']! as String,
    subject: json['subject']! as String,
    status: json['status']! as String,
    queueId: json['queueId']! as String,
    updatedAt: json['updatedAt']! as String,
  );

  final String id;
  final String category;
  final String severity;
  final String subject;
  final String status;
  final String queueId;
  final String updatedAt;
}

final class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.authorType,
    required this.body,
    required this.createdAt,
  });

  factory SupportMessage.fromJson(Map<String, Object?> json) => SupportMessage(
    id: json['id']! as String,
    authorType: json['authorType']! as String,
    body: json['body']! as String,
    createdAt: json['createdAt']! as String,
  );

  final String id;
  final String authorType;
  final String body;
  final String createdAt;
}

final class SupportTicketDetail {
  const SupportTicketDetail({required this.ticket, required this.messages});

  factory SupportTicketDetail.fromJson(
    Map<String, Object?> json,
  ) => SupportTicketDetail(
    ticket: SupportTicket.fromJson(json),
    messages: (json['messages']! as List<Object?>)
        .map(
          (item) =>
              SupportMessage.fromJson(Map<String, Object?>.from(item! as Map)),
        )
        .toList(growable: false),
  );

  final SupportTicket ticket;
  final List<SupportMessage> messages;
}
