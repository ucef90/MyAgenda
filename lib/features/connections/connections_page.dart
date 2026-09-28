import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../repositories/work_connection_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/format.dart';
import '../../repositories/workspace_store.dart';
import '../../services/calendar_import.dart';
import '../../services/device_assistant.dart';
import '../../widgets/common.dart';

class ConnectionsPage extends ConsumerStatefulWidget {
  const ConnectionsPage({super.key});
  @override
  ConsumerState<ConnectionsPage> createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends ConsumerState<ConnectionsPage> {
  List<Map>? _calendars;
  List<CalendarEvent>? _events;
  Set<String> _calendarIds = {}, _selected = {};
  bool _busy = false;
  String? _error;
  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final values = await DeviceAssistant.call<List>('calendars') ?? [];
      if (!mounted) return;
      setState(() {
        _calendars = values.cast<Map>();
        _calendarIds =
            ref
                .read(preferencesProvider)
                .getStringList('myagenda.calendars')
                ?.toSet() ??
            {};
      });
    } catch (e) {
      if (mounted) setState(() => _error = deviceError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _preview() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final events = await readCalendarEvents(_calendarIds.toList());
      if (mounted) {
        setState(() {
          _events = events;
          _selected = events
              .where((e) => !e.allDay && e.canImport)
              .map((e) => e.id)
              .toSet();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = deviceError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final selected = _events!.where((e) => _selected.contains(e.id)).toList();
      final store = ref.read(workspaceProvider.notifier);
      store.importCalendar(selected);
      await store.flush();
      if (store.persistenceError != null) {
        throw StateError(store.persistenceError!);
      }
      // Only existing imported events auto-refresh; new events always require preview.
      await ref
          .read(preferencesProvider)
          .setStringList('myagenda.calendars', _calendarIds.toList());
      if (mounted) {
        toast(context, '${selected.length} événements importés ou actualisés');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => _error = deviceError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Agenda & connexions')),
    bottomNavigationBar: _events == null
        ? null
        : SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: _busy || _selected.isEmpty ? null : _import,
                icon: const Icon(Icons.download_done),
                label: Text('Importer ${_selected.length} événements'),
              ),
            ),
          ),
    body: PageBody(
      children: [
        Text(
          'Vos rendez-vous, au même endroit.',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        const Text(
          'Importez les 90 prochains jours depuis les calendriers de l’iPhone, y compris Google Agenda s’il est ajouté dans les réglages iOS. MyAgenda ne modifie pas votre calendrier.',
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _busy || !DeviceAssistant.supported ? null : _load,
          icon: const Icon(Icons.calendar_month),
          label: const Text('Choisir mes calendriers'),
        ),
        if (!DeviceAssistant.supported)
          const Text('L’import est disponible sur iPhone.'),
        if (_busy)
          const Padding(
            padding: EdgeInsets.all(16),
            child: LinearProgressIndicator(),
          ),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.red)),
        if (_calendars != null) ...[
          for (final c in _calendars!)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(c['title']),
              subtitle: Text(c['source']),
              value: _calendarIds.contains(c['id']),
              onChanged: _busy
                  ? null
                  : (v) => setState(() {
                      v!
                          ? _calendarIds.add(c['id'])
                          : _calendarIds.remove(c['id']);
                      _events = null;
                    }),
            ),
          OutlinedButton(
            onPressed: _busy || _calendarIds.isEmpty ? null : _preview,
            child: const Text('Voir les événements à importer'),
          ),
        ],
        if (_events != null) ...[
          const SectionTitle('Événements à importer'),
          const Text(
            'Sélectionnez les rendez-vous utiles. Les événements déjà importés seront mis à jour sans perdre vos notes. Les journées entières sont décochées par défaut. Les événements de plus de 24 heures ne sont pas importables : créez une tâche par journée.',
          ),
          if (_events!.isEmpty)
            const Text('Aucun événement dans les 90 prochains jours.'),
          for (final e in _events!)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(e.title),
              subtitle: Text(
                '${shortDate(e.start)} · ${e.allDay ? 'Journée entière' : clock(e.start)} · ${e.calendar}',
              ),
              value: _selected.contains(e.id),
              onChanged: _busy || !e.canImport
                  ? null
                  : (v) => setState(() {
                      v! ? _selected.add(e.id) : _selected.remove(e.id);
                    }),
            ),
        ],
        const SectionTitle('Actualisation'),
        const Text(
          'À la réouverture, MyAgenda actualise les rendez-vous déjà importés. Importez à nouveau pour ajouter les nouveaux. Les événements supprimés dans l’agenda ne sont pas effacés automatiquement ici.',
        ),
        TextButton(
          onPressed: () async {
            await ref.read(preferencesProvider).remove('myagenda.calendars');
            if (context.mounted) {
              toast(context, 'Actualisation automatique désactivée');
            }
          },
          child: const Text('Désactiver l’actualisation'),
        ),
        const SectionTitle('Gmail & ChatGPT Work'),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.auto_awesome),
          title: const Text('ChatGPT Work'),
          subtitle: Text(
            ref.watch(workConnectionProvider).connected
                ? '${ref.watch(workConnectionProvider).proposals.length} propositions à vérifier · Voir la connexion'
                : 'Relier mon agenda et vérifier mes formations avec Gmail',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/work'),
        ),
        const Text(
          'Work analyse les mails via votre connexion Gmail et propose des confirmations à valider ici.',
        ),
      ],
    ),
  );
}
