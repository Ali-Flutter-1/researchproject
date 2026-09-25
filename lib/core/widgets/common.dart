import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Constrains reading width on wide screens. Long lines are hard to read;
/// a full-width paragraph on a 27" monitor is a layout bug.
class ReadableWidth extends StatelessWidget {
  const ReadableWidth({super.key, required this.child, this.maxWidth = 720});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Insets.sm),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: context.text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Insets.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: context.colors.outline),
              const SizedBox(height: Insets.md),
              Text(title,
                  style: context.text.titleMedium,
                  textAlign: TextAlign.center),
              if (message != null) ...[
                const SizedBox(height: Insets.sm),
                Text(
                  message!,
                  style: context.text.bodyMedium
                      ?.copyWith(color: context.colors.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: Insets.lg),
                action!,
              ],
            ],
          ),
        ),
      );
}

/// A small labelled fact, used throughout the paper detail and extraction views.
class LabelledValue extends StatelessWidget {
  const LabelledValue({
    super.key,
    required this.label,
    required this.child,
    this.onSource,
  });

  final String label;
  final Widget child;

  /// When present, renders the "jump to source passage" affordance. Every
  /// extracted fact should have one — a fact without provenance is unusable.
  final VoidCallback? onSource;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  label.toUpperCase(),
                  style: context.text.labelSmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (onSource != null) ...[
                  const SizedBox(width: Insets.sm),
                  InkWell(
                    onTap: onSource,
                    borderRadius: BorderRadius.circular(Radii.chip),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: Insets.xs, vertical: 2),
                      child: Icon(Icons.format_quote,
                          size: 14, color: context.colors.primary),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: Insets.xs),
            DefaultTextStyle.merge(
              style: context.text.bodyMedium,
              child: child,
            ),
          ],
        ),
      );
}

class WarningBanner extends StatelessWidget {
  const WarningBanner(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = dark ? AppColors.partialDark : AppColors.partial;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Insets.md, vertical: Insets.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: color),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(message, style: context.text.bodySmall),
          ),
        ],
      ),
    );
  }
}
