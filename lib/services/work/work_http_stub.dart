import '../../models/work_connection.dart';

Future<Map<String, dynamic>> workRequest(
  String url,
  String path, {
  String? token,
  Map<String, dynamic>? body,
  String method = 'POST',
}) async => throw const WorkError(
  'La connexion privée est disponible sur iPhone et Mac.',
);
