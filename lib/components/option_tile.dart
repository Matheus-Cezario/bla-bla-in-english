import 'package:bla_bla_in_english/constants.dart';
import 'package:bla_bla_in_english/models/answer_kind.dart';
import 'package:bla_bla_in_english/models/meaning_option.dart';
import 'package:flutter/material.dart';

/// One of the three meanings on offer.
///
/// Before an answer it is a plain tappable card. After one, every tile reveals
/// its own kind: the user needs to see not just that they were wrong, but which
/// meaning was right and how close their pick was.
class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.option,
    required this.chosenKind,
    required this.onTap,
  });

  final MeaningOption option;

  /// Null while the question is unanswered.
  final AnswerKind? chosenKind;

  final VoidCallback onTap;

  bool get _isAnswered => chosenKind != null;
  bool get _isChosen => chosenKind == option.kind;

  Color get _background {
    if (!_isAnswered) return optionColor;
    return switch (option.kind) {
      AnswerKind.correct => correctAnswerColor,
      AnswerKind.near => _isChosen ? nearAnswerColor : optionColor,
      AnswerKind.wrong => _isChosen ? wrongAnswerColor : optionColor,
    };
  }

  /// The right meaning is always outlined once revealed; the user's own pick is
  /// outlined too, so a near miss shows both at once.
  bool get _isOutlined =>
      _isAnswered && (_isChosen || option.kind == AnswerKind.correct);

  String? get _label {
    if (!_isAnswered) return null;
    if (option.kind == AnswerKind.correct) {
      return _isChosen ? 'Você acertou' : 'Esse era o certo';
    }
    if (!_isChosen) return null;
    return option.kind == AnswerKind.near ? 'Quase lá' : 'Não é esse';
  }

  @override
  Widget build(BuildContext context) {
    final label = _label;

    return Semantics(
      button: !_isAnswered,
      selected: _isChosen,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: _background,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            // Tapping a settled question must not re-answer it.
            onTap: _isAnswered ? null : onTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isOutlined ? Colors.black87 : optionBorderColor,
                  width: _isOutlined ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.text,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (label != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
