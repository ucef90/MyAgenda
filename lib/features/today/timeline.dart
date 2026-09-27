import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/format.dart';
import '../../models/task.dart';
import '../../repositories/workspace_store.dart';
import '../../services/planner.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/task_card.dart';
import '../tasks/task_form.dart';

class Timeline extends ConsumerWidget {
  final DateTime day;
  const Timeline({super.key, required this.day});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(workspaceProvider);
    final tasks = w.tasks
        .where(
          (t) =>
              t.scheduledAt != null &&
              sameDay(t.scheduledAt!, day) &&
              t.status != TaskStatus.cancelled,
        )
        .toList();
    final now = DateTime.now();
    final free = const Planner().freeSlots(
      day,
      w.preferences,
      w.tasks,
      notBefore: now,
    );
    final entries = <({DateTime at, Task? task, TimeSlot? slot})>[
      for (final t in tasks) (at: t.scheduledAt!, task: t, slot: null),
      for (final s in free.where((s) => s.minutes >= 15))
        (at: s.start, task: null, slot: s),
    ]..sort((a, b) => a.at.compareTo(b.at));
    if (entries.isEmpty) {
      return const EmptyState(
        title: 'Une journée à votre rythme',
        subtitle: 'Ajoutez une tâche ou choisissez un autre jour.',
      );
    }
    return Column(
      children: [
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 50,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 18),
                      child: Text(
                        clock(e.at),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: e.task != null
                        ? TaskCard(e.task!, compact: true)
                        : _FreeSlot(e.slot!),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _FreeSlot extends ConsumerWidget {
  final TimeSlot slot;
  const _FreeSlot(this.slot);
  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    decoration: BoxDecoration(
      color: AppColors.teal.withValues(alpha: .055),
      border: Border.all(color: AppColors.teal.withValues(alpha: .2)),
      borderRadius: BorderRadius.circular(18),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (c) {
          final w = ref.read(workspaceProvider);
          final choices = w.tasks
              .where(
                (t) =>
                    t.isOpen &&
                    t.scheduledAt == null &&
                    const Planner().canSchedule(
                      t,
                      slot.start,
                      w,
                      now: DateTime.now(),
                    ),
              )
              .toList();
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${durationLabel(slot.minutes)} pour avancer',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (choices.isEmpty)
                  const Text(
                    'Aucune tâche en attente ne tient dans ce créneau.',
                  ),
                for (final t in choices)
                  ListTile(
                    title: Text(t.title),
                    subtitle: Text(durationLabel(t.minutes)),
                    trailing: const Icon(Icons.add),
                    onTap: () {
                      if (attempt(
                        c,
                        () => ref
                            .read(workspaceProvider.notifier)
                            .schedule(t, slot.start),
                        success: 'Tâche planifiée',
                      )) {
                        Navigator.pop(c);
                      }
                    },
                  ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(c);
                    showTaskForm(context, slot: slot.start);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Créer une tâche ici'),
                ),
              ],
            ),
          );
        },
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${durationLabel(slot.minutes)} de temps libre',
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF5EEAD4)
                          : AppColors.teal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Planifier une tâche',
                    style: TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.add_circle_outline,
              color: AppColors.teal,
              size: 22,
            ),
          ],
        ),
      ),
    ),
  );
}
