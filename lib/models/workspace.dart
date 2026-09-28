import 'task.dart';
import 'personal_goal.dart';

class Client {
  final String id, name, email;
  const Client({required this.id, required this.name, this.email = ''});
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'email': email};
  factory Client.fromJson(Map<String, dynamic> j) =>
      Client(id: j['id'], name: j['name'], email: j['email'] ?? '');
}

class Mission {
  final String id, title, clientId;
  final DateTime start, end;
  const Mission({
    required this.id,
    required this.title,
    required this.clientId,
    required this.start,
    required this.end,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'clientId': clientId,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
  };
  factory Mission.fromJson(Map<String, dynamic> j) => Mission(
    id: j['id'],
    title: j['title'],
    clientId: j['clientId'],
    start: DateTime.parse(j['start']),
    end: DateTime.parse(j['end']),
  );
}

class Preferences {
  final String name;
  final int workStart, workEnd, breakStart, breakEnd;
  final List<int> weekdays;
  final bool dark;
  final List<PersonalGoal> goals;
  final int personalStart, personalEnd, bufferMinutes;
  final List<int> personalDays;
  final String motivation;
  const Preferences({
    this.name = 'Youssef',
    this.workStart = 540,
    this.workEnd = 1080,
    this.breakStart = 720,
    this.breakEnd = 780,
    this.weekdays = const [1, 2, 3, 4, 5],
    this.dark = false,
    this.goals = const [],
    this.personalStart = 480,
    this.personalEnd = 1260,
    this.personalDays = const [1, 2, 3, 4, 5, 6, 7],
    this.bufferMinutes = 10,
    this.motivation = '',
  });
  Preferences copyWith({
    String? name,
    int? workStart,
    int? workEnd,
    int? breakStart,
    int? breakEnd,
    List<int>? weekdays,
    bool? dark,
    List<PersonalGoal>? goals,
    int? personalStart,
    int? personalEnd,
    List<int>? personalDays,
    int? bufferMinutes,
    String? motivation,
  }) => Preferences(
    name: name ?? this.name,
    workStart: workStart ?? this.workStart,
    workEnd: workEnd ?? this.workEnd,
    breakStart: breakStart ?? this.breakStart,
    breakEnd: breakEnd ?? this.breakEnd,
    weekdays: weekdays ?? this.weekdays,
    dark: dark ?? this.dark,
    goals: goals ?? this.goals,
    personalStart: personalStart ?? this.personalStart,
    personalEnd: personalEnd ?? this.personalEnd,
    personalDays: personalDays ?? this.personalDays,
    bufferMinutes: bufferMinutes ?? this.bufferMinutes,
    motivation: motivation ?? this.motivation,
  );
  Preferences get personalWindow => copyWith(
    workStart: personalStart,
    workEnd: personalEnd,
    weekdays: personalDays,
    breakStart: 0,
    breakEnd: 0,
  );
  Map<String, dynamic> toJson() => {
    'name': name,
    'workStart': workStart,
    'workEnd': workEnd,
    'breakStart': breakStart,
    'breakEnd': breakEnd,
    'weekdays': weekdays,
    'dark': dark,
    'goals': goals.map((g) => g.toJson()).toList(),
    'personalStart': personalStart,
    'personalEnd': personalEnd,
    'personalDays': personalDays,
    'bufferMinutes': bufferMinutes,
    'motivation': motivation,
  };
  factory Preferences.fromJson(Map<String, dynamic> j) => Preferences(
    name: j['name'],
    workStart: j['workStart'],
    workEnd: j['workEnd'],
    breakStart: j['breakStart'],
    breakEnd: j['breakEnd'],
    weekdays: List<int>.from(j['weekdays']),
    dark: j['dark'] ?? false,
    goals: (j['goals'] as List? ?? [])
        .map((g) => PersonalGoal.fromJson(Map<String, dynamic>.from(g)))
        .toList(),
    personalStart: j['personalStart'] ?? 480,
    personalEnd: j['personalEnd'] ?? 1260,
    personalDays: List<int>.from(j['personalDays'] ?? [1, 2, 3, 4, 5, 6, 7]),
    bufferMinutes: j['bufferMinutes'] ?? 10,
    motivation: j['motivation'] ?? '',
  );
}

class Workspace {
  final List<Task> tasks;
  final List<Client> clients;
  final List<Mission> missions;
  final Preferences preferences;
  final bool demo;
  const Workspace({
    this.tasks = const [],
    this.clients = const [],
    this.missions = const [],
    this.preferences = const Preferences(),
    this.demo = false,
  });
  Workspace copyWith({
    List<Task>? tasks,
    List<Client>? clients,
    List<Mission>? missions,
    Preferences? preferences,
    bool? demo,
  }) => Workspace(
    tasks: tasks ?? this.tasks,
    clients: clients ?? this.clients,
    missions: missions ?? this.missions,
    preferences: preferences ?? this.preferences,
    demo: demo ?? this.demo,
  );
  String clientName(String? id) =>
      clients.where((c) => c.id == id).firstOrNull?.name ?? 'Professionnel';
  Map<String, dynamic> toJson() => {
    'version': 1,
    'demo': demo,
    'tasks': tasks.map((e) => e.toJson()).toList(),
    'clients': clients.map((e) => e.toJson()).toList(),
    'missions': missions.map((e) => e.toJson()).toList(),
    'preferences': preferences.toJson(),
  };
  factory Workspace.fromJson(Map<String, dynamic> j) {
    if (j['version'] != 1) {
      throw const FormatException('Version de sauvegarde incompatible');
    }
    return Workspace(
      tasks: (j['tasks'] as List)
          .map((e) => Task.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      clients: (j['clients'] as List)
          .map((e) => Client.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      missions: (j['missions'] as List)
          .map((e) => Mission.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      preferences: Preferences.fromJson(
        Map<String, dynamic>.from(j['preferences']),
      ),
      demo: j['demo'] ?? false,
    );
  }
}
