import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/task.dart';

class DeviceAssistant {
  static const channel = MethodChannel('fr.beyondexpertise.myagenda/assistant');
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  static Future<T?> call<T>(String method, [Object? args]) async {
    if (!supported) {
      throw PlatformException(
        code: 'unsupported',
        message: 'Cette fonction est disponible sur iPhone.',
      );
    }
    return channel.invokeMethod<T>(method, args);
  }

  static Future<AudioNote> stopRecording() async {
    final value = await call<Map>('recordStop');
    return AudioNote.fromJson(Map<String, dynamic>.from(value!));
  }

  static Future<void> removeAudio(String id) async {
    if (supported) await call('audioRemove', id);
  }
}

String deviceError(Object error) => error is PlatformException
    ? error.message ?? 'La fonction est indisponible. Réessayez.'
    : 'L’opération a échoué. Réessayez.';
