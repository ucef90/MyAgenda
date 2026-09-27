import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/format.dart';
import '../../models/task.dart';
import '../../repositories/workspace_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../planning/planning_sheet.dart';
import 'task_form.dart';

class TaskDetail extends ConsumerStatefulWidget {
  final String id;
  const TaskDetail({super.key, required this.id});
  @override
  ConsumerState<TaskDetail> createState() => _TaskDetailState();
}

class _TaskDetailState extends ConsumerState<TaskDetail> {
  final _item = TextEditingController();
  @override
  void dispose() {
    _item.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = ref.watch(workspaceProvider);
    final t = w.tasks.where((t) => t.id == widget.id).firstOrNull;
    if (t == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          title: 'Tâche introuvable',
          subtitle: 'Elle a peut-être été supprimée.',
        ),
      );
    }
    final now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();
    final store = ref.read(workspaceProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail de la tâche'),
        actions: [
          IconButton(
            tooltip: 'Modifier',
            onPressed: () => showTaskForm(context, task: t),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Supprimer',
            onPressed: () async {
              if (await confirm(
                    context,
                    'Supprimer cette tâche ?',
                    'Cette action supprimera aussi ses sous-tâches et ses notes.',
                  ) &&
                  context.mounted) {
                if (attempt(context, () => store.delete(t.id))) context.pop();
              }
            },
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: PageBody(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag(
                t.professional ? 'Professionnel' : 'Personnel',
                color: t.professional ? AppColors.indigo : AppColors.violet,
              ),
              const Tag(
                'Privé',
                icon: Icons.lock_outline,
                color: AppColors.muted,
              ),
              if (t.overdueAt(now))
                const Tag('En retard', color: AppColors.red),
            ],
          ),
          const SizedBox(height: 22),
          Text(t.title, style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 10),
          Text(
            t.professional ? w.clientName(t.clientId) : t.project,
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule),
                    title: Text('${durationLabel(t.minutes)} estimées'),
                    subtitle: Text(
                      '${durationLabel(t.secondsAt(now) ~/ 60)} réalisées',
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.flag_outlined),
                    title: Text(deadlineLabel(t.deadline)),
                    subtitle: Text(
                      'Priorité ${t.priority.label.toLowerCase()}',
                    ),
                  ),
                  if (t.scheduledAt != null)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_outlined),
                      title: Text(
                        '${shortDate(t.scheduledAt!)} · ${clock(t.scheduledAt!)} – ${clock(t.scheduledEnd!)}',
                      ),
                      subtitle: const Text('Créneau réservé'),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<TaskStatus>(
            key: ValueKey(t.status),
            initialValue: t.status,
            decoration: const InputDecoration(labelText: 'Statut'),
            items: [
              for (final s in TaskStatus.values)
                DropdownMenuItem(value: s, child: Text(s.label)),
            ],
            onChanged: (s) {
              if (s != null) attempt(context, () => store.setStatus(t, s));
            },
          ),
          const SectionTitle('Sous-tâches'),
          if (t.checklist.isNotEmpty) ...[
            LinearProgressIndicator(
              value: t.progress,
              minHeight: 6,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 8),
            Text(
              '${t.completedItems} sur ${t.checklist.length} · ${(t.progress * 100).round()} %',
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 8),
          ],
          for (final i in t.checklist)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: i.done,
              title: Text(
                i.title,
                style: TextStyle(
                  decoration: i.done ? TextDecoration.lineThrough : null,
                ),
              ),
              onChanged: (_) =>
                  attempt(context, () => store.toggleItem(t, i.id)),
            ),
          TextField(
            controller: _item,
            decoration: InputDecoration(
              hintText: 'Ajouter une sous-tâche',
              suffixIcon: IconButton(
                tooltip: 'Ajouter la sous-tâche',
                icon: const Icon(Icons.add),
                onPressed: () {
                  if (_item.text.trim().isNotEmpty &&
                      attempt(
                        context,
                        () => store.upsert(
                          t.copyWith(
                            checklist: [
                              ...t.checklist,
                              ChecklistItem(
                                id: newId(),
                                title: _item.text.trim(),
                              ),
                            ],
                          ),
                        ),
                      )) {
                    _item.clear();
                  }
                },
              ),
            ),
          ),
          const SectionTitle('Notes privées'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                t.notes.isEmpty
                    ? 'Ajoutez vos idées depuis le bouton Modifier.'
                    : t.notes,
              ),
            ),
          ),
          const SizedBox(height: 26),
          if (t.isOpen) ...[
            FilledButton.icon(
              onPressed: () {
                if (attempt(context, () => store.startFocus(t))) {
                  context.push('/focus/${t.id}');
                }
              },
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Démarrer le focus'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => showSuggestions(context, t),
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('Trouver un créneau'),
            ),
            if (t.scheduledAt != null)
              TextButton(
                onPressed: () => attempt(
                  context,
                  () => store.upsert(
                    t.copyWith(scheduledAt: null, status: TaskStatus.todo),
                  ),
                  success: 'Créneau libéré',
                ),
                child: const Text('Retirer du planning'),
              ),
          ],
        ],
      ),
    );
  }
}
