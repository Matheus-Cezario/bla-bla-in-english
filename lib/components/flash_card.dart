import 'dart:ui';
import 'package:bla_bla_in_english/constants.dart';
import 'package:bla_bla_in_english/models/card_infos.dart';
import 'package:flutter/material.dart';
import 'package:bla_bla_in_english/components/conditional_parent_widget.dart';

class FlashCard extends StatefulWidget {
  final CardInfos cardInfos;
  final void Function() onShowResolution;

  const FlashCard(
      {super.key, required this.cardInfos, required this.onShowResolution});

  @override
  State<FlashCard> createState() => _FlashCardState();
}

class _FlashCardState extends State<FlashCard> with TickerProviderStateMixin {
  bool showResolution = false;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final width = screenWidth * 0.75;
    final height = MediaQuery.of(context).size.height * 0.55;
    return FrontCard(
      height: height,
      width: width,
      cardInfos: widget.cardInfos,
      showResolution: showResolution,
      onShowResolution: () => setState(() {
        showResolution = true;
        widget.onShowResolution();
      }),
    );
  }
}

class FrontCard extends StatelessWidget {
  final double height;
  final double width;
  final CardInfos cardInfos;
  final bool showResolution;
  final void Function() onShowResolution;
  const FrontCard({
    super.key,
    required this.height,
    required this.width,
    required this.cardInfos,
    required this.showResolution,
    required this.onShowResolution,
  });

  Widget _buildSentence(
      BuildContext context, List<String> sentenceInParts, String mainWord,
      {bool hasBlur = false, void Function()? onTap}) {
    final bodyLargeTheme = Theme.of(context).textTheme.bodyLarge;
    final bodyMediumTheme = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.bold,
        );
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Center(
          child: ConditionalParentWidget(
            wrapInParent: hasBlur,
            buildParent: (child) => Stack(
              alignment: Alignment.center,
              children: [
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: child,
                ),
                TextButton(
                  onPressed: onTap,
                  child: Text(
                    'Clique para mostrar a tradução',
                    textAlign: TextAlign.center,
                    style: bodyMediumTheme,
                  ),
                )
              ],
            ),
            child: RichText(
              text: TextSpan(
                style: bodyLargeTheme,
                children: sentenceInParts.map((sentencePart) {
                  return TextSpan(
                    text: sentencePart,
                    style: sentencePart.toLowerCase().trim() == mainWord
                        ? TextStyle(fontWeight: FontWeight.bold)
                        : null,
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bodyMediumTheme = Theme.of(context).textTheme.bodyMedium;
    return Card(
      elevation: 9,
      color: Theme.of(context).colorScheme.onPrimaryFixed,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(
                top: 16,
              ),
              child: Text(
                'The main word is: ${cardInfos.englishWord}',
                style: bodyMediumTheme,
              ),
            ),
            _buildSentence(
              context,
              cardInfos.englishSentence.split(sentenceDivider),
              cardInfos.englishWord,
            ),
            Divider(),
            _buildSentence(
              context,
              cardInfos.translateSentence.split(sentenceDivider),
              cardInfos.translateWord,
              hasBlur: !showResolution,
              onTap: !showResolution ? onShowResolution : null,
            ),
          ],
        ),
      ),
    );
  }
}
