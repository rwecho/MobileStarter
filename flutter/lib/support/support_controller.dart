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
    try {
      final results = await Future.wait([
        _repository.help(),
        _repository.tickets(),
      ]);
      final articles = results[0] as List<HelpArticle>;
      final items = results[1] as List<SupportTicket>;
      help = articles.isEmpty ? const Empty() : Success(articles);
      tickets = items.isEmpty ? const Empty() : Success(items);
    } catch (error) {
      help = Failure(error.toString());
      tickets = Failure(error.toString());
    }
    notifyListeners();
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
    } catch (error) {
      detail = Failure(error.toString());
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
  }) => _run(
    () => _repository.feedback(
      category: category,
      title: title,
      body: body,
      rating: rating,
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
    } catch (error) {
      lastError = error.toString();
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
