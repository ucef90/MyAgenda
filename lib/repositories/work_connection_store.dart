import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/work_connection.dart';
import '../services/work/work_gateway.dart';
import 'workspace_store.dart';

final workGatewayProvider = Provider<WorkGateway>((ref) => NativeWorkGateway());
final workConnectionProvider =
    StateNotifierProvider<WorkConnectionStore, WorkConnectionState>((ref) {
      final store = WorkConnectionStore(
        ref.read(workGatewayProvider),
        ref.read(workspaceProvider.notifier),
      );
      unawaited(store.restore());
      return store;
    });

class WorkConnectionState {
  final bool ready, connected, busy, trainingsOnly;
  final String? url, name, error;
  final DateTime? lastSync;
  final List<WorkProposal> proposals;
  const WorkConnectionState({
    this.ready = false,
    this.connected = false,
    this.busy = false,
    this.trainingsOnly = true,
    this.url,
    this.name,
    this.error,
    this.lastSync,
    this.proposals = const [],
  });
}

class WorkConnectionStore extends StateNotifier<WorkConnectionState> {
  final WorkGateway gateway;
  final WorkspaceStore workspace;
  WorkCredentials? _credentials;
  WorkConnectionStore(this.gateway, this.workspace)
    : super(const WorkConnectionState());
  void _state({
    bool busy = false,
    String? error,
    DateTime? lastSync,
    List<WorkProposal>? proposals,
  }) {
    if (!mounted) return;
    state = WorkConnectionState(
      ready: true,
      connected: _credentials != null,
      busy: busy,
      trainingsOnly: _credentials?.trainingsOnly ?? true,
      url: _credentials?.url,
      name: _credentials?.name,
      error: error,
      lastSync: lastSync ?? state.lastSync,
      proposals: proposals ?? state.proposals,
    );
  }

  String _message(Object e) => e is WorkError
      ? e.message
      : 'La connexion n’a pas pu être enregistrée. Réessayez.';
  Future<void> restore() async {
    try {
      _credentials = await gateway.read();
      _state();
    } catch (e) {
      _state(error: _message(e));
    }
  }

  Future<void> connect(
    String url,
    String code,
    String name, {
    bool trainingsOnly = true,
  }) async {
    if (state.busy || !state.ready) return;
    _state(busy: true);
    try {
      if (_credentials != null) {
        throw const WorkError(
          'Déconnectez l’appareil avant de changer de serveur.',
        );
      }
      final server = workServerUri(url).toString();
      if (name.trim().isEmpty || code.trim().isEmpty) {
        throw const WorkError(
          'Saisissez le nom de l’appareil et son code d’association.',
        );
      }
      final result = await gateway.request(
        server,
        '/v1/pair',
        body: {'code': code.trim(), 'name': name.trim()},
      );
      final credentials = WorkCredentials(
        url: server,
        token: result['token'],
        deviceId: result['deviceId'],
        name: name.trim(),
        trainingsOnly: trainingsOnly,
      );
      try {
        await gateway.save(credentials);
      } catch (_) {
        try {
          await gateway.request(
            server,
            '/v1/device',
            token: credentials.token,
            method: 'DELETE',
          );
        } catch (_) {
          /* No snapshot has been shared. */
        }
        rethrow;
      }
      _credentials = credentials;
      await _sync();
      _state();
    } catch (e) {
      _state(error: _message(e));
    }
  }

  Future<void> _sync() async {
    final c = _credentials;
    if (c == null) return;
    await workspace.flush();
    if (workspace.persistenceError != null) {
      throw const WorkError(
        'Sauvegardez vos données locales avant de synchroniser.',
      );
    }
    final tasks = workspace.snapshot.tasks
        .where(
          (t) =>
              c.trainingsOnly ? t.isTraining : t.professional || t.isTraining,
        )
        .map(sharedTask)
        .toList();
    if (tasks.length > 1000) {
      throw const WorkError(
        'Le partage est limité à 1 000 tâches. Réduisez le périmètre partagé.',
      );
    }
    // Advance durably before sending; timeouts must never replay an old revision.
    final next = c.copyWith(revision: c.revision + 1);
    await gateway.save(next);
    _credentials = next;
    final result = await gateway.request(
      next.url,
      '/v1/sync',
      token: next.token,
      body: {'revision': next.revision, 'tasks': tasks},
    );
    final proposals = (result['proposals'] as List)
        .map((j) => WorkProposal.fromJson(Map<String, dynamic>.from(j)))
        .where((p) => p.deviceId == next.deviceId)
        .toList();
    // A crash after local persistence but before server acknowledgement is safe.
    final pending = <WorkProposal>[];
    for (final p in proposals) {
      final task = workspace.snapshot.tasks
          .where((t) => t.id == p.taskId)
          .firstOrNull;
      if (task != null && p.alreadyApplied(task)) {
        await _resolveRemote(p, 'accepted');
      } else {
        pending.add(p);
      }
    }
    _state(busy: true, lastSync: DateTime.now(), proposals: pending);
  }

  Future<void> sync() async {
    if (state.busy || !state.ready || _credentials == null) return;
    _state(busy: true);
    try {
      await _sync();
      _state();
    } catch (e) {
      _state(error: _message(e));
    }
  }

  Future<void> setTrainingsOnly(bool value) async {
    if (state.busy || _credentials == null) return;
    _state(busy: true);
    try {
      final c = _credentials!.copyWith(trainingsOnly: value);
      await gateway.save(c);
      _credentials = c;
      await _sync();
      _state();
    } catch (e) {
      _state(error: _message(e));
    }
  }

  Future<void> _resolveRemote(WorkProposal p, String decision) async {
    final c = _credentials!;
    await gateway.request(
      c.url,
      '/v1/proposals/${Uri.encodeComponent(p.id)}/resolve',
      token: c.token,
      body: {'decision': decision},
    );
  }

  Future<void> decide(WorkProposal p, {required bool accept}) async {
    if (state.busy || _credentials == null) return;
    _state(busy: true);
    try {
      if (p.deviceId != _credentials!.deviceId ||
          !state.proposals.any((x) => x.id == p.id)) {
        throw const WorkError('Proposition introuvable. Actualisez.');
      }
      if (accept) {
        final task = workspace.snapshot.tasks
            .where((t) => t.id == p.taskId)
            .firstOrNull;
        if (task == null) {
          throw const WorkError(
            'La tâche a été supprimée. Refusez cette proposition.',
          );
        }
        workspace.upsert(p.apply(task));
        await workspace.flush();
        if (workspace.persistenceError != null) {
          throw const WorkError('La confirmation n’a pas pu être sauvegardée.');
        }
      }
      await _resolveRemote(p, accept ? 'accepted' : 'rejected');
      _state(
        busy: true,
        proposals: state.proposals.where((x) => x.id != p.id).toList(),
      );
      await _sync();
      _state();
    } catch (e) {
      _state(error: _message(e));
    }
  }

  Future<void> disconnect() async {
    if (state.busy || _credentials == null) return;
    _state(busy: true);
    try {
      final c = _credentials!;
      try {
        await gateway.request(
          c.url,
          '/v1/device',
          token: c.token,
          method: 'DELETE',
        );
      } on WorkError catch (e) {
        if (e.status != 401) rethrow;
      }
      await gateway.clear();
      _credentials = null;
      if (mounted) state = const WorkConnectionState(ready: true);
    } catch (e) {
      _state(
        error:
            '${_message(e)} La suppression des données partagées reste à confirmer.',
      );
    }
  }
}
