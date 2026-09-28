import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/format.dart';
import '../../models/task.dart';
import '../../repositories/workspace_store.dart';
import '../../services/planner.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/task_card.dart';
import 'timeline.dart';
import '../../services/day_progress.dart';
import '../assistant/assistant_page.dart';

class TodayPage extends ConsumerWidget {
  const TodayPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(workspaceProvider),
        now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();
    final scheduled =
        w.tasks
            .where(
              (t) =>
                  t.scheduledAt != null &&
                  sameDay(t.scheduledAt!, now) &&
                  t.status != TaskStatus.cancelled,
            )
            .toList()
          ..sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));
    final active = w.tasks.where((t) => t.runningSince != null).firstOrNull;
    final next =
        active ??
        scheduled
            .where((t) => t.isOpen && t.scheduledEnd!.isAfter(now))
            .firstOrNull ??
        scheduled.where((t) => t.isOpen).firstOrNull;
    final planned = scheduled.fold(0, (s, t) => s + t.minutes);
    final free = const Planner()
        .freeSlots(now, w.preferences, w.tasks, notBefore: now)
        .fold(0, (s, t) => s + t.minutes);
    final progress = DayProgress.calculate(w.tasks, now);
    final paceColor = switch (progress.pace) {
      DayPace.behind => AppColors.red,
      DayPace.onTime => AppColors.teal,
      DayPace.ahead => const Color(0xFF0369A1),
    };
    final urgent = w.tasks
        .where(
          (t) =>
              t.isOpen && (t.overdueAt(now) || t.priority == Priority.urgent),
        )
        .toList();
    return PageBody(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dayLabel(now).toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bonjour ${w.preferences.name}',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Paramètres',
              onPressed: () => context.push('/settings'),
              icon: CircleAvatar(
                backgroundColor: const Color(0xFFEEF2FF),
                foregroundColor: AppColors.indigo,
                child: Text(
                  w.preferences.name.isEmpty
                      ? 'Y'
                      : w.preferences.name.substring(0, 1).toUpperCase(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Vos journées avancent. Vos envies aussi.',
          style: TextStyle(color: AppColors.muted),
        ),
        if (w.demo)
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Wrap(
              spacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Tag(
                  'Espace de découverte',
                  icon: Icons.auto_awesome_outlined,
                ),
                TextButton(
                  onPressed: () => context.push('/settings'),
                  child: const Text('Personnaliser'),
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${(progress.fraction * 100).round()} % réalisés',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      progress.label,
                      style: TextStyle(
                        color: paceColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: progress.fraction,
                  minHeight: 9,
                  borderRadius: BorderRadius.circular(8),
                  color: paceColor,
                  backgroundColor: paceColor.withValues(alpha: .12),
                ),
                const SizedBox(height: 8),
                Text(
                  '${progress.completed}/${progress.total} tâches du jour terminées · rythme selon les fins de créneau prévues',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        _FocusCard(task: next),
        const SizedBox(height: 18),
        const AssistantTeaser(),
        const SizedBox(height: 22),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _Metric(
                        '${scheduled.where((t) => t.isOpen).length}',
                        'tâches restantes',
                      ),
                    ),
                    Expanded(
                      child: _Metric(durationLabel(planned), 'planifiées'),
                    ),
                    Expanded(
                      child: _Metric(
                        durationLabel(free),
                        'encore libres',
                        color: AppColors.teal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SectionTitle(
          'Le fil de votre journée',
          action: IconButton(
            tooltip: 'Organiser ma journée',
            onPressed: () => context.push('/planning'),
            icon: const Icon(
              Icons.auto_awesome_outlined,
              color: AppColors.indigo,
            ),
          ),
        ),
        Timeline(day: now),
        if (urgent.isNotEmpty) ...[
          const SectionTitle('À garder en tête'),
          for (final t in urgent.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TaskCard(t),
            ),
        ],
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  final String value, label;
  final Color? color;
  const _Metric(this.value, this.label, {this.color});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: Theme.of(
          context,
        ).textTheme.headlineMedium?.copyWith(color: color, fontSize: 25),
      ),
      const SizedBox(height: 5),
      Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
    ],
  );
}

class _FocusCard extends ConsumerWidget {
  final Task? task;
  const _FocusCard({this.task});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF4F46E5), Color(0xFF6657DB)],
      ),
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: AppColors.indigo.withValues(alpha: .16),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.blur_on_rounded,
              color: Color(0xFFC7D2FE),
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                task?.runningSince != null
                    ? 'VOTRE MOMENT FOCUS'
                    : 'LA SUITE, EN DOUCEUR',
                style: const TextStyle(
                  color: Color(0xFFE0E7FF),
                  fontSize: 11,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.north_east_rounded,
              color: Color(0xFFC7D2FE),
              size: 20,
            ),
          ],
        ),
        const SizedBox(height: 22),
        Text(
          task?.title ?? 'L’esprit libre pour demain.',
          style: const TextStyle(
            fontSize: 25,
            height: 1.2,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -.5,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          task == null
              ? 'Votre planning est ouvert. Donnez une place à vos prochaines idées.'
              : '${task!.scheduledAt == null ? 'À votre rythme' : '${clock(task!.scheduledAt!)} – ${clock(task!.scheduledEnd!)}'}  ·  ${durationLabel(task!.minutes)}',
          style: const TextStyle(color: Color(0xFFE0E7FF), fontSize: 14),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.indigo,
          ),
          onPressed: () {
            if (task == null) {
              context.push('/planning');
            } else {
              if (attempt(
                context,
                () => ref.read(workspaceProvider.notifier).startFocus(task!),
              )) {
                context.push('/focus/${task!.id}');
              }
            }
          },
          icon: Icon(
            task == null
                ? Icons.auto_awesome_outlined
                : Icons.play_arrow_rounded,
          ),
          label: Text(
            task == null
                ? 'Organiser ma journée'
                : task!.runningSince != null
                ? 'Reprendre le focus'
                : 'Démarrer le focus',
          ),
        ),
      ],
    ),
  );
}
