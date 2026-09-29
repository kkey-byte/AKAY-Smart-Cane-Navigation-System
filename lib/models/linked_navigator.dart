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

/// Mock linked navigators — replace with backend / Firebase fetch.
class LinkedNavigatorService {
  LinkedNavigatorService._();

  static final LinkedNavigatorService instance = LinkedNavigatorService._();

  /// Logged-in visually impaired (navigator) user profile.
  static const LinkedNavigator selfNavigator = LinkedNavigator(
    id: 'nav_self',
    name: 'Mariel Joyce Batulanon',
    address: 'Rizal Street, Panabo City',
    location: LatLng(7.3064, 125.6865),
    status: 'Walking',
    batteryPercent: 78,
    isOnline: true,
  );

  static const List<LinkedNavigator> navigators = [
    LinkedNavigator(
      id: 'nav_1',
      name: 'Glaisa Regine Mariel',
      address: 'Quezon Street, Panabo City',
      location: LatLng(7.3064, 125.6865),
      status: 'Walking',
      batteryPercent: 82,
      isOnline: true,
    ),
    LinkedNavigator(
      id: 'nav_2',
      name: 'Juan Dela Cruz',
      address: 'Rizal Street, Panabo City',
      location: LatLng(7.3018, 125.6920),
      status: 'Idle',
      batteryPercent: 64,
      isOnline: true,
    ),
    LinkedNavigator(
      id: 'nav_3',
      name: 'Maria Santos',
      address: 'Tagum-Panabo Highway, Panabo City',
      location: LatLng(7.3142, 125.6785),
      status: 'Navigating',
      batteryPercent: 45,
      isOnline: true,
    ),
    LinkedNavigator(
      id: 'nav_4',
      name: 'Pedro Reyes',
      address: 'New Visayas, Panabo City',
      location: LatLng(7.2985, 125.6810),
      status: 'Offline',
      batteryPercent: 20,
      isOnline: false,
    ),
  ];

  LinkedNavigator? findById(String id) {
    for (final nav in navigators) {
      if (nav.id == id) return nav;
    }
    return null;
  }

  /// Firebase live tracking placeholder.
  void subscribeUpdates(void Function(List<LinkedNavigator> navigators) onUpdate) {
    // TODO: Firebase Realtime Database listener
  }
}
