import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import '../models/workspace.dart';
import '../services/planner.dart';
import 'demo_data.dart';

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
    state = next;
    _save();
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
        (old == null ||
            old.scheduledAt != task.scheduledAt ||
            old.minutes != task.minutes ||
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

  void savePreferences(Preferences p) =>
      _change(state.copyWith(preferences: p));
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
  void clearDemo() => _change(
    Workspace(preferences: Preferences(name: state.preferences.name)),
  );
  String export() => _corruptOnLoad
      ? prefs.getString(storageKey) ?? jsonEncode(state.toJson())
      : const JsonEncoder.withIndent('  ').convert(state.toJson());
}
