import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/format.dart';
import '../../models/personal_goal.dart';
import '../../models/task.dart';
import '../../models/workspace.dart';
import '../../repositories/workspace_store.dart';
import '../../theme/task_colors.dart';
import '../../widgets/common.dart';

class AssistantPreferencesPage extends ConsumerStatefulWidget {
  const AssistantPreferencesPage({super.key});
  @override
  ConsumerState<AssistantPreferencesPage> createState() =>
      _AssistantPreferencesPageState();
}

class _AssistantPreferencesPageState
    extends ConsumerState<AssistantPreferencesPage> {
  late Preferences _draft;
  late TextEditingController _motivation;
  @override
  void initState() {
    super.initState();
    _draft = ref.read(workspaceProvider).preferences;
    _motivation = TextEditingController(text: _draft.motivation);
  }

  @override
  void dispose() {
    _motivation.dispose();
    super.dispose();
  }

  Future<void> _edit([PersonalGoal? goal]) async {
    final result = await showModalBottomSheet<PersonalGoal>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _GoalForm(goal: goal),
    );
    if (result != null && mounted) {
      setState(
        () => _draft = _draft.copyWith(
          goals: [..._draft.goals.where((g) => g.id != result.id), result],
        ),
      );
    }
  }

  Widget _time(String label, int minute, ValueChanged<int> change) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    trailing: TextButton(
      onPressed: () async {
        final selected = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
        );
        if (selected != null && mounted) {
          setState(() => change(selected.hour * 60 + selected.minute));
        }
      },
      child: Text(clock(atMinute(DateTime.now(), minute))),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mes envies & mon rythme')),
    body: PageBody(
      children: [
        Text(
          'Du temps pour ce qui compte.',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 12),
        const Text(
          'Choisissez vos activités, leur durée et leur fréquence. L’assistant cherchera des places libres, sans déplacer vos engagements.',
        ),
        const SectionTitle('Mon intention'),
        TextField(
          controller: _motivation,
          maxLines: 2,
          maxLength: 250,
          decoration: const InputDecoration(
            hintText: 'Me remettre au sport, apprendre le piano…',
            labelText: 'Ce qui me motive',
          ),
        ),
        const Text(
          'Cette note vous sert de repère. Les suggestions utilisent les activités définies ci-dessous.',
          style: TextStyle(fontSize: 12),
        ),
        const SectionTitle('Mes activités'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final template in const [
              PersonalGoal(
                id: 'sport',
                title: 'Sport à mon rythme',
                color: TaskColor.teal,
              ),
              PersonalGoal(
                id: 'musique',
                title: 'Pratiquer la musique',
                minutes: 20,
                color: TaskColor.violet,
              ),
              PersonalGoal(
                id: 'lecture',
                title: 'Lire quelques pages',
                minutes: 20,
                color: TaskColor.blue,
              ),
              PersonalGoal(
                id: 'marche',
                title: 'Marcher en plein air',
                minutes: 20,
                color: TaskColor.amber,
              ),
            ])
              ActionChip(
                avatar: Icon(Icons.add, color: template.color.value, size: 18),
                label: Text(template.title),
                onPressed: () => _edit(
                  _draft.goals.where((g) => g.id == template.id).firstOrNull ??
                      template,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        for (final goal in _draft.goals)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: Column(
                children: [
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: goal.color.value.withValues(alpha: .12),
                      child: Icon(Icons.flag_outlined, color: goal.color.value),
                    ),
                    title: Text(goal.title),
                    subtitle: Text(
                      '${goal.weeklyTarget} × ${durationLabel(goal.minutes)} / semaine · ${goal.preferredTime.label}',
                    ),
                    onTap: () => _edit(goal),
                    trailing: const Icon(Icons.edit_outlined),
                  ),
                  Row(
                    children: [
                      Switch(
                        value: goal.enabled,
                        onChanged: (v) => setState(
                          () => _draft = _draft.copyWith(
                            goals: [
                              for (final g in _draft.goals)
                                g.id == goal.id ? g.copyWith(enabled: v) : g,
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          goal.enabled ? 'Suggestions activées' : 'En pause',
                        ),
                      ),
                      IconButton(
                        tooltip: 'Retirer l’objectif',
                        onPressed: () => setState(
                          () => _draft = _draft.copyWith(
                            goals: _draft.goals
                                .where((g) => g.id != goal.id)
                                .toList(),
                          ),
                        ),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        OutlinedButton.icon(
          onPressed: () => _edit(),
          icon: const Icon(Icons.add),
          label: const Text('Une autre activité'),
        ),
        const SectionTitle('Mes disponibilités personnelles'),
        const Text(
          'Ces horaires permettent aussi de proposer des activités le soir et le week-end.',
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          children: [
            for (var i = 1; i <= 7; i++)
              FilterChip(
                label: Text(
                  ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'][i - 1],
                ),
                selected: _draft.personalDays.contains(i),
                onSelected: (v) => setState(
                  () => _draft = _draft.copyWith(
                    personalDays: v
                        ? [..._draft.personalDays, i]
                        : _draft.personalDays.where((d) => d != i).toList(),
                  ),
                ),
              ),
          ],
        ),
        _time(
          'À partir de',
          _draft.personalStart,
          (v) => _draft = _draft.copyWith(personalStart: v),
        ),
        _time(
          'Jusqu’à',
          _draft.personalEnd,
          (v) => _draft = _draft.copyWith(personalEnd: v),
        ),
        const SectionTitle('Garder de la respiration'),
        DropdownButtonFormField<int>(
          initialValue: _draft.bufferMinutes,
          decoration: const InputDecoration(
            labelText: 'Marge entre deux activités',
          ),
          items: [
            for (final n in [0, 5, 10, 15, 30])
              DropdownMenuItem(value: n, child: Text('$n minutes')),
          ],
          onChanged: (v) =>
              setState(() => _draft = _draft.copyWith(bufferMinutes: v)),
        ),
        const SizedBox(height: 12),
        const Text(
          'L’assistant propose jusqu’à 3 tâches et 2 activités par jour. Il conserve une réserve de 30 minutes avant de proposer une activité personnelle.',
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () {
            final current = ref.read(workspaceProvider).preferences;
            if (attempt(
              context,
              () => ref
                  .read(workspaceProvider.notifier)
                  .savePreferences(
                    current.copyWith(
                      goals: _draft.goals,
                      motivation: _motivation.text.trim(),
                      personalStart: _draft.personalStart,
                      personalEnd: _draft.personalEnd,
                      personalDays: _draft.personalDays,
                      bufferMinutes: _draft.bufferMinutes,
                    ),
                  ),
              success: 'Préférences enregistrées',
            )) {
              context.canPop() ? context.pop() : context.go('/assistant');
            }
          },
          icon: const Icon(Icons.check),
          label: const Text('Enregistrer mes préférences'),
        ),
        const SizedBox(height: 16),
        const Text(
          'Vos activités restent vos choix. Un objectif de forme sert à réserver du temps ; l’app ne calcule pas de programme médical ni de perte de poids.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    ),
  );
}

class _GoalForm extends StatefulWidget {
  final PersonalGoal? goal;
  const _GoalForm({this.goal});
  @override
  State<_GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends State<_GoalForm> {
  late PersonalGoal _goal;
  late TextEditingController _title, _minutes;
  final _form = GlobalKey<FormState>();
  @override
  void initState() {
    super.initState();
    _goal = widget.goal ?? PersonalGoal(id: newId(), title: '');
    _title = TextEditingController(text: _goal.title);
    _minutes = TextEditingController(text: '${_goal.minutes}');
  }

  @override
  void dispose() {
    _title.dispose();
    _minutes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .85,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Une place pour moi',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Activité'),
                maxLength: 70,
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Nommez cette activité.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _minutes,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Durée d’une séance (min)',
                ),
                validator: (v) =>
                    (int.tryParse(v ?? '') ?? 0) < 5 ||
                        (int.tryParse(v ?? '') ?? 0) > 180
                    ? 'De 5 à 180 minutes.'
                    : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _goal.weeklyTarget,
                decoration: const InputDecoration(
                  labelText: 'Séances par semaine',
                ),
                items: [
                  for (var n = 1; n <= 7; n++)
                    DropdownMenuItem(
                      value: n,
                      child: Text('$n séance${n > 1 ? 's' : ''}'),
                    ),
                ],
                onChanged: (v) =>
                    setState(() => _goal = _goal.copyWith(weeklyTarget: v)),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<PreferredTime>(
                initialValue: _goal.preferredTime,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Mon moment préféré',
                ),
                items: [
                  for (final v in PreferredTime.values)
                    DropdownMenuItem(value: v, child: Text(v.label)),
                ],
                onChanged: (v) =>
                    setState(() => _goal = _goal.copyWith(preferredTime: v)),
              ),
              const SizedBox(height: 16),
              TaskColorPicker(
                selected: _goal.color,
                onChanged: (v) =>
                    setState(() => _goal = _goal.copyWith(color: v)),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  if (_form.currentState!.validate()) {
                    Navigator.pop(
                      context,
                      _goal.copyWith(
                        title: _title.text.trim(),
                        minutes: int.parse(_minutes.text),
                      ),
                    );
                  }
                },
                child: const Text('Valider cette activité'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
