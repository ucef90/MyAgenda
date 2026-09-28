import '../core/format.dart';
import '../models/personal_goal.dart';
import '../models/task.dart';
import '../models/workspace.dart';
import 'planner.dart';

class DaySuggestion {
  final Task task;
  final String reason;
  final bool newActivity;
  const DaySuggestion(this.task, this.reason, {this.newActivity = false});
}

class DayBrief {
  final List<DaySuggestion> suggestions;
  final List<Task> priorities, unplaced;
  final int plannedMinutes, freeMinutes;
  const DayBrief({
    required this.suggestions,
    required this.priorities,
    required this.unplaced,
    required this.plannedMinutes,
    required this.freeMinutes,
  });
}

/// Explicit preferences and calendar rules; no external model or inferred health data.
class AgendaAssistant {
  const AgendaAssistant();
  int weekCount(
    Workspace w,
    String goalId,
    DateTime day, {
    bool completedOnly = false,
  }) {
    final start = DateTime(day.year, day.month, day.day - day.weekday + 1);
    final end = DateTime(start.year, start.month, start.day + 7);
    return w.tasks
        .where(
          (t) =>
              t.goalId == goalId &&
              t.scheduledAt != null &&
              t.status != TaskStatus.cancelled &&
              (!completedOnly || t.status == TaskStatus.completed) &&
              !t.scheduledAt!.isBefore(start) &&
              t.scheduledAt!.isBefore(end),
        )
        .length;
  }

  Workspace _withBreathingRoom(Workspace w) => w.copyWith(
    tasks: [
      for (final t in w.tasks)
        if (t.scheduledAt != null && t.status != TaskStatus.cancelled)
          t.copyWith(
            scheduledAt: t.scheduledAt!.subtract(
              Duration(minutes: w.preferences.bufferMinutes),
            ),
            minutes: t.minutes + 2 * w.preferences.bufferMinutes,
          )
        else
          t,
    ],
  );
  bool hasBreathingRoom(Task task, Workspace w, DateTime now) =>
      task.scheduledAt != null &&
      const Planner().canSchedule(
        task,
        task.scheduledAt!,
        _withBreathingRoom(w),
        now: now,
      );

  DayBrief build(Workspace w, DateTime day, DateTime now) {
    final pending =
        w.tasks.where((t) => t.isOpen && t.scheduledAt == null).toList()..sort((
          a,
          b,
        ) {
          // Deadlines that have already passed require a new deadline, not an impossible slot.
          final aDue = a.deadline != null && sameDay(a.deadline!, day);
          final bDue = b.deadline != null && sameDay(b.deadline!, day);
          if (aDue != bDue) return aDue ? -1 : 1;
          final urgency = b.priority.index.compareTo(a.priority.index);
          if (urgency != 0) return urgency;
          return (a.deadline ?? DateTime(9999)).compareTo(
            b.deadline ?? DateTime(9999),
          );
        });
    final suggestions = <DaySuggestion>[];
    final unplaced = <Task>[];
    var preview = w;
    final from = dayOnly(day).isAfter(now) ? dayOnly(day) : now;
    for (final task in pending) {
      final slots = const Planner()
          .suggest(task, _withBreathingRoom(preview), from, days: 1)
          .where((s) => sameDay(s.start, day));
      if (slots.isEmpty || suggestions.length >= 3) {
        unplaced.add(task);
        continue;
      }
      final planned = task.copyWith(
        scheduledAt: slots.first.start,
        status: TaskStatus.planned,
      );
      suggestions.add(
        DaySuggestion(
          planned,
          task.deadline != null && sameDay(task.deadline!, day)
              ? 'Échéance aujourd’hui : un créneau avant votre limite.'
              : task.priority.index >= 2
              ? 'Priorité ${task.priority.label.toLowerCase()} : à avancer avant les tâches courantes.'
              : 'Un créneau de ${durationLabel(task.minutes)} disponible, avec une marge entre vos activités.',
        ),
      );
      preview = preview.copyWith(
        tasks: [...preview.tasks.where((t) => t.id != task.id), planned],
      );
    }
    // Rotate goals by remaining weekly need; never schedule more than one session per goal/day.
    final goals = w.preferences.goals.where((g) => g.enabled).toList()
      ..sort(
        (a, b) => (weekCount(w, a.id, day) / a.weeklyTarget).compareTo(
          weekCount(w, b.id, day) / b.weeklyTarget,
        ),
      );
    var activityCount = 0;
    for (final goal in goals) {
      final count = weekCount(preview, goal.id, day);
      if (count >= goal.weeklyTarget ||
          activityCount >= 2 ||
          preview.tasks.any(
            (t) =>
                t.goalId == goal.id &&
                t.status != TaskStatus.cancelled &&
                t.scheduledAt != null &&
                sameDay(t.scheduledAt!, day),
          )) {
        continue;
      }
      var startMinute = w.preferences.personalStart,
          endMinute = w.preferences.personalEnd;
      switch (goal.preferredTime) {
        case PreferredTime.morning:
          if (endMinute > 720) endMinute = 720;
        case PreferredTime.afternoon:
          if (startMinute < 720) startMinute = 720;
          if (endMinute > 1080) endMinute = 1080;
        case PreferredTime.evening:
          if (startMinute < 1080) startMinute = 1080;
        case PreferredTime.any:
          break;
      }
      if (endMinute <= startMinute) continue;
      final guarded = _withBreathingRoom(preview);
      final personal = w.preferences.personalWindow;
      // Preserve the usual lunch break on workdays as well as 30 minutes of unallocated personal time.
      final window = personal.copyWith(
        workStart: startMinute,
        workEnd: endMinute,
        breakStart: w.preferences.weekdays.contains(day.weekday)
            ? w.preferences.breakStart
            : 0,
        breakEnd: w.preferences.weekdays.contains(day.weekday)
            ? w.preferences.breakEnd
            : 0,
      );
      final allFree = const Planner().freeSlots(
        day,
        personal,
        guarded.tasks,
        notBefore: from,
      );
      if (allFree.fold<int>(0, (total, s) => total + s.minutes) <
          goal.minutes + 30) {
        continue;
      }
      final slots = const Planner()
          .freeSlots(day, window, guarded.tasks, notBefore: from)
          .where((s) => s.minutes >= goal.minutes);
      if (slots.isEmpty) continue;
      final at = slots.first.start;
      final task = Task(
        id: 'goal-${goal.id}-${at.millisecondsSinceEpoch}',
        title: goal.title,
        minutes: goal.minutes,
        color: goal.color,
        goalId: goal.id,
        personalTime: true,
        project: 'Mes objectifs',
        scheduledAt: at,
        status: TaskStatus.planned,
      );
      suggestions.add(
        DaySuggestion(
          task,
          'Votre objectif « ${goal.title} » : $count/${goal.weeklyTarget} séances prévues cette semaine. '
          'Ce créneau respecte vos disponibilités${goal.preferredTime == PreferredTime.any ? '' : ' (${goal.preferredTime.label.toLowerCase()})'}.',
          newActivity: true,
        ),
      );
      preview = preview.copyWith(tasks: [...preview.tasks, task]);
      activityCount++;
    }
    final priorities =
        w.tasks
            .where(
              (t) =>
                  t.isOpen &&
                  (t.overdueAt(now) ||
                      t.priority.index >= 2 ||
                      (t.deadline != null && sameDay(t.deadline!, day))),
            )
            .toList()
          ..sort(
            (a, b) => (a.deadline ?? DateTime(9999)).compareTo(
              b.deadline ?? DateTime(9999),
            ),
          );
    return DayBrief(
      suggestions: suggestions,
      priorities: priorities,
      unplaced: unplaced,
      plannedMinutes: w.tasks
          .where(
            (t) =>
                t.scheduledAt != null &&
                sameDay(t.scheduledAt!, day) &&
                t.status != TaskStatus.cancelled,
          )
          .fold(0, (total, t) => total + t.minutes),
      freeMinutes: const Planner()
          .freeSlots(
            day,
            w.preferences.personalWindow,
            w.tasks,
            notBefore: from,
          )
          .fold(0, (total, s) => total + s.minutes),
    );
  }
}
