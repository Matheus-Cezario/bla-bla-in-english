import 'package:bla_bla_in_english/models/answer_kind.dart';

/// The bucket a word currently sits in, which drives how urgently it comes
/// back. Ordered from most to least urgent — [SessionPlanner] relies on the
/// declaration order, so do not reorder without updating it.
enum WordStatus {
  /// Last answer was [AnswerKind.wrong].
  wrong(0),

  /// Last answer was [AnswerKind.near].
  near(1),

  /// Never answered.
  fresh(2),

  /// Last answer was [AnswerKind.correct].
  learned(3);

  const WordStatus(this.id);

  final int id;

  static WordStatus fromId(int id) =>
      WordStatus.values.firstWhere((status) => status.id == id);

  /// The status a word moves to after being answered with [kind].
  static WordStatus fromAnswer(AnswerKind kind) => switch (kind) {
        AnswerKind.correct => WordStatus.learned,
        AnswerKind.near => WordStatus.near,
        AnswerKind.wrong => WordStatus.wrong,
      };
}
