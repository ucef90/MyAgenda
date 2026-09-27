import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/format.dart';
import '../../models/task.dart';
import '../../repositories/workspace_store.dart';
import '../../widgets/common.dart';

Future<void> showTaskForm(BuildContext context, {Task? task, DateTime? slot}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => TaskForm(task: task, slot: slot),
    );

class TaskForm extends ConsumerStatefulWidget {
  final Task? task;
  final DateTime? slot;
  const TaskForm({super.key, this.task, this.slot});
  @override
  ConsumerState<TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends ConsumerState<TaskForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title, _notes, _duration, _project;
  late bool _professional, _expanded;
  late Priority _priority;
  DateTime? _earliest, _deadline, _scheduled;
  String? _client, _mission;
  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _title = TextEditingController(text: t?.title);
    _notes = TextEditingController(text: t?.notes);
    _duration = TextEditingController(text: '${t?.minutes ?? 30}');
    _project = TextEditingController(text: t?.project);
    _professional = t?.professional ?? false;
    _expanded = t != null;
    _priority = t?.priority ?? Priority.normal;
    _earliest = t?.earliest;
    _deadline = t?.deadline;
    _scheduled = t?.scheduledAt ?? widget.slot;
    _client = t?.clientId;
    _mission = t?.missionId;
  }

  @override
  void dispose() {
    for (final c in [_title, _notes, _duration, _project]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<DateTime?> pickDateTime(DateTime? initial) async {
    final base = initial ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: initial == null
          ? const TimeOfDay(hour: 18, minute: 0)
          : TimeOfDay.fromDateTime(base),
    );
    return time == null
        ? null
        : DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  void save() {
    if (!_form.currentState!.validate()) return;
    final task = (widget.task ?? Task(id: newId(), title: '')).copyWith(
      title: _title.text.trim(),
      notes: _notes.text.trim(),
      minutes: int.parse(_duration.text),
      project: _project.text.trim(),
      professional: _professional,
      clientId: _professional ? _client : null,
      missionId: _professional ? _mission : null,
      priority: _priority,
      earliest: _earliest,
      deadline: _deadline,
      scheduledAt: _scheduled,
      status: widget.task?.status == TaskStatus.completed
          ? TaskStatus.completed
          : widget.task?.status == TaskStatus.cancelled
          ? TaskStatus.cancelled
          : widget.task?.status == TaskStatus.inProgress
          ? TaskStatus.inProgress
          : _scheduled != null
          ? TaskStatus.planned
          : TaskStatus.todo,
    );
    if (attempt(
      context,
      () => ref.read(workspaceProvider.notifier).upsert(task),
      success: widget.task == null
          ? 'Tâche ajoutée'
          : 'Modifications enregistrées',
    )) {
      Navigator.pop(context);
    }
  }

  Widget dateRow(
    String label,
    DateTime? value,
    void Function(DateTime?) change,
  ) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.event_outlined),
    title: Text(label),
    subtitle: Text(
      value == null ? 'Non définie' : '${shortDate(value)} · ${clock(value)}',
    ),
    onTap: () async {
      final d = await pickDateTime(value);
      if (d != null && mounted) setState(() => change(d));
    },
    trailing: value == null
        ? const Icon(Icons.chevron_right)
        : IconButton(
            tooltip: 'Effacer $label',
            onPressed: () => setState(() => change(null)),
            icon: const Icon(Icons.close, size: 18),
          ),
  );
  @override
  Widget build(BuildContext context) {
    final w = ref.watch(workspaceProvider);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .88,
          maxWidth: 640,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.task == null ? 'Nouvelle tâche' : 'Modifier la tâche',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                const Text('Une idée en tête ? Faites-lui une place.'),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _title,
                  autofocus: widget.task == null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Que devez-vous faire ?',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Ajoutez un titre.'
                      : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _duration,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Durée (min)',
                          prefixIcon: Icon(Icons.schedule),
                        ),
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          return n == null || n < 5 || n > 1440
                              ? 'De 5 à 1 440 min'
                              : null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<Priority>(
                        initialValue: _priority,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Priorité',
                        ),
                        items: [
                          for (final p in Priority.values)
                            DropdownMenuItem(value: p, child: Text(p.label)),
                        ],
                        onChanged: (p) => setState(() => _priority = p!),
                      ),
                    ),
                  ],
                ),
                dateRow('Échéance', _deadline, (d) => _deadline = d),
                if (_scheduled != null || _expanded)
                  dateRow(
                    'Créneau planifié',
                    _scheduled,
                    (d) => _scheduled = d,
                  ),
                if (!_expanded)
                  TextButton.icon(
                    onPressed: () => setState(() => _expanded = true),
                    icon: const Icon(Icons.tune_rounded),
                    label: const Text('Plus d’options'),
                  ),
                if (_expanded) ...[
                  const Divider(),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('Personnel'),
                        icon: Icon(Icons.person_outline),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('Pro'),
                        icon: Icon(Icons.work_outline),
                      ),
                    ],
                    selected: {_professional},
                    onSelectionChanged: (s) =>
                        setState(() => _professional = s.first),
                  ),
                  const SizedBox(height: 16),
                  if (_professional) ...[
                    DropdownButtonFormField<String>(
                      initialValue: _client,
                      decoration: const InputDecoration(labelText: 'Client'),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Sans client'),
                        ),
                        for (final c in w.clients)
                          DropdownMenuItem(value: c.id, child: Text(c.name)),
                      ],
                      onChanged: (v) => setState(() {
                        _client = v;
                        _mission = null;
                      }),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      key: ValueKey(_client),
                      initialValue: _mission,
                      decoration: const InputDecoration(labelText: 'Mission'),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Sans mission'),
                        ),
                        for (final m in w.missions.where(
                          (m) => m.clientId == _client,
                        ))
                          DropdownMenuItem(value: m.id, child: Text(m.title)),
                      ],
                      onChanged: (v) => setState(() => _mission = v),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _project,
                    decoration: const InputDecoration(
                      labelText: 'Projet (facultatif)',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _notes,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notes privées',
                    ),
                  ),
                  dateRow(
                    'Disponible à partir du',
                    _earliest,
                    (d) => _earliest = d,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Les sous-tâches s’ajoutent dans le détail de la tâche.',
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: save,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(
                    widget.task == null ? 'Ajouter la tâche' : 'Enregistrer',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
