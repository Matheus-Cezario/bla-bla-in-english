import 'package:flutter/material.dart';

class AddCartsForm extends StatefulWidget {
  final void Function(int) onSubmit;
  final void Function() onCancel;
  const AddCartsForm(
      {super.key, required this.onSubmit, required this.onCancel});

  @override
  State<AddCartsForm> createState() => _AddCartsFormState();
}

class _AddCartsFormState extends State<AddCartsForm> {
  final _valueController = TextEditingController();
  final List<String> _cards = [];

  void submitForm() {
    final value = int.tryParse(_valueController.text) ?? 0;
    if (value <= 0) {
      return;
    }
    widget.onSubmit(value);
  }

  void addCard() {
    final value = _valueController.text;
    if (value.isEmpty) {
      return;
    }
    setState(() {
      _cards.add(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              children: [
                TextField(
                  controller: _valueController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText:
                        'Escreva a palavra que quer adicionar (em inglês)',
                    hintStyle: TextStyle(fontSize: 14),
                    floatingLabelBehavior: FloatingLabelBehavior.never,
                  ),
                  onSubmitted: (_) => submitForm(),
                  style: TextStyle(
                    color: Colors.black,
                  ),
                ),
                FilledButton(
                  onPressed: addCard,
                  child: Text('Adicionar'),
                ),
              ],
            ),
            SizedBox(
              height: 20,
            ),
            SizedBox.expand(
              child: ListView(
                children: _cards.map((e) => Text(e)).toList(),
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Color(0xFFFFC9C9),
                  ),
                  onPressed: widget.onCancel,
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
