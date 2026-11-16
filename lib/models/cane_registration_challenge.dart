class CaneRegistrationChallenge {
  const CaneRegistrationChallenge({
    required this.id,
    required this.code,
    required this.expiresAt,
  });

  final String id, code;
  final DateTime expiresAt;

  factory CaneRegistrationChallenge.fromJson(Map<String, dynamic> json) {
    final id = json['registrationId'];
    final code = json['code'];
    final expiry = DateTime.tryParse(json['expires_at']?.toString() ?? '');
    if (id is! String ||
        id.isEmpty ||
        code is! String ||
        !RegExp(r'^[A-HJ-NP-Z2-9]{6}$').hasMatch(code) ||
        expiry == null) {
      throw const FormatException('Invalid cane registration response.');
    }
    return CaneRegistrationChallenge(id: id, code: code, expiresAt: expiry);
  }
}
