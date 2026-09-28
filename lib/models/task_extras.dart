enum TaskCategory { automatic, work, training, sport, music, personal, rest }

extension CategoryLabel on TaskCategory {
  String get label => [
    'Automatique',
    'Professionnel',
    'Formation',
    'Sport',
    'Musique',
    'Personnel',
    'Repos',
  ][index];
  String get emoji => ['✨', '💼', '🎓', '🏃', '🎵', '🏠', '🌿'][index];
}

TaskCategory inferCategory(String title, {bool professional = false}) {
  final t = title.toLowerCase();
  if (RegExp(r'formation|atelier|training|webinaire').hasMatch(t)) {
    return TaskCategory.training;
  }
  if (!professional &&
      RegExp(
        r'sport|marche|courir|course à pied|running|fitness|musculation|natation|vélo|yoga',
      ).hasMatch(t)) {
    return TaskCategory.sport;
  }
  if (!professional &&
      RegExp(
        r'musique|piano|guitare|violon|batterie|solfège|chant',
      ).hasMatch(t)) {
    return TaskCategory.music;
  }
  return professional ? TaskCategory.work : TaskCategory.personal;
}

const preparationSteps = {
  'support': 'Formation préparée',
  'order': 'Bon de commande signé',
  'email': 'Mail de confirmation envoyé',
};

class AudioNote {
  final String id, name;
  final int seconds, bytes;
  const AudioNote({
    required this.id,
    required this.name,
    required this.seconds,
    required this.bytes,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'seconds': seconds,
    'bytes': bytes,
  };
  factory AudioNote.fromJson(Map<String, dynamic> j) => AudioNote(
    id: j['id'],
    name: j['name'],
    seconds: j['seconds'],
    bytes: j['bytes'],
  );
}
