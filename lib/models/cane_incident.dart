class CaneIncident {
  const CaneIncident({
    required this.id,
    required this.navigatorUid,
    required this.navigatorName,
    required this.deviceId,
    required this.kind,
    required this.createdAt,
    required this.detectedAt,
    this.acknowledgedAt,
    this.resolvedAt,
    this.latitude,
    this.longitude,
    this.resolution,
    this.isRead = false,
  });
  final String id, navigatorUid, navigatorName, deviceId, kind;
  final DateTime createdAt, detectedAt;
  final DateTime? acknowledgedAt, resolvedAt;
  final double? latitude, longitude;
  final String? resolution;
  final bool isRead;
  bool get unresolved => resolvedAt == null;
  String get status => resolvedAt != null
      ? (resolution == 'false_alarm' ? 'False alarm' : 'Resolved')
      : acknowledgedAt != null
      ? 'Acknowledged'
      : 'Needs response';
  String get title =>
      '${kind == 'sos' ? 'SOS' : 'Possible fall or impact'} — $navigatorName';
  factory CaneIncident.fromJson(Map<String, dynamic> json) {
    final kind = json['kind'];
    if (!['sos', 'motion'].contains(kind) ||
        json['id'] is! String ||
        json['navigator_uid'] is! String ||
        (json['navigator_uid'] as String).isEmpty) {
      throw const FormatException('Invalid cane incident.');
    }
    final lat = (json['latitude'] as num?)?.toDouble(),
        lon = (json['longitude'] as num?)?.toDouble();
    final valid =
        lat != null &&
        lon != null &&
        lat.isFinite &&
        lon.isFinite &&
        lat.abs() <= 90 &&
        lon.abs() <= 180;
    final name = (json['navigator_name'] as String?)?.trim();
    return CaneIncident(
      id: json['id'] as String,
      navigatorUid: json['navigator_uid'] as String,
      navigatorName: name == null || name.isEmpty ? 'Linked navigator' : name,
      deviceId: json['device_id'] as String,
      kind: kind as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      detectedAt: DateTime.parse(json['sampled_at'] as String),
      acknowledgedAt: DateTime.tryParse(
        json['acknowledged_at']?.toString() ?? '',
      ),
      resolvedAt: DateTime.tryParse(json['resolved_at']?.toString() ?? ''),
      latitude: valid ? lat : null,
      longitude: valid ? lon : null,
      resolution: json['resolution'] as String?,
      isRead: json['read_at'] != null,
    );
  }
}
