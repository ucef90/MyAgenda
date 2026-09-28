import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import '../models/workspace.dart';

class TaskReminder {
  final String id, taskId, title, body;
  final DateTime at;
  const TaskReminder({
    required this.id,
    required this.taskId,
    required this.title,
    required this.body,
    required this.at,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'taskId': taskId,
    'title': title,
    'body': body,
    'at': at.millisecondsSinceEpoch / 1000,
  };
}

/// Pure scheduling logic, independent from iOS permissions and UI.
class ReminderPlan {
  final List<TaskReminder> pending;
  final Map<String, double> validEvents;
  final int omitted;
  const ReminderPlan(this.pending, this.validEvents, this.omitted);
  factory ReminderPlan.build(Workspace w, DateTime now) {
    if (!w.preferences.remindersEnabled) return const ReminderPlan([], {}, 0);
    final events = <TaskReminder>[];
    for (final task in w.tasks.where(
      (t) => t.isOpen && t.runningSince == null,
    )) {
      final at = task.scheduledAt ?? task.deadline;
      if (at == null) continue;
      final deadline = task.scheduledAt == null;
      events.add(
        TaskReminder(
          id: '${task.id}-start',
          taskId: task.id,
          title: task.title,
          body: deadline
              ? 'Échéance maintenant. Ouvrez votre tâche.'
              : 'C’est le moment · ${task.minutes} min prévues. Touchez pour ouvrir.',
          at: at,
        ),
      );
      final lead = w.preferences.reminderLeadMinutes;
      if (lead > 0) {
        events.add(
          TaskReminder(
            id: '${task.id}-before',
            taskId: task.id,
            title: task.title,
            body: deadline
                ? 'Échéance dans $lead minutes.'
                : 'Votre tâche commence dans $lead minutes.',
            at: at.subtract(Duration(minutes: lead)),
          ),
        );
      }
    }
    events.sort((a, b) => a.at.compareTo(b.at));
    final future = events.where((e) => e.at.isAfter(now)).toList();
    // Keep headroom below the iOS limit (64) for the notification test.
    return ReminderPlan(future.take(60).toList(), {
      for (final e in events) e.id: e.at.millisecondsSinceEpoch / 1000,
    }, (future.length - 60).clamp(0, future.length));
  }
}

Task? lockScreenTask(Workspace w, DateTime now) {
  final open = w.tasks.where((t) => t.isOpen).toList();
  final running = open.where((t) => t.runningSince != null).firstOrNull;
  if (running != null) return running;
  final due =
      open
          .where(
            (t) =>
                t.scheduledAt != null &&
                !t.scheduledAt!.isAfter(now) &&
                t.scheduledEnd!.isAfter(now),
          )
          .toList()
        ..sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));
  if (due.isNotEmpty) return due.first;
  return open.where((t) => t.status == TaskStatus.inProgress).firstOrNull;
}

Map<String, dynamic>? liveTaskPayload(Workspace w, DateTime now) {
  if (!w.preferences.liveActivitiesEnabled) return null;
  final task = lockScreenTask(w, now);
  if (task == null) return null;
  final running = task.runningSince != null;
  final paused = !running && task.status == TaskStatus.inProgress;
  final start = running
      ? task.runningSince!.subtract(Duration(seconds: task.elapsedSeconds))
      : task.scheduledAt;
  final end = running
      ? start!.add(Duration(minutes: task.minutes))
      : task.scheduledEnd;
  return {
    'id': task.id,
    'title': task.title,
    'minutes': task.minutes,
    'mode': running
        ? 'running'
        : paused
        ? 'paused'
        : 'due',
    'start': start == null ? null : start.millisecondsSinceEpoch / 1000,
    'end': end == null ? null : end.millisecondsSinceEpoch / 1000,
    'elapsedSeconds': task.elapsedSeconds,
    'progress': task.progress,
  };
}

class IOSAlertStatus {
  final bool supported, authorized, denied, liveSupported, liveEnabled;
  final int pending;
  const IOSAlertStatus({
    this.supported = false,
    this.authorized = false,
    this.denied = false,
    this.liveSupported = false,
    this.liveEnabled = false,
    this.pending = 0,
  });
  factory IOSAlertStatus.fromMap(Map<dynamic, dynamic> value) => IOSAlertStatus(
    supported: true,
    authorized: value['authorized'] == true,
    denied: value['denied'] == true,
    liveSupported: value['liveSupported'] == true,
    liveEnabled: value['liveEnabled'] == true,
    pending: value['pending'] as int? ?? 0,
  );
}

final iosAlertsProvider = Provider((ref) => IOSAlerts());
final alertErrorProvider = StateProvider<String?>((ref) => null);
final iosAlertStatusProvider = FutureProvider(
  (ref) => ref.watch(iosAlertsProvider).status(),
);

class IOSAlerts {
  static const channel = MethodChannel('fr.beyondexpertise.myagenda/alerts');
  final bool? supportedOverride;
  IOSAlerts({this.supportedOverride});
  bool get supported =>
      supportedOverride ??
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS);
  String? _lastReminders, _lastLive;
  Future<void> _queue = Future.value();
  Future<IOSAlertStatus> status() async {
    if (!supported) return const IOSAlertStatus();
    return IOSAlertStatus.fromMap(
      await channel.invokeMapMethod('status') ?? {},
    );
  }

  Future<bool> requestPermission() async =>
      supported &&
      await channel.invokeMethod<bool>('requestPermission') == true;
  Future<void> openSettings() async {
    if (supported) await channel.invokeMethod('openSettings');
  }

  Future<void> testNotification() async {
    if (supported) await channel.invokeMethod('testNotification');
  }

  Future<String?> initialTask() async =>
      supported ? channel.invokeMethod<String>('initialTask') : null;
  void listen(ValueChanged<String> onTask) {
    if (!supported) return;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'openTask' && call.arguments is String) {
        onTask(call.arguments as String);
      }
    });
  }

  void stopListening() {
    if (supported) channel.setMethodCallHandler(null);
  }

  Future<void> sync(Workspace w, DateTime now, {bool force = false}) {
    if (!supported) return Future.value();
    // Serialize edits: a slower old synchronization cannot overwrite a newer one.
    final run = _queue.then((_) async {
      final plan = ReminderPlan.build(w, now);
      final reminders = {
        'events': plan.pending.map((e) => e.toJson()).toList(),
        'validEvents': plan.validEvents,
      };
      final signature = jsonEncode(reminders);
      if (force || signature != _lastReminders) {
        await channel.invokeMethod('syncReminders', reminders);
        _lastReminders = signature;
      }
      final live = liveTaskPayload(w, now);
      final liveSignature = jsonEncode(live);
      if (force || liveSignature != _lastLive) {
        await channel.invokeMethod('syncLiveActivity', live);
        _lastLive = liveSignature;
      }
    });
    _queue = run.catchError((Object _) {});
    return run;
  }
}
