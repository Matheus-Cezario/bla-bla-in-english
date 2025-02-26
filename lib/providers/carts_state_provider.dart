import 'package:flutter/material.dart';

enum CartStep {
  unFliped,
  fliped,
  reveled,
}

class CartsStateProvider with ChangeNotifier {
  CartStep _selectedCartStep = CartStep.unFliped;

  bool get isUnFliped => _selectedCartStep == CartStep.unFliped;
  bool get isFliped => _selectedCartStep == CartStep.fliped;
  bool get isReveled => _selectedCartStep == CartStep.reveled;

  void toNextStep() {
    switch (_selectedCartStep) {
      case CartStep.unFliped:
        _selectedCartStep = CartStep.fliped;
        break;
      case CartStep.fliped:
        _selectedCartStep = CartStep.reveled;
        break;
      case CartStep.reveled:
        _selectedCartStep = CartStep.unFliped;
        break;
    }
    notifyListeners();
  }
}
