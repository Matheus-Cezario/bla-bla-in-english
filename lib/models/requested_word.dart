import 'dart:math';

class RequestedWord {
  late final String id;
  final String englishWord;

  RequestedWord({required this.englishWord}) {
    id = (Random().nextDouble() * 1000).toStringAsFixed(0);
  }
}
