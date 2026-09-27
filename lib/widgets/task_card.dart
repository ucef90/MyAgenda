import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/format.dart';
import '../models/task.dart';
import '../repositories/workspace_store.dart';
import '../theme/app_theme.dart';
import 'common.dart';

class TaskCard extends ConsumerWidget {
  final Task task;
  final bool compact;
  const TaskCard(this.task, {super.key, this.compact = false});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(workspaceProvider);
    final now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();
    final color = task.professional ? AppColors.indigo : AppColors.violet;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/task/${task.id}'),
        child: Padding(
          padding: EdgeInsets.all(compact ? 14 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 34,
                    margin: const EdgeInsets.only(right: 12, top: 3),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                decoration: task.status == TaskStatus.completed
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          task.professional
                              ? w.clientName(task.clientId)
                              : task.project.isEmpty
                              ? 'Personnel'
                              : task.project,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: IconButton(
                      tooltip: task.status == TaskStatus.completed
                          ? 'Rouvrir la tâche'
                          : 'Terminer la tâche',
                      padding: EdgeInsets.zero,
                      onPressed: () => attempt(
                        context,
                        () => ref
                            .read(workspaceProvider.notifier)
                            .setStatus(
                              task,
                              task.status == TaskStatus.completed
                                  ? TaskStatus.todo
                                  : TaskStatus.completed,
                            ),
                        success: task.status == TaskStatus.completed
                            ? 'Tâche rouverte'
                            : 'Tâche terminée 🎉',
                      ),
                      icon: Icon(
                        task.status == TaskStatus.completed
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: task.status == TaskStatus.completed
                            ? AppColors.teal
                            : AppColors.muted,
                        size: 23,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 15,
                        color: AppColors.muted,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        durationLabel(task.minutes),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                  if (task.deadline != null)
                    Text(
                      deadlineLabel(task.deadline),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                  if (task.overdueAt(now))
                    const Tag('En retard', color: AppColors.red)
                  else if (task.priority.index >= 2)
                    Tag(
                      task.priority.label,
                      color: task.priority == Priority.urgent
                          ? AppColors.red
                          : AppColors.amber,
                    ),
                ],
              ),
              if (task.checklist.isNotEmpty) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: task.progress,
                          minHeight: 5,
                          color: color,
                          backgroundColor: color.withValues(alpha: .1),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${task.completedItems}/${task.checklist.length} · ${(task.progress * 100).round()} %',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
