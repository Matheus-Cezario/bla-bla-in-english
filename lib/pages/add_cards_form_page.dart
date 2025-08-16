import 'package:bla_bla_in_english/constants.dart';
import 'package:bla_bla_in_english/models/requested_word.dart';
import 'package:bla_bla_in_english/providers/cards_state_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AddCartsFormPage extends StatefulWidget {
  const AddCartsFormPage({super.key});

  @override
  State<AddCartsFormPage> createState() => _AddCartsFormPageState();
}

class _AddCartsFormPageState extends State<AddCartsFormPage> {
  final _valueController = TextEditingController();
  final List<RequestedWord> _cards = [];

  void submitForm() {
    final cartsState = Provider.of<CardsStateProvider>(context, listen: false);
    cartsState.addCards(_cards);
    Navigator.of(context).pop();
  }

  void addCard() {
    final value = _valueController.text;
    if (value.isEmpty) {
      return;
    }
    setState(() {
      _cards.add(RequestedWord(englishWord: value));
      _valueController.clear();
    });
  }

  void _deleteCard(String id) {
    setState(() {
      _cards.removeWhere((card) => card.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Blá Blá in English'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Flexible(
                    child: TextField(
                      controller: _valueController,
                      keyboardType: TextInputType.text,
                      decoration: InputDecoration(
                        hintText:
                            'Escreva a palavra que quer adicionar (em inglês)',
                        hintStyle: TextStyle(fontSize: 14),
                        floatingLabelBehavior: FloatingLabelBehavior.never,
                      ),
                      onSubmitted: (_) => addCard(),
                      style: TextStyle(
                        color: Colors.black,
                      ),
                    ),
                  ),
                  IconButton.filled(
                    onPressed: addCard,
                    icon: Icon(
                      Icons.check,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 20,
            ),
            Flexible(
              child: ListView.builder(
                itemCount: _cards.length,
                itemBuilder: (context, index) => ListTile(
                  key: ValueKey(_cards[index].id),
                  title: Text(_cards[index].englishWord),
                  trailing: IconButton(
                    onPressed: () {
                      _deleteCard(_cards[index].id);
                    },
                    icon: Icon(
                      Icons.delete,
                      color: wrongAnswerColor,
                    ),
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Color(0xFFFFC9C9),
                  ),
                  onPressed: () {},
                  child: Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: submitForm,
                  child: Text('Adicionar'),
                ),
              ],
            ),
            SizedBox(
              height: 20,
            ),
          ],
        ),
      ),
    );
  }
}
