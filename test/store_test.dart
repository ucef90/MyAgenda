import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_agenda/models/task.dart';
import 'package:my_agenda/models/workspace.dart';
import 'package:my_agenda/repositories/workspace_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late WorkspaceStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      WorkspaceStore.storageKey: jsonEncode(const Workspace().toJson()),
    });
    prefs = await SharedPreferences.getInstance();
    store = WorkspaceStore(prefs);
  });
  tearDown(() async {
    await store.flush();
    store.dispose();
  });
  test('CRUD and checklist survive reloading the repository', () async {
    const t = Task(
      id: 'one',
      title: 'Ma tâche',
      checklist: [ChecklistItem(id: 'item', title: 'Vérifier')],
    );
    store.upsert(t);
    store.toggleItem(t, 'item');
    await store.flush();
    final reload = WorkspaceStore(prefs);
    expect(reload.state.tasks.single.completedItems, 1);
    reload.dispose();
    store.delete('one');
    await store.flush();
    expect(
      Workspace.fromJson(
        jsonDecode(prefs.getString(WorkspaceStore.storageKey)!),
      ).tasks,
      isEmpty,
    );
  });
  test(
    'Exactly one focus timer runs, and pausing persists accumulated time',
    () {
      store.upsert(
        Task(
          id: 'a',
          title: 'a',
          runningSince: DateTime.now().subtract(const Duration(seconds: 20)),
          status: TaskStatus.inProgress,
        ),
      );
      const b = Task(id: 'b', title: 'b');
      store.upsert(b);
      store.startFocus(b);
      expect(
        store.state.tasks.where((t) => t.runningSince != null).single.id,
        'b',
      );
      expect(
        store.state.tasks.firstWhere((t) => t.id == 'a').elapsedSeconds,
        greaterThanOrEqualTo(20),
      );
      store.pauseFocus(store.state.tasks.firstWhere((t) => t.id == 'b'));
      expect(store.state.tasks.where((t) => t.runningSince != null), isEmpty);
    },
  );
  test('Rejects impossible durations and stale scheduling conflicts', () {
    expect(
      () => store.upsert(const Task(id: 'bad', title: 'bad', minutes: -1)),
      throwsArgumentError,
    );
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final start = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9);
    store.savePreferences(const Preferences(weekdays: [1, 2, 3, 4, 5, 6, 7]));
    store.upsert(Task(id: 'a', title: 'a', scheduledAt: start, minutes: 60));
    expect(
      () => store.upsert(
        Task(id: 'b', title: 'b', scheduledAt: start, minutes: 30),
      ),
      throwsStateError,
    );
    expect(store.state.tasks.length, 1);
  });
  test('Reopening a cancelled task rechecks its old reservation', () {
    store.savePreferences(const Preferences(weekdays: [1, 2, 3, 4, 5, 6, 7]));
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final start = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9);
    final first = Task(id: 'first', title: 'Formation', scheduledAt: start);
    store.upsert(first);
    store.setStatus(first, TaskStatus.cancelled);
    final cancelled = store.state.tasks.single;
    final second = Task(id: 'second', title: 'Réunion', scheduledAt: start);
    store.upsert(second);

    expect(
      () => store.setStatus(cancelled, TaskStatus.planned),
      throwsStateError,
    );
    expect(store.state.tasks.first.status, TaskStatus.cancelled);
    store.setStatus(second, TaskStatus.cancelled);
    store.setStatus(cancelled, TaskStatus.planned);
    expect(store.state.tasks.last.status, TaskStatus.planned);
  });
  test('Closed tasks cannot restart a focus timer through a stale screen', () {
    const task = Task(id: 'closed', title: 'Support');
    store.upsert(task);
    store.setStatus(task, TaskStatus.cancelled);
    expect(() => store.startFocus(task), throwsStateError);
    expect(store.state.tasks.single.runningSince, isNull);
    expect(store.state.tasks.single.status, TaskStatus.cancelled);
    store.setStatus(store.state.tasks.single, TaskStatus.completed);
    expect(() => store.startFocus(task), throwsStateError);
    expect(store.state.tasks.single.status, TaskStatus.completed);
  });
  test(
    'Starting with an empty workspace keeps all personal preferences',
    () async {
      const preferences = Preferences(
        name: 'Youssef',
        workStart: 480,
        workEnd: 1020,
        breakStart: 720,
        breakEnd: 750,
        weekdays: [1, 3, 5],
        dark: true,
      );
      store.savePreferences(preferences);
      store.upsert(const Task(id: 'demo', title: 'Exemple'));
      store.clearDemo();
      await store.flush();
      final reloaded = WorkspaceStore(prefs);
      expect(reloaded.state.tasks, isEmpty);
      expect(reloaded.state.demo, isFalse);
      expect(reloaded.state.preferences.toJson(), preferences.toJson());
      reloaded.dispose();
    },
  );
  test(
    'Corrupt local data is preserved and not silently replaced with demo data',
    () async {
      await prefs.setString(WorkspaceStore.storageKey, 'not json');
      final broken = WorkspaceStore(prefs);
      expect(broken.persistenceError, isNotNull);
      expect(broken.state.demo, isFalse);
      expect(broken.export(), 'not json');
      expect(
        () => broken.upsert(const Task(id: 'a', title: 'a')),
        throwsStateError,
      );
      broken.dispose();
    },
  );
}
