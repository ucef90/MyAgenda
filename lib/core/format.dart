import 'package:intl/intl.dart';

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime atMinute(DateTime day, int minute) =>
    DateTime(day.year, day.month, day.day, minute ~/ 60, minute % 60);
bool sameDay(DateTime a, DateTime b) => dayOnly(a) == dayOnly(b);
String clock(DateTime d) => DateFormat('HH:mm', 'fr').format(d);
String dayLabel(DateTime d) => DateFormat('EEEE d MMMM', 'fr').format(d);
String shortDate(DateTime d) => DateFormat('d MMM', 'fr').format(d);
String durationLabel(int minutes) => minutes < 60
    ? '$minutes min'
    : '${minutes ~/ 60}h${minutes % 60 == 0 ? '' : (minutes % 60).toString().padLeft(2, '0')}';
String deadlineLabel(DateTime? date) {
  if (date == null) return 'Sans échéance';
  if (sameDay(date, DateTime.now())) return 'Aujourd’hui ${clock(date)}';
  return '${shortDate(date)} · ${clock(date)}';
}
