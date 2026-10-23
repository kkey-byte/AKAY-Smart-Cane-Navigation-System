import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'app_session_service.dart';

class SecureApiException implements Exception {
  const SecureApiException(this.message, {this.status, this.code});
  final String message;
  final int? status;
  final String? code;
  @override
  String toString() => message;
}

/// Protected requests always use a fresh SDK ID token, never a UID or saved token.
class SecureApi {
  SecureApi({
    http.Client? client,
    Future<String?> Function()? idToken,
    List<String>? bases,
    int Function()? revision,
  }) : _client = client ?? http.Client(),
       _idToken =
           idToken ??
           (() =>
               FirebaseAuth.instance.currentUser?.getIdToken() ??
               Future.value()),
       _bases = bases ?? ApiConfig.candidateBaseUrls,
       _revision =
           revision ?? (() => AppSessionService.instance.identityRevision);
  static final instance = SecureApi();
  static String? preferredBase;
  final http.Client _client;
  final Future<String?> Function() _idToken;
  final List<String> _bases;
  final int Function() _revision;
  final Map<String, Stream<Map<String, dynamic>>> _watches = {};

  /// Share one permission-checked polling subscription per account and resource.
  /// No response is cached across subscribers or account changes.
  Stream<Map<String, dynamic>> watchGet(String path) {
    final key = '${_revision()}:$path';
    return _watches.putIfAbsent(key, () {
      late StreamController<Map<String, dynamic>> controller;
      StreamSubscription<Map<String, dynamic>>? subscription;
      controller = StreamController<Map<String, dynamic>>.broadcast(
        onListen: () {
          subscription = poll(
            () => request('GET', path),
          ).listen(controller.add, onError: controller.addError);
        },
        onCancel: () {
          unawaited(subscription?.cancel());
          _watches.remove(key);
          unawaited(controller.close());
        },
      );
      return controller.stream;
    });
  }

  Future<Map<String, dynamic>> request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final revision = _revision();
    final token = await _idToken();
    if (token == null || token.isEmpty) {
      throw const SecureApiException('Sign in again to continue.', status: 401);
    }
    if (_revision() != revision) {
      throw const SecureApiException(
        'Account changed. Reload this page.',
        status: 401,
      );
    }
    final bases = _bases.contains(preferredBase)
        ? [preferredBase!, ..._bases.where((base) => base != preferredBase)]
        : _bases;
    for (var i = 0; i < bases.length; i++) {
      http.Response response;
      final uri = Uri.parse('${bases[i]}$path');
      if (kReleaseMode && uri.scheme != 'https') {
        throw const SecureApiException(
          'HTTPS is required. Configure a secure API endpoint.',
        );
      }
      try {
        final request = http.Request(method, uri)
          ..headers.addAll({
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          });
        if (body != null) request.body = jsonEncode(body);
        response = await http.Response.fromStream(
          await _client.send(request).timeout(const Duration(seconds: 15)),
        ).timeout(const Duration(seconds: 15));
      } on Exception {
        // Retrying a mutation after an uncertain network outcome can consume an
        // invitation twice. Let the user refresh its status instead.
        if (method != 'GET' || i == bases.length - 1) {
          throw const SecureApiException(
            'Service unreachable. Refresh status before retrying.',
          );
        }
        continue;
      }
      if (_revision() != revision) {
        throw const SecureApiException(
          'Account changed. Reload this page.',
          status: 401,
        );
      }
      Map<String, dynamic> data;
      try {
        data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      } catch (_) {
        throw const SecureApiException(
          'Invalid service response. Please try again.',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw SecureApiException(
          data['message']?.toString() ?? 'Request failed.',
          status: response.statusCode,
          code: data['code']?.toString(),
        );
      }
      return data;
    }
    throw const SecureApiException('Service unavailable.');
  }

  /// Polling intentionally rechecks backend permission on every read. Errors
  /// remove old data in consumers; they do not become an empty success response.
  Stream<T> poll<T>(Future<T> Function() fetch) {
    late StreamController<T> controller;
    Timer? timer;
    var busy = false, cancelled = false;
    final revision = _revision();
    Future<void> refresh() async {
      if (busy || cancelled) return;
      busy = true;
      try {
        if (_revision() != revision) {
          throw const SecureApiException('Account changed.', status: 401);
        }
        final result = await fetch();
        if (!cancelled && _revision() == revision) controller.add(result);
      } catch (error, stack) {
        if (!cancelled) controller.addError(error, stack);
      } finally {
        busy = false;
      }
    }

    controller = StreamController<T>(
      onListen: () {
        unawaited(refresh());
        timer = Timer.periodic(
          const Duration(seconds: 5),
          (_) => unawaited(refresh()),
        );
      },
      onCancel: () {
        cancelled = true;
        timer?.cancel();
      },
    );
    return controller.stream;
  }
}
