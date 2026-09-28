import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../repositories/workspace_store.dart';
import '../../services/ios_alerts.dart';
import '../../widgets/common.dart';

class AlertsPage extends ConsumerStatefulWidget {
  const AlertsPage({super.key});
  @override
  ConsumerState<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends ConsumerState<AlertsPage> {
  bool _busy = false;
  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(iosAlertStatusProvider);
    } catch (_) {
      if (mounted) {
        toast(
          context,
          'Impossible de terminer. Vérifiez les autorisations dans Réglages.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sync() async {
    final store = ref.read(workspaceProvider.notifier);
    await store.flush();
    if (store.persistenceError != null) {
      throw StateError('Sauvegarde impossible');
    }
    await ref
        .read(iosAlertsProvider)
        .sync(ref.read(workspaceProvider), DateTime.now(), force: true);
    ref.read(alertErrorProvider.notifier).state = null;
  }

  @override
  Widget build(BuildContext context) {
    final w = ref.watch(workspaceProvider), p = w.preferences;
    final service = ref.read(iosAlertsProvider);
    final status = ref.watch(iosAlertStatusProvider);
    final info = status.valueOrNull;
    final error = ref.watch(alertErrorProvider);
    final plan = ReminderPlan.build(w, DateTime.now());
    return Scaffold(
      appBar: AppBar(title: const Text('Rappels & écran verrouillé')),
      body: PageBody(
        children: [
          Text(
            'La bonne tâche,\nau bon moment.',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 16),
          if (!service.supported)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Ces fonctions s’activent dans MyAgenda sur votre iPhone. Les réglages sont propres à chaque appareil.',
                ),
              ),
            ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Me rappeler mes tâches'),
            subtitle: const Text(
              'À l’heure planifiée, ou à l’échéance si aucun créneau n’est défini. Fonctionne aussi quand l’application est fermée.',
            ),
            value: p.remindersEnabled,
            onChanged: !service.supported || _busy
                ? null
                : (value) => _run(() async {
                    if (value && !await service.requestPermission()) {
                      if (context.mounted) {
                        toast(
                          context,
                          'Autorisez les notifications de MyAgenda dans Réglages.',
                        );
                      }
                      return;
                    }
                    ref
                        .read(workspaceProvider.notifier)
                        .savePreferences(p.copyWith(remindersEnabled: value));
                    await _sync();
                  }),
          ),
          DropdownButtonFormField<int>(
            isExpanded: true,
            initialValue: [0, 5, 10, 15, 30].contains(p.reminderLeadMinutes)
                ? p.reminderLeadMinutes
                : 5,
            decoration: const InputDecoration(labelText: 'Un rappel en avance'),
            items: [0, 5, 10, 15, 30]
                .map(
                  (m) => DropdownMenuItem(
                    value: m,
                    child: Text(
                      m == 0
                          ? 'Uniquement à l’heure prévue'
                          : '$m minutes avant',
                    ),
                  ),
                )
                .toList(),
            onChanged: !service.supported || _busy
                ? null
                : (v) => _run(() async {
                    ref
                        .read(workspaceProvider.notifier)
                        .savePreferences(p.copyWith(reminderLeadMinutes: v));
                    await _sync();
                  }),
          ),
          const SizedBox(height: 12),
          if (service.supported)
            Text(
              status.isLoading
                  ? 'Vérification des autorisations…'
                  : info?.authorized == true
                  ? '${plan.pending.length} rappels à venir préparés sur cet iPhone.'
                  : 'Notifications non autorisées. Activez-les pour recevoir les alertes.',
            ),
          if (plan.omitted > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${plan.omitted} rappels supplémentaires seront préparés aux prochaines ouvertures. Les 60 plus proches sont prioritaires.',
              ),
            ),
          const SectionTitle('Votre tâche reste à portée de regard'),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Activité en direct'),
            subtitle: const Text(
              'Une carte sur l’écran verrouillé et, sur les modèles compatibles, dans la Dynamic Island.',
            ),
            value: p.liveActivitiesEnabled,
            onChanged:
                !service.supported ||
                    _busy ||
                    info?.liveSupported != true ||
                    info?.liveEnabled != true
                ? null
                : (v) => _run(() async {
                    ref
                        .read(workspaceProvider.notifier)
                        .savePreferences(p.copyWith(liveActivitiesEnabled: v));
                    await _sync();
                  }),
          ),
          if (service.supported && info != null && !info.liveSupported)
            const Text(
              'L’activité en direct nécessite iOS 16.2 ou une version ultérieure.',
            ),
          if (info?.liveSupported == true && info?.liveEnabled == false)
            const Text(
              'Autorisez les activités en direct de MyAgenda dans Réglages.',
            ),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Ouvrez la tâche depuis son rappel ou lancez le mode Focus pour afficher la carte. Elle suit le chronomètre, la pause et la fin de tâche. Une nouvelle carte ne démarre pas automatiquement lorsque l’application est fermée.\n\niOS limite une activité à 8 heures, puis peut la garder jusqu’à 4 heures sur l’écran verrouillé. Vous pouvez la retirer à tout moment. L’écran ne reste pas forcément allumé.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (error != null || status.hasError)
            Text(error ?? 'Impossible de lire les autorisations. Réessayez.'),
          if (service.supported) ...[
            FilledButton.icon(
              onPressed: _busy || info?.authorized != true
                  ? null
                  : () => _run(() async {
                      await service.testNotification();
                      if (context.mounted) {
                        toast(
                          context,
                          'Test dans 5 secondes. Vous pouvez verrouiller l’iPhone.',
                        );
                      }
                    }),
              icon: const Icon(Icons.notifications_active_outlined),
              label: const Text('Tester une notification'),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _run(_sync),
              icon: const Icon(Icons.refresh),
              label: const Text('Actualiser les rappels'),
            ),
            TextButton(
              onPressed: _busy ? null : () => _run(service.openSettings),
              child: const Text('Ouvrir les réglages de l’iPhone'),
            ),
            const Text(
              'Dans Réglages → Notifications → MyAgenda, activez Écran verrouillé et Bannières. Choisissez le style Persistant si proposé. Les modes Concentration et Résumé programmé peuvent retarder les alertes.',
            ),
          ],
        ],
      ),
    );
  }
}
