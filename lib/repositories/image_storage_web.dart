import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';

const _prefix = 'myagenda.image.';
Future<void> persistImage(String id, Uint8List data) async {
  final prefs = await SharedPreferences.getInstance();
  final encoded = base64Encode(data);
  final used = prefs
      .getKeys()
      .where((k) => k.startsWith(_prefix) && k != '$_prefix$id')
      .fold<int>(0, (n, key) => n + (prefs.getString(key)?.length ?? 0));
  if (used + encoded.length > 3500000) {
    throw StateError(
      'Espace images du navigateur plein. Retirez une image ou utilisez l’application Mac/iPhone.',
    );
  }
  if (!await prefs.setString('$_prefix$id', encoded)) {
    throw StateError('Image non enregistrée.');
  }
}

Future<Uint8List?> readImage(String id) async {
  final raw = (await SharedPreferences.getInstance()).getString('$_prefix$id');
  return raw == null ? null : base64Decode(raw);
}

Future<void> removeImage(String id) async =>
    (await SharedPreferences.getInstance()).remove('$_prefix$id');
