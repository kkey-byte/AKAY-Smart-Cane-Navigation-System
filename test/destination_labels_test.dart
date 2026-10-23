import 'package:app_mobile/models/route_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('POI title and short locality preserve original routing data', () {
    const place = MapPlace(
      id: 'school',
      name: 'Panabo National High School',
      address:
          'Panabo National High School, Brgy. San Francisco, Panabo City, Davao del Norte, Davao Region, 8105, Philippines',
      latitude: 7.3,
      longitude: 125.6,
    );
    expect(place.displayName, 'Panabo National High School');
    expect(place.shortAddress, 'Brgy. San Francisco, Panabo City');
    expect(place.address, contains('8105'));
    expect(place.latLng.latitude, 7.3);
    expect(place.latLng.longitude, 125.6);
  });
  test('keeps a short address and coordinate fallback', () {
    const place = MapPlace(
      id: 'mall',
      name: 'Mall',
      address: 'J.P. Laurel Avenue, Panabo City',
      latitude: 7.3,
      longitude: 125.6,
    );
    expect(place.shortAddress, place.address);
    expect(
      place.copyWith(address: '7.30000, 125.60000').shortAddress,
      '7.30000, 125.60000',
    );
    expect(place.copyWith(address: '').shortAddress, '');
  });
  test('does not duplicate POI or show region country and postcode', () {
    const place = MapPlace(
      id: 'hospital',
      name: 'Hospital',
      address: 'Hospital, New Visayas, Panabo, Davao Region, 8105, Philippines',
      latitude: 7.3,
      longitude: 125.6,
    );
    expect(place.shortAddress, 'New Visayas, Panabo');
  });
}
