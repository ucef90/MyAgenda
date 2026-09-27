import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/format.dart';
import '../../models/task.dart';
import '../../models/workspace.dart';
import '../../repositories/workspace_store.dart';
import '../../services/planner.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/task_card.dart';

class ProPage extends ConsumerStatefulWidget {
  const ProPage({super.key});
  @override
  ConsumerState<ProPage> createState() => _ProPageState();
}

class _ProPageState extends ConsumerState<ProPage> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) {
    final w = ref.watch(workspaceProvider), now = DateTime.now();
    final professional = w.tasks.where((t) => t.professional).toList();
    final monday = dayOnly(now).subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 7));
    final weekly = professional
        .where(
          (t) =>
              t.scheduledAt != null &&
              !t.scheduledAt!.isBefore(monday) &&
              t.scheduledAt!.isBefore(sunday) &&
              t.status != TaskStatus.cancelled,
        )
        .fold(0, (n, t) => n + t.minutes);
    return PageBody(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Mon espace Pro',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
            ),
            const Icon(Icons.work_outline_rounded, color: AppColors.indigo),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Votre activité, en toute clarté.',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${w.missions.where((m) => !m.end.isBefore(dayOnly(now))).length}',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const Text(
                        'missions actives',
                        style: TextStyle(color: AppColors.muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        durationLabel(weekly),
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(color: AppColors.indigo),
                      ),
                      const Text(
                        'prévues cette semaine',
                        style: TextStyle(color: AppColors.muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 0, label: Text('Missions')),
              ButtonSegment(value: 1, label: Text('Clients')),
              ButtonSegment(value: 2, label: Text('Disponibilités')),
            ],
            selected: {_tab},
            onSelectionChanged: (v) => setState(() => _tab = v.first),
          ),
        ),
        if (_tab == 0) ...[
          SectionTitle(
            'Vos missions',
            action: IconButton(
              tooltip: 'Créer une mission',
              onPressed: () => showMissionForm(context),
              icon: const Icon(Icons.add),
            ),
          ),
          if (w.missions.isEmpty)
            const EmptyState(
              title: 'Votre prochaine mission commence ici',
              subtitle: 'Créez un client puis une mission.',
            ),
          for (final m in w.missions)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _MissionCard(mission: m),
            ),
        ],
        if (_tab == 1) ...[
          SectionTitle(
            'Vos clients',
            action: IconButton(
              tooltip: 'Ajouter un client',
              onPressed: () => showClientForm(context),
              icon: const Icon(Icons.person_add_alt),
            ),
          ),
          if (w.clients.isEmpty)
            const EmptyState(
              title: 'Votre carnet est prêt',
              subtitle: 'Ajoutez votre premier client.',
            ),
          for (final c in w.clients)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.indigo.withValues(alpha: .08),
                    child: Text(c.name.substring(0, 1)),
                  ),
                  title: Text(c.name),
                  subtitle: Text(
                    c.email.isEmpty
                        ? '${w.missions.where((m) => m.clientId == c.id).length} mission(s)'
                        : c.email,
                  ),
                  trailing: const Icon(Icons.edit_outlined, size: 20),
                  onTap: () => showClientForm(context, client: c),
                ),
              ),
            ),
        ],
        if (_tab == 2) ...[
          const SectionTitle('Les 7 prochains jours'),
          const AvailabilityList(),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => context.push('/client-preview'),
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('Aperçu de mes disponibilités'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Seuls vos créneaux libres sont visibles dans cet aperçu. Aucun titre de tâche ni nom de client.',
            style: TextStyle(color: AppColors.muted),
          ),
        ],
      ],
    );
  }
}

class _MissionCard extends ConsumerWidget {
  final Mission mission;
  const _MissionCard({required this.mission});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(workspaceProvider),
        list = w.tasks.where((t) => t.missionId == mission.id).toList();
    final done = list.where((t) => t.status == TaskStatus.completed).length;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (context) => Consumer(
            builder: (context, ref, _) {
              final tasks = ref
                  .watch(workspaceProvider)
                  .tasks
                  .where((t) => t.missionId == mission.id)
                  .toList();
              return SizedBox(
                height: MediaQuery.sizeOf(context).height * .72,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 30),
                  children: [
                    Text(
                      mission.title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(w.clientName(mission.clientId)),
                    const SizedBox(height: 18),
                    OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        showMissionForm(context, mission: mission);
                      },
                      child: const Text('Modifier la mission'),
                    ),
                    const SizedBox(height: 16),
                    if (tasks.isEmpty)
                      const Text(
                        'Associez des tâches à cette mission depuis leurs options.',
                      ),
                    for (final t in tasks)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TaskCard(t),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Tag(w.clientName(mission.clientId)),
              const SizedBox(height: 14),
              Text(
                mission.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '${shortDate(mission.start)} – ${shortDate(mission.end)}',
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 20),
              LinearProgressIndicator(
                value: list.isEmpty ? 0 : done / list.length,
                minHeight: 6,
                borderRadius: BorderRadius.circular(5),
                color: AppColors.indigo,
                backgroundColor: AppColors.indigo.withValues(alpha: .08),
              ),
              const SizedBox(height: 10),
              Text(
                '$done / ${list.length} tâches terminées',
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AvailabilityList extends ConsumerWidget {
  const AvailabilityList({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(workspaceProvider), now = DateTime.now();
    return Column(
      children: [
        for (var i = 0; i < 7; i++)
          Builder(
            builder: (context) {
              final day = DateTime(now.year, now.month, now.day + i),
                  slots = const Planner().freeSlots(
                    day,
                    w.preferences,
                    w.tasks,
                    notBefore: now,
                  );
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            dayLabel(day),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            slots.isEmpty
                                ? 'Indisponible'
                                : slots
                                      .map(
                                        (s) =>
                                            '${clock(s.start)} – ${clock(s.end)}',
                                      )
                                      .join('\n'),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: slots.isEmpty
                                  ? AppColors.muted
                                  : AppColors.teal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class ClientPreview extends ConsumerWidget {
  const ClientPreview({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(workspaceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Aperçu client')),
      body: PageBody(
        children: [
          const Tag('Aperçu local · non publié', color: AppColors.amber),
          const SizedBox(height: 24),
          Text(
            w.preferences.name,
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 8),
          const Text('Mes disponibilités pour les prochains jours'),
          const SizedBox(height: 28),
          const AvailabilityList(),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () async {
              final now = DateTime.now();
              final lines = <String>['Disponibilités de ${w.preferences.name}'];
              for (var i = 0; i < 7; i++) {
                final day = DateTime(now.year, now.month, now.day + i),
                    slots = const Planner().freeSlots(
                      day,
                      w.preferences,
                      w.tasks,
                      notBefore: now,
                    );
                lines.add(
                  '${dayLabel(day)} : ${slots.isEmpty ? 'indisponible' : slots.map((s) => '${clock(s.start)}–${clock(s.end)}').join(', ')}',
                );
              }
              await Clipboard.setData(ClipboardData(text: lines.join('\n')));
              if (context.mounted) {
                toast(context, 'Disponibilités copiées, sans données privées');
              }
            },
            icon: const Icon(Icons.copy_outlined),
            label: const Text('Copier mes disponibilités'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Le lien public sécurisé sera activé après la connexion au serveur.',
            style: TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

Future<void> showClientForm(BuildContext context, {Client? client}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EntityForm(client: client),
    );
Future<void> showMissionForm(BuildContext context, {Mission? mission}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EntityForm(missionMode: true, mission: mission),
    );

class _EntityForm extends ConsumerStatefulWidget {
  final bool missionMode;
  final Client? client;
  final Mission? mission;
  const _EntityForm({this.missionMode = false, this.client, this.mission});
  @override
  ConsumerState<_EntityForm> createState() => _EntityFormState();
}

class _EntityFormState extends ConsumerState<_EntityForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _email;
  String? _client;
  late DateTime _start, _end;
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: widget.client?.name ?? widget.mission?.title,
    );
    _email = TextEditingController(text: widget.client?.email);
    _client = widget.mission?.clientId;
    _start = widget.mission?.start ?? dayOnly(DateTime.now());
    _end = widget.mission?.end ?? _start.add(const Duration(days: 1));
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(workspaceProvider).clients;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 30,
      ),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.missionMode ? 'Votre mission' : 'Votre client',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 22),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nom'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Indiquez un nom.' : null,
            ),
            const SizedBox(height: 16),
            if (!widget.missionMode)
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email (facultatif)',
                ),
              )
            else ...[
              DropdownButtonFormField<String>(
                initialValue: _client,
                decoration: const InputDecoration(labelText: 'Client'),
                items: [
                  for (final c in clients)
                    DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                validator: (v) =>
                    v == null ? 'Créez puis sélectionnez un client.' : null,
                onChanged: (v) => setState(() => _client = v),
              ),
              ListTile(
                title: const Text('Dates de la mission'),
                subtitle: Text('${shortDate(_start)} – ${shortDate(_end)}'),
                trailing: const Icon(Icons.date_range),
                onTap: () async {
                  final d = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                    initialDateRange: DateTimeRange(start: _start, end: _end),
                  );
                  if (d != null) {
                    setState(() {
                      _start = d.start;
                      _end = d.end;
                    });
                  }
                },
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                if (!_form.currentState!.validate()) return;
                final store = ref.read(workspaceProvider.notifier);
                if (attempt(context, () {
                  if (widget.missionMode) {
                    store.saveMission(
                      Mission(
                        id: widget.mission?.id ?? newId(),
                        title: _name.text.trim(),
                        clientId: _client!,
                        start: _start,
                        end: _end,
                      ),
                    );
                  } else {
                    store.saveClient(
                      Client(
                        id: widget.client?.id ?? newId(),
                        name: _name.text.trim(),
                        email: _email.text.trim(),
                      ),
                    );
                  }
                }, success: 'Enregistré')) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
