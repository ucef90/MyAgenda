import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_agenda/models/task.dart';
import 'package:my_agenda/models/workspace.dart';
import 'package:my_agenda/services/ios_alerts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2030, 1, 7, 9);
  const enabled = Preferences(
    remindersEnabled: true,
    liveActivitiesEnabled: true,
  );
  test('Migrate preferences without enabling alerts silently', () {
    final old = const Preferences().toJson()
      ..remove('remindersEnabled')
      ..remove('liveActivitiesEnabled')
      ..remove('reminderLeadMinutes');
    final p = Preferences.fromJson(old);
    expect(p.remindersEnabled, false);
    expect(p.liveActivitiesEnabled, false);
    final restored = Preferences.fromJson(
      enabled.copyWith(reminderLeadMinutes: 15).toJson(),
    );
    expect(restored.remindersEnabled, true);
    expect(restored.liveActivitiesEnabled, true);
    expect(restored.reminderLeadMinutes, 15);
  });
  test(
    'Reminder uses schedule then deadline, sorts and excludes closed or running tasks',
    () {
      final at = now.add(const Duration(hours: 1));
      final w = Workspace(
        preferences: enabled,
        tasks: [
          Task(
            id: 'scheduled',
            title: 'Piano',
            scheduledAt: at,
            deadline: at.add(const Duration(days: 1)),
          ),
          Task(
            id: 'deadline',
            title: 'Livraison',
            deadline: at.add(const Duration(minutes: 30)),
          ),
          Task(
            id: 'done',
            title: 'Fini',
            scheduledAt: at,
            status: TaskStatus.completed,
          ),
          Task(
            id: 'cancel',
            title: 'Annulé',
            scheduledAt: at,
            status: TaskStatus.cancelled,
          ),
          Task(
            id: 'running',
            title: 'Focus',
            scheduledAt: at,
            runningSince: now,
          ),
          const Task(id: 'no-date', title: 'Un jour'),
        ],
      );
      final plan = ReminderPlan.build(w, now);
      expect(plan.pending.map((e) => e.id), [
        'scheduled-before',
        'scheduled-start',
        'deadline-before',
        'deadline-start',
      ]);
      expect(plan.pending[1].at, at);
      expect(plan.pending[2].body, contains('Échéance'));
      expect(
        ReminderPlan.build(
          w.copyWith(preferences: const Preferences()),
          now,
        ).pending,
        isEmpty,
      );
      expect(
        ReminderPlan.build(w.copyWith(tasks: []), now).validEvents,
        isEmpty,
      );
    },
  );
  test(
    'Keep delivered reminders valid but never reschedule past events; cap future requests',
    () {
      final tasks = List.generate(
        40,
        (i) => Task(
          id: '$i',
          title: 'Tâche $i',
          scheduledAt: now.add(Duration(hours: i)),
        ),
      );
      final plan = ReminderPlan.build(
        Workspace(preferences: enabled, tasks: tasks),
        now,
      );
      expect(plan.pending.length, 60);
      expect(plan.omitted, 18);
      expect(plan.validEvents.containsKey('0-start'), true);
      expect(plan.pending.every((e) => e.at.isAfter(now)), true);
      expect(plan.pending.last.at.isBefore(tasks.last.scheduledAt!), true);
    },
  );
  test(
    'Running task takes precedence; pause and completion change live card',
    () {
      final due = Task(
        id: 'due',
        title: 'À faire',
        scheduledAt: now.subtract(const Duration(minutes: 10)),
        minutes: 30,
      );
      final running = Task(
        id: 'focus',
        title: 'Concentration',
        status: TaskStatus.inProgress,
        runningSince: now.subtract(const Duration(minutes: 3)),
        elapsedSeconds: 120,
      );
      var w = Workspace(preferences: enabled, tasks: [due, running]);
      var live = liveTaskPayload(w, now)!;
      expect(live['id'], 'focus');
      expect(live['mode'], 'running');
      expect(
        live['start'],
        now.subtract(const Duration(minutes: 5)).millisecondsSinceEpoch / 1000,
      );
      w = w.copyWith(
        tasks: [
          const Task(
            id: 'pause',
            title: 'Pause',
            status: TaskStatus.inProgress,
            elapsedSeconds: 400,
          ),
        ],
      );
      expect(liveTaskPayload(w, now)!['mode'], 'paused');
      w = w.copyWith(tasks: [due]);
      expect(liveTaskPayload(w, now)!['mode'], 'due');
      expect(liveTaskPayload(w, now.add(const Duration(hours: 1))), isNull);
      expect(
        liveTaskPayload(
          w.copyWith(tasks: [due.copyWith(status: TaskStatus.completed)]),
          now,
        ),
        isNull,
      );
      expect(
        liveTaskPayload(w.copyWith(preferences: const Preferences()), now),
        isNull,
      );
    },
  );
  test(
    'Bridge retries failures, deduplicates, and sends removals after completion',
    () async {
      final calls = <MethodCall>[];
      var fail = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(IOSAlerts.channel, (call) async {
            calls.add(call);
            if (fail) {
              fail = false;
              throw PlatformException(code: 'temporary');
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(IOSAlerts.channel, null),
      );
      final service = IOSAlerts(supportedOverride: true);
      final task = Task(
        id: 'a',
        title: 'Réunion',
        scheduledAt: now.add(const Duration(hours: 1)),
      );
      final w = Workspace(preferences: enabled, tasks: [task]);
      await expectLater(
        service.sync(w, now),
        throwsA(isA<PlatformException>()),
      );
      await service.sync(w, now);
      expect(calls.length, 3);
      await service.sync(w, now);
      expect(calls.length, 3);
      await service.sync(
        w.copyWith(tasks: [task.copyWith(status: TaskStatus.completed)]),
        now,
      );
      expect((calls.last.arguments as Map)['events'], isEmpty);
      expect((calls.last.arguments as Map)['validEvents'], isEmpty);
    },
  );
}
