import 'package:flutter/material.dart';
import '../models/task.dart';

extension TaskColorStyle on TaskColor {
  Color get value => switch (this) {
    TaskColor.automatic || TaskColor.indigo => const Color(0xFF4F46E5),
    TaskColor.teal => const Color(0xFF0F766E),
    TaskColor.blue => const Color(0xFF0369A1),
    TaskColor.violet => const Color(0xFF7C3AED),
    TaskColor.amber => const Color(0xFFB45309),
    TaskColor.rose => const Color(0xFFBE185D),
  };
}

extension TaskStyle on Task {
  TaskColor get resolvedColor => color == TaskColor.automatic
      ? switch (resolvedCategory) {
          TaskCategory.work => TaskColor.blue,
          TaskCategory.training => TaskColor.indigo,
          TaskCategory.sport => TaskColor.teal,
          TaskCategory.music => TaskColor.violet,
          TaskCategory.rest => TaskColor.amber,
          _ => TaskColor.rose,
        }
      : color;
  Color get displayColor => resolvedColor.value;
  Color blockColor(BuildContext context) => Color.alphaBlend(
    displayColor.withValues(
      alpha: Theme.of(context).brightness == Brightness.dark ? .30 : .14,
    ),
    Theme.of(context).colorScheme.surface,
  );
}

class TaskColorPicker extends StatelessWidget {
  final TaskColor selected;
  final ValueChanged<TaskColor> onChanged;
  const TaskColorPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 4,
    children: [
      for (final color in TaskColor.values)
        ChoiceChip(
          label: Text(color.label),
          avatar: CircleAvatar(radius: 6, backgroundColor: color.value),
          selected: selected == color,
          onSelected: (_) => onChanged(color),
        ),
    ],
  );
}
