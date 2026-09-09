import 'user_role.dart';

/// Mirrors the PostgreSQL `Users` table payload returned by the backend.
class AppUser {
  const AppUser({
    required this.userId,
    required this.email,
    required this.role,
    this.firebaseUid,
    this.name,
    this.phone,
    this.profilePicture,
    this.createdAt,
    this.updatedAt,
  });

  final String userId;
  final String? firebaseUid;
  final String? name;
  final String email;
  final UserRole role;
  final String? phone;
  final String? profilePicture;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final roleRaw = (json['role'] ?? json['user_role'])?.toString();
    final role = UserRole.fromBackend(roleRaw);
    if (role == null) {
      throw FormatException('Unknown user role: $roleRaw');
    }

    return AppUser(
      userId: (json['user_id'] ?? json['userId'] ?? json['id']).toString(),
      firebaseUid:
          (json['firebase_uid'] ?? json['firebaseUid'])?.toString(),
      name: json['name'] as String?,
      email: (json['email'] as String?) ?? '',
      role: role,
      phone: json['phone'] as String?,
      profilePicture:
          (json['profile_picture'] ?? json['profilePicture']) as String?,
      createdAt: _parseDate(json['created_at'] ?? json['createdAt']),
      updatedAt: _parseDate(json['updated_at'] ?? json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'firebase_uid': firebaseUid,
        'name': name,
        'email': email,
        'role': role.backendValue,
        'phone': phone,
        'profile_picture': profilePicture,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      };

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
