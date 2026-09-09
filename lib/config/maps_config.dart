/// Google Maps configuration.
///
/// Add your key to `android/local.properties`:
/// `GOOGLE_MAPS_API_KEY=AIza...`
///
/// Or run with:
/// `flutter run --dart-define=GOOGLE_MAPS_API_KEY=AIza...`
class MapsConfig {
  MapsConfig._();

  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );

  static const String _placeholder = 'YOUR_GOOGLE_MAPS_API_KEY';

  static bool get hasGoogleMapsApiKey {
    if (googleMapsApiKey.isEmpty) return false;
    if (googleMapsApiKey == _placeholder) return false;
    return true;
  }

  /// Uses OpenStreetMap tiles when no Google key is configured.
  static bool get useOpenStreetMapFallback => !hasGoogleMapsApiKey;
}
