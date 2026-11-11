import '../models/route_plan.dart';
import 'secure_api.dart';

class DestinationAssignmentService {
  DestinationAssignmentService({SecureApi? api})
    : api = api ?? SecureApi.instance;
  static final instance = DestinationAssignmentService();
  final SecureApi api;

  Future<void> send(String navigatorUid, MapPlace destination) async {
    await api.request(
      'POST',
      '/v2/navigators/${Uri.encodeComponent(navigatorUid)}/destination',
      {
        'navigator_id': navigatorUid,
        'destination': {
          'name': destination.name,
          'address': destination.address,
          'latitude': destination.latitude,
          'longitude': destination.longitude,
        },
      },
    );
  }

  Stream<Map<String, dynamic>> watch() => api.watchGet('/v2/destination');
  Future<void> acknowledge(String id) async {
    await api.request(
      'POST',
      '/v2/destination/${Uri.encodeComponent(id)}/acknowledge',
    );
  }
}
