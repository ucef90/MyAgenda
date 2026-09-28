import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:my_agenda/features/attachments/attachment_editor.dart';
import 'package:my_agenda/models/attachment.dart';
import 'package:my_agenda/repositories/attachment_repository.dart';

final png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAEUlEQVR4nGPwd3v6H4QZYAwAU7gJ5UxPw40AAAAASUVORK5CYII=',
);

class _Paths extends PathProviderPlatform {
  final String directory;
  _Paths(this.directory);
  @override
  Future<String?> getApplicationSupportPath() async => directory;
}

class _Images extends AttachmentRepository {
  final Map<String, Uint8List> files = {};
  @override
  Future<TaskAttachment> add(Uint8List bytes, String name) async {
    files['photo'] = bytes;
    return TaskAttachment(id: 'photo', name: name, bytes: bytes.length);
  }

  @override
  Future<Uint8List?> read(String id) async => files[id];
  @override
  Future<void> remove(String id) async {
    files.remove(id);
  }
}

class _Picker extends ImagePickerPlatform {
  bool denied = false;
  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    if (denied) throw PlatformException(code: 'photo_access_denied');
    return XFile.fromData(
      png,
      name: 'design.png',
      path: 'design.png',
      mimeType: 'image/png',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'An imported image is stored outside cache and survives repository recreation',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'myagenda-images-test',
      );
      final original = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _Paths(directory.path);
      try {
        final repo = AttachmentRepository();
        final attachment = await repo.add(png, 'design.png');
        final restored = await AttachmentRepository().read(attachment.id);
        expect(restored, isNotNull);
        expect(restored!.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
        expect(attachment.bytes, restored.length);
        expect(
          await Directory('${directory.path}/attachments').list().length,
          1,
        );
        await repo.remove(attachment.id);
        expect(await repo.read(attachment.id), isNull);
        await expectLater(repo.read('../outside'), throwsFormatException);
      } finally {
        PathProviderPlatform.instance = original;
        await directory.delete(recursive: true);
      }
    },
  );
  testWidgets(
    'Image import, preview, removal and permission denial remain usable',
    (tester) async {
      final original = ImagePickerPlatform.instance;
      final picker = _Picker();
      ImagePickerPlatform.instance = picker;
      addTearDown(() => ImagePickerPlatform.instance = original);
      final images = _Images();
      var attachments = <TaskAttachment>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [attachmentRepositoryProvider.overrideWithValue(images)],
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) => AttachmentEditor(
                  value: attachments,
                  onChanged: (value) => setState(() => attachments = value),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Image'));
      await tester.pumpAndSettle();
      expect(attachments.single.name, 'design.png');
      expect(find.byType(Image), findsOneWidget);
      await tester.tap(find.byTooltip('Retirer design.png'));
      await tester.pumpAndSettle();
      expect(attachments, isEmpty);
      picker.denied = true;
      await tester.tap(find.text('Image'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Autorisez les photos'), findsOneWidget);
      expect(attachments, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
