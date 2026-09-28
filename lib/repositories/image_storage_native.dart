import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

Future<File> _file(String id) async {
  if (!RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(id)) {
    throw const FormatException('Image invalide');
  }
  final root = await getApplicationSupportDirectory();
  final directory = Directory('${root.path}/attachments');
  await directory.create(recursive: true);
  return File('${directory.path}/$id.png');
}

Future<void> persistImage(String id, Uint8List data) async {
  final destination = await _file(id);
  final temporary = File('${destination.path}.tmp');
  await temporary.writeAsBytes(data, flush: true);
  await temporary.rename(destination.path);
}

Future<Uint8List?> readImage(String id) async {
  final file = await _file(id);
  return await file.exists() ? file.readAsBytes() : null;
}

Future<void> removeImage(String id) async {
  final file = await _file(id);
  if (await file.exists()) await file.delete();
}
