import 'package:bla_bla_in_english/constants.dart';
import 'package:bla_bla_in_english/models/practice_item.dart';
import 'package:flutter/material.dart';

/// Renders a practice sentence with the target word picked out.
///
/// The sentence arrives with the word wrapped in [sentenceDivider]; the split
/// happens in [PracticeItem.parts] so this widget only decides how it looks.
class SentenceText extends StatelessWidget {
  const SentenceText({super.key, required this.item});

  final PracticeItem item;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyLarge!.copyWith(
          fontSize: 26,
          height: 1.45,
        );

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: base,
        children: [
          for (final part in item.parts)
            TextSpan(
              text: part.text,
              style: part.isTarget
                  ? base.copyWith(
                      fontWeight: FontWeight.bold,
                      backgroundColor: tertiaryColor,
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}
