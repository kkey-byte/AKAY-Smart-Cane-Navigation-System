class PatientHealthStatus {
  const PatientHealthStatus({
    this.height,
    this.weight,
    this.medicalConditions,
    this.allergies,
    this.emergencyContactPhone,
  });
  final double? height, weight;
  final String? medicalConditions, allergies, emergencyContactPhone;

  factory PatientHealthStatus.fromJson(Map<String, dynamic> json) =>
      PatientHealthStatus(
        height: _number(json['height']),
        weight: _number(json['weight']),
        medicalConditions: json['medical_conditions'] as String?,
        allergies: json['allergies'] as String?,
        emergencyContactPhone: json['emergency_contact_phone'] as String?,
      );
  static double? _number(Object? value) =>
      value == null ? null : double.parse(value.toString());

  /// Full health-editor snapshot: explicit null clears an unknown measurement.
  Map<String, dynamic> toJson() => {
    'height': height,
    'weight': weight,
    'medical_conditions': medicalConditions,
    'allergies': allergies,
    'emergency_contact_phone': emergencyContactPhone,
  };
}
