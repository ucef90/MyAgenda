import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/format.dart';
import '../../repositories/workspace_store.dart';
import '../../services/assistant.dart';
import '../../theme/app_theme.dart';
import '../../theme/task_colors.dart';
import '../../widgets/common.dart';
import '../../widgets/task_list_row.dart';

class AssistantPage extends ConsumerStatefulWidget {
  const AssistantPage({super.key});
  @override
  ConsumerState<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends ConsumerState<AssistantPage> {
  DateTime _day = dayOnly(DateTime.now());
  @override
  Widget build(BuildContext context) {
    final w = ref.watch(workspaceProvider);
    final now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();
    final brief = const AgendaAssistant().build(w, _day, now);
    return PageBody(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Mon assistant',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
            ),
            IconButton(
              tooltip: 'Mes envies et mon rythme',
              onPressed: () => context.push('/assistant/preferences'),
              icon: const Icon(Icons.tune_rounded),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Vos priorités. Vos envies. Une journée qui vous ressemble.',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 22),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            spacing: 8,
            children: [
              for (var i = 0; i < 3; i++)
                ChoiceChip(
                  label: Text(
                    i == 0
                        ? 'Aujourd’hui'
                        : i == 1
                        ? 'Demain'
                        : shortDate(DateTime(now.year, now.month, now.day + i)),
                  ),
                  selected: sameDay(
                    _day,
                    DateTime(now.year, now.month, now.day + i),
                  ),
                  onSelected: (_) => setState(
                    () => _day = DateTime(now.year, now.month, now.day + i),
                  ),
                ),
              ActionChip(
                label: const Text('Autre jour'),
                avatar: const Icon(Icons.calendar_today_outlined, size: 16),
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _day.isBefore(dayOnly(now))
                        ? dayOnly(now)
                        : _day,
                    firstDate: dayOnly(now),
                    lastDate: DateTime(now.year, now.month, now.day + 30),
                  );
                  if (date != null && mounted) setState(() => _day = date);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF172554), Color(0xFF3730A3)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Color(0xFF99F6E4), size: 20),
                  SizedBox(width: 10),
                  Text(
                    'VOTRE BRIEF DU JOUR',
                    style: TextStyle(
                      color: Color(0xFFC7D2FE),
                      letterSpacing: 1.5,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                brief.priorities.isNotEmpty
                    ? 'Commençons par l’essentiel.'
                    : 'Faites aussi une place à vos envies.',
                style: const TextStyle(
                  fontSize: 27,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${dayLabel(_day)} · ${durationLabel(brief.plannedMinutes)} déjà planifiées. '
                '${durationLabel(brief.freeMinutes)} disponibles dans vos horaires personnels.',
                style: const TextStyle(color: Color(0xFFE0E7FF)),
              ),
              if (w.preferences.motivation.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Text(
                    'Votre intention : ${w.preferences.motivation}',
                    style: const TextStyle(
                      color: Color(0xFF99F6E4),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (brief.priorities.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Card(
              child: ExpansionTile(
                shape: const Border(),
                collapsedShape: const Border(),
                leading: const Icon(
                  Icons.flag_outlined,
                  color: AppColors.amber,
                ),
                title: Text(
                  '${brief.priorities.length} priorités à surveiller',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                subtitle: const Text(
                  'Voir les échéances et les urgences',
                  style: TextStyle(fontSize: 12),
                ),
                childrenPadding: const EdgeInsets.all(12),
                children: [
                  for (final task in brief.priorities.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TaskListRow(task),
                    ),
                  if (brief.priorities.any((t) => t.overdueAt(now)))
                    const Text(
                      'Une échéance est dépassée : terminez la tâche ou ajustez sa date avant de la replanifier.',
                    ),
                ],
              ),
            ),
          ),
        SectionTitle(
          'Mes suggestions',
          action: Tag(
            '${brief.suggestions.length} idées',
            icon: Icons.lightbulb_outline,
          ),
        ),
        const Text(
          'Choisissez ce qui vous convient. Rien n’est ajouté sans votre validation.',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 16),
        if (brief.suggestions.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.spa_outlined,
                    size: 28,
                    color: AppColors.teal,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    w.preferences.goals.isEmpty
                        ? 'Et si ce temps était pour vous ?'
                        : 'Pas de créneau adapté pour ce jour.',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    w.preferences.goals.isEmpty
                        ? 'Ajoutez vos envies de sport, de musique ou de lecture pour recevoir des propositions.'
                        : 'Vos horaires, vos pauses ou vos objectifs déjà planifiés limitent les propositions. Regardez demain ou ajustez vos préférences.',
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/assistant/preferences'),
                    icon: const Icon(Icons.tune),
                    label: const Text('Personnaliser mon assistant'),
                  ),
                ],
              ),
            ),
          ),
        LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final suggestion in brief.suggestions)
                SizedBox(
                  width: constraints.maxWidth >= 760
                      ? (constraints.maxWidth - 12) / 2
                      : constraints.maxWidth,
                  child: SuggestionCard(suggestion),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (brief.unplaced.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${brief.unplaced.length} autres tâches à organiser',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'La proposition se limite à trois tâches. Certaines durées ou échéances peuvent aussi empêcher un placement.',
                  ),
                  for (final task in brief.unplaced.take(3))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(task.title),
                      subtitle: Text(
                        '${durationLabel(task.minutes)} · ${deadlineLabel(task.deadline)}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/task/${task.id}'),
                    ),
                ],
              ),
            ),
          ),
        SectionTitle(
          'Mes objectifs cette semaine',
          action: IconButton(
            tooltip: 'Modifier mes objectifs',
            onPressed: () => context.push('/assistant/preferences'),
            icon: const Icon(Icons.edit_outlined),
          ),
        ),
        if (w.preferences.goals.isEmpty)
          OutlinedButton.icon(
            onPressed: () => context.push('/assistant/preferences'),
            icon: const Icon(Icons.add),
            label: const Text('Sport, musique… ajouter mes envies'),
          ),
        for (final goal in w.preferences.goals)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Builder(
                  builder: (context) {
                    final planned = const AgendaAssistant().weekCount(
                      w,
                      goal.id,
                      _day,
                    );
                    final done = const AgendaAssistant().weekCount(
                      w,
                      goal.id,
                      _day,
                      completedOnly: true,
                    );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.flag_outlined, color: goal.color.value),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                goal.title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            if (!goal.enabled) const Tag('En pause'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: (done / goal.weeklyTarget).clamp(0, 1),
                          color: goal.color.value,
                          backgroundColor: goal.color.value.withValues(
                            alpha: .1,
                          ),
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '$done réalisées · $planned prévues sur ${goal.weeklyTarget} · ${durationLabel(goal.minutes)} / séance',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        const SizedBox(height: 20),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Comment sont choisies les suggestions ?'),
          children: const [
            Padding(
              padding: EdgeInsets.only(bottom: 18),
              child: Text(
                'L’assistant utilise vos tâches et les préférences que vous renseignez : échéances, priorités, durées, activités et horaires. '
                'Il respecte les créneaux réservés, la pause et une marge entre activités. Il ne déplace jamais un rendez-vous. '
                'Ce moteur fonctionne localement, sans IA conversationnelle et sans analyse du contenu de vos images.',
              ),
            ),
          ],
        ),
        const SizedBox(height: 70),
      ],
    );
  }
}

class SuggestionCard extends ConsumerWidget {
  final DaySuggestion suggestion;
  const SuggestionCard(this.suggestion, {super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = suggestion.task;
    final color = task.displayColor;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Tag(
                  '${clock(task.scheduledAt!)} – ${clock(task.scheduledEnd!)}',
                  color: color,
                  icon: Icons.schedule,
                ),
                Tag(
                  suggestion.newActivity
                      ? 'Du temps pour moi'
                      : 'Faire avancer mes tâches',
                  color: color,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(task.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              suggestion.reason,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: color),
              onPressed: () => attempt(
                context,
                () => ref
                    .read(workspaceProvider.notifier)
                    .acceptSuggestion(suggestion),
                success: 'Ajouté à votre agenda',
              ),
              icon: const Icon(Icons.add_task),
              label: const Text('Ajouter à mon agenda'),
            ),
          ],
        ),
      ),
    );
  }
}

class AssistantTeaser extends ConsumerWidget {
  const AssistantTeaser({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(workspaceProvider),
        now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();
    final suggestions = const AgendaAssistant().build(w, now, now).suggestions;
    final personal = suggestions.where((s) => s.newActivity).firstOrNull;
    final first = personal ?? suggestions.firstOrNull;
    return Card(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF142D35)
          : const Color(0xFFF0FDFA),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.go('/assistant'),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.teal),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'UNE IDÉE POUR VOTRE JOURNÉE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: AppColors.teal,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      first == null
                          ? 'Du temps pour vos projets et pour vous.'
                          : first.task.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      first == null
                          ? 'Sport, musique… personnalisez votre assistant.'
                          : '${clock(first.task.scheduledAt!)} – ${clock(first.task.scheduledEnd!)} · Voir les suggestions',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.teal,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
