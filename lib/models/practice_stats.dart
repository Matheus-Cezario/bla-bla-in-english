import 'package:bla_bla_in_english/models/answer_kind.dart';
import 'package:bla_bla_in_english/models/word_status.dart';

/// How many answers landed on one calendar day.
class DailyCount {
  const DailyCount({required this.day, required this.count});

  /// Local, date only — midnight of the day being counted.
  final DateTime day;
  final int count;
}

/// Everything the statistics screen shows, read in one pass so the numbers on
/// screen all describe the same moment.
class PracticeStats {
  const PracticeStats({
    required this.dictionaryWords,
    required this.wordsByStatus,
    required this.answersByKind,
    required this.daysPractised,
    required this.currentStreak,
    required this.bestStreak,
    required this.recentDays,
  });

  /// How many words the dictionary holds, practised or not.
  final int dictionaryWords;

  /// Where each word stands now. Complete over [WordStatus], `fresh` being the
  /// words never answered.
  final Map<WordStatus, int> wordsByStatus;

  /// The whole answer history, by kind. Complete over [AnswerKind].
  final Map<AnswerKind, int> answersByKind;

  final int daysPractised;
  final int currentStreak;
  final int bestStreak;

  /// The activity chart's window: oldest first, one entry per day, including
  /// the days with nothing on them.
  final List<DailyCount> recentDays;

  int countOfStatus(WordStatus status) => wordsByStatus[status] ?? 0;

  int countOfKind(AnswerKind kind) => answersByKind[kind] ?? 0;

  /// Words the user has answered at least once.
  int get practisedWords => dictionaryWords - countOfStatus(WordStatus.fresh);

  int get totalAnswers =>
      answersByKind.values.fold(0, (sum, count) => sum + count);

  int get answersToday => recentDays.isEmpty ? 0 : recentDays.last.count;

  /// Share of answers that hit the right meaning. Near misses deliberately do
  /// not count: the number should mean "I knew it", not "I was in the area".
  double get accuracy =>
      totalAnswers == 0 ? 0 : countOfKind(AnswerKind.correct) / totalAnswers;

  /// False on a fresh install, where every panel would be a row of zeroes.
  bool get hasHistory => totalAnswers > 0;
}
