import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/common.dart';
import '../../../../core/widgets/status_dot.dart';
import '../../domain/entities/claim.dart';
import '../../domain/entities/research_run.dart';
import 'evidence_sheet.dart';

/// Tab 1 — the written synthesis, with every factual sentence traceable.
class AnswerTab extends StatelessWidget {
  const AnswerTab({super.key, required this.run});
  final ResearchRun run;

  @override
  Widget build(BuildContext context) {
    if (run.synthesis.isEmpty) {
      return const EmptyState(
        icon: Icons.article_outlined,
        title: 'No synthesis yet',
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Insets.lg),
      child: ReadableWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _VerificationSummary(run: run),
            const SizedBox(height: Insets.lg),
            for (final paragraph in run.synthesis) ...[
              _CitedParagraph(text: paragraph, run: run),
              const SizedBox(height: Insets.md),
            ],
            const SizedBox(height: Insets.lg),
            if (run.needsCheckCount > 0) _NeedsChecking(run: run),
          ],
        ),
      ),
    );
  }
}

/// "34 claims · 31 verified · 3 need checking" — stated up front.
/// This is what earns trust in the other 31.
class _VerificationSummary extends StatelessWidget {
  const _VerificationSummary({required this.run});
  final ResearchRun run;

  @override
  Widget build(BuildContext context) {
    if (run.claims.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_outlined,
              size: 18, color: context.colors.primary),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              '${run.claims.length} claims · ${run.verifiedCount} verified'
              '${run.needsCheckCount > 0 ? ' · ${run.needsCheckCount} need checking' : ''}',
              style: context.text.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders a paragraph whose `[[claimId]]` markers become tappable superscripts.
class _CitedParagraph extends StatelessWidget {
  const _CitedParagraph({required this.text, required this.run});
  final String text;
  final ResearchRun run;

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'\[\[(\w+)\]\]');
    var cursor = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      final claim = run.claimById(match.group(1)!);
      if (claim != null) spans.add(_marker(context, claim));
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return SelectableText.rich(
      TextSpan(
        style: context.text.bodyLarge?.copyWith(height: 1.7),
        children: spans,
      ),
    );
  }

  InlineSpan _marker(BuildContext context, Claim claim) {
    final color = StatusDot.colorFor(context, claim.status);
    return WidgetSpan(
      alignment: PlaceholderAlignment.top,
      child: Transform.translate(
        offset: const Offset(1, -2),
        child: GestureDetector(
          onTap: () =>
              showEvidenceSheet(context, chunkId: claim.chunkId, claim: claim),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(Radii.chip),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StatusDot(claim.status, size: 5),
                  const SizedBox(width: 3),
                  Text(
                    '${claim.index}',
                    style: context.text.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Unverified claims are collected where they cannot be missed.
class _NeedsChecking extends StatelessWidget {
  const _NeedsChecking({required this.run});
  final ResearchRun run;

  @override
  Widget build(BuildContext context) {
    final flagged = run.claims.where((c) => c.status.needsAttention).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Needs checking'),
        Text(
          'These statements could not be fully confirmed against their source. '
          'Read the passage before relying on them.',
          style: context.text.bodySmall
              ?.copyWith(color: context.colors.onSurfaceVariant),
        ),
        const SizedBox(height: Insets.md),
        for (final claim in flagged)
          Card(
            margin: const EdgeInsets.only(bottom: Insets.sm),
            child: InkWell(
              onTap: () => showEvidenceSheet(context,
                  chunkId: claim.chunkId, claim: claim),
              borderRadius: BorderRadius.circular(Radii.card),
              child: Padding(
                padding: const EdgeInsets.all(Insets.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatusChip(claim.status),
                    const SizedBox(height: Insets.sm),
                    Text(claim.text, style: context.text.bodyMedium),
                    if (claim.note.isNotEmpty) ...[
                      const SizedBox(height: Insets.xs),
                      Text(
                        claim.note,
                        style: context.text.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
