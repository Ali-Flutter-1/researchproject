import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/common.dart';
import '../../domain/entities/gap.dart';
import '../../domain/entities/research_run.dart';

/// Tab 4 — research gaps.
///
/// Each gap shows the counting that produced it. Without that arithmetic
/// underneath, a gap is just the model's opinion and a researcher cannot
/// act on it.
class GapsTab extends StatelessWidget {
  const GapsTab({super.key, required this.run});
  final ResearchRun run;

  @override
  Widget build(BuildContext context) {
    if (run.gaps.isEmpty) {
      return const EmptyState(
        icon: Icons.lightbulb_outline,
        title: 'No gaps identified yet',
        message: 'Gaps are computed once every paper has been analysed.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(Insets.lg),
      children: [
        ReadableWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Where this literature has not gone yet, ranked by how clearly '
                'the evidence supports the gap.',
                style: context.text.bodySmall
                    ?.copyWith(color: context.colors.onSurfaceVariant),
              ),
              const SizedBox(height: Insets.lg),
              for (final gap in run.gaps) _GapCard(gap: gap, run: run),
            ],
          ),
        ),
      ],
    );
  }
}

class _GapCard extends StatelessWidget {
  const _GapCard({required this.gap, required this.run});
  final Gap gap;
  final ResearchRun run;

  @override
  Widget build(BuildContext context) {
    final papers = gap.relatedPaperIds
        .map(run.paperById)
        .whereType<dynamic>()
        .toList();

    return Card(
      margin: const EdgeInsets.only(bottom: Insets.md),
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Insets.sm, vertical: 2),
                  decoration: BoxDecoration(
                    color: context.colors.primaryContainer,
                    borderRadius: BorderRadius.circular(Radii.chip),
                  ),
                  child: Text(
                    gap.kind.label,
                    style: context.text.labelSmall?.copyWith(
                      color: context.colors.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                _Confidence(value: gap.confidence),
              ],
            ),
            const SizedBox(height: Insets.md),
            Text(
              gap.statement,
              style: context.text.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600, height: 1.4),
            ),
            const SizedBox(height: Insets.sm),
            // The arithmetic. This is the part that makes the gap checkable.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Insets.sm),
              decoration: BoxDecoration(
                color: context.colors.surfaceContainerHighest
                    .withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(Radii.card - 4),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.functions,
                      size: 14, color: context.colors.onSurfaceVariant),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: Text(
                      gap.evidence,
                      style: context.text.bodySmall?.copyWith(height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
            if (papers.isNotEmpty) ...[
              const SizedBox(height: Insets.sm),
              Wrap(
                spacing: Insets.sm,
                runSpacing: Insets.xs,
                children: [
                  for (final p in papers)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                      label: Text(
                        '${p.authorLine}, ${p.year}',
                        style: context.text.labelSmall,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Confidence extends StatelessWidget {
  const _Confidence({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 44,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(value: value, minHeight: 4),
            ),
          ),
          const SizedBox(width: Insets.xs),
          Text(
            '${(value * 100).round()}%',
            style: context.text.labelSmall
                ?.copyWith(color: context.colors.onSurfaceVariant),
          ),
        ],
      );
}
