import 'package:flutter/material.dart';

enum CardStep {
  unFliped,
  fliped,
  reveled,
}

class CardInfos {
  final String id;
  final String englishSentence;
  final String translateSentence;
  final String englishWord;
  final String translateWord;
  final Color color;
  CardStep cardStep = CardStep.unFliped;

  CardInfos(
      {required this.id,
      required this.englishSentence,
      required this.translateSentence,
      required this.englishWord,
      required this.translateWord,
      required this.color});

  CardInfos copy() {
    return CardInfos(
        id: id,
        englishSentence: englishSentence,
        translateSentence: translateSentence,
        englishWord: englishWord,
        translateWord: translateWord,
        color: color);
  }
}
