import 'package:bla_bla_in_english/models/answer_kind.dart';
import 'package:bla_bla_in_english/models/practice_item.dart';
import 'package:bla_bla_in_english/repositories/session_repository.dart';
import 'package:bla_bla_in_english/repositories/settings_repository.dart';
import 'package:flutter/foundation.dart';

enum SessionState { loading, ready, empty, failed }

/// Drives today's practice session: loads the plan, tracks where the user is in
/// it, and writes answers through to the database.
class SessionProvider with ChangeNotifier {
  SessionProvider({
    required SessionRepository sessions,
    required SettingsRepository settings,
  })  : _sessions = sessions,
        _settings = settings;

  final SessionRepository _sessions;
  final SettingsRepository _settings;

  SessionState _state = SessionState.loading;
  List<PracticeItem> _items = const [];
  int _index = 0;
  int _wordsPerDay = SettingsRepository.defaultWordsPerDay;
  Object? _error;

  SessionState get state => _state;
  List<PracticeItem> get items => _items;
  int get wordsPerDay => _wordsPerDay;
  Object? get error => _error;

  int get total => _items.length;
  int get answeredCount => _items.where((item) => item.isAnswered).length;
  bool get isFinished => _items.isNotEmpty && answeredCount == total;

  /// The item on screen, or null once the session is done.
  PracticeItem? get current =>
      _index >= 0 && _index < _items.length ? _items[_index] : null;

  int get currentNumber => _index + 1;

  int countOf(AnswerKind kind) =>
      _items.where((item) => item.answeredKind == kind).length;

  Future<void> load() async {
    await _replaceItems(
      (wordsPerDay) => _sessions.todaySession(wordsPerDay: wordsPerDay),
    );
  }

  /// Draws another day's worth of words into the session the user just
  /// finished, and returns how many were actually added: the dictionary can
  /// run out, and the UI has to say so instead of looking broken.
  Future<int> extendSession() => _replaceItems(
        (wordsPerDay) => _sessions.extendTodaySession(wordsPerDay: wordsPerDay),
      );

  /// Adds hand-picked words to today's session. Returns how many landed —
  /// words already queued today are skipped, so this can be less than asked.
  Future<int> addWords(List<int> wordIds) => _replaceItems(
        (wordsPerDay) => _sessions.addWordsToTodaySession(
          wordIds: wordIds,
          wordsPerDay: wordsPerDay,
        ),
      );

  /// Runs [fetch] against the current daily target and swaps in what it
  /// returns, resuming at the first unanswered item. Returns how many items the
  /// session gained.
  Future<int> _replaceItems(
    Future<List<PracticeItem>> Function(int wordsPerDay) fetch,
  ) async {
    final before = _items.length;

    _state = SessionState.loading;
    notifyListeners();

    try {
      _wordsPerDay = await _settings.wordsPerDay();
      _items = await fetch(_wordsPerDay);
      // Resume where the user stopped rather than at the top.
      final next = _items.indexWhere((item) => !item.isAnswered);
      _index = next == -1 ? _items.length : next;
      _state = _items.isEmpty ? SessionState.empty : SessionState.ready;
    } catch (error) {
      _error = error;
      _state = SessionState.failed;
      notifyListeners();
      return 0;
    }

    notifyListeners();
    return _items.length - before;
  }

  /// Records the user's choice for the item on screen. The UI shows feedback
  /// before calling [advance], so this does not move on by itself.
  Future<void> answer(AnswerKind kind) async {
    final item = current;
    if (item == null || item.isAnswered) return;

    await _sessions.recordAnswer(item: item, kind: kind);
    notifyListeners();
  }

  void advance() {
    if (_index < _items.length) {
      _index++;
      notifyListeners();
    }
  }

  /// Re-reads the settings and, if the daily target changed, nothing about
  /// today's already-planned session moves — the new target applies tomorrow.
  Future<void> refreshSettings() async {
    _wordsPerDay = await _settings.wordsPerDay();
    notifyListeners();
  }
}
