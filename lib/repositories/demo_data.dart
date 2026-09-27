import '../core/format.dart';
import '../models/task.dart';
import '../models/workspace.dart';

Workspace demoWorkspace(DateTime now) {
  final today = dayOnly(now);
  final tomorrow = today.add(const Duration(days: 1));
  return Workspace(
    demo: true,
    preferences: const Preferences(weekdays: [1, 2, 3, 4, 5, 6, 7]),
    clients: const [
      Client(id: 'abc', name: 'ABC Consulting', email: 'contact@example.com'),
      Client(id: 'xyz', name: 'Studio Horizon'),
    ],
    missions: [
      Mission(
        id: 'pbi',
        title: 'Formation Power BI',
        clientId: 'abc',
        start: today,
        end: today.add(const Duration(days: 5)),
      ),
      Mission(
        id: 'audit',
        title: 'Audit des données',
        clientId: 'xyz',
        start: tomorrow,
        end: tomorrow.add(const Duration(days: 7)),
      ),
    ],
    tasks: [
      Task(
        id: 'formation',
        title: 'Formation Power BI',
        professional: true,
        clientId: 'abc',
        missionId: 'pbi',
        minutes: 120,
        scheduledAt: atMinute(today, 540),
        deadline: atMinute(today, 660),
        status: TaskStatus.planned,
        notes: 'Modélisation, mesures DAX et cas pratique.',
      ),
      Task(
        id: 'meeting',
        title: 'Point projet avec le client',
        professional: true,
        clientId: 'abc',
        minutes: 60,
        scheduledAt: atMinute(today, 840),
        deadline: atMinute(today, 900),
        status: TaskStatus.planned,
      ),
      Task(
        id: 'app',
        title: 'Application facturation',
        project: 'Mes projets',
        minutes: 150,
        scheduledAt: atMinute(today, 915),
        deadline: atMinute(today.add(const Duration(days: 3)), 1080),
        status: TaskStatus.planned,
        priority: Priority.important,
        notes: 'Une application simple pour suivre mes devis et mes factures.',
        checklist: [
          for (var i = 0; i < 7; i++)
            ChecklistItem(
              id: 'app-$i',
              title: [
                'Définir les écrans',
                'Créer les clients',
                'Maquetter une facture',
                'Développer les factures',
                'Exporter en PDF',
                'Tester le parcours',
                'Préparer la mise en ligne',
              ][i],
              done: i < 3,
            ),
        ],
      ),
      Task(
        id: 'support',
        title: 'Préparer le support Power BI',
        professional: true,
        clientId: 'abc',
        missionId: 'pbi',
        minutes: 90,
        deadline: atMinute(tomorrow, 1080),
        priority: Priority.important,
      ),
      Task(
        id: 'invoice',
        title: 'Envoyer la facture client',
        professional: true,
        clientId: 'abc',
        minutes: 20,
        deadline: atMinute(today, 1080),
        priority: Priority.urgent,
      ),
      const Task(
        id: 'read',
        title: 'Lire quelques pages',
        project: 'Pour moi',
        minutes: 30,
        priority: Priority.low,
      ),
      Task(
        id: 'brief',
        title: 'Valider le programme',
        professional: true,
        clientId: 'abc',
        missionId: 'pbi',
        minutes: 30,
        status: TaskStatus.completed,
        elapsedSeconds: 1500,
      ),
    ],
  );
}
