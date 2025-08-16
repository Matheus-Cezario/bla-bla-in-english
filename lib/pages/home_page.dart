import 'package:bla_bla_in_english/components/add_carts_form.dart';
import 'package:bla_bla_in_english/components/flash_card.dart';
import 'package:bla_bla_in_english/constants.dart';
import 'package:bla_bla_in_english/models/card_infos.dart';
import 'package:bla_bla_in_english/providers/cards_state_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  CardSwiperController controller = CardSwiperController();
  bool canSwipe = false;
  CardSwiperDirection? lastSwipeDirection;

  @override
  Widget build(BuildContext context) {
    final cartsState = Provider.of<CardsStateProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Blá Blá in English'),
        centerTitle: true,
        // actions: [
        //   Padding(
        //     padding: const EdgeInsets.only(right: 15),
        //     child: Tooltip(
        //       message: 'Estamos carregando suas frases :)',
        //       triggerMode: TooltipTriggerMode.tap,
        //       child: CircularProgressIndicator(
        //         color: Theme.of(context).colorScheme.inverseSurface,
        //       ),
        //     ),
        //   )
        // ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 300,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Parabéns! Você finalizou todas as palavras que tinha para hoje!',
                  textAlign: TextAlign.center,
                ),
                SizedBox(
                  height: 20,
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed('add-cards');
                  },
                  child: Text(
                    'Quer adicionar mais palavras?',
                  ),
                ),
              ],
            ),
          ),
          if (cartsState.totalOfCards > 0)
            CardSwiper(
                isDisabled: !canSwipe,
                controller: controller,
                cardsCount: cartsState.totalOfCards,
                isLoop: false,
                onSwipe: (_, __, ___) {
                  setState(() {
                    canSwipe = false;
                  });
                  return true;
                },
                onSwipeDirectionChange:
                    (horizontalDirection, verticalDirection) {
                  setState(() {
                    lastSwipeDirection = horizontalDirection;
                  });
                },
                cardBuilder:
                    (context, index, percentThresholdX, percentThresholdY) {
                  CardInfos cardInfo = cartsState.getCardInfo(index);

                  return Center(
                    child: FlashCard(
                        key: ValueKey(cardInfo.id),
                        cardInfos: cardInfo,
                        onShowResolution: () {
                          setState(() {
                            canSwipe = true;
                          });
                        }),
                  );
                }),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  FeedBackTooltip(
                    opacity:
                        lastSwipeDirection == CardSwiperDirection.left ? 1 : 0,
                    color: wrongAnswerColor,
                    icon: Icons.heart_broken,
                    text: 'Errei :(',
                  ),
                  FeedBackTooltip(
                    opacity:
                        lastSwipeDirection == CardSwiperDirection.right ? 1 : 0,
                    color: correctAnswerColor,
                    icon: Icons.check_circle,
                    text: 'Acertei :)',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      // floatingActionButton: FloatingActionBar(),
      // floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

class FeedBackTooltip extends StatelessWidget {
  const FeedBackTooltip({
    super.key,
    required this.opacity,
    required this.color,
    required this.icon,
    required this.text,
  });

  final double opacity;
  final Color color;
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: opacity,
      duration: Duration(milliseconds: 300),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(25),
        ),
        height: 50,
        child: Row(
          spacing: 10,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 10,
            ),
            Icon(
              icon,
            ),
            Text(
              text,
            ),
            SizedBox(
              width: 10,
            ),
          ],
        ),
      ),
    );
  }
}
