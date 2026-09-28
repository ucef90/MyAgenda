import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_agenda/models/task.dart';
import 'package:my_agenda/models/workspace.dart';
import 'package:my_agenda/services/calendar_import.dart';
import 'package:my_agenda/services/day_progress.dart';
import 'package:my_agenda/services/ios_alerts.dart';
import 'package:my_agenda/features/tasks/task_form.dart';
import 'package:my_agenda/repositories/workspace_store.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  test('Old tasks migrate without losing attachments and infer category', () {
    final json =
        const Task(
            id: 'old',
            title: 'Formation Power BI',
            professional: true,
          ).toJson()
          ..remove('category')
          ..remove('audioNotes')
          ..remove('preparation');
    final task = Task.fromJson(json);
    expect(task.resolvedCategory, TaskCategory.training);
    expect(task.preparationDone, 0);
    expect(task.preparation['order'], isNull);
    final edited = task.copyWith(
      category: TaskCategory.sport,
      preparation: {'order': true},
      audioNotes: [
        const AudioNote(id: 'audio', name: 'Note', seconds: 12, bytes: 100),
      ],
    );
    final restored = Task.fromJson(edited.toJson());
    expect(restored.resolvedCategory, TaskCategory.sport);
    expect(restored.audioNotes.single.seconds, 12);
    expect(restored.preparation['order'], true);
  });
  test(
    'Calendar reimport updates appointment without duplicating or erasing work',
    () {
      final event = CalendarEvent(
        id: 'external',
        title: 'Formation',
        calendar: 'Travail',
        start: DateTime(2030, 1, 7, 10),
        end: DateTime(2030, 1, 7, 12),
      );
      final first = mergeCalendarEvents([], [event]);
      final edited = first.single.copyWith(
        notes: 'Préparation privée',
        preparation: {'support': true},
      );
      final moved = CalendarEvent(
        id: event.id,
        title: 'Formation déplacée',
        calendar: 'Travail',
        start: DateTime(2030, 1, 8, 10),
        end: DateTime(2030, 1, 8, 12),
      );
      final second = mergeCalendarEvents([edited], [moved, moved]);
      expect(second.length, 1);
      expect(second.single.notes, 'Préparation privée');
      expect(second.single.preparation['support'], true);
      expect(second.single.scheduledAt, moved.start);
      final complete = second.single.copyWith(status: TaskStatus.completed);
      expect(
        mergeCalendarEvents([complete], [event]).single.status,
        TaskStatus.completed,
      );
    },
  );
  test('Pace compares completed tasks against planned finish times', () {
    final now = DateTime(2030, 1, 7, 10);
    final future = Task(
      id: 'future',
      title: 'Sport',
      scheduledAt: DateTime(2030, 1, 7, 11),
    );
    expect(DayProgress.calculate([future], now).pace, DayPace.onTime);
    expect(
      DayProgress.calculate([
        future.copyWith(status: TaskStatus.completed),
      ], now).pace,
      DayPace.ahead,
    );
    final missed = future.copyWith(scheduledAt: DateTime(2030, 1, 7, 9));
    expect(missed.overdueAt(now), true);
    expect(DayProgress.calculate([missed], now).pace, DayPace.behind);
    expect(
      DayProgress.calculate([
        missed.copyWith(status: TaskStatus.completed),
      ], now).fraction,
      1,
    );
  });
  test(
    'Lock screen has next task and end notification follows remaining focus time',
    () {
      final now = DateTime(2030, 1, 7, 10);
      final current = Task(
        id: 'a',
        title: 'Focus',
        minutes: 30,
        runningSince: now,
        elapsedSeconds: 600,
        status: TaskStatus.inProgress,
      );
      final next = Task(
        id: 'b',
        title: 'Piano',
        scheduledAt: now.add(const Duration(hours: 1)),
      );
      final w = Workspace(
        tasks: [current, next],
        preferences: const Preferences(
          remindersEnabled: true,
          liveActivitiesEnabled: true,
        ),
      );
      expect(liveTaskPayload(w, now)!['nextTitle'], 'Piano');
      final end = ReminderPlan.build(
        w,
        now,
      ).pending.firstWhere((e) => e.id == 'a-end');
      expect(end.at, now.add(const Duration(minutes: 20)));
      expect(end.kind, 'end');
      expect(
        ReminderPlan.build(
          w.copyWith(
            tasks: [
              current.copyWith(
                status: TaskStatus.completed,
                runningSince: null,
              ),
            ],
          ),
          now,
        ).pending,
        isEmpty,
      );
    },
  );
  testWidgets(
    'Save stays visible on small screen above keyboard and really persists',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        WorkspaceStore.storageKey:
            '{"version":1,"tasks":[],"clients":[],"missions":[],"preferences":{"name":"Youssef","workStart":540,"workEnd":1080,"breakStart":720,"breakEnd":780,"weekdays":[1,2,3,4,5]}}',
      });
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [preferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            locale: const Locale('fr'),
            supportedLocales: const [Locale('fr')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showTaskForm(context),
                  child: const Text('Ajouter'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ajouter'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Que devez-vous faire ?'),
        'Pratiquer la guitare',
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 290);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('save-task')).hitTestable(), findsOneWidget);
      await tester.tap(find.byKey(const Key('save-task')));
      await tester.pumpAndSettle();
      expect(
        prefs.getString(WorkspaceStore.storageKey),
        contains('Pratiquer la guitare'),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
