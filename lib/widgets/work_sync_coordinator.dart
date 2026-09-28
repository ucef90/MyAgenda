import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/work_connection_store.dart';
import '../repositories/workspace_store.dart';

class WorkSyncCoordinator extends ConsumerStatefulWidget {
  final Widget child;
  const WorkSyncCoordinator({super.key, required this.child});
  @override
  ConsumerState<WorkSyncCoordinator> createState() =>
      _WorkSyncCoordinatorState();
}

class _WorkSyncCoordinatorState extends ConsumerState<WorkSyncCoordinator>
    with WidgetsBindingObserver {
  Timer? _timer, _debounce;
  bool _foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _sync());
  }

  void _sync() {
    if (_foreground && mounted) {
      unawaited(ref.read(workConnectionProvider.notifier).sync());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) _sync();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(workspaceProvider, (_, next) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(seconds: 2), _sync);
    });
    ref.listen(workConnectionProvider.select((s) => s.ready && s.connected), (
      old,
      next,
    ) {
      if (next && old != true) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(seconds: 2), _sync);
      }
    });
    return widget.child;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _debounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
