import 'package:flutter_test/flutter_test.dart';
import 'package:my_agenda/models/attachment.dart';
import 'package:my_agenda/models/personal_goal.dart';
import 'package:my_agenda/models/task.dart';
import 'package:my_agenda/models/workspace.dart';
import 'package:my_agenda/services/assistant.dart';
import 'package:my_agenda/services/planner.dart';
import 'package:my_agenda/repositories/workspace_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  const assistant = AgendaAssistant();
  final monday = DateTime(2030, 1, 7, 8);
  const sport = PersonalGoal(id: 'sport', title: 'Sport', minutes: 30);
  const music = PersonalGoal(
    id: 'music',
    title: 'Piano',
    minutes: 20,
    preferredTime: PreferredTime.evening,
    color: TaskColor.violet,
  );
  test(
    'Old saves migrate without losing data; new fields survive round trip',
    () {
      final old = const Workspace(
        tasks: [Task(id: 'old', title: 'Existing')],
      ).toJson();
      (old['preferences'] as Map).removeWhere(
        (key, value) => [
          'goals',
          'personalStart',
          'personalEnd',
          'personalDays',
          'bufferMinutes',
          'motivation',
        ].contains(key),
      );
      final migrated = Workspace.fromJson(old);
      expect(migrated.tasks.single.title, 'Existing');
      expect(migrated.preferences.goals, isEmpty);
      final task = migrated.tasks.single.copyWith(
        color: TaskColor.rose,
        personalTime: true,
        goalId: 'music',
        attachments: [
          const TaskAttachment(id: 'pic1', name: 'design.png', bytes: 100),
        ],
      );
      final restored = Workspace.fromJson(
        migrated
            .copyWith(
              tasks: [task],
              preferences: migrated.preferences.copyWith(
                goals: [music],
                motivation: 'Apprendre',
              ),
            )
            .toJson(),
      );
      expect(restored.tasks.single.color, TaskColor.rose);
      expect(restored.tasks.single.attachments.single.name, 'design.png');
      expect(restored.tasks.single.personalTime, isTrue);
      expect(
        restored.preferences.goals.single.preferredTime,
        PreferredTime.evening,
      );
    },
  );
  test(
    'Suggestions honor deadlines, buffers, lunch, preferences and each other',
    () {
      final w = Workspace(
        preferences: const Preferences(goals: [sport, music]),
        tasks: [
          Task(
            id: 'busy',
            title: 'Client',
            scheduledAt: DateTime(2030, 1, 7, 9),
            minutes: 60,
          ),
          Task(
            id: 'due',
            title: 'Livrer',
            deadline: DateTime(2030, 1, 7, 12),
            minutes: 40,
          ),
          const Task(id: 'later', title: 'Recherche', minutes: 60),
        ],
      );
      final brief = assistant.build(w, monday, monday);
      expect(brief.suggestions.first.task.id, 'due');
      var preview = w;
      for (final s in brief.suggestions) {
        expect(assistant.hasBreathingRoom(s.task, preview, monday), isTrue);
        preview = preview.copyWith(
          tasks: [...preview.tasks.where((t) => t.id != s.task.id), s.task],
        );
        if (s.newActivity) {
          expect(
            s.task.scheduledAt!.hour >= 13 || s.task.scheduledEnd!.hour <= 12,
            isTrue,
          );
        }
      }
      final piano = brief.suggestions.firstWhere(
        (s) => s.task.goalId == 'music',
      );
      expect(piano.task.scheduledAt!.hour, greaterThanOrEqualTo(18));
      expect(
        brief.suggestions.first.task.scheduledAt,
        DateTime(2030, 1, 7, 10, 10),
      );
    },
  );
  test('Weekend personal activities work outside professional hours', () {
    final saturday = DateTime(2030, 1, 12, 8);
    final w = const Workspace(preferences: Preferences(goals: [sport]));
    final s = assistant.build(w, saturday, saturday).suggestions.single;
    expect(s.task.personalTime, isTrue);
    expect(
      const Planner().canSchedule(
        s.task,
        s.task.scheduledAt!,
        w,
        now: saturday,
      ),
      isTrue,
    );
    expect(
      const Planner().canSchedule(
        s.task.copyWith(personalTime: false),
        s.task.scheduledAt!,
        w,
      ),
      isFalse,
    );
  });
  test(
    'Weekly target counts completed and planned, ignores cancelled and previous week',
    () {
      final tasks = [
        for (var i = 0; i < 3; i++)
          Task(
            id: 's$i',
            title: 'Sport',
            goalId: 'sport',
            scheduledAt: DateTime(2030, 1, 7 + i, 18),
            status: i == 0 ? TaskStatus.completed : TaskStatus.planned,
          ),
      ];
      final w = Workspace(
        tasks: tasks,
        preferences: const Preferences(goals: [sport]),
      );
      expect(assistant.weekCount(w, 'sport', monday), 3);
      expect(assistant.weekCount(w, 'sport', monday, completedOnly: true), 1);
      expect(
        assistant.build(w, DateTime(2030, 1, 10), monday).suggestions,
        isEmpty,
      );
      expect(
        assistant
            .build(
              w.copyWith(
                tasks: [tasks.first.copyWith(status: TaskStatus.cancelled)],
              ),
              monday,
              monday,
            )
            .suggestions
            .length,
        1,
      );
    },
  );
  test(
    'No suggestions in past, when disabled, or when insufficient free reserve',
    () {
      final w = Workspace(
        preferences: Preferences(
          goals: [sport],
          personalStart: 1080,
          personalEnd: 1120,
        ),
      );
      expect(assistant.build(w, monday, monday).suggestions, isEmpty);
      expect(
        assistant
            .build(
              w.copyWith(
                preferences: w.preferences.copyWith(
                  personalEnd: 1200,
                  goals: [sport.copyWith(enabled: false)],
                ),
              ),
              monday,
              monday,
            )
            .suggestions,
        isEmpty,
      );
      expect(
        assistant.build(w, monday, DateTime(2030, 1, 8)).suggestions,
        isEmpty,
      );
    },
  );
  test(
    'Accept uses latest task edits and rejects stale or duplicate slots',
    () async {
      final future = DateTime.now().add(const Duration(days: 7));
      final day = DateTime(future.year, future.month, future.day, 8);
      final w = Workspace(
        preferences: const Preferences(
          weekdays: [1, 2, 3, 4, 5, 6, 7],
          goals: [sport],
        ),
        tasks: const [Task(id: 't', title: 'Before')],
      );
      SharedPreferences.setMockInitialValues({
        WorkspaceStore.storageKey: jsonEncode(w.toJson()),
      });
      final store = WorkspaceStore(await SharedPreferences.getInstance());
      final proposals = assistant.build(w, day, DateTime.now()).suggestions;
      final work = proposals.firstWhere((s) => !s.newActivity);
      store.upsert(w.tasks.single.copyWith(title: 'Edited'));
      store.acceptSuggestion(work);
      expect(store.state.tasks.firstWhere((t) => t.id == 't').title, 'Edited');
      expect(() => store.acceptSuggestion(work), throwsStateError);
      final activity = proposals.firstWhere((s) => s.newActivity);
      store.acceptSuggestion(activity);
      expect(() => store.acceptSuggestion(activity), throwsStateError);
      await store.flush();
      final reload = WorkspaceStore(await SharedPreferences.getInstance());
      expect(reload.state.tasks.where((t) => t.goalId == 'sport').length, 1);
      store.dispose();
      reload.dispose();
    },
  );
}
