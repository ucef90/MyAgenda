import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_agenda/features/connections/work_connection_page.dart';
import 'package:my_agenda/models/task.dart';
import 'package:my_agenda/models/work_connection.dart';
import 'package:my_agenda/models/workspace.dart';
import 'package:my_agenda/repositories/work_connection_store.dart';
import 'package:my_agenda/repositories/workspace_store.dart';
import 'package:my_agenda/services/work/work_gateway.dart';
import 'package:my_agenda/theme/app_theme.dart';

const training = Task(
  id: 'formation',
  title: 'Formation Power BI',
  notes: 'Confidentiel',
  project: 'Client ABC',
  category: TaskCategory.training,
  professional: true,
);
Map<String, dynamic> proposal({
  String field = 'order',
  bool? value = true,
  Task task = training,
}) => {
  'id': 'proposal-$field',
  'deviceId': 'phone',
  'taskId': task.id,
  'field': field,
  'value': value,
  'basis': sharedTask(task),
  'reason':
      'Le bon signé est confirmé dans le mail du client pour cette formation.',
  'evidence': [
    {
      'title': 'Bon de commande signé · Formation Power BI',
      'messageId': 'test',
      'date': '2030-09-28T12:00:00.000Z',
      'url': 'https://mail.google.com/mail/u/0/#all/test',
    },
  ],
};

class FakeGateway implements WorkGateway {
  WorkCredentials? credentials;
  List<Map<String, dynamic>> inbox = [];
  List<Map<String, dynamic>> snapshots = [];
  bool failResolve = false, failSave = false;
  @override
  bool get supported => true;
  @override
  Future<WorkCredentials?> read() async => credentials;
  @override
  Future<void> save(WorkCredentials value) async {
    if (failSave) throw StateError('locked');
    credentials = value;
  }

  @override
  Future<void> clear() async {
    credentials = null;
  }

  @override
  Future<Map<String, dynamic>> request(
    String url,
    String path, {
    String? token,
    Map<String, dynamic>? body,
    String method = 'POST',
  }) async {
    if (path == '/v1/pair') {
      return {'deviceId': 'phone', 'token': 'private-test-token'};
    }
    if (path == '/v1/sync') {
      snapshots.add(body!);
      return {'proposals': inbox, 'revision': body['revision']};
    }
    if (path.endsWith('/resolve')) {
      if (failResolve) throw const WorkError('Réseau interrompu.');
      inbox.removeWhere((p) => path.contains(p['id'] as String));
      return {'status': body!['decision']};
    }
    if (path == '/v1/device') {
      inbox = [];
      return {'disconnected': true};
    }
    throw UnimplementedError(path);
  }
}

Future<(WorkspaceStore, SharedPreferences)> workspace() async {
  SharedPreferences.setMockInitialValues({
    WorkspaceStore.storageKey: jsonEncode(
      const Workspace(
        tasks: [
          training,
          Task(id: 'sport', title: 'Sport', category: TaskCategory.sport),
          Task(id: 'pro', title: 'Projet pro', professional: true),
        ],
      ).toJson(),
    ),
  });
  final prefs = await SharedPreferences.getInstance();
  return (WorkspaceStore(prefs), prefs);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  test(
    'Only explicit metadata is shared; insecure and credential-bearing URLs refused',
    () {
      expect(sharedTask(training).containsKey('notes'), false);
      expect(sharedTask(training).containsKey('audioNotes'), false);
      expect(sharedTask(training).containsKey('attachments'), false);
      for (final url in [
        'http://example.com',
        'https://token@example.com',
        'https://example.com/path',
        'https://example.com?token=x',
        'https://example.com#x',
      ]) {
        expect(() => workServerUri(url), throwsA(isA<WorkError>()));
      }
      expect(
        workServerUri('https://agenda.example.com/').toString(),
        'https://agenda.example.com',
      );
    },
  );
  test(
    'Evidence migrates; stale field rejected; independent preparation fields can be reviewed together',
    () {
      final p = WorkProposal.fromJson(proposal());
      expect(
        () => p.apply(training.copyWith(title: 'Autre formation')),
        throwsA(isA<WorkError>()),
      );
      expect(
        () => p.apply(training.copyWith(preparation: {'order': false})),
        throwsA(isA<WorkError>()),
      );
      final applied = p.apply(training);
      expect(applied.preparation['order'], true);
      final restored = Task.fromJson(applied.toJson());
      expect(p.alreadyApplied(restored), true);
      expect(
        p.apply(restored).preparationEvidence['order']!['proposalId'],
        p.id,
      );
      final support = WorkProposal.fromJson(proposal(field: 'support'));
      expect(support.matches(restored), true);
      expect(support.apply(restored).preparationDone, 2);
      final legacy = training.toJson()..remove('preparationEvidence');
      expect(Task.fromJson(legacy).preparationEvidence, isEmpty);
    },
  );
  test(
    'Durable review survives lost acknowledgement; credentials never enter task export',
    () async {
      final (ws, prefs) = await workspace();
      final gateway = FakeGateway()..inbox = [proposal()];
      var controller = WorkConnectionStore(gateway, ws);
      await controller.restore();
      await controller.connect('https://agenda.example.com', 'test', 'iPhone');
      expect(controller.state.connected, true);
      expect((gateway.snapshots.single['tasks'] as List).map((t) => t['id']), [
        'formation',
      ]);
      expect(ws.snapshot.tasks.first.preparation['order'], null);
      gateway.failResolve = true;
      await controller.decide(controller.state.proposals.single, accept: true);
      expect(controller.state.error, isNotNull);
      expect(
        WorkspaceStore(prefs).snapshot.tasks
            .firstWhere((t) => t.id == training.id)
            .preparation['order'],
        true,
      );
      expect(ws.export(), isNot(contains('private-test-token')));
      controller.dispose();
      gateway.failResolve = false;
      controller = WorkConnectionStore(gateway, ws);
      await controller.restore();
      await controller.sync();
      expect(controller.state.proposals, isEmpty);
      expect(gateway.inbox, isEmpty);
      expect(gateway.snapshots.last['revision'], 2);
      await controller.disconnect();
      expect(controller.state.connected, false);
      expect(ws.snapshot.tasks.length, 3);
      controller.dispose();
      ws.dispose();
    },
  );
  test(
    'Keychain failure prevents sharing; stale proposals cannot change local tasks',
    () async {
      final (ws, _) = await workspace();
      final gateway = FakeGateway()..failSave = true;
      final controller = WorkConnectionStore(gateway, ws);
      await controller.restore();
      await controller.connect('https://agenda.example.com', 'test', 'iPhone');
      expect(controller.state.connected, false);
      expect(gateway.snapshots, isEmpty);
      gateway.failSave = false;
      gateway.inbox = [proposal()];
      await controller.connect('https://agenda.example.com', 'test', 'iPhone');
      ws.upsert(training.copyWith(title: 'Formation replanifiée'));
      await controller.decide(controller.state.proposals.single, accept: true);
      expect(controller.state.error, contains('changé'));
      expect(ws.snapshot.tasks.last.preparation['order'], null);
      await controller.decide(controller.state.proposals.single, accept: false);
      expect(controller.state.proposals, isEmpty);
      controller.dispose();
      ws.dispose();
    },
  );
  testWidgets('Connection form fits a phone and displays evidence review', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (const bool.fromEnvironment('CAPTURE_PREVIEWS')) {
      await tester.runAsync(() async {
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
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
    }
    final (_, prefs) = await workspace();
    final gateway = FakeGateway();
    final container = ProviderContainer(
      overrides: [
        preferencesProvider.overrideWithValue(prefs),
        workGatewayProvider.overrideWithValue(gateway),
      ],
    );
    addTearDown(container.dispose);
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: appTheme(),
          home: RepaintBoundary(
            key: boundaryKey,
            child: const WorkConnectionPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Relier mon agenda'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.widgetWithText(TextField, 'Adresse HTTPS du serveur'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Adresse HTTPS du serveur'),
      'https://agenda.example.com',
    );
    await tester.scrollUntilVisible(
      find.widgetWithText(TextField, 'Code d’association temporaire'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Code d’association temporaire'),
      'test',
    );
    await tester.tap(find.text('Relier mon agenda'));
    await tester.pumpAndSettle();
    expect(container.read(workConnectionProvider).connected, true);
    gateway.inbox = [proposal()];
    await container.read(workConnectionProvider.notifier).sync();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Confirmer'));
    await tester.pumpAndSettle();
    expect(find.text('Proposition : Oui, confirmé'), findsOneWidget);
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('CAPTURE_PREVIEWS')) {
      await tester.scrollUntilVisible(
        find.text('À valider (1)'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File(
          'docs/screenshots/work-connection.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.ensureVisible(find.text('Confirmer'));
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();
    expect(
      container
          .read(workspaceProvider)
          .tasks
          .firstWhere((t) => t.id == training.id)
          .preparation['order'],
      true,
    );
    await tester.scrollUntilVisible(
      find.text('Aucune proposition en attente'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Aucune proposition en attente'), findsOneWidget);
  });
}
