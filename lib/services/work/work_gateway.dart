import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../models/work_connection.dart';
import 'work_http.dart';

abstract class WorkGateway {
  bool get supported;
  Future<WorkCredentials?> read();
  Future<void> save(WorkCredentials value);
  Future<void> clear();
  Future<Map<String, dynamic>> request(
    String url,
    String path, {
    String? token,
    Map<String, dynamic>? body,
    String method = 'POST',
  });
}

class NativeWorkGateway implements WorkGateway {
  static const channel = MethodChannel('fr.beyondexpertise.myagenda/assistant');
  @override
  bool get supported =>
      !kIsWeb &&
      [
        TargetPlatform.iOS,
        TargetPlatform.macOS,
      ].contains(defaultTargetPlatform);
  @override
  Future<WorkCredentials?> read() async {
    if (!supported) return null;
    final raw = await channel.invokeMethod<String>('workRead');
    return raw == null
        ? null
        : WorkCredentials.fromJson(Map<String, dynamic>.from(jsonDecode(raw)));
  }

  @override
  Future<void> save(WorkCredentials value) =>
      channel.invokeMethod<void>('workWrite', jsonEncode(value.toJson()));
  @override
  Future<void> clear() => channel.invokeMethod<void>('workDelete');
  @override
  Future<Map<String, dynamic>> request(
    String url,
    String path, {
    String? token,
    Map<String, dynamic>? body,
    String method = 'POST',
  }) => workRequest(url, path, token: token, body: body, method: method);
}
