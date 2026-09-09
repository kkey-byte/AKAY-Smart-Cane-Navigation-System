class EmergencyContact {
  const EmergencyContact({
    required this.name,
    required this.phone,
    this.relationship = '',
  });

  final String name;
  final String phone;
  final String relationship;

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'relationship': relationship,
      };

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      relationship: json['relationship'] as String? ?? '',
    );
  }
}

class AccessibilityPreferences {
  const AccessibilityPreferences({
    this.textScale = 1.0,
    this.highContrast = false,
    this.voiceGuidance = true,
    this.speechSpeed = 1.0,
    this.language = 'English',
    this.hapticFeedback = true,
  });

  final double textScale;
  final bool highContrast;
  final bool voiceGuidance;
  final double speechSpeed;
  final String language;
  final bool hapticFeedback;

  AccessibilityPreferences copyWith({
    double? textScale,
    bool? highContrast,
    bool? voiceGuidance,
    double? speechSpeed,
    String? language,
    bool? hapticFeedback,
  }) {
    return AccessibilityPreferences(
      textScale: textScale ?? this.textScale,
      highContrast: highContrast ?? this.highContrast,
      voiceGuidance: voiceGuidance ?? this.voiceGuidance,
      speechSpeed: speechSpeed ?? this.speechSpeed,
      language: language ?? this.language,
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
    );
  }

  Map<String, dynamic> toJson() => {
        'textScale': textScale,
        'highContrast': highContrast,
        'voiceGuidance': voiceGuidance,
        'speechSpeed': speechSpeed,
        'language': language,
        'hapticFeedback': hapticFeedback,
      };

  factory AccessibilityPreferences.fromJson(Map<String, dynamic> json) {
    return AccessibilityPreferences(
      textScale: (json['textScale'] as num?)?.toDouble() ?? 1.0,
      highContrast: json['highContrast'] as bool? ?? false,
      voiceGuidance: json['voiceGuidance'] as bool? ?? true,
      speechSpeed: (json['speechSpeed'] as num?)?.toDouble() ?? 1.0,
      language: json['language'] as String? ?? 'English',
      hapticFeedback: json['hapticFeedback'] as bool? ?? true,
    );
  }
}

class OnboardingSetupData {
  const OnboardingSetupData({
    this.smartCanePaired = false,
    this.smartCaneSkipped = false,
    this.emergencyContacts = const [],
    this.locationGranted = false,
    this.notificationsGranted = false,
    this.linkedInviteCode = '',
    this.tutorialSkipped = false,
    this.accessibility = const AccessibilityPreferences(),
  });

  final bool smartCanePaired;
  final bool smartCaneSkipped;
  final List<EmergencyContact> emergencyContacts;
  final bool locationGranted;
  final bool notificationsGranted;
  final String linkedInviteCode;
  final bool tutorialSkipped;
  final AccessibilityPreferences accessibility;

  OnboardingSetupData copyWith({
    bool? smartCanePaired,
    bool? smartCaneSkipped,
    List<EmergencyContact>? emergencyContacts,
    bool? locationGranted,
    bool? notificationsGranted,
    String? linkedInviteCode,
    bool? tutorialSkipped,
    AccessibilityPreferences? accessibility,
  }) {
    return OnboardingSetupData(
      smartCanePaired: smartCanePaired ?? this.smartCanePaired,
      smartCaneSkipped: smartCaneSkipped ?? this.smartCaneSkipped,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
      locationGranted: locationGranted ?? this.locationGranted,
      notificationsGranted: notificationsGranted ?? this.notificationsGranted,
      linkedInviteCode: linkedInviteCode ?? this.linkedInviteCode,
      tutorialSkipped: tutorialSkipped ?? this.tutorialSkipped,
      accessibility: accessibility ?? this.accessibility,
    );
  }
}
