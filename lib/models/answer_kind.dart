/// Which of the three meaning options the user picked.
///
/// The three options offered for every sentence are always one of each kind,
/// so the chosen kind is what classifies the answer.
enum AnswerKind {
  /// The right meaning of the word in that sentence.
  correct(0),

  /// Plausible but not right: a neighbouring sense, or the right idea with the
  /// wrong nuance. Counts as a partial hit.
  near(1),

  /// Unrelated meaning.
  wrong(2);

  const AnswerKind(this.id);

  final int id;

  static AnswerKind fromId(int id) =>
      AnswerKind.values.firstWhere((kind) => kind.id == id);
}
