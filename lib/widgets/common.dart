import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PageBody extends StatelessWidget {
  final List<Widget> children;
  const PageBody({super.key, required this.children});
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1120),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 32),
        children: children,
      ),
    ),
  );
}

class SectionTitle extends StatelessWidget {
  final String title;
  final Widget? action;
  const SectionTitle(this.title, {super.key, this.action});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 26, bottom: 14),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (action != null) action!,
      ],
    ),
  );
}

class Tag extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const Tag(this.label, {super.key, this.color = AppColors.indigo, this.icon});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
        ],
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Color.lerp(color, Colors.white, .4)
                  : color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Widget? action;
  const EmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.check_circle_outline_rounded,
    this.action,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.indigo.withValues(alpha: .08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 32, color: AppColors.indigo),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted),
        ),
        if (action != null) ...[const SizedBox(height: 18), action!],
      ],
    ),
  );
}

void toast(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
bool attempt(BuildContext context, VoidCallback action, {String? success}) {
  try {
    action();
    if (success != null) toast(context, success);
    return true;
  } catch (e) {
    toast(
      context,
      e
          .toString()
          .replaceFirst('Bad state: ', '')
          .replaceFirst('Invalid argument(s): ', ''),
    );
    return false;
  }
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    ) ??
    false;
