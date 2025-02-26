import 'package:bla_bla_in_english/components/floating_action_bar.dart';
import 'package:bla_bla_in_english/providers/carts_state_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final cartsState = Provider.of<CartsStateProvider>(context, listen: false);
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
        child: TextButton(
          onPressed: () {
            cartsState.toNextStep();
          },
          child: Text('Next cart stage'),
        ),
      ),
      floatingActionButton: FloatingActionBar(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
