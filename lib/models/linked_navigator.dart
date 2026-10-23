import '../services/app_session_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// A visually impaired user linked to the caregiver account.
/// Ready for Firebase Realtime Database live location updates.
class LinkedNavigator {
  final String id;
  final String name;
  final String address;
  final LatLng location;
  final String status;
  final int batteryPercent;
  final bool isOnline;

  /// Device key used by Firebase Realtime Database live-location updates.
  /// When omitted, the linked navigator id is used for backward compatibility.
  final String? deviceId;

  /// The time the most recent GPS fix was received.
  final DateTime? lastLocationUpdated;

  const LinkedNavigator({
    required this.id,
    required this.name,
    required this.address,
    required this.location,
    required this.status,
    required this.batteryPercent,
    this.isOnline = true,
    this.deviceId,
    this.lastLocationUpdated,
  });

  String get liveLocationId => deviceId ?? id;

  LinkedNavigator copyWith({
    String? address,
    LatLng? location,
    String? status,
    bool? isOnline,
    DateTime? lastLocationUpdated,
    bool replaceLastLocationUpdated = false,
  }) {
    return LinkedNavigator(
      id: id,
      name: name,
      address: address ?? this.address,
      location: location ?? this.location,
      status: status ?? this.status,
      batteryPercent: batteryPercent,
      isOnline: isOnline ?? this.isOnline,
      deviceId: deviceId,
      lastLocationUpdated: replaceLastLocationUpdated
          ? lastLocationUpdated
          : lastLocationUpdated ?? this.lastLocationUpdated,
    );
  }
}

/// Telemetry and device pairing are unavailable until a verified API exists.
class LinkedNavigatorService {
  LinkedNavigatorService._();
  static final instance = LinkedNavigatorService._();
  static const navigators = <LinkedNavigator>[];
  static LinkedNavigator get selfNavigator => LinkedNavigator(
    id: AppSessionService.instance.userId ?? '',
    name: AppSessionService.instance.displayName ?? 'Navigator',
    address: 'Location unavailable',
    location: const LatLng(0, 0),
    status: 'Status unavailable',
    batteryPercent: -1,
    isOnline: false,
  );
  LinkedNavigator? findById(String id) => null;
  void subscribeUpdates(void Function(List<LinkedNavigator>) onUpdate) =>
      onUpdate(const []);
}
