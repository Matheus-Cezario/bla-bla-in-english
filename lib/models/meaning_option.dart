import 'package:bla_bla_in_english/models/answer_kind.dart';

/// One of the three meanings offered for a sentence.
class MeaningOption {
  const MeaningOption({
    required this.id,
    required this.text,
    required this.kind,
  });

  final int id;

  /// The English definition shown to the user.
  final String text;

  final AnswerKind kind;

  factory MeaningOption.fromRow(Map<String, Object?> row) => MeaningOption(
        id: row['id']! as int,
        text: row['text']! as String,
        kind: AnswerKind.fromId(row['kind']! as int),
      );
}
