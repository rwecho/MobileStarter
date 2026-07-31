import 'package:flutter/foundation.dart';
import '../state/async_state.dart';
import 'support_models.dart';
import 'support_repository.dart';

final class SupportController extends ChangeNotifier {
  SupportController(this._repository);

  final SupportRepository _repository;
  AsyncState<List<HelpArticle>> help = const Idle();
  AsyncState<List<SupportTicket>> tickets = const Idle();
  AsyncState<SupportTicketDetail> detail = const Idle();
  bool busy = false;
  String? lastError;

  Future<void> loadHome() async {
    help = const Loading();
    tickets = const Loading();
    notifyListeners();
    await Future.wait([_loadHelp(), _loadTickets()]);
    notifyListeners();
  }

  Future<void> _loadHelp() async {
    try {
      final articles = await _repository.help();
      help = articles.isEmpty ? const Empty() : Success(articles);
    } catch (_) {
      help = const Failure('常见问题暂时无法加载，请稍后重试');
    }
  }

  Future<void> _loadTickets() async {
    try {
      final items = await _repository.tickets();
      tickets = items.isEmpty ? const Empty() : Success(items);
    } catch (_) {
      tickets = const Failure('工单暂时无法加载，请稍后重试');
    }
  }

  Future<bool> createTicket({
    required String category,
    required String severity,
    required String subject,
    required String message,
  }) async {
    return _run(() async {
      final ticket = await _repository.createTicket(
        category: category,
        severity: severity,
        subject: subject,
        message: message,
      );
      await openTicket(ticket.id);
    });
  }

  Future<void> openTicket(String id) async {
    detail = const Loading();
    notifyListeners();
    try {
      detail = Success(await _repository.ticket(id));
    } catch (_) {
      detail = const Failure('工单详情暂时无法加载，请稍后重试');
    }
    notifyListeners();
  }

  Future<bool> reply(String message) async {
    final current = detail;
    if (current is! Success<SupportTicketDetail>) return false;
    return _run(() async {
      final sent = await _repository.reply(current.data.ticket.id, message);
      detail = Success(
        SupportTicketDetail(
          ticket: current.data.ticket,
          messages: [...current.data.messages, sent],
        ),
      );
    });
  }

  Future<bool> submitFeedback({
    required String category,
    required String title,
    required String body,
    required int rating,
    required List<FeedbackScreenshot> screenshots,
  }) => _run(
    () => _repository.feedback(
      category: category,
      title: title,
      body: body,
      rating: rating,
      screenshots: screenshots,
    ),
  );

  Future<bool> _run(Future<void> Function() operation) async {
    if (busy) return false;
    busy = true;
    lastError = null;
    notifyListeners();
    try {
      await operation();
      return true;
    } catch (_) {
      lastError = '提交失败，请检查网络后重试';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
