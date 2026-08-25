import 'package:bla_bla_in_english/data/schema.dart';
import 'package:bla_bla_in_english/models/answer_kind.dart';
import 'package:bla_bla_in_english/models/practice_stats.dart';
import 'package:bla_bla_in_english/models/word_status.dart';
import 'package:bla_bla_in_english/repositories/session_repository.dart';
import 'package:sqflite/sqflite.dart';

/// Reads the progress database for the statistics screen.
///
/// Everything here is read-only and derived: `answers` is the full history and
/// `word_progress` the current state, so no counter has to be maintained by
/// hand and the numbers cannot drift out of step with the answers behind them.
class StatsRepository {
  const StatsRepository(this._db);

  final Database _db;

  /// How many days the activity chart covers.
  static const int recentDayCount = 14;

  Future<PracticeStats> load() async {
    final dictionaryWords = Sqflite.firstIntValue(
          await _db.rawQuery('SELECT COUNT(*) FROM $dictionaryAlias.words'),
        ) ??
        0;

    final statusRows = await _db.rawQuery(
      'SELECT status, COUNT(*) AS n FROM word_progress GROUP BY status',
    );
    final kindRows = await _db.rawQuery(
      'SELECT kind, COUNT(*) AS n FROM answers GROUP BY kind',
    );

    // SQLite gets the day, not Dart: bucketing has to agree with `dayKey`, and
    // 'localtime' is what makes a 23:50 answer count for the day the user was
    // actually living rather than for UTC's.
    final dayRows = await _db.rawQuery(
      "SELECT date(answered_at / 1000, 'unixepoch', 'localtime') AS day, "
      'COUNT(*) AS n FROM answers GROUP BY day ORDER BY day',
    );

    final wordsByStatus = {for (final status in WordStatus.values) status: 0};
    var practised = 0;
    for (final row in statusRows) {
      final count = row['n']! as int;
      practised += count;
      wordsByStatus[WordStatus.fromId(row['status']! as int)] = count;
    }
    // A swapped dictionary can leave progress for words that no longer exist,
    // so clamp rather than reporting a negative pile of untouched words.
    wordsByStatus[WordStatus.fresh] =
        (dictionaryWords - practised).clamp(0, dictionaryWords);

    final answersByKind = {for (final kind in AnswerKind.values) kind: 0};
    for (final row in kindRows) {
      answersByKind[AnswerKind.fromId(row['kind']! as int)] = row['n']! as int;
    }

    final countsByDay = {
      for (final row in dayRows) row['day']! as String: row['n']! as int,
    };

    return PracticeStats(
      dictionaryWords: dictionaryWords,
      wordsByStatus: wordsByStatus,
      answersByKind: answersByKind,
      daysPractised: countsByDay.length,
      currentStreak: _currentStreak(countsByDay.keys.toSet()),
      bestStreak: _bestStreak(countsByDay.keys.toList()),
      recentDays: _recentDays(countsByDay),
    );
  }

  /// Midnight today, local. Built from calendar fields rather than by
  /// subtracting durations, so the walk backwards cannot be knocked off by a
  /// daylight-saving day that is 23 or 25 hours long.
  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime _dayBefore(DateTime day) =>
      DateTime(day.year, day.month, day.day - 1);

  /// Days in a row up to now.
  ///
  /// An empty today does not break the streak — only a whole day gone by with
  /// nothing answered does. Otherwise the number would read 0 every morning
  /// until the first answer, which is exactly when it is most discouraging.
  static int _currentStreak(Set<String> days) {
    var cursor = _today();
    if (!days.contains(SessionRepository.dayKey(cursor))) {
      cursor = _dayBefore(cursor);
      if (!days.contains(SessionRepository.dayKey(cursor))) return 0;
    }

    var streak = 0;
    while (days.contains(SessionRepository.dayKey(cursor))) {
      streak++;
      cursor = _dayBefore(cursor);
    }
    return streak;
  }

  /// The longest run of consecutive days in the whole history.
  static int _bestStreak(List<String> sortedDays) {
    var best = 0;
    var run = 0;
    DateTime? previous;

    for (final key in sortedDays) {
      final day = DateTime.parse(key);
      run = previous != null && day == _dayAfter(previous) ? run + 1 : 1;
      if (run > best) best = run;
      previous = day;
    }
    return best;
  }

  static DateTime _dayAfter(DateTime day) =>
      DateTime(day.year, day.month, day.day + 1);

  /// The chart window, ending today, with the quiet days filled in as zeroes so
  /// a gap reads as "nothing here" instead of collapsing the timeline.
  static List<DailyCount> _recentDays(Map<String, int> countsByDay) {
    final today = _today();
    return [
      for (var back = recentDayCount - 1; back >= 0; back--)
        () {
          final day = DateTime(today.year, today.month, today.day - back);
          return DailyCount(
            day: day,
            count: countsByDay[SessionRepository.dayKey(day)] ?? 0,
          );
        }(),
    ];
  }
}
