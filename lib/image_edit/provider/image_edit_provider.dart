import 'dart:typed_data';
import 'package:flutter/cupertino.dart';

class ImageEditProvider extends ChangeNotifier {
  final List<Uint8List> _history = [];
  int _currentIndex = -1;
  int get currentIndex => _currentIndex;
  Uint8List? get currentState =>
      _currentIndex >= 0 && _currentIndex < _history.length
          ? _history[_currentIndex]
          : null;

  void startSession(Uint8List imageData) {
    _history.clear();
    _currentIndex = -1;
    if (imageData.isNotEmpty) {
      _history.add(imageData);
      _currentIndex = 0;
    }
    notifyListeners();
  }

  void addState(Uint8List imageData) {
    if (imageData.isEmpty) return;
    if (_currentIndex < _history.length - 1) {
      _history.removeRange(_currentIndex + 1, _history.length);
    }
    _history.add(imageData);
    _currentIndex = _history.length - 1;
    notifyListeners();
  }

  void undo() {
    if (canUndo) {
      _currentIndex--;
      notifyListeners();
    }
  }

  void clearState() {
    _history.clear();
    _currentIndex = -1;
    notifyListeners();
  }

  bool get canUndo => _currentIndex > 0 && currentState != null;
}
