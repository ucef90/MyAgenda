import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/format.dart';
import '../../models/task.dart';
import '../../repositories/workspace_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/task_card.dart';
import 'task_form.dart';

class TasksPage extends ConsumerStatefulWidget {
  const TasksPage({super.key});
  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage> {
  String _filter = 'Toutes', _search = '';
  bool _board = false;
  int _column = 0;
  final PageController _pages = PageController();
  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = ref.watch(workspaceProvider),
        now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();
    final tasks = w.tasks
        .where(
          (t) =>
              ('${t.title} ${t.project} ${w.clientName(t.clientId)} ${w.missions.where((m) => m.id == t.missionId).firstOrNull?.title ?? ''}')
                  .toLowerCase()
                  .contains(_search.toLowerCase()) &&
              switch (_filter) {
                'Aujourd’hui' =>
                  (t.scheduledAt != null && sameDay(t.scheduledAt!, now)) ||
                      (t.deadline != null && sameDay(t.deadline!, now)),
                'Pro' => t.professional,
                'Perso' => !t.professional,
                'Urgent' => t.priority == Priority.urgent || t.overdueAt(now),
                _ => true,
              },
        )
        .toList();
    final header = <Widget>[
      Row(
        children: [
          Expanded(
            child: Text(
              'Mes tâches',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
          ),
          IconButton(
            tooltip: 'Ajouter une tâche',
            onPressed: () => showTaskForm(context),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      const SizedBox(height: 8),
      const Text(
        'Toutes vos idées, une place pour chacune.',
        style: TextStyle(color: AppColors.muted),
      ),
      const SizedBox(height: 24),
      TextField(
        decoration: const InputDecoration(
          hintText: 'Rechercher une tâche, un projet…',
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: (s) => setState(() => _search = s),
      ),
      const SizedBox(height: 16),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final f in ['Toutes', 'Aujourd’hui', 'Pro', 'Perso', 'Urgent'])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(f),
                  selected: _filter == f,
                  onSelected: (_) => setState(() => _filter = f),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      Wrap(
        spacing: 16,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: false,
                label: Text('Liste'),
                icon: Icon(Icons.view_list_outlined),
              ),
              ButtonSegment(
                value: true,
                label: Text('Board'),
                icon: Icon(Icons.view_kanban_outlined),
              ),
            ],
            selected: {_board},
            onSelectionChanged: (v) => setState(() => _board = v.first),
          ),
          Text(
            '${tasks.length} tâches',
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ],
      ),
      const SizedBox(height: 24),
    ];
    if (!_board) {
      final groups = <String, List<Task>>{
        'À faire aujourd’hui': [],
        'À venir': [],
        'Sans date': [],
        'Terminées': [],
      };
      for (final t in tasks) {
        final date = t.scheduledAt ?? t.deadline;
        groups[t.status == TaskStatus.completed
                ? 'Terminées'
                : date == null
                ? 'Sans date'
                : !dayOnly(date).isAfter(dayOnly(now))
                ? 'À faire aujourd’hui'
                : 'À venir']!
            .add(t);
      }
      return PageBody(
        children: [
          ...header,
          if (tasks.isEmpty)
            EmptyState(
              title: 'Tout commence par une idée',
              subtitle: 'Ajoutez votre première tâche ou changez de filtre.',
              action: FilledButton(
                onPressed: () => showTaskForm(context),
                child: const Text('Créer une tâche'),
              ),
            ),
          for (final g in groups.entries.where((g) => g.value.isNotEmpty)) ...[
            SectionTitle(g.key, action: Tag('${g.value.length}')),
            for (final t in g.value)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TaskCard(t),
              ),
          ],
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = [
          TaskStatus.todo,
          TaskStatus.inProgress,
          TaskStatus.completed,
        ];
        Widget column(TaskStatus status) {
          final list = tasks
              .where(
                (t) => status == TaskStatus.todo
                    ? t.status == TaskStatus.todo ||
                          t.status == TaskStatus.planned
                    : t.status == status,
              )
              .toList();
          return DragTarget<String>(
            onAcceptWithDetails: (d) {
              final t = w.tasks.firstWhere((t) => t.id == d.data);
              attempt(
                context,
                () => ref.read(workspaceProvider.notifier).setStatus(t, status),
                success: 'Statut mis à jour',
              );
              HapticFeedback.lightImpact();
            },
            builder: (context, candidates, rejected) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 5),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: candidates.isNotEmpty
                    ? AppColors.indigo.withValues(alpha: .1)
                    : AppColors.muted.withValues(alpha: .045),
                borderRadius: BorderRadius.circular(20),
              ),
              child: ListView(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          status.label,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Tag('${list.length}'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (list.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Déposez une tâche ici.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  for (final t in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: LongPressDraggable<String>(
                        data: t.id,
                        feedback: Material(
                          color: Colors.transparent,
                          child: SizedBox(width: 280, child: TaskCard(t)),
                        ),
                        childWhenDragging: Opacity(
                          opacity: .3,
                          child: TaskCard(t),
                        ),
                        child: TaskCard(t),
                      ),
                    ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
              child: Column(children: header),
            ),
            if (constraints.maxWidth < 800)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SegmentedButton<int>(
                  segments: [
                    for (var i = 0; i < 3; i++)
                      ButtonSegment(value: i, label: Text(columns[i].label)),
                  ],
                  selected: {_column},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => _pages.animateToPage(
                    s.first,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                  ),
                ),
              ),
            Expanded(
              child: constraints.maxWidth < 800
                  ? PageView(
                      controller: _pages,
                      onPageChanged: (i) => setState(() => _column = i),
                      children: [for (final s in columns) column(s)],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final s in columns) Expanded(child: column(s)),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }
}
