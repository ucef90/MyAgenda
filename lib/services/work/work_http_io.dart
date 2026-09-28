import 'dart:convert';
import 'dart:io';
import '../../models/work_connection.dart';

Future<Map<String, dynamic>> workRequest(
  String url,
  String path, {
  String? token,
  Map<String, dynamic>? body,
  String method = 'POST',
}) async {
  final base = workServerUri(url);
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    return await (() async {
      final request = await client.openUrl(method, base.replace(path: path));
      request.followRedirects = false;
      request.headers.contentType = ContentType.json;
      if (token != null) request.headers.set('Authorization', 'Bearer $token');
      if (body != null) request.write(jsonEncode(body));
      final response = await request.close();
      if (response.isRedirect) {
        throw const WorkError(
          'Redirection refusée. Vérifiez l’adresse exacte du serveur.',
        );
      }
      final bytes = <int>[];
      await for (final chunk in response) {
        if (bytes.length + chunk.length > 2 * 1024 * 1024) {
          throw const WorkError('Réponse du serveur trop volumineuse.');
        }
        bytes.addAll(chunk);
      }
      if (response.statusCode == 401) {
        throw const WorkError(
          'Code expiré ou connexion révoquée. Générez un nouveau code sur le serveur.',
          status: 401,
        );
      }
      if (response.statusCode == 409) {
        throw const WorkError(
          'La synchronisation a changé. Actualisez puis réessayez.',
        );
      }
      if (response.statusCode == 429) {
        throw const WorkError('Trop de tentatives. Réessayez dans une minute.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const WorkError(
          'Le serveur a refusé la demande. Vérifiez sa configuration.',
        );
      }
      return Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes)) as Map);
    })().timeout(const Duration(seconds: 20));
  } on WorkError {
    rethrow;
  } catch (_) {
    throw const WorkError(
      'Serveur injoignable. Vérifiez Internet et l’adresse HTTPS. Vos tâches restent sur cet appareil.',
    );
  } finally {
    client.close(force: true);
  }
}
