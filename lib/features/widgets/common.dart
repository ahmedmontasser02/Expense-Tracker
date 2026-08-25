import 'package:flutter/material.dart';

import '../../core/category_presets.dart';
import '../../core/format.dart';
import '../../core/theme.dart';

/// Colored rounded-square tile with a preset icon for categories/goals.
class CategoryIcon extends StatelessWidget {
  const CategoryIcon(
      {super.key, required this.iconCode, this.colorValue, this.size = 40});

  final String iconCode;
  final int? colorValue;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = Color(colorValue ?? 0xFF546E7A);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: Theme.of(context).brightness ==
                Brightness.light
            ? .16
            : .22),
        borderRadius: BorderRadius.circular(size * .3),
      ),
      child: Icon(IconPresets.of(iconCode) ?? Icons.more_horiz,
          size: size * .52, color: color),
    );
  }
}

/// Large display-font section title with an optional mono-caps trailing link
/// (e.g. "Plan  RECURRING").
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

/// Small mono-caps eyebrow label with a left accent bar
/// (e.g. "| TODAY, OCT 24" or settings section headers).
class CapsHeader extends StatelessWidget {
  const CapsHeader(this.title, {super.key, this.color, this.padding});

  final String title;
  final Color? color;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? Theme.of(context).colorScheme.primary;
    return Padding(
      padding: padding ?? const EdgeInsets.only(top: 20, bottom: 8),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(title.toUpperCase(),
              style: AppTheme.labelCaps(context, color: accent)),
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 5),
                ],
                Flexible(
                  child: Text(label.toUpperCase(),
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.labelCaps(context)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800, color: color)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Deterministic fill bar for budgets and goals, with animated changes.
class FillBar extends StatelessWidget {
  const FillBar({super.key, required this.fraction, required this.color});

  /// 0..1+ ; clamped for display.
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: fraction.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: value,
          minHeight: 4,
          backgroundColor:
              Theme.of(context).colorScheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation(fraction > 1 ? Colors.red : color),
        ),
      ),
    );
  }
}

/// Amount text that animates (fade + slide) whenever its value changes.
class AnimatedAmount extends StatelessWidget {
  const AnimatedAmount(this.text,
      {super.key, this.style, this.axis = Axis.vertical});

  final String text;
  final TextStyle? style;
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => ClipRect(
        child: SlideTransition(
          position: Tween<Offset>(
            begin: axis == Axis.vertical ? const Offset(0, 0.4) : const Offset(0.4, 0),
            end: Offset.zero,
          ).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        ),
      ),
      child: Text(text,
          key: ValueKey(text),
          style: style ??
              Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.message, {super.key, this.icon = Icons.inbox_outlined});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline)),
          ],
        ),
      ),
    );
  }
}

String fmtAmount(String symbol, int minorUnits) =>
    MoneyFmt.withSymbol(symbol, minorUnits);

/// Small named-input dialog shared by tag/category/filter editors.
/// Returns the trimmed input, or null when cancelled/empty.
Future<String?> promptForText(
  BuildContext context, {
  required String title,
  required String label,
  String? initial,
  String? helper,
  int maxLength = 40,
  String cancelLabel = 'Cancel',
  String confirmLabel = 'Save',
}) async {
  final ctrl = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        maxLength: maxLength,
        decoration: InputDecoration(labelText: label, helperText: helper),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: Text(cancelLabel)),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(confirmLabel)),
      ],
    ),
  );
  ctrl.dispose();
  final trimmed = result?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}
