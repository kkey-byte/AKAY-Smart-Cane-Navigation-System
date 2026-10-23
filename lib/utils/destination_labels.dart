/// Compact presentation labels. Original addresses and coordinates stay intact.
class DestinationLabels {
  DestinationLabels._();

  static String name(String name, String address) {
    final value = name.trim();
    if (value.isNotEmpty && value.toLowerCase() != 'place') {
      return value == address.trim() ? value.split(',').first.trim() : value;
    }
    return address.trim().isEmpty ? 'Place' : address.split(',').first.trim();
  }

  static String shortAddress(String address, String placeName) {
    final raw = address.trim();
    if (RegExp(r'^-?\d+(?:\.\d+)?,\s*-?\d+(?:\.\d+)?$').hasMatch(raw)) {
      return raw;
    }
    final title = name(placeName, address).toLowerCase();
    final parts = raw
        .split(',')
        .map((s) => s.trim())
        .where(
          (s) =>
              s.isNotEmpty &&
              s.toLowerCase() != title &&
              !RegExp(r'^\d{4,6}$').hasMatch(s) &&
              !RegExp(
                r'^(philippines|republic of the philippines)$',
                caseSensitive: false,
              ).hasMatch(s) &&
              !RegExp(
                r'\b(region|province)\b',
                caseSensitive: false,
              ).hasMatch(s),
        )
        .toList();
    // A city gives a reliable boundary before province/country components.
    final city = parts.indexWhere(
      (s) => RegExp(r'\bcity\b', caseSensitive: false).hasMatch(s),
    );
    if (city >= 0) {
      return [if (city > 0) parts[city - 1], parts[city]].join(', ');
    }
    // Unstructured provider results: retain only the first two local components.
    return parts.take(2).join(', ');
  }
}
