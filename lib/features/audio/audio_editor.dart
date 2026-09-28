import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/task.dart';
import '../../services/device_assistant.dart';
import '../../widgets/common.dart';

Future<AudioNote?> recordAudio(BuildContext context) =>
    showModalBottomSheet<AudioNote>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      useSafeArea: true,
      builder: (_) => const _Recorder(),
    );

Future<String?> dictateTask(BuildContext context) async {
  final note = await recordAudio(context);
  if (note == null || !context.mounted) return null;
  try {
    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _Transcription(note),
    );
  } finally {
    await DeviceAssistant.removeAudio(note.id);
  }
}

class _Transcription extends StatefulWidget {
  final AudioNote note;
  const _Transcription(this.note);
  @override
  State<_Transcription> createState() => _TranscriptionState();
}

class _TranscriptionState extends State<_Transcription> {
  String? _error;
  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final text = await DeviceAssistant.call<String>(
        'transcribe',
        widget.note.id,
      );
      if (mounted) Navigator.pop(context, text);
    } catch (e) {
      if (mounted) setState(() => _error = deviceError(e));
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _error != null,
    child: AlertDialog(
      title: const Text('Votre voix devient une tâche'),
      content: _error == null
          ? const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Transcription en français…'),
              ],
            )
          : Text(_error!),
      actions: _error == null
          ? null
          : [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
            ],
    ),
  );
}

class _Recorder extends StatefulWidget {
  const _Recorder();
  @override
  State<_Recorder> createState() => _RecorderState();
}

class _RecorderState extends State<_Recorder> with WidgetsBindingObserver {
  bool _recording = false, _busy = false;
  String? _error;
  int _seconds = 0;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _recording && !_busy) _stop();
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await DeviceAssistant.call('recordStart');
      if (!mounted) {
        await DeviceAssistant.call('recordCancel');
        return;
      }
      setState(() {
        _recording = true;
        _seconds = 0;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _seconds++);
        if (_seconds >= 180) _stop();
      });
    } catch (e) {
      if (mounted) setState(() => _error = deviceError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    if (_busy) return;
    _timer?.cancel();
    setState(() => _busy = true);
    try {
      final note = await DeviceAssistant.stopRecording();
      _recording = false;
      if (mounted) Navigator.pop(context, note);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = deviceError(e);
          _recording = false;
          _busy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (_recording) {
      unawaited(DeviceAssistant.call('recordCancel').catchError((_) => null));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Une idée à voix haute',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            _recording
                ? '● Enregistrement · ${_seconds ~/ 60}:${(_seconds % 60).toString().padLeft(2, '0')}'
                : 'Jusqu’à 3 minutes. L’audio reste dans MyAgenda ; une dictée est transcrite par Apple avec votre autorisation.',
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy
                ? null
                : _recording
                ? _stop
                : _start,
            icon: Icon(_recording ? Icons.stop : Icons.mic),
            label: Text(
              _busy
                  ? 'Un instant…'
                  : _recording
                  ? 'Arrêter et utiliser'
                  : 'Commencer l’enregistrement',
            ),
          ),
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
        ],
      ),
    ),
  );
}

class AudioNotesEditor extends StatefulWidget {
  final List<AudioNote> value;
  final ValueChanged<List<AudioNote>> onChanged;
  final ValueChanged<bool>? onBusy;
  const AudioNotesEditor({
    super.key,
    required this.value,
    required this.onChanged,
    this.onBusy,
  });
  @override
  State<AudioNotesEditor> createState() => _AudioNotesEditorState();
}

class _AudioNotesEditorState extends State<AudioNotesEditor> {
  String? _playing;
  bool _busy = false;
  @override
  void dispose() {
    if (_playing != null) {
      unawaited(DeviceAssistant.call('audioStop').catchError((_) => null));
    }
    super.dispose();
  }

  Future<void> _play(AudioNote note) async {
    try {
      if (_playing != null) {
        await DeviceAssistant.call('audioStop');
        if (!mounted) return;
        setState(() => _playing = null);
        return;
      }
      setState(() => _playing = note.id);
      await DeviceAssistant.call('audioPlay', note.id);
    } catch (e) {
      if (mounted) toast(context, deviceError(e));
    } finally {
      if (mounted) setState(() => _playing = null);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final note in widget.value)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: IconButton(
            tooltip: _playing == note.id
                ? 'Arrêter la lecture'
                : 'Écouter la note',
            onPressed: () => _play(note),
            icon: Icon(
              _playing == note.id
                  ? Icons.stop_circle
                  : Icons.play_circle_outline,
            ),
          ),
          title: Text(note.name),
          subtitle: Text('${note.seconds} secondes'),
          trailing: IconButton(
            tooltip: 'Retirer la note audio',
            icon: const Icon(Icons.close),
            onPressed: () async {
              if (_playing == note.id) {
                await DeviceAssistant.call('audioStop');
              }
              if (mounted) {
                widget.onChanged(
                  widget.value.where((n) => n.id != note.id).toList(),
                );
              }
            },
          ),
        ),
      if (DeviceAssistant.supported)
        OutlinedButton.icon(
          onPressed: _busy || widget.value.length >= 8
              ? null
              : () async {
                  setState(() => _busy = true);
                  widget.onBusy?.call(true);
                  try {
                    final note = await recordAudio(context);
                    if (note != null) {
                      if (mounted) {
                        widget.onChanged([...widget.value, note]);
                      } else {
                        await DeviceAssistant.removeAudio(note.id);
                      }
                    }
                  } finally {
                    if (mounted) {
                      setState(() => _busy = false);
                      widget.onBusy?.call(false);
                    }
                  }
                },
          icon: const Icon(Icons.mic_none),
          label: const Text('Joindre une note audio'),
        )
      else
        const Text('L’enregistrement audio est disponible sur iPhone.'),
    ],
  );
}
