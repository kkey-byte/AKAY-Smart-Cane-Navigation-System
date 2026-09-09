import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/onboarding_data.dart';
import '../models/user_role.dart';

/// Persists auth session and onboarding state locally.
/// Ready to sync with the PostgreSQL-backed auth API.
class AppSessionService extends ChangeNotifier {
  AppSessionService._();

  static final AppSessionService instance = AppSessionService._();

  static const _keyLoggedIn = 'isLoggedIn';
  static const _keyOnboardingComplete = 'onboardingComplete';
  static const _keyRole = 'userRole';
  static const _keyEmail = 'userEmail';
  static const _keyUserId = 'userId';
  static const _keyAuthToken = 'authToken';
  static const _keyOnboardingData = 'onboardingData';
  static const _keyDisplayName = 'displayName';
  static const _keyPhone = 'userPhone';
  static const _keyProfilePicture = 'profilePicture';
  static const _keyProfileComplete = 'profileComplete';

  bool _initialized = false;
  bool isLoggedIn = false;
  bool onboardingComplete = false;
  UserRole? role;
  String? email;
  String? userId;
  String? authToken;
  String? displayName;
  String? phone;
  String? profilePicture;
  bool profileComplete = false;
  OnboardingSetupData setupData = const OnboardingSetupData();

  bool get isInitialized => _initialized;

  /// True when lazy-signup fields still need completion.
  bool get needsProfileCompletion => isLoggedIn && !profileComplete;

  Future<void> init() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    isLoggedIn = prefs.getBool(_keyLoggedIn) ?? false;
    onboardingComplete = prefs.getBool(_keyOnboardingComplete) ?? false;
    role = UserRole.fromStorage(prefs.getString(_keyRole));
    email = prefs.getString(_keyEmail);
    userId = prefs.getString(_keyUserId);
    authToken = prefs.getString(_keyAuthToken);
    displayName = prefs.getString(_keyDisplayName);
    phone = prefs.getString(_keyPhone);
    profilePicture = prefs.getString(_keyProfilePicture);
    profileComplete = prefs.getBool(_keyProfileComplete) ?? false;

    final rawData = prefs.getString(_keyOnboardingData);
    if (rawData != null) {
      try {
        final map = jsonDecode(rawData) as Map<String, dynamic>;
        setupData = _parseSetupData(map);
      } catch (_) {
        setupData = const OnboardingSetupData();
      }
    }

    _initialized = true;
    notifyListeners();
  }

  Future<void> registerSession({
    required String userEmail,
    required UserRole userRole,
    String? id,
    String? token,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    isLoggedIn = true;
    onboardingComplete = false;
    role = userRole;
    email = userEmail;
    userId = id;
    authToken = token;
    setupData = const OnboardingSetupData();

    await prefs.setBool(_keyLoggedIn, true);
    await prefs.setBool(_keyOnboardingComplete, false);
    await prefs.setString(_keyRole, userRole.storageValue);
    await prefs.setString(_keyEmail, userEmail);
    await _persistIdentity(prefs, id: id, token: token);
    await _saveSetupData(prefs);

    notifyListeners();
  }

  Future<void> loginSession({
    required String userEmail,
    required UserRole userRole,
    String? id,
    String? token,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    isLoggedIn = true;
    role = userRole;
    email = userEmail;
    userId = id;
    authToken = token;

    await prefs.setBool(_keyLoggedIn, true);
    await prefs.setString(_keyRole, userRole.storageValue);
    await prefs.setString(_keyEmail, userEmail);
    await _persistIdentity(prefs, id: id, token: token);

    notifyListeners();
  }

  Future<void> _persistIdentity(
    SharedPreferences prefs, {
    String? id,
    String? token,
  }) async {
    if (id != null) {
      await prefs.setString(_keyUserId, id);
    } else {
      await prefs.remove(_keyUserId);
    }
    if (token != null) {
      await prefs.setString(_keyAuthToken, token);
    } else {
      await prefs.remove(_keyAuthToken);
    }
  }

  Future<void> updateSetupData(OnboardingSetupData data) async {
    setupData = data;
    final prefs = await SharedPreferences.getInstance();
    await _saveSetupData(prefs);
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    onboardingComplete = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboardingComplete, true);
    notifyListeners();
  }

  Future<void> updateProfileCache({
    String? name,
    String? phone,
    String? profilePicture,
    bool? profileComplete,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (name != null) {
      displayName = name;
      await prefs.setString(_keyDisplayName, name);
    }
    if (phone != null) {
      this.phone = phone;
      await prefs.setString(_keyPhone, phone);
    }
    if (profilePicture != null) {
      this.profilePicture = profilePicture;
      // Large data URLs can exceed SharedPreferences limits — keep in memory
      // and only persist shorter http(s) URLs / small payloads.
      if (!profilePicture.startsWith('data:') ||
          profilePicture.length < 350000) {
        await prefs.setString(_keyProfilePicture, profilePicture);
      } else {
        await prefs.remove(_keyProfilePicture);
      }
    }
    if (profileComplete != null) {
      this.profileComplete = profileComplete;
      await prefs.setBool(_keyProfileComplete, profileComplete);
    }
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    isLoggedIn = false;
    onboardingComplete = false;
    role = null;
    email = null;
    userId = null;
    authToken = null;
    displayName = null;
    phone = null;
    profilePicture = null;
    profileComplete = false;
    setupData = const OnboardingSetupData();

    await prefs.remove(_keyLoggedIn);
    await prefs.remove(_keyOnboardingComplete);
    await prefs.remove(_keyRole);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyAuthToken);
    await prefs.remove(_keyOnboardingData);
    await prefs.remove(_keyDisplayName);
    await prefs.remove(_keyPhone);
    await prefs.remove(_keyProfilePicture);
    await prefs.remove(_keyProfileComplete);

    notifyListeners();
  }

  Future<void> _saveSetupData(SharedPreferences prefs) async {
    final map = {
      'smartCanePaired': setupData.smartCanePaired,
      'smartCaneSkipped': setupData.smartCaneSkipped,
      'emergencyContacts':
          setupData.emergencyContacts.map((c) => c.toJson()).toList(),
      'locationGranted': setupData.locationGranted,
      'notificationsGranted': setupData.notificationsGranted,
      'linkedInviteCode': setupData.linkedInviteCode,
      'tutorialSkipped': setupData.tutorialSkipped,
      'accessibility': setupData.accessibility.toJson(),
    };
    await prefs.setString(_keyOnboardingData, jsonEncode(map));
  }

  OnboardingSetupData _parseSetupData(Map<String, dynamic> map) {
    final contactsRaw = map['emergencyContacts'] as List<dynamic>? ?? [];
    return OnboardingSetupData(
      smartCanePaired: map['smartCanePaired'] as bool? ?? false,
      smartCaneSkipped: map['smartCaneSkipped'] as bool? ?? false,
      emergencyContacts: contactsRaw
          .map((e) => EmergencyContact.fromJson(e as Map<String, dynamic>))
          .toList(),
      locationGranted: map['locationGranted'] as bool? ?? false,
      notificationsGranted: map['notificationsGranted'] as bool? ?? false,
      linkedInviteCode: map['linkedInviteCode'] as String? ?? '',
      tutorialSkipped: map['tutorialSkipped'] as bool? ?? false,
      accessibility: AccessibilityPreferences.fromJson(
        map['accessibility'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}
