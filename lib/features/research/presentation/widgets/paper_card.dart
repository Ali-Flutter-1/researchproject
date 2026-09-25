import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/paper.dart';

class PaperCard extends StatelessWidget {
  const PaperCard({
    super.key,
    required this.paper,
    this.dense = false,
    this.runId,
  });

  final Paper paper;
  final bool dense;
  final String? runId;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: dense ? 0 : Insets.sm),
        child: Card(
          child: InkWell(
            onTap: runId == null
                ? null
                : () => context.go('/run/$runId/paper/${paper.id}'),
            borderRadius: BorderRadius.circular(Radii.card),
            child: Padding(
              padding: const EdgeInsets.all(Insets.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    paper.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600, height: 1.3),
                  ),
                  const SizedBox(height: Insets.xs),
                  Text(
                    '${paper.authorLine} · ${paper.year} · ${paper.venue}',
                    style: context.text.bodySmall
                        ?.copyWith(color: context.colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: Insets.sm),
                  if (paper.whyIncluded.isNotEmpty)
                    Text(
                      paper.whyIncluded,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: Insets.sm),
                  Wrap(
                    spacing: Insets.sm,
                    runSpacing: Insets.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _Meta(
                        icon: Icons.format_quote,
                        label: '${paper.citationCount}',
                      ),
                      _Meta(
                        icon: Icons.my_location,
                        label: '${(paper.relevance * 100).round()}% match',
                      ),
                      // Parse confidence is surfaced, not hidden. A badly
                      // parsed paper produces bad extractions, and the user
                      // deserves to know which ones to distrust.
                      if (paper.parseConfidence != ParseConfidence.high)
                        _Meta(
                          icon: Icons.warning_amber_rounded,
                          label: paper.parseConfidence == ParseConfidence.low
                              ? 'Poor text quality'
                              : 'Partial text',
                          color: AppColors.partial,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label, this.color});
  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.colors.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: c),
        const SizedBox(width: 3),
        Text(label, style: context.text.labelSmall?.copyWith(color: c)),
      ],
    );
  }
}
