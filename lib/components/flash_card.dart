import 'dart:ui';
import 'package:bla_bla_in_english/animated/flip_card_animated.dart';
import 'package:bla_bla_in_english/animated/flip_card_animated_controller.dart';
import 'package:bla_bla_in_english/constants.dart';
import 'package:bla_bla_in_english/models/card_infos.dart';
import 'package:bla_bla_in_english/providers/cards_state_provider.dart';
import 'package:flutter/material.dart';
import 'package:bla_bla_in_english/components/conditional_parent_widget.dart';
import 'package:provider/provider.dart';

class FlashCard extends StatefulWidget {
  final bool isTop;
  final double height;
  final double width;
  final CardInfos cardInfos;

  FlashCard(
      {super.key,
      required this.isTop,
      required this.height,
      required this.width,
      required this.cardInfos});

  @override
  State<FlashCard> createState() => _FlashCardState();
}

class _FlashCardState extends State<FlashCard> with TickerProviderStateMixin {
  late FlipCardController _controller;
  late CardsStateProvider cardsStateProvider;

  @override
  void initState() {
    super.initState();
    _controller = FlipCardController();

    if (widget.isTop) {
      Provider.of<CardsStateProvider>(context, listen: false)
          .addListener(listernerCardState);
    }
  }

  @override
  void didChangeDependencies() {
    cardsStateProvider =
        Provider.of<CardsStateProvider>(context, listen: false);
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    cardsStateProvider.removeListener(listernerCardState);
    super.dispose();
  }

  void listernerCardState() {
    final isAnimating = _controller.controller?.isAnimating ?? false;
    print(isAnimating);
    if (isAnimating) return;
    final cartsState = Provider.of<CardsStateProvider>(context, listen: false);

    if (cartsState.isFliped) {
      _controller.toggleCard();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartsState =
        Provider.of<CardsStateProvider>(context, listen: widget.isTop);
    // final showingFront = !(_controller.state?.isFront ?? true);

    // if (cartsState.isFliped && !showingFront) {
    //   _controller.toggleCard();
    // }

    return FlipCard(
      flipOnTouch: false,
      controller: _controller,
      fill: Fill
          .fillBack, // Fill the back side of the card to make in the same size as the front.
      side: CardSide.BACK,
      back: BackCard(
        height: widget.height,
        width: widget.width,
        isTop: widget.isTop,
      ),
      front: FrontCard(
        height: widget.height,
        width: widget.width,
        cardInfos: widget.cardInfos,
        showResolution: widget.isTop && cartsState.isReveled,
      ),
      // onTapFlipping: isTop,
      // controller: _controller,
      // rotateSide: RotateSide.bottom,
      // disableSplashEffect: true,
      // frontSideUp: cartsState.isFliped,
    );
  }
}

class FrontCard extends StatelessWidget {
  final double height;
  final double width;
  final CardInfos cardInfos;
  final bool showResolution;
  const FrontCard({
    super.key,
    required this.height,
    required this.width,
    required this.cardInfos,
    required this.showResolution,
  });

  Widget _buildSentence(
      BuildContext context, List<String> sentenceInParts, String mainWord,
      {bool hasBlur = false}) {
    final bodyLargeTheme = Theme.of(context).textTheme.bodyLarge;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Center(
          child: ConditionalParentWidget(
            wrapInParent: hasBlur,
            buildParent: (child) => ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: child,
            ),
            child: RichText(
              text: TextSpan(
                // Note: Styles for TextSpans must be explicitly defined.
                // Child text spans will inherit styles from parent
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
          // mainAxisAlignment: MainAxisAlignment.spaceAround,
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
            ),
          ],
        ),
      ),
    );
  }
}

class BackCard extends StatelessWidget {
  final double height;
  final double width;
  final bool isTop;
  const BackCard({
    super.key,
    required this.height,
    required this.width,
    required this.isTop,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isTop ? 13 : 5,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          image: DecorationImage(
              image: AssetImage('assets/image/large-triangles.png'),
              repeat: ImageRepeat.repeat,
              colorFilter: ColorFilter.mode(
                  Theme.of(context).colorScheme.onPrimaryFixed,
                  BlendMode.color)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.black, width: 2),
        ),
        child: Center(
          child: Text(
            'Blá Blá in English',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 80,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
