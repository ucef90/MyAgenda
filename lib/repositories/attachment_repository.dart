import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/attachment.dart';
import 'workspace_store.dart';
import 'image_storage.dart' as storage;

final attachmentRepositoryProvider = Provider((ref) => AttachmentRepository());
final attachmentBytesProvider = FutureProvider.autoDispose
    .family<Uint8List?, String>(
      (ref, id) => ref.watch(attachmentRepositoryProvider).read(id),
    );

class AttachmentRepository {
  Future<TaskAttachment> add(Uint8List bytes, String name) async {
    if (bytes.length > 20 * 1024 * 1024) {
      throw StateError('Choisissez une image de moins de 20 Mo.');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? image;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      if (descriptor.width * descriptor.height > 60000000) {
        throw StateError(
          'Cette image est trop grande. Exportez-la dans une taille plus petite.',
        );
      }
      final scale = math.min(
        1.0,
        1600 / math.max(descriptor.width, descriptor.height),
      );
      codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (descriptor.width * scale).round()),
        targetHeight: math.max(1, (descriptor.height * scale).round()),
      );
      image = (await codec.getNextFrame()).image;
      final data = (await image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List();
      final id = newId();
      await storage.persistImage(id, data);
      return TaskAttachment(id: id, name: name, bytes: data.length);
    } finally {
      image?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }

  Future<Uint8List?> read(String id) => storage.readImage(id);
  Future<void> remove(String id) => storage.removeImage(id);
}
