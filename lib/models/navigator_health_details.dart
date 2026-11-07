import 'patient_profile.dart';
import 'patient_health_status.dart';

/// Read-only information for a navigator authorized by an active connection.
class NavigatorHealthDetails {
  const NavigatorHealthDetails({
    required this.uid,
    this.phone,
    this.profile = const PatientProfile(),
    this.health,
    this.healthUnavailable = false,
  });
  final String uid;
  final String? phone;
  final PatientProfile profile;
  final PatientHealthStatus? health;
  final bool healthUnavailable;

  factory NavigatorHealthDetails.fromJson(Map<String, dynamic> json) {
    final navigator = json['navigator'];
    if (navigator is! Map || navigator['uid'] is! String) {
      throw const FormatException('Navigator identity unavailable.');
    }
    final patient = json['patientProfile'];
    final health = json['health_status'];
    return NavigatorHealthDetails(
      uid: navigator['uid'] as String,
      phone: navigator['phone'] as String?,
      profile: PatientProfile.fromJson(
        patient is Map ? Map<String, dynamic>.from(patient) : null,
      ),
      health: health is Map
          ? PatientHealthStatus.fromJson(Map<String, dynamic>.from(health))
          : null,
      healthUnavailable: json['healthUnavailable'] == true,
    );
  }
}
