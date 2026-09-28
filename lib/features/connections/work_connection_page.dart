import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/task.dart';
import '../../models/work_connection.dart';
import '../../repositories/work_connection_store.dart';
import '../../repositories/workspace_store.dart';
import '../../services/work/work_gateway.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class WorkConnectionPage extends ConsumerStatefulWidget {
  const WorkConnectionPage({super.key});
  @override
  ConsumerState<WorkConnectionPage> createState() => _WorkConnectionPageState();
}

class _WorkConnectionPageState extends ConsumerState<WorkConnectionPage> {
  final _url = TextEditingController(),
      _code = TextEditingController(),
      _name = TextEditingController(text: 'Mon agenda');
  bool _trainingsOnly = true;
  @override
  void dispose() {
    _url.dispose();
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    FocusScope.of(context).unfocus();
    await ref
        .read(workConnectionProvider.notifier)
        .connect(
          _url.text,
          _code.text,
          _name.text,
          trainingsOnly: _trainingsOnly,
        );
    if (mounted && ref.read(workConnectionProvider).connected) _code.clear();
  }

  Future<void> _disconnect() async {
    final answer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirer cet appareil de Work ?'),
        content: const Text(
          'Les tâches partagées et les propositions de cet appareil seront supprimées du serveur. Vos tâches locales et les confirmations déjà acceptées seront conservées. Les conversations déjà créées dans Work restent dans Work.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Déconnecter'),
          ),
        ],
      ),
    );
    if (answer == true && mounted) {
      await ref.read(workConnectionProvider.notifier).disconnect();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workConnectionProvider),
        store = ref.read(workConnectionProvider.notifier);
    final supported = ref.watch(workGatewayProvider).supported;
    final tasks = ref.watch(workspaceProvider).tasks;
    return Scaffold(
      appBar: AppBar(title: const Text('ChatGPT Work')),
      bottomNavigationBar: !state.connected && supported
          ? SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  12 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: FilledButton.icon(
                  onPressed: state.busy || !state.ready ? null : _connect,
                  icon: const Icon(Icons.link),
                  label: const Text('Relier mon agenda'),
                ),
              ),
            )
          : null,
      body: PageBody(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3730A3), Color(0xFF6D28D9)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome, color: Colors.white, size: 30),
                const SizedBox(height: 16),
                Text(
                  state.connected
                      ? 'Votre assistant, relié à votre agenda.'
                      : 'Préparez vos formations avec Work.',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineMedium?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Work croise vos formations avec les mails accessibles dans Gmail. Vous gardez la main sur chaque confirmation.',
                  style: TextStyle(color: Colors.white, height: 1.5),
                ),
                const SizedBox(height: 16),
                Text(
                  state.connected
                      ? '${state.proposals.length} proposition${state.proposals.length > 1 ? 's' : ''} à vérifier'
                      : 'Connexion au serveur à configurer',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (state.busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: LinearProgressIndicator(),
            ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                state.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (!supported)
            const Padding(
              padding: EdgeInsets.only(top: 20),
              child: Text(
                'Cette connexion privée est disponible dans MyAgenda sur iPhone et Mac.',
              ),
            ),
          if (!state.connected) ...[
            const SectionTitle('1. Votre serveur MyAgenda'),
            const Text(
              'Le serveur privé doit être installé avec une adresse HTTPS. Récupérez ensuite un code d’association valable 10 minutes. Aucun mot de passe Gmail n’est demandé ici.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _url,
              enabled: !state.busy && supported,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Adresse HTTPS du serveur',
                hintText: 'https://agenda.votre-domaine.fr',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _name,
              enabled: !state.busy && supported,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Nom de cet appareil',
                helperText: 'Par exemple : iPhone de Youssef',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _code,
              enabled: !state.busy && supported,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'Code d’association temporaire',
              ),
            ),
            const SectionTitle('2. Ce que vous partagez'),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _trainingsOnly,
              onChanged: state.busy
                  ? null
                  : (v) => setState(() => _trainingsOnly = v),
              title: const Text('Uniquement mes formations'),
              subtitle: Text(
                _trainingsOnly
                    ? 'Titres, projets, dates, durées, statuts et préparation.'
                    : 'Formations et tâches professionnelles : titres, projets, dates, durées, statuts et préparation.',
              ),
            ),
            const Text(
              'Les notes, photos, audios et coordonnées clients restent sur cet appareil.',
            ),
          ] else ...[
            const SectionTitle('Connexion de cet appareil'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                state.lastSync != null && state.error == null
                    ? Icons.cloud_done_outlined
                    : Icons.cloud_sync_outlined,
                color: AppColors.teal,
              ),
              title: Text(state.name ?? 'Mon agenda'),
              subtitle: Text(
                '${state.url}\n${state.lastSync == null ? 'Première synchronisation à terminer' : 'Dernier échange : ${state.lastSync!.hour.toString().padLeft(2, '0')}:${state.lastSync!.minute.toString().padLeft(2, '0')}'}',
              ),
            ),
            OutlinedButton.icon(
              onPressed: state.busy ? null : store.sync,
              icon: const Icon(Icons.sync),
              label: const Text('Actualiser maintenant'),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: state.trainingsOnly,
              onChanged: state.busy ? null : store.setTrainingsOnly,
              title: const Text('Uniquement mes formations'),
              subtitle: const Text(
                'Désactivez pour inclure les autres tâches professionnelles. Le changement s’applique au prochain échange réussi.',
              ),
            ),
            const Text(
              'Synchronisation à l’ouverture et pendant l’utilisation. Ouvrez MyAgenda avant de demander une analyse dans Work.',
            ),
            SectionTitle('À valider (${state.proposals.length})'),
            if (state.proposals.isEmpty)
              const EmptyState(
                icon: Icons.mark_email_read_outlined,
                title: 'Aucune proposition en attente',
                subtitle:
                    'Dans Work, demandez de vérifier les prochaines formations avec Gmail, puis actualisez ici.',
              ),
            for (final p in state.proposals)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _ProposalCard(
                  proposal: p,
                  task: tasks.where((t) => t.id == p.taskId).firstOrNull,
                  busy: state.busy,
                  onDecision: (accept) => store.decide(p, accept: accept),
                ),
              ),
          ],
          const SectionTitle('Dans ChatGPT Work'),
          const Text(
            'Ajoutez le connecteur MyAgenda avec l’adresse ci-dessous, autorisez-le sur la page de votre serveur, puis utilisez-le avec votre connexion Gmail. Le compte Gmail reste géré dans Work.',
          ),
          const SizedBox(height: 12),
          if (state.url != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: SelectableText('${state.url}/mcp'),
              trailing: IconButton(
                tooltip: 'Copier l’adresse du connecteur',
                icon: const Icon(Icons.copy),
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: '${state.url}/mcp'),
                  );
                  if (context.mounted) toast(context, 'Adresse copiée');
                },
              ),
            ),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: SelectableText(
                '« Vérifie mes prochaines formations dans MyAgenda avec les mails Gmail. Propose les confirmations pour le support, le bon de commande signé et le mail envoyé. Cite les mails et laisse “À vérifier” quand tu ne peux pas conclure. »',
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Une recherche sans résultat n’est pas une preuve de retard. Les sources proposées par Work doivent correspondre à la bonne formation et à sa date. Cette version ne lance pas d’analyse Gmail en continu.',
          ),
          if (state.connected)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: TextButton.icon(
                onPressed: state.busy ? null : _disconnect,
                icon: const Icon(Icons.link_off),
                label: const Text(
                  'Déconnecter et retirer les données partagées',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProposalCard extends StatelessWidget {
  final WorkProposal proposal;
  final Task? task;
  final bool busy;
  final ValueChanged<bool> onDecision;
  const _ProposalCard({
    required this.proposal,
    required this.task,
    required this.busy,
    required this.onDecision,
  });
  @override
  Widget build(BuildContext context) {
    final p = proposal,
        current = task != null && (p.matches(task!) || p.alreadyApplied(task!));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tag(
              preparationSteps[p.field]!,
              color: AppColors.violet,
              icon: Icons.auto_awesome,
            ),
            const SizedBox(height: 12),
            Text(
              task?.title ?? p.basis['title'] as String? ?? 'Tâche supprimée',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              p.value == null
                  ? 'Proposition : À vérifier'
                  : p.value!
                  ? 'Proposition : Oui, confirmé'
                  : 'Proposition : À faire',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(p.reason),
            WorkEvidenceSources(sources: p.evidence),
            if (!current)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'La tâche a changé depuis l’analyse. Demandez une nouvelle proposition.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (task != null)
              TextButton(
                onPressed: () => context.push('/task/${task!.id}'),
                child: const Text('Voir la formation'),
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: busy || !current ? null : () => onDecision(true),
                  icon: const Icon(Icons.check),
                  label: const Text('Confirmer'),
                ),
                OutlinedButton(
                  onPressed: busy ? null : () => onDecision(false),
                  child: const Text('Refuser'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class WorkEvidenceSources extends StatelessWidget {
  final List<Map<String, dynamic>> sources;
  const WorkEvidenceSources({super.key, required this.sources});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final source in sources)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.mail_outline),
          title: Text(source['title'] as String? ?? 'Source Gmail'),
          subtitle: Text(
            'Mail du ${(source['date'] as String? ?? '').split('T').first} · Source proposée par Work',
          ),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () async {
            final url = Uri.tryParse(source['url'] as String? ?? '');
            if (url == null ||
                url.scheme != 'https' ||
                url.host != 'mail.google.com' ||
                url.userInfo.isNotEmpty ||
                url.hasPort) {
              return;
            }
            try {
              await NativeWorkGateway.channel.invokeMethod(
                'workOpenMail',
                url.toString(),
              );
            } catch (_) {
              if (context.mounted) {
                toast(
                  context,
                  'Ouvrez ce mail dans Gmail pour vérifier la source.',
                );
              }
            }
          },
        ),
    ],
  );
}
