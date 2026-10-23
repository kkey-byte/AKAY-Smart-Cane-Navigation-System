import 'package:flutter/foundation.dart';

/// Shared navigation state between VI home dashboard and track tab.
class ViNavigationSession extends ChangeNotifier {
  ViNavigationSession._();

  static final ViNavigationSession instance = ViNavigationSession._();

  String? destination;
  String? estimatedTime;
  String? estimatedDistance;
  bool _isNavigating = false;

  bool get isNavigating => _isNavigating;

  void setNavigating(
    bool value, {
    String? destination,
    String? estimatedTime,
    String? estimatedDistance,
  }) {
    this.destination = value ? destination : null;
    this.estimatedTime = value ? estimatedTime : null;
    this.estimatedDistance = value ? estimatedDistance : null;
    _isNavigating = value;
    notifyListeners();
  }
}
