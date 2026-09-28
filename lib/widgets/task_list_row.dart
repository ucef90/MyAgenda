import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/format.dart';
import '../models/task.dart';
import '../repositories/workspace_store.dart';
import '../theme/app_theme.dart';
import '../theme/task_colors.dart';
import 'common.dart';
import 'task_status_badge.dart';

class TaskListRow extends ConsumerWidget {
  final Task task;
  const TaskListRow(this.task, {super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = task.displayColor;
    final done = task.status == TaskStatus.completed;
    final now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();
    return Card(
      color: task.blockColor(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: color.withValues(alpha: .25)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/task/${task.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 13, 16, 13),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 42,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              IconButton(
                tooltip: done ? 'Rouvrir la tâche' : 'Terminer la tâche',
                onPressed: task.status == TaskStatus.cancelled
                    ? null
                    : () => attempt(
                        context,
                        () => ref
                            .read(workspaceProvider.notifier)
                            .setStatus(
                              task,
                              done ? TaskStatus.todo : TaskStatus.completed,
                            ),
                      ),
                icon: Icon(
                  done ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: done ? AppColors.teal : color,
                  size: 22,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        decoration: done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          task.professional
                              ? ref
                                    .watch(workspaceProvider)
                                    .clientName(task.clientId)
                              : task.project.isEmpty
                              ? task.resolvedCategory.label
                              : task.project,
                          style: TextStyle(
                            fontSize: 12,
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          durationLabel(task.minutes),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                        if (task.scheduledAt != null)
                          Text(
                            '${shortDate(task.scheduledAt!)} · ${clock(task.scheduledAt!)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          )
                        else if (task.deadline != null)
                          Text(
                            deadlineLabel(task.deadline),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        TaskStatusBadge(task: task, now: now),
                        if (task.priority.index >= 2)
                          Tag(task.priority.label, color: AppColors.amber),
                        if (task.attachments.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.image_outlined,
                                size: 14,
                                color: AppColors.muted,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${task.attachments.length}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        if (task.checklist.isNotEmpty)
                          Text(
                            '${task.completedItems}/${task.checklist.length} étapes',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, size: 18, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
