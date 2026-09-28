import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/config.dart';
import 'features/connections/connections_page.dart';
import 'features/assistant/assistant_page.dart';
import 'features/assistant/assistant_preferences.dart';
import 'features/calendar/calendar_page.dart';
import 'features/focus/focus_page.dart';
import 'features/planning/planning_sheet.dart';
import 'features/pro/pro_page.dart';
import 'features/settings/settings_page.dart';
import 'features/tasks/task_detail.dart';
import 'features/tasks/tasks_page.dart';
import 'features/today/today_page.dart';
import 'repositories/workspace_store.dart';
import 'theme/app_theme.dart';
import 'widgets/app_shell.dart';
import 'widgets/alert_coordinator.dart';
import 'features/settings/alerts_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, s) => const TodayPage()),
          GoRoute(path: '/tasks', builder: (_, s) => const TasksPage()),
          GoRoute(path: '/calendar', builder: (_, s) => const CalendarPage()),
          GoRoute(path: '/assistant', builder: (_, s) => const AssistantPage()),
          GoRoute(path: '/pro', builder: (_, s) => const ProPage()),
        ],
      ),
      GoRoute(
        path: '/task/:id',
        builder: (_, s) => TaskDetail(id: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/focus/:id',
        builder: (_, s) => FocusPage(id: s.pathParameters['id']!),
      ),
      GoRoute(path: '/planning', builder: (_, s) => const PlanningPage()),
      GoRoute(
        path: '/assistant/preferences',
        builder: (_, s) => const AssistantPreferencesPage(),
      ),
      GoRoute(path: '/connections', builder: (_, s) => const ConnectionsPage()),
      GoRoute(path: '/alerts', builder: (_, s) => const AlertsPage()),
      GoRoute(path: '/settings', builder: (_, s) => const SettingsPage()),
      GoRoute(
        path: '/client-preview',
        builder: (_, s) => const ClientPreview(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => context.go('/'),
          child: const Text('Revenir à mon agenda'),
        ),
      ),
    ),
  );
  ref.onDispose(router.dispose);
  return router;
});

class MyAgendaApp extends ConsumerWidget {
  const MyAgendaApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    builder: (context, child) =>
        AlertCoordinator(child: child ?? const SizedBox()),
    title: appName,
    debugShowCheckedModeBanner: false,
    theme: appTheme(),
    darkTheme: appTheme(dark: true),
    themeMode: ref.watch(workspaceProvider).preferences.dark
        ? ThemeMode.dark
        : ThemeMode.light,
    locale: const Locale('fr'),
    supportedLocales: const [Locale('fr')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    routerConfig: ref.watch(routerProvider),
  );
}
