import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/config.dart';
import '../repositories/workspace_store.dart';
import '../theme/app_theme.dart';
import '../features/tasks/task_form.dart';

class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});
  static const routes = ['/', '/tasks', '/calendar', '/assistant', '/pro'];
  static const labels = ['Aujourd’hui', 'Tâches', 'Agenda', 'Assistant', 'Pro'];
  static const icons = [
    Icons.wb_sunny_outlined,
    Icons.check_box_outlined,
    Icons.calendar_month_outlined,
    Icons.auto_awesome_outlined,
    Icons.work_outline_rounded,
  ];
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = GoRouterState.of(context).uri.path;
    final active = routes.indexOf(current).clamp(0, 4);
    final error = ref.watch(persistenceErrorProvider);
    final wide = MediaQuery.sizeOf(context).width >= 960;
    final bg = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF111827)
        : Colors.white;
    Widget nav(int i) => Expanded(
      child: InkWell(
        onTap: () => context.go(routes[i]),
        child: SizedBox(
          height: 66,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icons[i],
                size: 23,
                color: active == i ? AppColors.indigo : AppColors.muted,
              ),
              const SizedBox(height: 5),
              Text(
                labels[i],
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: active == i ? FontWeight.w700 : FontWeight.w500,
                  color: active == i ? AppColors.indigo : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final content = Column(
      children: [
        if (error != null)
          MaterialBanner(
            content: Text(error),
            actions: [
              TextButton(
                onPressed: () => context.push('/settings'),
                child: const Text('Sauvegarde'),
              ),
            ],
          ),
        Expanded(child: child),
      ],
    );
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: wide
            ? Row(
                children: [
                  Container(
                    width: 258,
                    decoration: BoxDecoration(
                      color: bg,
                      border: const Border(
                        right: BorderSide(color: AppColors.line, width: .6),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.indigo,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.layers_outlined,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                appName,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 36),
                        for (var i = 0; i < routes.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              selected: active == i,
                              selectedTileColor: AppColors.indigo.withValues(
                                alpha: .07,
                              ),
                              selectedColor: AppColors.indigo,
                              leading: Icon(icons[i]),
                              title: Text(labels[i]),
                              onTap: () => context.go(routes[i]),
                            ),
                          ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: () => showTaskForm(context),
                          icon: const Icon(Icons.add),
                          label: const Text('Nouvelle tâche'),
                        ),
                        const Spacer(),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.settings_outlined),
                          title: const Text('Paramètres'),
                          onTap: () => context.push('/settings'),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Un peu d’ordre.\nPlus d’espace.',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: content),
                ],
              )
            : content,
      ),
      floatingActionButton: wide
          ? null
          : FloatingActionButton(
              heroTag: 'quick-add',
              backgroundColor: AppColors.indigo,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              tooltip: 'Nouvelle tâche',
              elevation: 2,
              onPressed: () => showTaskForm(context),
              child: const Icon(Icons.add_rounded),
            ),
      bottomNavigationBar: wide
          ? null
          : Container(
              decoration: BoxDecoration(
                color: bg,
                border: const Border(
                  top: BorderSide(color: AppColors.line, width: .6),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Row(children: [nav(0), nav(1), nav(2), nav(3), nav(4)]),
              ),
            ),
    );
  }
}
