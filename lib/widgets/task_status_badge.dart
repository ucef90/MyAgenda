import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/task.dart';

class TaskStatusBadge extends StatefulWidget {
  final Task task;
  final DateTime now;
  const TaskStatusBadge({super.key, required this.task, required this.now});
  @override
  State<TaskStatusBadge> createState() => _TaskStatusBadgeState();
}

class _TaskStatusBadgeState extends State<TaskStatusBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _configure();
  }

  @override
  void didUpdateWidget(covariant TaskStatusBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    _configure();
  }

  void _configure() {
    final animate =
        widget.task.isOpen &&
        (widget.task.overdueAt(widget.now) ||
            widget.task.runningSince != null) &&
        !MediaQuery.disableAnimationsOf(context);
    if (animate && !_animation.isAnimating) _animation.repeat();
    if (!animate) _animation.stop();
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final late = task.overdueAt(widget.now);
    final running = task.runningSince != null;
    final seconds = task.secondsAt(widget.now);
    final time =
        '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    final label = !task.isOpen
        ? task.status.label
        : running
        ? '${late ? 'En retard · ' : ''}$time'
        : late
        ? 'En retard'
        : task.status == TaskStatus.inProgress
        ? 'En pause'
        : (task.scheduledAt?.isAfter(widget.now) ?? true)
        ? 'À venir'
        : 'À commencer';
    final color = late
        ? const Color(0xFFB91C1C)
        : Theme.of(context).colorScheme.onSurface;
    return Semantics(
      label: running ? 'Chronomètre en cours, $label' : label,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (late)
              CustomPaint(
                size: const Size(18, 18),
                painter: _BeaconPainter(_animation.value),
              ),
            if (running)
              Transform.rotate(
                angle: _animation.value * math.pi * 2,
                child: Icon(Icons.timer_outlined, size: 16, color: color),
              )
            else if (!late)
              Icon(
                !task.isOpen
                    ? Icons.check_circle_outline
                    : task.status == TaskStatus.inProgress
                    ? Icons.pause_circle_outline
                    : (task.scheduledAt?.isAfter(widget.now) ?? true)
                    ? Icons.airline_seat_individual_suite
                    : Icons.play_circle_outline,
                size: 18,
                color: color,
              ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BeaconPainter extends CustomPainter {
  final double phase;
  const _BeaconPainter(this.phase);
  @override
  void paint(Canvas canvas, Size size) {
    final pulse = .6 + .4 * math.sin(phase * math.pi).abs();
    final paint = Paint()
      ..color = const Color(0xFFDC2626).withValues(alpha: pulse);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        const Rect.fromLTWH(4, 5, 10, 9),
        topLeft: const Radius.circular(5),
        topRight: const Radius.circular(5),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(2, 14, 14, 3),
        const Radius.circular(1),
      ),
      paint,
    );
    paint
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(9, 0), const Offset(9, 2), paint);
    canvas.drawLine(const Offset(1, 4), const Offset(3, 6), paint);
    canvas.drawLine(const Offset(17, 4), const Offset(15, 6), paint);
    canvas.drawLine(
      const Offset(7, 8),
      const Offset(7, 11),
      Paint()
        ..color = Colors.white.withValues(alpha: .7)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _BeaconPainter oldDelegate) =>
      oldDelegate.phase != phase;
}
