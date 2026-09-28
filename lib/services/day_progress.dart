import '../models/task.dart';
import '../core/format.dart';

enum DayPace { behind, onTime, ahead }

class DayProgress {
  final int completed, total;
  final double expectedMinutes, completedMinutes;
  final bool overdue;
  const DayProgress(
    this.completed,
    this.total,
    this.expectedMinutes,
    this.completedMinutes,
    this.overdue,
  );
  factory DayProgress.calculate(Iterable<Task> tasks, DateTime now) {
    final day = tasks
        .where(
          (t) =>
              t.status != TaskStatus.cancelled &&
              ((t.scheduledAt != null && sameDay(t.scheduledAt!, now)) ||
                  (t.scheduledAt == null &&
                      t.deadline != null &&
                      sameDay(t.deadline!, now))),
        )
        .toList();
    final expected = day.fold<double>(0, (sum, t) {
      final end = t.scheduledEnd ?? t.deadline!;
      return sum + (!end.isAfter(now) ? t.minutes : 0);
    });
    final done = day.where((t) => t.status == TaskStatus.completed).toList();
    return DayProgress(
      done.length,
      day.length,
      expected,
      done.fold<double>(0, (s, t) => s + t.minutes),
      day.any((t) => t.overdueAt(now)),
    );
  }
  double get fraction => total == 0 ? 0 : completed / total;
  DayPace get pace => overdue || completedMinutes < expectedMinutes
      ? DayPace.behind
      : completedMinutes > expectedMinutes
      ? DayPace.ahead
      : DayPace.onTime;
  String get label => total == 0
      ? 'Journée à organiser'
      : switch (pace) {
          DayPace.behind => 'En retard',
          DayPace.onTime => 'Dans les temps',
          DayPace.ahead => 'En avance',
        };
}
