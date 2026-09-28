import 'dart:convert';
import 'task.dart';

// Deliberate allowlist: no notes, recordings, images, client contacts or tokens.
Map<String, dynamic> sharedTask(Task t) => {
  'id': t.id,
  'title': t.title,
  'project': t.project,
  'category': t.resolvedCategory.name,
  'professional': t.professional,
  'minutes': t.minutes,
  'scheduledAt': t.scheduledAt?.toUtc().toIso8601String(),
  'deadline': t.deadline?.toUtc().toIso8601String(),
  'status': t.status.name,
  'preparation': {
    for (final key in preparationSteps.keys) key: t.preparation[key],
  },
};
String canonicalWorkJson(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return '{${keys.map((k) => '${jsonEncode(k)}:${canonicalWorkJson(value[k])}').join(',')}}';
  }
  if (value is List) return '[${value.map(canonicalWorkJson).join(',')}]';
  return jsonEncode(value);
}

Uri workServerUri(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      (uri.path.isNotEmpty && uri.path != '/')) {
    throw const WorkError(
      'Saisissez l’adresse HTTPS du serveur, sans chemin ni code secret.',
    );
  }
  return uri.replace(path: '');
}

class WorkError implements Exception {
  final String message;
  final int? status;
  const WorkError(this.message, {this.status});
  @override
  String toString() => message;
}

class WorkCredentials {
  final String url, token, deviceId, name;
  final int revision;
  final bool trainingsOnly;
  const WorkCredentials({
    required this.url,
    required this.token,
    required this.deviceId,
    required this.name,
    this.revision = 0,
    this.trainingsOnly = true,
  });
  WorkCredentials copyWith({int? revision, bool? trainingsOnly}) =>
      WorkCredentials(
        url: url,
        token: token,
        deviceId: deviceId,
        name: name,
        revision: revision ?? this.revision,
        trainingsOnly: trainingsOnly ?? this.trainingsOnly,
      );
  Map<String, dynamic> toJson() => {
    'url': url,
    'token': token,
    'deviceId': deviceId,
    'name': name,
    'revision': revision,
    'trainingsOnly': trainingsOnly,
  };
  factory WorkCredentials.fromJson(Map<String, dynamic> j) => WorkCredentials(
    url: workServerUri(j['url']).toString(),
    token: j['token'],
    deviceId: j['deviceId'],
    name: j['name'],
    revision: j['revision'] ?? 0,
    trainingsOnly: j['trainingsOnly'] ?? true,
  );
}

class WorkProposal {
  final String id, deviceId, taskId, field, reason;
  final bool? value;
  final Map<String, dynamic> basis;
  final List<Map<String, dynamic>> evidence;
  const WorkProposal({
    required this.id,
    required this.deviceId,
    required this.taskId,
    required this.field,
    required this.reason,
    required this.value,
    required this.basis,
    required this.evidence,
  });
  factory WorkProposal.fromJson(Map<String, dynamic> j) {
    if (!preparationSteps.containsKey(j['field']) ||
        (j['value'] != null && j['value'] is! bool)) {
      throw const WorkError('Proposition non reconnue.');
    }
    final evidence = (j['evidence'] as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    if (j['value'] != null && evidence.isEmpty) {
      throw const WorkError('Cette proposition ne contient pas de source.');
    }
    return WorkProposal(
      id: j['id'],
      deviceId: j['deviceId'],
      taskId: j['taskId'],
      field: j['field'],
      reason: j['reason'],
      value: j['value'],
      basis: Map<String, dynamic>.from(j['basis']),
      evidence: evidence,
    );
  }
  bool matches(Task task) {
    final local = sharedTask(task), remote = Map<String, dynamic>.from(basis);
    local['preparation'] = {field: task.preparation[field]};
    remote['preparation'] = {field: (basis['preparation'] as Map)[field]};
    return canonicalWorkJson(local) == canonicalWorkJson(remote);
  }

  bool alreadyApplied(Task task) =>
      task.preparationEvidence[field]?['proposalId'] == id;
  Task apply(Task task) {
    if (alreadyApplied(task)) return task;
    if (task.id != taskId || !task.isTraining || !matches(task)) {
      throw const WorkError(
        'Cette tâche a changé. Refusez la proposition et demandez une nouvelle analyse dans Work.',
      );
    }
    return task.copyWith(
      preparation: {...task.preparation, field: value},
      preparationEvidence: {
        ...task.preparationEvidence,
        field: {
          'proposalId': id,
          'reason': reason,
          'sources': evidence,
          'acceptedAt': DateTime.now().toUtc().toIso8601String(),
        },
      },
    );
  }
}
