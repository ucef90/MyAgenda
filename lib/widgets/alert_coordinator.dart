import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app.dart';
import '../models/task.dart';
import '../services/calendar_import.dart';
import '../models/workspace.dart';
import '../repositories/workspace_store.dart';
import '../services/ios_alerts.dart';

class AlertCoordinator extends ConsumerStatefulWidget {
  final Widget child;
  const AlertCoordinator({super.key, required this.child});
  @override
  ConsumerState<AlertCoordinator> createState() => _AlertCoordinatorState();
}

class _AlertCoordinatorState extends ConsumerState<AlertCoordinator>
    with WidgetsBindingObserver {
  late IOSAlerts _alerts;
  ProviderSubscription<Workspace>? _subscription;
  Timer? _timer;
  bool _foreground = true;
  @override
  void initState() {
    super.initState();
    _alerts = ref.read(iosAlertsProvider);
    if (!_alerts.supported) return;
    WidgetsBinding.instance.addObserver(this);
    _alerts.listen(_openTask);
    _subscription = ref.listenManual(workspaceProvider, (_, value) => _sync());
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _refreshCalendar();
      await _sync(force: true);
      try {
        final id = await _alerts.initialTask();
        if (id != null && mounted) _openTask(id);
      } catch (_) {
        /* A reminder tap must never prevent app launch. */
      }
    });
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_foreground) _sync();
    });
  }

  void _openTask(String id) {
    if (!mounted) return;
    final uri = Uri.tryParse(id);
    final action = uri?.scheme == 'myagenda'
        ? uri?.queryParameters['action']
        : null;
    if (uri?.scheme == 'myagenda') id = uri!.queryParameters['id'] ?? '';
    final task = ref
        .read(workspaceProvider)
        .tasks
        .where((t) => t.id == id)
        .firstOrNull;
    if (task != null && task.isOpen) {
      final store = ref.read(workspaceProvider.notifier);
      try {
        if (action == 'done') store.setStatus(task, TaskStatus.completed);
        if (action == 'later') store.setStatus(task, TaskStatus.inProgress);
        if (action == 'start') store.startFocus(task);
      } catch (_) {
        /* Keep task accessible if persistence fails. */
      }
    }
    final exists = ref.read(workspaceProvider).tasks.any((t) => t.id == id);
    ref
        .read(routerProvider)
        .go(exists ? '/task/${Uri.encodeComponent(id)}' : '/');
  }

  bool _calendarBusy = false;
  Future<void> _refreshCalendar() async {
    if (_calendarBusy || !mounted) return;
    final ids =
        ref.read(preferencesProvider).getStringList('myagenda.calendars') ?? [];
    if (ids.isEmpty) return;
    _calendarBusy = true;
    try {
      final events = await readCalendarEvents(ids);
      if (!mounted) return;
      final tasks = ref.read(workspaceProvider).tasks;
      final existing = events
          .where((e) => tasks.any((t) => t.calendarEventId == e.id))
          .toList();
      if (existing.isNotEmpty) {
        ref.read(workspaceProvider.notifier).importCalendar(existing);
      }
    } catch (_) {
      /* A revoked calendar permission must not block the agenda. */
    } finally {
      _calendarBusy = false;
    }
  }

  Future<void> _sync({bool force = false}) async {
    if (!mounted) return;
    // Only schedule a state that has reached persistent storage.
    final store = ref.read(workspaceProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await store.flush();
    if (!mounted || store.persistenceError != null) return;
    try {
      await _alerts.sync(
        ref.read(workspaceProvider),
        DateTime.now(),
        force: force,
      );
      if (mounted) ref.read(alertErrorProvider.notifier).state = null;
    } catch (_) {
      if (mounted) {
        ref.read(alertErrorProvider.notifier).state =
            'Les rappels ou l’activité en direct n’ont pas pu être actualisés. Vérifiez les autorisations puis réessayez.';
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      ref.invalidate(iosAlertStatusProvider);
      _refreshCalendar();
      _sync(force: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.close();
    _timer?.cancel();
    _alerts.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
