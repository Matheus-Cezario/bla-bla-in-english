import 'dart:math';

import 'package:bla_bla_in_english/models/card_infos.dart';
import 'package:bla_bla_in_english/models/requested_word.dart';
import 'package:flutter/material.dart';

class CardsStateProvider with ChangeNotifier {
  late List<CardInfos> _cardInfoList;

  CardsStateProvider() {
    _cardInfoList = _getCardInfoList();
  }

  int get totalOfCards => _cardInfoList.length;

  CardInfos getCardInfo(int index) => _cardInfoList[index];

  List<CardInfos> _getCardInfoList([int total = 0]) {
    List<CardInfos> cardInfoList = [];
    for (int index = 0; index < total; index++) {
      final id = (Random().nextDouble() * 1000).toStringAsFixed(0);
      cardInfoList.add(CardInfos(
          id: id,
          englishSentence: 'The #book# is on the table. $index',
          englishWord: 'book',
          translateSentence: 'O #livro# está na mesa. $index',
          translateWord: 'livro',
          color: getRandomColor()));
    }
    return cardInfoList;
  }

  void addCards(List<RequestedWord> words) {
    _cardInfoList = words
        .map((word) => CardInfos(
            id: word.id,
            englishSentence: 'The #${word.englishWord}# is on the table.',
            englishWord: 'book',
            translateSentence: 'O #${word.englishWord}# está na mesa.',
            translateWord: 'livro',
            color: getRandomColor()))
        .toList();
    notifyListeners();
  }

  // bool get isUnFliped => _selectedCardInfo.cardStep == CardStep.unFliped;
  // bool get isFliped => _selectedCardInfo.cardStep == CardStep.fliped;
  // bool get isReveled => _selectedCardInfo.cardStep == CardStep.reveled;

  void toNextStep() {
    // switch (_selectedCardInfo.cardStep) {
    //   case CardStep.unFliped:
    //     _selectedCardInfo.cardStep = CardStep.fliped;
    //     break;
    //   case CardStep.fliped:
    //     _selectedCardInfo.cardStep = CardStep.reveled;
    //     break;
    //   case CardStep.reveled:
    //     _selectedCardInfo = _getNextCardInfo();
    //     break;
    // }
    // notifyListeners();
  }
}

Color getRandomColor() {
  const colors = [
    Color(0xFFA5D8FF),
    Color(0xFFB2F2BB),
    Color(0xFFFFEC99),
    Color(0xFFFFC9C9),
  ];
  final random = Random();
  return colors[random.nextInt(colors.length)];
}
