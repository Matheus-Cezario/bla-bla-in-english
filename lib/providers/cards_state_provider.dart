import 'dart:math';

import 'package:bla_bla_in_english/models/card_infos.dart';
import 'package:flutter/material.dart';

class CardsStateProvider with ChangeNotifier {
  late CardInfos _selectedCardInfo;

  CardsStateProvider() {
    _selectedCardInfo = _getNextCardInfo();
  }

  CardInfos get selectedCardInfo => _selectedCardInfo.copy();

  CardInfos _getNextCardInfo() {
    final id = (Random().nextDouble() * 1000).toStringAsFixed(0);
    return CardInfos(
      id: id,
      englishSentence: 'The #book# is on the table. $id',
      englishWord: 'book',
      translateSentence: 'O #livro# está na mesa. $id',
      translateWord: 'livro',
    );
  }

  bool get isUnFliped => _selectedCardInfo.cardStep == CardStep.unFliped;
  bool get isFliped => _selectedCardInfo.cardStep == CardStep.fliped;
  bool get isReveled => _selectedCardInfo.cardStep == CardStep.reveled;

  void toNextStep() {
    switch (_selectedCardInfo.cardStep) {
      case CardStep.unFliped:
        _selectedCardInfo.cardStep = CardStep.fliped;
        break;
      case CardStep.fliped:
        _selectedCardInfo.cardStep = CardStep.reveled;
        break;
      case CardStep.reveled:
        _selectedCardInfo = _getNextCardInfo();
        break;
    }
    notifyListeners();
  }
}
