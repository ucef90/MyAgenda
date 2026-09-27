import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/format.dart';
import '../../models/task.dart';
import '../../repositories/workspace_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class FocusPage extends ConsumerWidget {
  final String id;
  const FocusPage({super.key, required this.id});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref
        .watch(workspaceProvider)
        .tasks
        .where((t) => t.id == id)
        .firstOrNull;
    final now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();
    if (t == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          title: 'Tâche introuvable',
          subtitle: 'Revenez à vos tâches.',
        ),
      );
    }
    final seconds = t.secondsAt(now),
        store = ref.read(workspaceProvider.notifier);
    final time =
        '${(seconds ~/ 3600).toString().padLeft(2, '0')}:${(seconds ~/ 60 % 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    return Scaffold(
      appBar: AppBar(title: const Text('Mode Focus')),
      body: PageBody(
        children: [
          const SizedBox(height: 28),
          Center(
            child: Tag(
              t.status == TaskStatus.completed
                  ? 'Tâche terminée'
                  : t.status == TaskStatus.cancelled
                  ? 'Tâche annulée'
                  : t.runningSince == null
                  ? 'En pause'
                  : 'Un instant pour avancer',
              color: AppColors.violet,
              icon: Icons.blur_on,
            ),
          ),
          const SizedBox(height: 26),
          Text(
            t.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 32),
          Center(
            child: SizedBox(
              width: 260,
              height: 260,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: (seconds / (t.minutes * 60)).clamp(0, 1),
                      strokeWidth: 7,
                      color: AppColors.violet,
                      backgroundColor: AppColors.violet.withValues(alpha: .09),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        time,
                        style: const TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'sur ${durationLabel(t.minutes)} prévues',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 34),
          if (t.isOpen)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => attempt(
                      context,
                      () => t.runningSince == null
                          ? store.startFocus(t)
                          : store.pauseFocus(t),
                    ),
                    icon: Icon(
                      t.runningSince == null ? Icons.play_arrow : Icons.pause,
                    ),
                    label: Text(t.runningSince == null ? 'Reprendre' : 'Pause'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      attempt(
                        context,
                        () => store.setStatus(t, TaskStatus.completed),
                        success: 'Tâche terminée 🎉',
                      );
                      HapticFeedback.lightImpact();
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Terminer'),
                  ),
                ),
              ],
            )
          else if (t.status == TaskStatus.completed)
            const Center(
              child: Text(
                'Un pas de plus. Bien joué !',
                style: TextStyle(color: AppColors.teal, fontSize: 18),
              ),
            ),
          if (t.status == TaskStatus.cancelled)
            const Center(
              child: Text('Rouvrez la tâche depuis son détail pour reprendre.'),
            ),
          if (t.checklist.isNotEmpty) ...[
            const SectionTitle('Un pas après l’autre'),
            for (final i in t.checklist)
              CheckboxListTile(
                value: i.done,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(i.title),
                onChanged: (_) =>
                    attempt(context, () => store.toggleItem(t, i.id)),
              ),
          ],
          const SizedBox(height: 18),
          const Text(
            'Le chronomètre reste actif si vous quittez cet écran. Il ne s’arrête qu’avec Pause ou Terminer.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
