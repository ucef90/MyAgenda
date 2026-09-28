import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_agenda/app.dart';
import 'package:my_agenda/widgets/task_list_row.dart';
import 'package:my_agenda/models/task.dart';
import 'package:my_agenda/models/personal_goal.dart';
import 'package:my_agenda/repositories/workspace_store.dart';

void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;
  Future<void> launch(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    await initializeDateFormatting('fr');
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [preferencesProvider.overrideWithValue(prefs)],
        child: const MyAgendaApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Create, edit checklist, focus and complete a task on a phone', (
    tester,
  ) async {
    await launch(tester);
    expect(find.text('Bonjour Youssef'), findsOneWidget);
    await tester.tap(find.byTooltip('Nouvelle tâche'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Que devez-vous faire ?'),
      'Vérifier mon agenda',
    );
    await tester.ensureVisible(find.text('Ajouter la tâche'));
    await tester.tap(find.text('Ajouter la tâche'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tâches'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Vérifier mon agenda');
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.widgetWithText(TaskListRow, 'Vérifier mon agenda'),
    );
    await tester.tap(find.widgetWithText(TaskListRow, 'Vérifier mon agenda'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(TextField, 'Ajouter une sous-tâche'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Ajouter une sous-tâche'),
      'Tester le focus',
    );
    await tester.tap(find.byTooltip('Ajouter la sous-tâche'));
    await tester.pumpAndSettle();
    expect(find.text('Tester le focus'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Démarrer le focus'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(seconds: 4));
    await tester.drag(find.byType(ListView).last, const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Démarrer le focus'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terminer'));
    await tester.pumpAndSettle();
    expect(find.text('Un pas de plus. Bien joué !'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('All navigation views fit narrow and desktop sizes', (
    tester,
  ) async {
    for (final size in [const Size(360, 800), const Size(1280, 900)]) {
      await launch(tester, size: size);
      for (final label in [
        'Tâches',
        'Agenda',
        'Assistant',
        'Pro',
        'Aujourd’hui',
      ]) {
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$label at $size');
        expect(
          find.text(
            {
              'Tâches': 'Mes tâches',
              'Agenda': 'Mon agenda',
              'Pro': 'Mon espace Pro',
              'Assistant': 'Mon assistant',
              'Aujourd’hui': 'Bonjour Youssef',
            }[label]!,
          ),
          findsOneWidget,
        );
      }
      await tester.pumpWidget(const SizedBox());
    }
  });
  testWidgets(
    'Editing a cancelled task keeps it cancelled and focus unavailable',
    (tester) async {
      await launch(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MyAgendaApp)),
      );
      final store = container.read(workspaceProvider.notifier);
      store.upsert(
        const Task(
          id: 'cancelled',
          title: 'Formation annulée',
          status: TaskStatus.cancelled,
        ),
      );
      container.read(routerProvider).go('/task/cancelled');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Modifier'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Que devez-vous faire ?'),
        'Formation reportée',
      );
      await tester.ensureVisible(find.text('Enregistrer'));
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(store.state.tasks.last.title, 'Formation reportée');
      expect(store.state.tasks.last.status, TaskStatus.cancelled);
      container.read(routerProvider).go('/focus/cancelled');
      await tester.pumpAndSettle();
      expect(find.text('Tâche annulée'), findsOneWidget);
      expect(find.text('Reprendre'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Personalize assistant, save goals, and keep them when saving general settings',
    (tester) async {
      await launch(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MyAgendaApp)),
      );
      container.read(routerProvider).go('/assistant/preferences');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pratiquer la musique'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Valider cette activité'));
      await tester.tap(find.text('Valider cette activité'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Enregistrer mes préférences'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Enregistrer mes préférences'));
      await tester.pumpAndSettle();
      final store = container.read(workspaceProvider.notifier);
      expect(
        store.state.preferences.goals.single.title,
        'Pratiquer la musique',
      );
      container.read(routerProvider).go('/settings');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Youssef test');
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Enregistrer mes préférences'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Enregistrer mes préférences'));
      await tester.pumpAndSettle();
      expect(
        store.state.preferences.goals.single.title,
        'Pratiquer la musique',
      );
      expect(store.state.preferences.name, 'Youssef test');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Task color is saved and used by list filtering', (tester) async {
    await launch(tester);
    await tester.tap(find.byTooltip('Nouvelle tâche'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Que devez-vous faire ?'),
      'Mon design',
    );
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Rose'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Rose'));
    await tester.ensureVisible(find.text('Ajouter la tâche'));
    await tester.tap(find.text('Ajouter la tâche'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MyAgendaApp)),
    );
    expect(container.read(workspaceProvider).tasks.last.color, TaskColor.rose);
    container.read(routerProvider).go('/tasks');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Mon design');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TaskListRow, 'Mon design'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Capture review screens when explicitly requested', (
    tester,
  ) async {
    if (!const bool.fromEnvironment('CAPTURE_PREVIEWS')) return;
    await tester.runAsync(() async {
      final font = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await font.load();
      final sdk = Platform.environment['MYAGENDA_FLUTTER_SDK'];
      if (sdk != null) {
        final bytes = await File(
          '$sdk/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
        ).readAsBytes();
        await (FontLoader(
          'Roboto',
        )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      }
    });
    await launch(tester);
    final boundaryKey = GlobalKey();
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [preferencesProvider.overrideWithValue(prefs)],
    );
    final demo = container.read(workspaceProvider);
    container
        .read(workspaceProvider.notifier)
        .savePreferences(
          demo.preferences.copyWith(
            goals: const [
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
            ],
          ),
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: RepaintBoundary(key: boundaryKey, child: const MyAgendaApp()),
      ),
    );
    await tester.pumpAndSettle();
    for (final entry in {
      'today': '/',
      'tasks': '/tasks',
      'calendar': '/calendar',
      'pro': '/pro',
      'assistant': '/assistant',
      'assistant-desktop': '/assistant',
    }.entries) {
      tester.view.physicalSize = entry.key.endsWith('desktop')
          ? const Size(1280, 900)
          : const Size(390, 844);
      container.read(routerProvider).go(entry.value);
      await tester.pumpAndSettle();
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('docs/screenshots').create(recursive: true);
        await File(
          'docs/screenshots/${entry.key}.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await tester.pump();
  });
}
