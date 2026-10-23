class EmergencyContactEntry {
  const EmergencyContactEntry({
    required this.name,
    required this.relationship,
    required this.phone,
  });

  final String name;
  final String relationship;
  final String phone;
}

class NavigatorHealthProfile {
  const NavigatorHealthProfile({
    required this.name,
    required this.age,
    required this.gender,
    required this.bloodType,
    required this.height,
    required this.weight,
    required this.medicalConditions,
    required this.drugAllergies,
    required this.foodAllergies,
    required this.otherAllergies,
    required this.emergencyContacts,
    this.avatarAsset = '',
  });

  final String name;
  final int age;
  final String gender;
  final String bloodType;
  final String height;
  final String weight;
  final List<String> medicalConditions;
  final String drugAllergies;
  final String foodAllergies;
  final String otherAllergies;
  final List<EmergencyContactEntry> emergencyContacts;
  final String avatarAsset;

  String get ageGenderLabel => '$age years old • $gender';
}
