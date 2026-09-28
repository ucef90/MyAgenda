import 'attachment.dart';

enum TaskStatus { todo, planned, inProgress, completed, cancelled }

enum TaskColor { automatic, indigo, teal, blue, violet, amber, rose }

extension TaskColorLabel on TaskColor {
  String get label => [
    'Automatique',
    'Indigo',
    'Vert',
    'Bleu',
    'Violet',
    'Orange',
    'Rose',
  ][index];
}

enum Priority { low, normal, important, urgent }

extension PriorityLabel on Priority {
  String get label => ['Faible', 'Normale', 'Importante', 'Urgente'][index];
}

extension StatusLabel on TaskStatus {
  String get label =>
      ['À faire', 'Planifiée', 'En cours', 'Terminée', 'Annulée'][index];
}

class ChecklistItem {
  final String id, title;
  final bool done;
  const ChecklistItem({
    required this.id,
    required this.title,
    this.done = false,
  });
  ChecklistItem toggle() => ChecklistItem(id: id, title: title, done: !done);
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'done': done};
  factory ChecklistItem.fromJson(Map<String, dynamic> j) =>
      ChecklistItem(id: j['id'], title: j['title'], done: j['done'] ?? false);
}

const _unset = Object();

class Task {
  final String id, title, notes, project;
  final String? clientId, missionId, goalId;
  final TaskColor color;
  final bool personalTime;
  final List<TaskAttachment> attachments;
  final bool professional;
  final int minutes, elapsedSeconds;
  final DateTime? earliest, deadline, scheduledAt, runningSince;
  final TaskStatus status;
  final Priority priority;
  final List<ChecklistItem> checklist;
  const Task({
    required this.id,
    required this.title,
    this.notes = '',
    this.project = '',
    this.clientId,
    this.goalId,
    this.color = TaskColor.automatic,
    this.personalTime = false,
    this.attachments = const [],
    this.missionId,
    this.professional = false,
    this.minutes = 30,
    this.elapsedSeconds = 0,
    this.earliest,
    this.deadline,
    this.scheduledAt,
    this.runningSince,
    this.status = TaskStatus.todo,
    this.priority = Priority.normal,
    this.checklist = const [],
  });
  bool get isOpen =>
      status != TaskStatus.completed && status != TaskStatus.cancelled;
  bool overdueAt(DateTime now) =>
      isOpen && deadline != null && deadline!.isBefore(now);
  DateTime? get scheduledEnd => scheduledAt?.add(Duration(minutes: minutes));
  int get completedItems => checklist.where((i) => i.done).length;
  double get progress => status == TaskStatus.completed
      ? 1
      : checklist.isEmpty
      ? 0
      : completedItems / checklist.length;
  int secondsAt(DateTime now) =>
      elapsedSeconds +
      (runningSince == null
          ? 0
          : now.difference(runningSince!).inSeconds.clamp(0, 31536000));
  Task copyWith({
    TaskColor? color,
    bool? personalTime,
    List<TaskAttachment>? attachments,
    Object? goalId = _unset,
    String? title,
    String? notes,
    String? project,
    Object? clientId = _unset,
    Object? missionId = _unset,
    bool? professional,
    int? minutes,
    int? elapsedSeconds,
    Object? earliest = _unset,
    Object? deadline = _unset,
    Object? scheduledAt = _unset,
    Object? runningSince = _unset,
    TaskStatus? status,
    Priority? priority,
    List<ChecklistItem>? checklist,
  }) => Task(
    id: id,
    color: color ?? this.color,
    personalTime: personalTime ?? this.personalTime,
    attachments: attachments ?? this.attachments,
    goalId: identical(goalId, _unset) ? this.goalId : goalId as String?,
    title: title ?? this.title,
    notes: notes ?? this.notes,
    project: project ?? this.project,
    clientId: identical(clientId, _unset) ? this.clientId : clientId as String?,
    missionId: identical(missionId, _unset)
        ? this.missionId
        : missionId as String?,
    professional: professional ?? this.professional,
    minutes: minutes ?? this.minutes,
    elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
    earliest: identical(earliest, _unset)
        ? this.earliest
        : earliest as DateTime?,
    deadline: identical(deadline, _unset)
        ? this.deadline
        : deadline as DateTime?,
    scheduledAt: identical(scheduledAt, _unset)
        ? this.scheduledAt
        : scheduledAt as DateTime?,
    runningSince: identical(runningSince, _unset)
        ? this.runningSince
        : runningSince as DateTime?,
    status: status ?? this.status,
    priority: priority ?? this.priority,
    checklist: checklist ?? this.checklist,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'color': color.name,
    'personalTime': personalTime,
    'goalId': goalId,
    'attachments': attachments.map((a) => a.toJson()).toList(),
    'title': title,
    'notes': notes,
    'project': project,
    'clientId': clientId,
    'missionId': missionId,
    'professional': professional,
    'minutes': minutes,
    'elapsedSeconds': elapsedSeconds,
    'earliest': earliest?.toIso8601String(),
    'deadline': deadline?.toIso8601String(),
    'scheduledAt': scheduledAt?.toIso8601String(),
    'runningSince': runningSince?.toIso8601String(),
    'status': status.name,
    'priority': priority.name,
    'checklist': checklist.map((i) => i.toJson()).toList(),
  };
  factory Task.fromJson(Map<String, dynamic> j) => Task(
    id: j['id'],
    color:
        TaskColor.values.where((c) => c.name == j['color']).firstOrNull ??
        TaskColor.automatic,
    personalTime: j['personalTime'] ?? false,
    goalId: j['goalId'],
    attachments: (j['attachments'] as List? ?? [])
        .map((a) => TaskAttachment.fromJson(Map<String, dynamic>.from(a)))
        .toList(),
    title: j['title'],
    notes: j['notes'] ?? '',
    project: j['project'] ?? '',
    clientId: j['clientId'],
    missionId: j['missionId'],
    professional: j['professional'] ?? false,
    minutes: j['minutes'],
    elapsedSeconds: j['elapsedSeconds'] ?? 0,
    earliest: DateTime.tryParse(j['earliest'] ?? ''),
    deadline: DateTime.tryParse(j['deadline'] ?? ''),
    scheduledAt: DateTime.tryParse(j['scheduledAt'] ?? ''),
    runningSince: DateTime.tryParse(j['runningSince'] ?? ''),
    status: TaskStatus.values.byName(j['status']),
    priority: Priority.values.byName(j['priority']),
    checklist: (j['checklist'] as List? ?? [])
        .map((i) => ChecklistItem.fromJson(Map<String, dynamic>.from(i)))
        .toList(),
  );
}
