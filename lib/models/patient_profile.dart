/// Combined progressive profile payload from `/api/profile`.
class PatientProfile {
  const PatientProfile({
    this.profileId,
    this.userId,
    this.age,
    this.gender,
    this.birthdate,
    this.medicalConditions,
    this.allergies,
    this.bloodType,
    this.emergencyContact,
    this.address,
  });

  final String? profileId;
  final String? userId;
  final int? age;
  final String? gender;
  final DateTime? birthdate;
  final String? medicalConditions;
  final String? allergies;
  final String? bloodType;
  final String? emergencyContact;
  final String? address;

  factory PatientProfile.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PatientProfile();
    return PatientProfile(
      profileId: (json['profileId'] ?? json['profile_id'])?.toString(),
      userId: (json['userId'] ?? json['user_id'])?.toString(),
      age: (json['age'] as num?)?.toInt(),
      gender: json['gender']?.toString(),
      birthdate: _parseDate(json['birthdate'] ?? json['birthDate']),
      medicalConditions:
          (json['medicalConditions'] ?? json['medical_conditions'])?.toString(),
      allergies: json['allergies']?.toString(),
      bloodType: (json['bloodType'] ?? json['blood_type'])?.toString(),
      emergencyContact:
          (json['emergencyContact'] ?? json['emergency_contact'])?.toString(),
      address: json['address']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (age != null) 'age': age,
        if (gender != null) 'gender': gender,
        if (birthdate != null)
          'birthdate': birthdate!.toIso8601String().split('T').first,
        if (medicalConditions != null) 'medicalConditions': medicalConditions,
        if (allergies != null) 'allergies': allergies,
        if (bloodType != null) 'bloodType': bloodType,
        if (emergencyContact != null) 'emergencyContact': emergencyContact,
        if (address != null) 'address': address,
      };

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}

class ProfileBundle {
  const ProfileBundle({
    required this.userId,
    required this.email,
    required this.role,
    this.name,
    this.phone,
    this.profilePicture,
    this.patientProfile = const PatientProfile(),
    this.profileComplete = false,
  });

  final String userId;
  final String email;
  final String role;
  final String? name;
  final String? phone;
  final String? profilePicture;
  final PatientProfile patientProfile;
  final bool profileComplete;

  factory ProfileBundle.fromJson(Map<String, dynamic> json) {
    final user = Map<String, dynamic>.from(
      (json['user'] as Map?) ?? const {},
    );
    final patientRaw = json['patientProfile'] ?? json['patient_profile'];
    return ProfileBundle(
      userId: (user['user_id'] ?? user['userId'] ?? '').toString(),
      email: (user['email'] ?? '').toString(),
      role: (user['role'] ?? '').toString(),
      name: user['name']?.toString(),
      phone: user['phone']?.toString(),
      profilePicture:
          (user['profile_picture'] ?? user['profilePicture'])?.toString(),
      patientProfile: PatientProfile.fromJson(
        patientRaw is Map
            ? Map<String, dynamic>.from(patientRaw)
            : null,
      ),
      profileComplete: json['profileComplete'] == true,
    );
  }
}
