import 'package:bla_bla_in_english/constants.dart';
import 'package:bla_bla_in_english/models/answer_kind.dart';
import 'package:bla_bla_in_english/models/meaning_option.dart';

/// One question in a day's session: a sentence, the word being practised, and
/// the three meanings to choose from.
class PracticeItem {
  PracticeItem({
    required this.sessionItemId,
    required this.wordId,
    required this.word,
    required this.sentenceId,
    required this.sentenceText,
    required this.options,
    this.answeredKind,
  });

  final int sessionItemId;
  final int wordId;
  final String word;
  final int sentenceId;

  /// The sentence with the target word wrapped in [sentenceDivider], e.g.
  /// `The #book# is on the table.`
  final String sentenceText;

  /// The three options, already shuffled for display.
  final List<MeaningOption> options;

  /// Null while the item is still unanswered.
  AnswerKind? answeredKind;

  bool get isAnswered => answeredKind != null;

  MeaningOption get correctOption =>
      options.firstWhere((option) => option.kind == AnswerKind.correct);

  /// The sentence split into plain runs and the highlighted word, so the UI can
  /// style the target word without re-parsing the divider syntax.
  List<SentencePart> get parts {
    final chunks = sentenceText.split(sentenceDivider);
    return [
      for (var i = 0; i < chunks.length; i++)
        if (chunks[i].isNotEmpty)
          SentencePart(text: chunks[i], isTarget: i.isOdd),
    ];
  }
}

class SentencePart {
  const SentencePart({required this.text, required this.isTarget});

  final String text;
  final bool isTarget;
}
