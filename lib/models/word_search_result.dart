import 'package:bla_bla_in_english/models/word_status.dart';

/// A dictionary word as the search screen shows it: the word itself, how the
/// user is doing with it, and whether today's session already has it.
class WordSearchResult {
  const WordSearchResult({
    required this.wordId,
    required this.word,
    required this.status,
    required this.inTodaySession,
  });

  final int wordId;
  final String word;
  final WordStatus status;

  /// True when today's session already contains the word, so adding it again
  /// would only queue the same word twice.
  final bool inTodaySession;
}
