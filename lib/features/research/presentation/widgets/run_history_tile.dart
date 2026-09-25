import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/research_run.dart';
import '../../domain/entities/run_stage.dart';

class RunHistoryTile extends StatelessWidget {
  const RunHistoryTile({super.key, required this.run, required this.onTap});

  final ResearchRun run;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Insets.sm),
        child: Card(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(Radii.card),
            child: Padding(
              padding: const EdgeInsets.all(Insets.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    run.question,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: Insets.sm),
                  Row(
                    children: [
                      _StatusPill(run.status),
                      const SizedBox(width: Insets.sm),
                      Text(
                        '${run.papers.length} papers · '
                        '${DateFormat.yMMMd().format(run.createdAt)}',
                        style: context.text.bodySmall
                            ?.copyWith(color: context.colors.onSurfaceVariant),
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

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.status);
  final RunStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      RunStatus.completed => ('Complete', AppColors.supported),
      // Partial is a normal outcome, not a failure — styled as information.
      RunStatus.partial => ('Partial', AppColors.partial),
      RunStatus.failed => ('Failed', AppColors.contradicted),
      _ => ('Running', context.colors.primary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
      child: Text(
        label,
        style: context.text.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
