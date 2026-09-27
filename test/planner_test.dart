import 'package:flutter_test/flutter_test.dart';
import 'package:my_agenda/models/task.dart';
import 'package:my_agenda/models/workspace.dart';
import 'package:my_agenda/services/planner.dart';

void main() {
  const planner = Planner(), prefs = Preferences();
  final day = DateTime(2026, 9, 28);
  DateTime at(int h, [int m = 0]) => DateTime(2026, 9, 28, h, m);
  test(
    'Subtracts lunch and merges overlapping reservations without double counting',
    () {
      final slots = planner.freeSlots(day, prefs, [
        Task(id: 'a', title: 'a', scheduledAt: at(10), minutes: 90),
        Task(id: 'b', title: 'b', scheduledAt: at(11), minutes: 60),
        Task(id: 'c', title: 'c', scheduledAt: at(14), minutes: 120),
      ]);
      expect(slots.map((s) => [s.start, s.end]).toList(), [
        [at(9), at(10)],
        [at(13), at(14)],
        [at(16), at(18)],
      ]);
    },
  );
  test('Clips events spanning midnight and ignores cancelled reservations', () {
    final slots = planner.freeSlots(day, prefs, [
      Task(
        id: 'a',
        title: 'a',
        scheduledAt: DateTime(2026, 9, 27, 23),
        minutes: 660,
      ),
      Task(
        id: 'b',
        title: 'b',
        scheduledAt: at(14),
        minutes: 60,
        status: TaskStatus.cancelled,
      ),
    ]);
    expect(slots.first.start, at(10));
    expect(slots.last.minutes, 300);
  });
  test(
    'Completed reservations remain occupied and non-working days stay closed',
    () {
      expect(planner.freeSlots(DateTime(2026, 9, 27), prefs, []), isEmpty);
      final slots = planner.freeSlots(day, prefs, [
        Task(
          id: 'a',
          title: 'a',
          scheduledAt: at(9),
          minutes: 60,
          status: TaskStatus.completed,
        ),
      ]);
      expect(slots.first.start, at(10));
    },
  );
  test(
    'Suggestions never use the past, overlap a break or end after the deadline',
    () {
      final task = Task(id: 't', title: 't', minutes: 90, deadline: at(14));
      final slots = planner.suggest(task, const Workspace(), at(11, 1));
      expect(slots, isEmpty);
      final next = planner.suggest(
        task.copyWith(deadline: at(15)),
        const Workspace(),
        at(11, 1),
      );
      expect(next.single.start, at(13));
      expect(next.single.end, at(14, 30));
    },
  );
  test(
    'Earliest start is enforced and rescheduling excludes the task itself',
    () {
      final t = Task(
        id: 't',
        title: 't',
        minutes: 60,
        earliest: at(15),
        scheduledAt: at(15),
      );
      final w = Workspace(tasks: [t]);
      expect(planner.canSchedule(t, at(14), w), isFalse);
      expect(planner.canSchedule(t, at(15), w), isTrue);
      expect(planner.suggest(t, w, at(9)).first.start, at(15));
    },
  );
  test('Day planning respects priority and does not overlap assignments', () {
    final w = Workspace(
      tasks: [
        Task(id: 'normal', title: 'normal', minutes: 120, deadline: at(12)),
        Task(
          id: 'urgent',
          title: 'urgent',
          minutes: 120,
          deadline: at(12),
          priority: Priority.urgent,
        ),
      ],
    );
    final plan = planner.planDay(w, day, at(8));
    expect(plan.assignments, {'urgent': at(9)});
    expect(plan.unplaced.single.id, 'normal');
  });
  test(
    'Overdue status is computed and completed/cancelled tasks never become overdue',
    () {
      final t = Task(id: 't', title: 't', deadline: at(9));
      expect(t.overdueAt(at(10)), isTrue);
      expect(
        t.copyWith(status: TaskStatus.completed).overdueAt(at(10)),
        isFalse,
      );
      expect(
        t.copyWith(status: TaskStatus.cancelled).overdueAt(at(10)),
        isFalse,
      );
    },
  );
  test('Checklist progression has one source of truth', () {
    final t = Task(
      id: 't',
      title: 't',
      checklist: [
        for (var i = 0; i < 7; i++)
          ChecklistItem(id: '$i', title: 'Item', done: i < 3),
      ],
    );
    expect((t.progress * 100).round(), 43);
    expect(Task.fromJson(t.toJson()).completedItems, 3);
  });
}
