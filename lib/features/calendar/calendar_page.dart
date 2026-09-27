import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/format.dart';
import '../../models/task.dart';
import '../../repositories/workspace_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../today/timeline.dart';

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});
  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  DateTime _day = dayOnly(DateTime.now());
  int _days = 3;
  @override
  Widget build(BuildContext context) {
    final w = ref.watch(workspaceProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Mon agenda',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        setState(() => _day = dayOnly(DateTime.now())),
                    child: const Text('Aujourd’hui'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Du temps pour ce qui compte.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Période précédente',
                    onPressed: () => setState(
                      () => _day = DateTime(
                        _day.year,
                        _day.month,
                        _day.day - _days,
                      ),
                    ),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _day,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) setState(() => _day = d);
                      },
                      child: Text(
                        _days == 1
                            ? dayLabel(_day)
                            : '${shortDate(_day)} — ${shortDate(DateTime(_day.year, _day.month, _day.day + _days - 1))}',
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Période suivante',
                    onPressed: () => setState(
                      () => _day = DateTime(
                        _day.year,
                        _day.month,
                        _day.day + _days,
                      ),
                    ),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 1, label: Text('Jour')),
                  ButtonSegment(value: 3, label: Text('3 jours')),
                  ButtonSegment(value: 7, label: Text('Semaine')),
                ],
                selected: {_days},
                onSelectionChanged: (s) => setState(() => _days = s.first),
              ),
            ],
          ),
        ),
        Expanded(
          child: _days == 1
              ? SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Timeline(day: _day),
                )
              : LayoutBuilder(
                  builder: (context, c) {
                    final width = math.max(c.maxWidth - 48, _days * 112.0),
                        dayWidth = width / _days;
                    return SingleChildScrollView(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 48,
                            child: Column(
                              children: [
                                const SizedBox(height: 66),
                                for (var hour = 7; hour < 23; hour++)
                                  SizedBox(
                                    height: 70,
                                    child: Align(
                                      alignment: Alignment.topCenter,
                                      child: Text(
                                        '${hour.toString().padLeft(2, '0')}:00',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.muted,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: width,
                                height: 1190,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (var i = 0; i < _days; i++)
                                      SizedBox(
                                        width: dayWidth,
                                        child: _DayColumn(
                                          day: DateTime(
                                            _day.year,
                                            _day.month,
                                            _day.day + i,
                                          ),
                                          tasks: w.tasks,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _DayColumn extends ConsumerWidget {
  final DateTime day;
  final List<Task> tasks;
  const _DayColumn({required this.day, required this.tasks});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = sameDay(day, DateTime.now());
    final list = tasks
        .where(
          (t) =>
              t.scheduledAt != null &&
              sameDay(t.scheduledAt!, day) &&
              t.status != TaskStatus.cancelled,
        )
        .toList();
    return Column(
      children: [
        SizedBox(
          height: 66,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  dayLabel(day).split(' ').first.substring(0, 3).toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: today ? AppColors.indigo : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${day.day}',
                    style: TextStyle(
                      color: today ? Colors.white : null,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 1120,
          child: Stack(
            children: [
              for (var hour = 7; hour < 23; hour++)
                Positioned(
                  top: (hour - 7) * 70.0,
                  left: 0,
                  right: 0,
                  height: 70,
                  child: DragTarget<String>(
                    onAcceptWithDetails: (d) {
                      final t = tasks.firstWhere((t) => t.id == d.data);
                      attempt(
                        context,
                        () => ref
                            .read(workspaceProvider.notifier)
                            .schedule(t, atMinute(day, hour * 60)),
                        success: 'Créneau déplacé',
                      );
                    },
                    builder: (context, candidates, rejected) => Container(
                      decoration: BoxDecoration(
                        color: candidates.isNotEmpty
                            ? AppColors.teal.withValues(alpha: .12)
                            : null,
                        border: const Border(
                          top: BorderSide(color: AppColors.line, width: .5),
                          left: BorderSide(color: AppColors.line, width: .5),
                        ),
                      ),
                    ),
                  ),
                ),
              for (final t in list)
                if (t.scheduledAt!.hour >= 7 && t.scheduledAt!.hour < 23)
                  Positioned(
                    top:
                        ((t.scheduledAt!.hour - 7) * 60 +
                            t.scheduledAt!.minute) *
                        70 /
                        60,
                    left: 4,
                    right: 4,
                    height: math.max(
                      46,
                      math.min(
                            t.minutes * 70 / 60,
                            1120 -
                                ((t.scheduledAt!.hour - 7) * 60 +
                                        t.scheduledAt!.minute) *
                                    70 /
                                    60,
                          ) -
                          4,
                    ),
                    child: LongPressDraggable<String>(
                      data: t.id,
                      feedback: Material(
                        color: Colors.transparent,
                        child: SizedBox(width: 150, child: _Event(t: t)),
                      ),
                      childWhenDragging: Opacity(
                        opacity: .25,
                        child: _Event(t: t),
                      ),
                      child: _Event(t: t),
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Event extends StatelessWidget {
  final Task t;
  const _Event({required this.t});
  @override
  Widget build(BuildContext context) {
    final color = t.status == TaskStatus.completed
        ? AppColors.teal
        : t.professional
        ? AppColors.indigo
        : AppColors.violet;
    return Material(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => context.push('/task/${t.id}'),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: color, width: 3)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: LayoutBuilder(
            builder: (context, c) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    t.title,
                    maxLines: c.maxHeight < 50 ? 1 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : color,
                    ),
                  ),
                ),
                if (c.maxHeight > 42)
                  Text(
                    clock(t.scheduledAt!),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
