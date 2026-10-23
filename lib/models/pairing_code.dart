/// The QR and text workflows carry the same short invitation, never an identity.
String? parsePairingCode(String value) {
  var code = value.trim();
  if (code.toLowerCase().startsWith('akay://')) {
    final uri = Uri.tryParse(code);
    if (uri == null ||
        uri.scheme != 'akay' ||
        uri.host != 'pair' ||
        uri.path.isNotEmpty ||
        uri.queryParametersAll['code']?.length != 1) {
      return null;
    }
    code = uri.queryParameters['code'] ?? '';
  }
  code = code.toUpperCase();
  return RegExp(r'^[A-HJ-NP-Z2-9]{6}$').hasMatch(code) ? code : null;
}
