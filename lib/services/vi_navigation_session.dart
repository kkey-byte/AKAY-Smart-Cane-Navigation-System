import 'package:flutter/foundation.dart';

/// Shared navigation state between VI home dashboard and track tab.
class ViNavigationSession extends ChangeNotifier {
  ViNavigationSession._();

  static final ViNavigationSession instance = ViNavigationSession._();

  bool _isNavigating = false;

  bool get isNavigating => _isNavigating;

  void setNavigating(bool value) {
    if (_isNavigating == value) return;
    _isNavigating = value;
    notifyListeners();
  }
}
