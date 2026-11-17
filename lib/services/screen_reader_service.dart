import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Reflects the device screen reader rather than an app speech preference.
class ScreenReaderService extends ChangeNotifier with WidgetsBindingObserver {
  ScreenReaderService();
  static final instance = ScreenReaderService();
  static const channel = MethodChannel('akay/accessibility');
  bool _enabled = false;
  bool _observing = false;
  bool get enabled => _enabled;
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> initialize() async {
    if (!supported) return;
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    await refresh();
  }

  Future<void> refresh() async {
    if (!supported) return;
    try {
      final enabled = await channel.invokeMethod<bool>('isScreenReaderEnabled');
      if (enabled != null && enabled != _enabled) {
        _enabled = enabled;
        notifyListeners();
      }
    } on PlatformException {
      // Keep the last confirmed device state if the native query fails.
    } on MissingPluginException {
      // Other platforms do not provide the Android bridge.
    }
  }

  Future<void> openSettings() async {
    if (!supported) return;
    try {
      await channel.invokeMethod<void>('openAccessibilitySettings');
    } on PlatformException {
      // Do not display an enabled state when settings could not be opened.
    } on MissingPluginException {
      // The switch must continue to reflect only confirmed native state.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  @override
  void dispose() {
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
