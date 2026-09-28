import '../models/task.dart';
import 'device_assistant.dart';

class CalendarEvent {
  final String id, title, calendar;
  final DateTime start, end;
  final bool allDay;
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.calendar,
    required this.start,
    required this.end,
    this.allDay = false,
  });
  factory CalendarEvent.fromJson(Map j) => CalendarEvent(
    id: j['id'],
    title: j['title'],
    calendar: j['calendar'],
    start: DateTime.fromMillisecondsSinceEpoch(
      (j['start'] as num).toInt() * 1000,
    ),
    end: DateTime.fromMillisecondsSinceEpoch((j['end'] as num).toInt() * 1000),
    allDay: j['allDay'] == true,
  );
  bool get canImport =>
      end.isAfter(start) && end.difference(start).inMinutes <= 1440;
  Task toTask() => Task(
    id: 'calendar-$id',
    title: title,
    calendarEventId: id,
    calendarName: calendar,
    scheduledAt: start,
    minutes: end.difference(start).inMinutes.clamp(5, 1440),
    professional: true,
    status: TaskStatus.planned,
  );
}

/// Imported commitments may be outside work hours or overlap. Never move them
/// silently to satisfy the planner. Reimport preserves local notes and progress.
List<Task> mergeCalendarEvents(List<Task> tasks, List<CalendarEvent> events) {
  final result = [...tasks];
  for (final event in events) {
    if (!event.canImport) continue;
    final index = result.indexWhere((t) => t.calendarEventId == event.id);
    if (index < 0) {
      result.add(event.toTask());
      continue;
    }
    final old = result[index];
    if (!old.isOpen || old.runningSince != null) continue;
    result[index] = old.copyWith(
      title: event.title,
      scheduledAt: event.start,
      minutes: event.end.difference(event.start).inMinutes.clamp(5, 1440),
      calendarName: event.calendar,
    );
  }
  return result;
}

Future<List<CalendarEvent>> readCalendarEvents(List<String> calendars) async {
  final values =
      await DeviceAssistant.call<List>('calendarEvents', calendars) ?? [];
  return values.map((e) => CalendarEvent.fromJson(e as Map)).toList();
}
