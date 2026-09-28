class TaskAttachment {
  final String id, name;
  final int bytes;
  const TaskAttachment({
    required this.id,
    required this.name,
    required this.bytes,
  });
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'bytes': bytes};
  factory TaskAttachment.fromJson(Map<String, dynamic> j) =>
      TaskAttachment(id: j['id'], name: j['name'], bytes: j['bytes']);
}
