class PairingConnection {
  const PairingConnection({
    required this.id,
    required this.navigatorUid,
    required this.caregiverUid,
    required this.navigatorName,
    required this.caregiverName,
    required this.status,
  });
  final String id,
      navigatorUid,
      caregiverUid,
      navigatorName,
      caregiverName,
      status;
  factory PairingConnection.fromJson(Map<String, dynamic> json) =>
      PairingConnection(
        id: json['id'] as String,
        navigatorUid: json['navigator_uid'] as String,
        caregiverUid: json['caregiver_uid'] as String,
        navigatorName: _name(json['navigator_name']),
        caregiverName: _name(json['caregiver_name']),
        status: json['status'] as String,
      );
  static String _name(Object? value) =>
      value is String && value.trim().isNotEmpty ? value : 'Name not provided';
}

class RegisteredCane {
  const RegisteredCane({
    required this.id,
    required this.serial,
    this.assignmentId,
  });
  final String id, serial;
  final String? assignmentId;
  factory RegisteredCane.fromJson(Map<String, dynamic> json) => RegisteredCane(
    id: json['id'] as String,
    serial: json['serial'] as String,
    assignmentId: json['assignment_id'] as String?,
  );
}

class CaneReading {
  CaneReading.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      serial = json['serial'] as String,
      assignmentId = json['assignment_id'] as String,
      time = DateTime.tryParse(json['sampled_at']?.toString() ?? ''),
      battery = json['battery'] is num
          ? (json['battery'] as num).toInt()
          : null,
      status = json['status'] as String?,
      latitude = _coordinate(json['latitude'], 90),
      longitude = _coordinate(json['longitude'], 180);
  final String id, serial, assignmentId;
  final DateTime? time;
  final int? battery;
  final String? status;
  final double? latitude, longitude;
  bool fresh(DateTime now) =>
      time != null &&
      now.difference(time!).inSeconds >= -30 &&
      now.difference(time!) <= const Duration(seconds: 45);
  static double? _coordinate(Object? raw, int bound) {
    final value = raw is num
        ? raw.toDouble()
        : double.tryParse(raw?.toString() ?? '');
    return value != null && value.isFinite && value.abs() <= bound
        ? value
        : null;
  }
}
