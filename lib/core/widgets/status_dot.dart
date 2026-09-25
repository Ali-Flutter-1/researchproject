import 'package:flutter/material.dart';

import '../../features/research/domain/entities/claim.dart';
import '../theme/app_colors.dart';

/// The verification mark. Amber and red are the feature, not an embarrassment —
/// a tool that never admits uncertainty is one the researcher must re-check
/// by hand, which means it saved them nothing.
class StatusDot extends StatelessWidget {
  const StatusDot(this.status, {super.key, this.size = 8});

  final VerificationStatus status;
  final double size;

  static Color colorFor(BuildContext context, VerificationStatus s) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return switch (s) {
      VerificationStatus.supported =>
        dark ? AppColors.supportedDark : AppColors.supported,
      VerificationStatus.partiallySupported =>
        dark ? AppColors.partialDark : AppColors.partial,
      VerificationStatus.contradicted =>
        dark ? AppColors.contradictedDark : AppColors.contradicted,
      VerificationStatus.notFound =>
        dark ? AppColors.notFoundDark : AppColors.notFound,
    };
  }

  @override
  Widget build(BuildContext context) => Semantics(
        label: status.label,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: colorFor(context, status),
            shape: BoxShape.circle,
          ),
        ),
      );
}

/// Status conveyed by shape as well as colour, for the colour-blind case and
/// for anywhere a bare dot would be ambiguous.
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final VerificationStatus status;

  @override
  Widget build(BuildContext context) {
    final color = StatusDot.colorFor(context, status);
    final icon = switch (status) {
      VerificationStatus.supported => Icons.check_circle_outline,
      VerificationStatus.partiallySupported => Icons.error_outline,
      VerificationStatus.contradicted => Icons.cancel_outlined,
      VerificationStatus.notFound => Icons.help_outline,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: Insets.xs),
        Text(
          status.label,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
