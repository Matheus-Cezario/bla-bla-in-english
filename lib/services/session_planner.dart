import 'package:bla_bla_in_english/models/word_status.dart';

/// A word eligible for today's session, already resolved to the sentence it
/// would show.
class WordCandidate {
  const WordCandidate({
    required this.wordId,
    required this.word,
    required this.status,
    required this.sentenceId,
  });

  final int wordId;
  final String word;
  final WordStatus status;
  final int sentenceId;
}

/// Chooses which words make up a day's session.
///
/// The rule has two halves that pull against each other: words the user got
/// wrong are the most urgent, but the session should still contain all four
/// kinds of word so a day is never only drilling failures. So the planner
/// reserves a small quota for every bucket that has candidates, then fills
/// whatever is left strictly by priority.
///
/// With 20 words/day, plenty of wrong words and at least one of everything
/// else, that yields 17 wrong + 1 near + 1 fresh + 1 learned.
class SessionPlanner {
  const SessionPlanner({this.reservedPerBucket = 1});

  /// How many slots each non-empty bucket is guaranteed before priority takes
  /// over. Raise it to make sessions more balanced and less remedial.
  final int reservedPerBucket;

  /// Buckets in descending urgency. [WordStatus] declares its values in this
  /// order deliberately.
  static const List<WordStatus> _priority = WordStatus.values;

  /// Returns at most [targetWords] candidates.
  ///
  /// [byStatus] must already be ordered within each bucket by how much the word
  /// deserves to come back first — see `SessionRepository.candidatesFor`.
  /// Returns fewer than [targetWords] only when the dictionary genuinely runs
  /// out of eligible words.
  List<WordCandidate> plan({
    required Map<WordStatus, List<WordCandidate>> byStatus,
    required int targetWords,
  }) {
    if (targetWords <= 0) return const [];

    // How far into each bucket we have already drawn.
    final taken = {for (final status in _priority) status: 0};
    final picked = <WordCandidate>[];

    void drawFrom(WordStatus status, int count) {
      final bucket = byStatus[status] ?? const [];
      for (var i = 0; i < count; i++) {
        if (picked.length >= targetWords) return;
        final cursor = taken[status]!;
        if (cursor >= bucket.length) return;
        picked.add(bucket[cursor]);
        taken[status] = cursor + 1;
      }
    }

    // Pass 1 — guarantee representation. Runs in priority order so that when
    // targetWords is smaller than the number of non-empty buckets, the urgent
    // ones still win.
    for (final status in _priority) {
      drawFrom(status, reservedPerBucket);
    }

    // Pass 2 — fill the rest by strict priority.
    for (final status in _priority) {
      if (picked.length >= targetWords) break;
      drawFrom(status, targetWords - picked.length);
    }

    return picked;
  }
}
