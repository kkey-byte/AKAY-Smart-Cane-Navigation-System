import '../models/navigator_health_details.dart';
import 'secure_api.dart';

class NavigatorHealthService {
  NavigatorHealthService({SecureApi? api}) : api = api ?? SecureApi.instance;
  final SecureApi api;

  Stream<NavigatorHealthDetails> watch(String uid) => api
      .watchGet('/v2/navigators/${Uri.encodeComponent(uid)}/health')
      .map((json) {
        final details = NavigatorHealthDetails.fromJson(json);
        if (details.uid != uid) {
          throw const FormatException(
            'Navigator identity could not be verified.',
          );
        }
        return details;
      });
}
