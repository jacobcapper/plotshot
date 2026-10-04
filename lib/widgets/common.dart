import 'package:flutter/material.dart';

import '../logic/units.dart';
import '../theme.dart';

class StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? unit;
  final String? suffix;
  final Color? iconColor;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.unit,
    this.suffix,
    this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: iconColor ?? AppColors.accent),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.fade,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: value,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (unit != null)
                        TextSpan(
                          text: unit,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.muted,
                          ),
                        ),
                      if (suffix != null)
                        TextSpan(
                          text: ' $suffix',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.muted,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lays children out in rows of [columns] equal-width cells.
class StatGrid extends StatelessWidget {
  final List<Widget> children;
  final int columns;
  const StatGrid({super.key, required this.children, this.columns = 3});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      final cells = <Widget>[];
      for (var c = 0; c < columns; c++) {
        if (c > 0) cells.add(const SizedBox(width: 10));
        cells.add(
          Expanded(
            child: i + c < children.length
                ? children[i + c]
                : const SizedBox.shrink(),
          ),
        );
      }
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 10));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: cells,
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Widget? titleTrailing;
  const SectionHeader(
    this.title, {
    super.key,
    this.trailing,
    this.titleTrailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 12),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (titleTrailing != null) ...[
                  const SizedBox(width: 4),
                  titleTrailing!,
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class DoseChip extends StatelessWidget {
  final double doseMg;
  final Color? color;
  const DoseChip(this.doseMg, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color ?? AppColors.cardHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '${formatDose(doseMg)} mg',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: color == null ? AppColors.text : AppColors.background,
        ),
      ),
    );
  }
}

/// Colour for [dose] given every dose that appears in the data.
Color doseColor(double dose, Iterable<double> allDoses) {
  final sorted = allDoses.toSet().toList()..sort();
  final i = sorted.indexOf(dose);
  if (i < 0) return AppColors.muted;
  if (sorted.length == 1) return AppColors.doses[3];
  // Spread across the palette so a few doses still look distinct.
  final idx = (i * (AppColors.doses.length - 1) / (sorted.length - 1)).round();
  return AppColors.doses[idx];
}

class EmptyHint extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? action;
  const EmptyHint({
    super.key,
    required this.icon,
    required this.text,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, color: AppColors.muted, size: 32),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    );
  }
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String message, {
  String action = 'Delete',
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(c, true),
          child: Text(action, style: const TextStyle(color: AppColors.danger)),
        ),
      ],
    ),
  );
  return r ?? false;
}
