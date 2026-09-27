import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/format.dart';
import '../../models/task.dart';
import '../../repositories/workspace_store.dart';
import '../../services/planner.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

Future<void> showSuggestions(
  BuildContext context,
  Task task,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => Consumer(
    builder: (context, ref, _) {
      final current =
          ref
              .watch(workspaceProvider)
              .tasks
              .where((t) => t.id == task.id)
              .firstOrNull ??
          task;
      final slots = const Planner().suggest(
        current,
        ref.watch(workspaceProvider),
        DateTime.now(),
      );
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Trouver le bon moment',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 10),
            Text('${task.title} · ${durationLabel(task.minutes)}'),
            const SizedBox(height: 20),
            if (slots.isEmpty)
              const EmptyState(
                title: 'Un peu plus de souplesse ?',
                subtitle:
                    'Aucun créneau continu compatible dans les 30 prochains jours. Ajustez la durée, l’échéance ou vos horaires.',
              ),
            for (final slot in slots)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: const Icon(
                      Icons.auto_awesome_outlined,
                      color: AppColors.teal,
                    ),
                    title: Text(dayLabel(slot.start)),
                    subtitle: Text('${clock(slot.start)} – ${clock(slot.end)}'),
                    trailing: const Icon(Icons.arrow_forward_rounded),
                    onTap: () {
                      if (attempt(
                        context,
                        () => ref
                            .read(workspaceProvider.notifier)
                            .schedule(current, slot.start),
                        success: 'Tâche planifiée',
                      )) {
                        Navigator.pop(context);
                      }
                    },
                  ),
                ),
              ),
          ],
        ),
      );
    },
  ),
);

class PlanningPage extends ConsumerWidget {
  const PlanningPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(workspaceProvider);
    final now = DateTime.now();
    final tomorrow = now.hour >= 18;
    final day = dayOnly(now).add(Duration(days: tomorrow ? 1 : 0));
    final proposal = const Planner().planDay(w, day, now);
    return Scaffold(
      appBar: AppBar(title: const Text('Organiser ma journée')),
      body: PageBody(
        children: [
          Text(
            'Un peu d’ordre.\nPlus d’espace.',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 12),
          Text(
            'Proposition pour ${dayLabel(day)}. Vous gardez le dernier mot.',
          ),
          const SectionTitle('Votre proposition'),
          for (final e in proposal.assignments.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Text(
                    clock(e.value),
                    style: const TextStyle(
                      color: AppColors.indigo,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  title: Text(w.tasks.firstWhere((t) => t.id == e.key).title),
                  subtitle: Text(
                    durationLabel(
                      w.tasks.firstWhere((t) => t.id == e.key).minutes,
                    ),
                  ),
                ),
              ),
            ),
          if (proposal.assignments.isEmpty)
            const EmptyState(
              title: 'Rien à placer pour le moment',
              subtitle:
                  'Vos tâches sont déjà planifiées, ou aucun créneau ne respecte leurs contraintes.',
            ),
          if (proposal.unplaced.isNotEmpty) ...[
            const SectionTitle('À ajuster ensemble'),
            const Text(
              'Ces tâches ne rentrent pas dans cette journée. Vous pouvez choisir une autre date depuis leur détail.',
            ),
            const SizedBox(height: 12),
            for (final t in proposal.unplaced)
              ListTile(
                title: Text(t.title),
                subtitle: Text(
                  '${durationLabel(t.minutes)} · ${deadlineLabel(t.deadline)}',
                ),
                trailing: const Icon(Icons.schedule),
                onTap: () => showSuggestions(context, t),
              ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: proposal.assignments.isEmpty
                ? null
                : () => attempt(
                    context,
                    () => ref
                        .read(workspaceProvider.notifier)
                        .applyPlan(proposal),
                    success: 'Votre planning est prêt',
                  ),
            icon: const Icon(Icons.check_rounded),
            label: const Text('Appliquer ce planning'),
          ),
        ],
      ),
    );
  }
}
