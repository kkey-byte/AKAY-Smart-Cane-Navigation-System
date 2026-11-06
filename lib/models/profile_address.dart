/// Structured presentation of the existing single address field.
class ProfileAddress {
  const ProfileAddress({
    required this.region,
    required this.province,
    required this.city,
    required this.barangay,
    required this.postalCode,
    required this.street,
  });
  final String region, province, city, barangay, postalCode, street;
  String get area => [
    region,
    province,
    city,
    barangay,
  ].where((value) => value != 'Not applicable').join('\n');
  String serialize() =>
      'Region: $region\nProvince: $province\nCity/Municipality: $city\nBarangay: $barangay\nPostal Code: $postalCode\nStreet: $street';
  static ProfileAddress? tryParse(String value) {
    final labels = [
      'Region',
      'Province',
      'City/Municipality',
      'Barangay',
      'Postal Code',
      'Street',
    ];
    final parts = <String, String>{};
    var streetStarted = false;
    for (final line in value.split('\n')) {
      if (streetStarted) {
        parts['Street'] = '${parts['Street']}\n$line';
        continue;
      }
      final colon = line.indexOf(':');
      if (colon < 0) continue;
      parts[line.substring(0, colon)] = line.substring(colon + 1).trim();
      if (line.substring(0, colon) == 'Street') streetStarted = true;
    }
    if (!labels.every(parts.containsKey)) return null;
    return ProfileAddress(
      region: parts['Region']!,
      province: parts['Province']!,
      city: parts['City/Municipality']!,
      barangay: parts['Barangay']!,
      postalCode: parts['Postal Code']!,
      street: parts['Street']!,
    );
  }
}

class AddressPlace {
  const AddressPlace(this.code, this.name);
  final String code, name;
}
