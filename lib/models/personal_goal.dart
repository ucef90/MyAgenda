import 'task.dart';

enum PreferredTime { any, morning, afternoon, evening }

extension PreferredTimeLabel on PreferredTime {
  String get label =>
      ['Quand c’est possible', 'Le matin', 'L’après-midi', 'Le soir'][index];
}

class PersonalGoal {
  final String id, title;
  final int minutes, weeklyTarget;
  final TaskColor color;
  final PreferredTime preferredTime;
  final bool enabled;
  const PersonalGoal({
    required this.id,
    required this.title,
    this.minutes = 30,
    this.weeklyTarget = 3,
    this.color = TaskColor.teal,
    this.preferredTime = PreferredTime.any,
    this.enabled = true,
  });
  PersonalGoal copyWith({
    String? title,
    int? minutes,
    int? weeklyTarget,
    TaskColor? color,
    PreferredTime? preferredTime,
    bool? enabled,
  }) => PersonalGoal(
    id: id,
    title: title ?? this.title,
    minutes: minutes ?? this.minutes,
    weeklyTarget: weeklyTarget ?? this.weeklyTarget,
    color: color ?? this.color,
    preferredTime: preferredTime ?? this.preferredTime,
    enabled: enabled ?? this.enabled,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'minutes': minutes,
    'weeklyTarget': weeklyTarget,
    'color': color.name,
    'preferredTime': preferredTime.name,
    'enabled': enabled,
  };
  factory PersonalGoal.fromJson(Map<String, dynamic> j) => PersonalGoal(
    id: j['id'],
    title: j['title'],
    minutes: j['minutes'],
    weeklyTarget: j['weeklyTarget'],
    color: TaskColor.values.byName(j['color']),
    preferredTime: PreferredTime.values.byName(j['preferredTime']),
    enabled: j['enabled'] ?? true,
  );
}
