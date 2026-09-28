import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/attachment.dart';
import '../../repositories/attachment_repository.dart';
import '../../widgets/common.dart';
import 'sketch_page.dart';

class AttachmentEditor extends ConsumerStatefulWidget {
  final List<TaskAttachment> value;
  final ValueChanged<List<TaskAttachment>> onChanged;
  final ValueChanged<bool>? onBusyChanged;
  const AttachmentEditor({
    super.key,
    required this.value,
    required this.onChanged,
    this.onBusyChanged,
  });
  @override
  ConsumerState<AttachmentEditor> createState() => _AttachmentEditorState();
}

class _AttachmentEditorState extends ConsumerState<AttachmentEditor> {
  bool _busy = false;
  Future<void> _add({ImageSource? source}) async {
    if (widget.value.length >= 8) {
      toast(context, 'Jusqu’à 8 visuels par tâche.');
      return;
    }
    setState(() => _busy = true);
    widget.onBusyChanged?.call(true);
    final repository = ref.read(attachmentRepositoryProvider);
    try {
      Uint8List? bytes;
      var name = 'Croquis.png';
      if (source == null) {
        bytes = await Navigator.push<Uint8List>(
          context,
          MaterialPageRoute(builder: (_) => const SketchPage()),
        );
      } else {
        final photo = await ImagePicker().pickImage(
          source: source,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 85,
          requestFullMetadata: false,
        );
        if (photo == null) return;
        if (await photo.length() > 20 * 1024 * 1024) {
          throw StateError('Choisissez une image de moins de 20 Mo.');
        }
        bytes = await photo.readAsBytes();
        name = photo.name.isEmpty ? 'Photo.png' : photo.name;
      }
      if (bytes == null || !mounted) return;
      final attachment = await repository.add(bytes, name);
      if (mounted) {
        widget.onChanged([...widget.value, attachment]);
      } else {
        await repository.remove(attachment.id);
      }
    } on PlatformException catch (e) {
      if (mounted) {
        toast(
          context,
          e.code.toLowerCase().contains('access') ||
                  e.code.toLowerCase().contains('denied')
              ? 'Autorisez les photos ou la caméra dans les réglages de votre appareil, puis réessayez.'
              : 'L’image n’a pas pu être ouverte. Réessayez avec un fichier PNG ou JPEG.',
        );
      }
    } catch (e) {
      if (mounted) {
        toast(
          context,
          e is StateError
              ? e.message.toString()
              : 'Image illisible. Essayez un fichier PNG ou JPEG.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        widget.onBusyChanged?.call(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final camera =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AttachmentGallery(
          attachments: widget.value,
          onRemove: _busy
              ? null
              : (image) => widget.onChanged(
                  widget.value.where((a) => a.id != image.id).toList(),
                ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _add(source: ImageSource.gallery),
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Image'),
            ),
            if (camera)
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _add(source: ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Photo'),
              ),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _add(),
              icon: const Icon(Icons.draw_outlined),
              label: const Text('Croquis'),
            ),
          ],
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LinearProgressIndicator(),
          ),
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Photos, captures ou designs en image · 8 visuels maximum.',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class AttachmentGallery extends ConsumerWidget {
  final List<TaskAttachment> attachments;
  final ValueChanged<TaskAttachment>? onRemove;
  const AttachmentGallery({
    super.key,
    required this.attachments,
    this.onRemove,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      for (final attachment in attachments)
        SizedBox(
          width: 140,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      height: 110,
                      width: 140,
                      child: Material(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        child: InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => Scaffold(
                                appBar: AppBar(title: Text(attachment.name)),
                                body: Center(
                                  child: InteractiveViewer(
                                    minScale: .5,
                                    maxScale: 5,
                                    child: AttachmentImage(
                                      id: attachment.id,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          child: AttachmentImage(id: attachment.id),
                        ),
                      ),
                    ),
                  ),
                  if (onRemove != null)
                    Positioned(
                      top: 2,
                      right: 2,
                      child: IconButton.filledTonal(
                        tooltip: 'Retirer ${attachment.name}',
                        onPressed: () => onRemove!(attachment),
                        icon: const Icon(Icons.close, size: 18),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 5, 2, 12),
                child: Text(
                  attachment.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

class AttachmentImage extends ConsumerWidget {
  final String id;
  final BoxFit fit;
  const AttachmentImage({super.key, required this.id, this.fit = BoxFit.cover});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(attachmentBytesProvider(id))
      .when(
        data: (bytes) => bytes == null
            ? const Center(
                child: Text('Image introuvable', textAlign: TextAlign.center),
              )
            : Image.memory(
                bytes,
                fit: fit,
                errorBuilder: (_, e, stack) =>
                    const Icon(Icons.broken_image_outlined),
              ),
        loading: () => const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (_, stack) => const Center(
          child: Text('Image indisponible', textAlign: TextAlign.center),
        ),
      );
}
