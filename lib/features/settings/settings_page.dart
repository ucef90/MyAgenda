import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config.dart';
import '../../core/format.dart';
import '../../models/workspace.dart';
import '../../repositories/workspace_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});
  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late TextEditingController _name;
  late int _start, _end, _breakStart, _breakEnd;
  late Set<int> _weekdays;
  late bool _dark;
  @override
  void initState() {
    super.initState();
    final p = ref.read(workspaceProvider).preferences;
    _name = TextEditingController(text: p.name);
    _start = p.workStart;
    _end = p.workEnd;
    _breakStart = p.breakStart;
    _breakEnd = p.breakEnd;
    _weekdays = p.weekdays.toSet();
    _dark = p.dark;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Widget timeSetting(String title, int minutes, void Function(int) set) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title),
        trailing: TextButton(
          onPressed: () async {
            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
            );
            if (time != null) setState(() => set(time.hour * 60 + time.minute));
          },
          child: Text(clock(atMinute(DateTime.now(), minutes))),
        ),
      );
  @override
  Widget build(BuildContext context) {
    final store = ref.read(workspaceProvider.notifier),
        w = ref.watch(workspaceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('À votre rythme')),
      body: PageBody(
        children: [
          Text(
            'Votre espace,\nvos habitudes.',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SectionTitle('Profil'),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Prénom'),
          ),
          const SectionTitle('Horaires habituels'),
          Wrap(
            spacing: 7,
            children: [
              for (var i = 1; i <= 7; i++)
                FilterChip(
                  label: Text(
                    ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'][i - 1],
                  ),
                  selected: _weekdays.contains(i),
                  onSelected: (v) => setState(
                    () => v ? _weekdays.add(i) : _weekdays.remove(i),
                  ),
                ),
            ],
          ),
          timeSetting('Début de journée', _start, (v) => _start = v),
          timeSetting('Fin de journée', _end, (v) => _end = v),
          timeSetting('Début de pause', _breakStart, (v) => _breakStart = v),
          timeSetting('Fin de pause', _breakEnd, (v) => _breakEnd = v),
          const Text(
            'Une pause de durée nulle désactive la pause. Les tâches déjà planifiées restent en place après un changement d’horaires.',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          const SectionTitle('Apparence'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mode sombre'),
            value: _dark,
            onChanged: (v) => setState(() => _dark = v),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              if (_name.text.trim().isEmpty ||
                  _start >= _end ||
                  _breakEnd < _breakStart ||
                  _breakStart < _start ||
                  _breakEnd > _end) {
                toast(
                  context,
                  'Vérifiez votre prénom, vos horaires et la pause.',
                );
                return;
              }
              attempt(
                context,
                () => store.savePreferences(
                  Preferences(
                    name: _name.text.trim(),
                    workStart: _start,
                    workEnd: _end,
                    breakStart: _breakStart,
                    breakEnd: _breakEnd,
                    weekdays: _weekdays.toList()..sort(),
                    dark: _dark,
                  ),
                ),
                success: 'Préférences enregistrées',
              );
            },
            child: const Text('Enregistrer mes préférences'),
          ),
          const SectionTitle('Mes données'),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.lock_outline),
            title: Text('Sur cet appareil uniquement'),
            subtitle: Text(
              'Pas de compte requis dans cette version. Aucune synchronisation ni publication automatique.',
            ),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: store.export()));
              if (context.mounted) {
                toast(
                  context,
                  'Sauvegarde JSON copiée. Conservez-la dans un fichier sûr.',
                );
              }
            },
            icon: const Icon(Icons.copy_all_outlined),
            label: const Text('Copier une sauvegarde JSON'),
          ),
          if (w.demo) ...[
            const SizedBox(height: 14),
            TextButton(
              onPressed: () async {
                if (await confirm(
                      context,
                      'Commencer avec un espace vide ?',
                      'Toutes les données présentes seront effacées, y compris vos éventuels ajouts. Copiez une sauvegarde avant de continuer.',
                    ) &&
                    context.mounted) {
                  if (attempt(
                    context,
                    store.clearDemo,
                    success: 'Votre espace est prêt',
                  )) {
                    Navigator.pop(context);
                  }
                }
              },
              child: const Text('Effacer les données de découverte'),
            ),
          ],
          const SectionTitle('Cette première version'),
          const Text(
            'Tâches, sous-tâches, notes, planning et focus sont utilisables localement. La connexion serveur, les rappels système et les liens publics clients viendront après validation de l’interface.',
          ),
          const SizedBox(height: 28),
          const Center(
            child: Text(
              '$appName · 0.1.0\n$appTagline',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class RemindersPage extends ConsumerWidget {
  const RemindersPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final list =
        ref
            .watch(workspaceProvider)
            .tasks
            .where(
              (t) =>
                  t.isOpen &&
                  t.deadline != null &&
                  t.deadline!.isBefore(now.add(const Duration(days: 2))),
            )
            .toList()
          ..sort((a, b) => a.deadline!.compareTo(b.deadline!));
    return Scaffold(
      appBar: AppBar(title: const Text('À surveiller')),
      body: PageBody(
        children: [
          const Text(
            'Vos prochaines échéances. Les rappels système ne sont pas encore activés dans cette version.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 20),
          if (list.isEmpty)
            const EmptyState(
              title: 'L’esprit tranquille',
              subtitle: 'Aucune échéance proche.',
            ),
          for (final t in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  leading: Icon(
                    t.overdueAt(now) ? Icons.schedule : Icons.flag_outlined,
                    color: t.overdueAt(now) ? AppColors.red : AppColors.indigo,
                  ),
                  title: Text(t.title),
                  subtitle: Text(deadlineLabel(t.deadline)),
                  onTap: () => Navigator.pop(context, t.id),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
