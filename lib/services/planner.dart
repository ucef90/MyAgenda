import '../core/format.dart';
import '../models/task.dart';
import '../models/workspace.dart';

class TimeSlot {
  final DateTime start, end;
  const TimeSlot(this.start, this.end);
  int get minutes => end.difference(start).inMinutes;
  bool overlaps(TimeSlot other) =>
      start.isBefore(other.end) && end.isAfter(other.start);
}

class PlanProposal {
  final Map<String, DateTime> assignments;
  final List<Task> unplaced;
  const PlanProposal(this.assignments, this.unplaced);
}

class Planner {
  const Planner();
  List<TimeSlot> freeSlots(
    DateTime day,
    Preferences p,
    List<Task> tasks, {
    DateTime? notBefore,
    String? excludeId,
  }) {
    if (!p.weekdays.contains(day.weekday)) return [];
    final start = atMinute(day, p.workStart), end = atMinute(day, p.workEnd);
    if (!end.isAfter(start)) return [];
    final occupied =
        <TimeSlot>[
            if (p.breakEnd > p.breakStart)
              TimeSlot(atMinute(day, p.breakStart), atMinute(day, p.breakEnd)),
            for (final t in tasks)
              if (t.id != excludeId &&
                  t.status != TaskStatus.cancelled &&
                  t.scheduledAt != null)
                TimeSlot(t.scheduledAt!, t.scheduledEnd!),
          ].where((s) => s.start.isBefore(end) && s.end.isAfter(start)).toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    var cursor = notBefore != null && notBefore.isAfter(start)
        ? notBefore
        : start;
    if (notBefore != null && cursor == notBefore) {
      final epoch = cursor.millisecondsSinceEpoch;
      cursor = DateTime.fromMillisecondsSinceEpoch(
        ((epoch + 299999) ~/ 300000) * 300000,
      );
    }
    final result = <TimeSlot>[];
    for (final busy in occupied) {
      if (cursor.isBefore(busy.start) && cursor.isBefore(end)) {
        result.add(
          TimeSlot(cursor, busy.start.isBefore(end) ? busy.start : end),
        );
      }
      if (busy.end.isAfter(cursor)) cursor = busy.end;
    }
    if (cursor.isBefore(end)) result.add(TimeSlot(cursor, end));
    return result.where((s) => s.minutes > 0).toList();
  }

  bool canSchedule(Task task, DateTime start, Workspace w, {DateTime? now}) {
    if (now != null && start.isBefore(now)) return false;
    final end = start.add(Duration(minutes: task.minutes));
    if (task.earliest != null && start.isBefore(task.earliest!)) return false;
    if (task.deadline != null && end.isAfter(task.deadline!)) return false;
    return freeSlots(
      start,
      task.personalTime ? w.preferences.personalWindow : w.preferences,
      w.tasks,
      excludeId: task.id,
    ).any((s) => !start.isBefore(s.start) && !end.isAfter(s.end));
  }

  List<TimeSlot> suggest(
    Task task,
    Workspace w,
    DateTime now, {
    int days = 30,
  }) {
    final result = <TimeSlot>[];
    for (var i = 0; i < days && result.length < 3; i++) {
      final day = DateTime(now.year, now.month, now.day + i);
      for (final slot in freeSlots(
        day,
        task.personalTime ? w.preferences.personalWindow : w.preferences,
        w.tasks,
        notBefore: now,
        excludeId: task.id,
      )) {
        var start = task.earliest != null && task.earliest!.isAfter(slot.start)
            ? task.earliest!
            : slot.start;
        // Round upwards to the next five-minute boundary; never propose the past.
        final epoch = start.millisecondsSinceEpoch;
        start = DateTime.fromMillisecondsSinceEpoch(
          ((epoch + 299999) ~/ 300000) * 300000,
        );
        final end = start.add(Duration(minutes: task.minutes));
        if (!end.isAfter(slot.end) &&
            (task.deadline == null || !end.isAfter(task.deadline!))) {
          result.add(TimeSlot(start, end));
        }
        if (result.length == 3) break;
      }
    }
    return result;
  }

  PlanProposal planDay(Workspace w, DateTime day, DateTime now) {
    final pending =
        w.tasks.where((t) => t.isOpen && t.scheduledAt == null).toList()
          ..sort((a, b) {
            final priority = b.priority.index.compareTo(a.priority.index);
            return priority != 0
                ? priority
                : (a.deadline ?? DateTime(9999)).compareTo(
                    b.deadline ?? DateTime(9999),
                  );
          });
    var preview = w;
    final assignments = <String, DateTime>{};
    final unplaced = <Task>[];
    for (final task in pending) {
      final start = dayOnly(day).isAfter(now) ? dayOnly(day) : now;
      final slots = suggest(
        task,
        preview,
        start,
        days: 1,
      ).where((s) => sameDay(s.start, day));
      if (slots.isEmpty) {
        unplaced.add(task);
        continue;
      }
      assignments[task.id] = slots.first.start;
      preview = preview.copyWith(
        tasks: preview.tasks
            .map(
              (t) => t.id == task.id
                  ? t.copyWith(
                      scheduledAt: slots.first.start,
                      status: TaskStatus.planned,
                    )
                  : t,
            )
            .toList(),
      );
    }
    return PlanProposal(assignments, unplaced);
  }
}
