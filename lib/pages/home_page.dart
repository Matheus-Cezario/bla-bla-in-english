import 'package:bla_bla_in_english/components/flash_card.dart';
import 'package:bla_bla_in_english/components/floating_action_bar.dart';
import 'package:bla_bla_in_english/providers/cards_state_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  static final offset1 = Tween<Offset>(begin: Offset(-2, 0), end: Offset(0, 0));

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final width = screenWidth * 0.75;
    final height = MediaQuery.of(context).size.height * 0.55;

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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 68),
          child: AnimatedSwitcher(
            duration: Duration(seconds: 1),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return SlideTransition(
                position: offset1.animate(animation),
                child: child,
              );
            },
            child: FlashCard(
              key: ValueKey(cartsState.selectedCardInfo.id),
              isTop: true,
              height: height,
              width: width,
              cardInfos: cartsState.selectedCardInfo,
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionBar(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
