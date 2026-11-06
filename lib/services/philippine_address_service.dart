import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/profile_address.dart';

/// Read-only public geographic reference data; no profile data is sent here.
/// API reference: https://psgc.cloud/api-docs/v2
class PhilippineAddressService {
  PhilippineAddressService({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  final _cache = <String, List<AddressPlace>>{};
  Future<List<AddressPlace>> _fetch(String path) async {
    if (_cache.containsKey(path)) return _cache[path]!;
    final response = await _client
        .get(Uri.parse('https://psgc.cloud/api/v2/$path'))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw StateError('Address directory unavailable');
    }
    final decoded = jsonDecode(response.body);
    final rows = decoded is Map ? decoded['data'] : decoded;
    if (rows is! List) throw const FormatException('Invalid address directory');
    final result =
        rows
            .map(
              (row) =>
                  AddressPlace(row['code'] as String, row['name'] as String),
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    _cache[path] = result;
    return result;
  }

  Future<List<AddressPlace>> regions() => _fetch('regions');
  Future<List<AddressPlace>> provinces(String region) =>
      _fetch('regions/${Uri.encodeComponent(region)}/provinces');
  Future<List<AddressPlace>> cities(String region, String? province) => _fetch(
    province == null
        ? 'regions/${Uri.encodeComponent(region)}/cities-municipalities'
        : 'provinces/${Uri.encodeComponent(province)}/cities-municipalities',
  );
  Future<List<AddressPlace>> barangays(String city) =>
      _fetch('cities-municipalities/${Uri.encodeComponent(city)}/barangays');
  void dispose() => _client.close();
}
