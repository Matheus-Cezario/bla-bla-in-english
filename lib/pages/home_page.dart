import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Blá Blá in English'),
        centerTitle: true,
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Card(
          child: Container(
            height: 60,
            width: double.infinity,
            child: Text('Teste'),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
