import 'package:bla_bla_in_english/components/floating_action_bar.dart';
import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Blá Blá in English'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 15),
            child: Tooltip(
              message: 'Estamos carregando suas frases :)',
              triggerMode: TooltipTriggerMode.tap,
              child: CircularProgressIndicator(),
            ),
          )
        ],
      ),
      floatingActionButton: FloatingActionBar(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
