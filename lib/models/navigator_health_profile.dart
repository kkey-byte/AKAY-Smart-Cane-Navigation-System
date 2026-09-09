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
    this.avatarAsset = 'assets/profile.jpg',
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

  static const linkedNavigator = NavigatorHealthProfile(
    name: 'Glaisa Regine Mariel',
    age: 22,
    gender: 'Female',
    bloodType: 'O+',
    height: '165 cm',
    weight: '62 kg',
    medicalConditions: [
      'Retinitis pigmentosa',
      'Mild asthma',
      'Vitamin A deficiency',
    ],
    drugAllergies: 'Paracetamol',
    foodAllergies: 'Crab and Talong',
    otherAllergies: 'None',
    emergencyContacts: [
      EmergencyContactEntry(
        name: 'Mariel Glaisa Regine',
        relationship: 'Primary Caregiver',
        phone: '+63 998 877 6655',
      ),
      EmergencyContactEntry(
        name: 'Regine Kris Cadiao',
        relationship: 'Secondary Contact',
        phone: '+63 912 345 6789',
      ),
      EmergencyContactEntry(
        name: 'Glaisa',
        relationship: 'Friend',
        phone: '+63 917 654 3210',
      ),
    ],
  );

  static const navigatorUser = NavigatorHealthProfile(
    name: 'Mariel Joyce Batulanon',
    age: 24,
    gender: 'Female',
    bloodType: 'A+',
    height: '160 cm',
    weight: '58 kg',
    medicalConditions: [
      'Visually impaired',
      'Mild hearing sensitivity',
    ],
    drugAllergies: 'Penicillin',
    foodAllergies: 'None',
    otherAllergies: 'Dust',
    emergencyContacts: [
      EmergencyContactEntry(
        name: 'Maria Batulanon',
        relationship: 'Primary Caregiver',
        phone: '+63 917 000 1111',
      ),
      EmergencyContactEntry(
        name: 'Juan Batulanon',
        relationship: 'Secondary Contact',
        phone: '+63 918 222 3333',
      ),
    ],
  );
}
