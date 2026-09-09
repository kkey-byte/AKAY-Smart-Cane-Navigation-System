enum UserRole {
  caregiver,
  navigator;

  String get label => switch (this) {
        UserRole.caregiver => 'Caregiver',
        UserRole.navigator => 'Navigator',
      };

  /// Value stored in PostgreSQL `Users.role`
  /// (`CHECK (role IN ('visually_impaired', 'caregiver'))`).
  String get backendValue => switch (this) {
        UserRole.caregiver => 'caregiver',
        UserRole.navigator => 'visually_impaired',
      };

  String get storageValue => name;

  static UserRole? fromStorage(String? value) {
    return switch (value) {
      'caregiver' => UserRole.caregiver,
      'navigator' => UserRole.navigator,
      _ => null,
    };
  }

  /// Parses role strings returned by the PostgreSQL-backed API.
  static UserRole? fromBackend(String? value) {
    if (value == null) return null;
    final normalized = value.toLowerCase().trim().replaceAll(' ', '_');

    if (normalized == 'caregiver') return UserRole.caregiver;

    if (normalized == 'navigator' ||
        normalized == 'vi' ||
        normalized == 'visually_impaired' ||
        normalized.contains('visually_impaired') ||
        value.toLowerCase().contains('visually impaired')) {
      return UserRole.navigator;
    }

    return null;
  }
}
