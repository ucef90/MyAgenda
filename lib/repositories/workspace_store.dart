import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import '../models/workspace.dart';
import '../services/planner.dart';
import '../services/assistant.dart';
import '../core/format.dart';
import 'demo_data.dart';
import 'image_storage.dart' as images;

final preferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(),
);
final workspaceProvider = StateNotifierProvider<WorkspaceStore, Workspace>(
  (ref) => WorkspaceStore(ref.watch(preferencesProvider)),
);
final persistenceErrorProvider = Provider<String?>((ref) {
  ref.watch(workspaceProvider);
  return ref.read(workspaceProvider.notifier).persistenceError;
});
final clockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
});
String newId() => '${DateTime.now().microsecondsSinceEpoch}-${_counter++}';
int _counter = 0;

class WorkspaceStore extends StateNotifier<Workspace> {
  final SharedPreferences prefs;
  String? persistenceError;
  bool _corruptOnLoad = false;
  Future<void> _writes = Future.value();
  static const storageKey = 'myagenda.workspace.v1';
  WorkspaceStore(this.prefs) : super(const Workspace()) {
    final raw = prefs.getString(storageKey);
    if (raw == null) {
      state = demoWorkspace(DateTime.now());
      _save();
    } else {
      try {
        state = Workspace.fromJson(jsonDecode(raw));
      } catch (_) {
        _corruptOnLoad = true;
        persistenceError =
            'La sauvegarde locale est illisible. Elle a été conservée. Exportez-la depuis les paramètres.';
      }
    }
  }
  void _save() {
    if (persistenceError != null) return;
    final raw = jsonEncode(state.toJson());
    _writes = _writes.then((_) async {
      try {
        if (!await prefs.setString(storageKey, raw)) {
          throw StateError('write failed');
        }
      } catch (_) {
        persistenceError =
            'La sauvegarde a échoué. Exportez vos données avant de fermer l’application.';
        if (mounted) state = state.copyWith();
      }
    });
  }

  Future<void> flush() => _writes;
  void _change(Workspace next) {
    if (persistenceError != null) throw StateError(persistenceError!);
    final removed = state.tasks
        .expand((t) => t.attachments)
        .where(
          (a) => !next.tasks.any((t) => t.attachments.any((b) => b.id == a.id)),
        )
        .toList();
    state = next;
    _save();
    unawaited(
      flush().then((_) async {
        if (!mounted || persistenceError != null) return;
        for (final image in removed) {
          if (!state.tasks.any(
            (t) => t.attachments.any((a) => a.id == image.id),
          )) {
            try {
              await images.removeImage(image.id);
            } catch (_) {
              /* Keep an orphan rather than lose a task. */
            }
          }
        }
      }),
    );
  }

  void upsert(Task task) {
    if (task.title.trim().isEmpty || task.minutes < 5 || task.minutes > 1440) {
      throw ArgumentError('Titre et durée valides requis.');
    }
    if (task.deadline != null &&
        task.earliest != null &&
        task.deadline!.isBefore(task.earliest!)) {
      throw ArgumentError('L’échéance doit suivre la date de début.');
    }
    final old = state.tasks.where((t) => t.id == task.id).firstOrNull;
    if (task.scheduledAt != null &&
        task.status != TaskStatus.cancelled &&
        (old == null ||
            (old.status == TaskStatus.cancelled &&
                task.status != TaskStatus.cancelled) ||
            old.scheduledAt != task.scheduledAt ||
            old.minutes != task.minutes ||
            old.personalTime != task.personalTime ||
            old.deadline != task.deadline ||
            old.earliest != task.earliest) &&
        !const Planner().canSchedule(
          task,
          task.scheduledAt!,
          state,
          now: DateTime.now(),
        )) {
      throw StateError(
        'Ce créneau est indisponible ou dépasse votre échéance. Recherchez un autre créneau.',
      );
    }
    _change(
      state.copyWith(
        tasks: [...state.tasks.where((t) => t.id != task.id), task],
      ),
    );
  }

  void delete(String id) => _change(
    state.copyWith(tasks: state.tasks.where((t) => t.id != id).toList()),
  );
  void setStatus(Task task, TaskStatus status) => upsert(
    task.copyWith(
      status: status,
      elapsedSeconds: task.secondsAt(DateTime.now()),
      runningSince: null,
    ),
  );
  void toggleItem(Task task, String id) => upsert(
    task.copyWith(
      checklist: task.checklist
          .map((i) => i.id == id ? i.toggle() : i)
          .toList(),
    ),
  );
  void startFocus(Task task) {
    final current = state.tasks.where((t) => t.id == task.id).firstOrNull;
    if (current == null || !current.isOpen) {
      throw StateError('Rouvrez cette tâche avant de démarrer le focus.');
    }
    final now = DateTime.now();
    _change(
      state.copyWith(
        tasks: state.tasks
            .map(
              (t) => t.id == task.id
                  ? t.copyWith(
                      status: TaskStatus.inProgress,
                      runningSince: t.runningSince ?? now,
                    )
                  : t.runningSince != null
                  ? t.copyWith(
                      elapsedSeconds: t.secondsAt(now),
                      runningSince: null,
                    )
                  : t,
            )
            .toList(),
      ),
    );
  }

  void pauseFocus(Task task) => upsert(
    task.copyWith(
      elapsedSeconds: task.secondsAt(DateTime.now()),
      runningSince: null,
    ),
  );
  void schedule(Task task, DateTime at) =>
      upsert(task.copyWith(scheduledAt: at, status: TaskStatus.planned));
  void applyPlan(PlanProposal proposal) {
    var preview = state;
    final now = DateTime.now();
    for (final entry in proposal.assignments.entries) {
      final task = preview.tasks.where((t) => t.id == entry.key).firstOrNull;
      if (task == null ||
          !task.isOpen ||
          !const Planner().canSchedule(task, entry.value, preview, now: now)) {
        throw StateError('Le planning a changé. Recalculez les propositions.');
      }
      preview = preview.copyWith(
        tasks: preview.tasks
            .map(
              (t) => t.id == task.id
                  ? t.copyWith(
                      scheduledAt: entry.value,
                      status: TaskStatus.planned,
                    )
                  : t,
            )
            .toList(),
      );
    }
    _change(preview);
  }

  void acceptSuggestion(DaySuggestion suggestion) {
    final now = DateTime.now();
    var task = suggestion.task;
    if (suggestion.newActivity) {
      final goal = state.preferences.goals
          .where((g) => g.id == task.goalId && g.enabled)
          .firstOrNull;
      if (goal == null ||
          const AgendaAssistant().weekCount(
                state,
                goal.id,
                task.scheduledAt!,
              ) >=
              goal.weeklyTarget ||
          state.tasks.any(
            (t) =>
                t.goalId == goal.id &&
                t.status != TaskStatus.cancelled &&
                t.scheduledAt != null &&
                sameDay(t.scheduledAt!, task.scheduledAt!),
          )) {
        throw StateError(
          'Cet objectif a changé ou possède déjà une séance. Actualisez les suggestions.',
        );
      }
      if (!const AgendaAssistant()
          .build(state, task.scheduledAt!, now)
          .suggestions
          .any(
            (s) =>
                s.newActivity &&
                s.task.goalId == goal.id &&
                s.task.scheduledAt == task.scheduledAt,
          )) {
        throw StateError(
          'Vos disponibilités ou préférences ont changé. Actualisez les suggestions.',
        );
      }
      task = task.copyWith(
        title: goal.title,
        color: goal.color,
        minutes: goal.minutes,
      );
    } else {
      final current = state.tasks.where((t) => t.id == task.id).firstOrNull;
      if (current == null || !current.isOpen || current.scheduledAt != null) {
        throw StateError('Cette tâche a changé. Actualisez les suggestions.');
      }
      task = current.copyWith(
        scheduledAt: task.scheduledAt,
        status: TaskStatus.planned,
      );
    }
    if (!const AgendaAssistant().hasBreathingRoom(task, state, now)) {
      throw StateError(
        'Ce créneau n’est plus disponible. Actualisez les suggestions.',
      );
    }
    upsert(task);
  }

  void savePreferences(Preferences p) {
    if (p.personalStart < 0 ||
        p.personalEnd > 1440 ||
        p.personalStart >= p.personalEnd ||
        p.personalDays.isEmpty ||
        p.bufferMinutes < 0 ||
        p.bufferMinutes > 60 ||
        p.goals.any(
          (g) =>
              g.title.trim().isEmpty ||
              g.minutes < 5 ||
              g.minutes > 180 ||
              g.weeklyTarget < 1 ||
              g.weeklyTarget > 7,
        )) {
      throw ArgumentError(
        'Vérifiez vos horaires personnels, vos jours et vos activités.',
      );
    }
    _change(state.copyWith(preferences: p));
  }

  void saveClient(Client client) => _change(
    state.copyWith(
      clients: [...state.clients.where((c) => c.id != client.id), client],
    ),
  );
  void saveMission(Mission mission) => _change(
    state.copyWith(
      missions: [...state.missions.where((m) => m.id != mission.id), mission],
    ),
  );
  void clearDemo() => _change(Workspace(preferences: state.preferences));
  Future<String> exportWithImages() async {
    if (_corruptOnLoad) return export();
    final snapshot = state;
    final files = <String, String>{};
    for (final image in snapshot.tasks.expand((t) => t.attachments)) {
      final data = await images.readImage(image.id);
      if (data == null) {
        throw StateError(
          'Image manquante : ${image.name}. Export interrompu pour éviter une sauvegarde incomplète.',
        );
      }
      files[image.id] = base64Encode(data);
    }
    return jsonEncode({...snapshot.toJson(), 'imageFiles': files});
  }

  String export() => _corruptOnLoad
      ? prefs.getString(storageKey) ?? jsonEncode(state.toJson())
      : const JsonEncoder.withIndent('  ').convert(state.toJson());
}
