/// Custom Google Maps styling for GABAY track screens.
class GabayMapStyle {
  GabayMapStyle._();

  /// Light grayscale map — keeps navigation route and markers readable.
  static const String grayscale = '''
[
  {"elementType":"geometry","stylers":[{"color":"#f7f7f7"}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#f7f7f7"}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"color":"#e0e0e0"}]},
  {"featureType":"administrative.land_parcel","elementType":"labels.text.fill","stylers":[{"color":"#bdbdbd"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#eeeeee"}]},
  {"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#9e9e9e"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#e8e8e8"}]},
  {"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#9e9e9e"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
  {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#fafafa"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#f0f0f0"}]},
  {"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#616161"}]},
  {"featureType":"road.local","elementType":"labels.text.fill","stylers":[{"color":"#9e9e9e"}]},
  {"featureType":"transit.line","elementType":"geometry","stylers":[{"color":"#e5e5e5"}]},
  {"featureType":"transit.station","elementType":"geometry","stylers":[{"color":"#eeeeee"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#e3e3e3"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#9e9e9e"}]}
]
''';
}
