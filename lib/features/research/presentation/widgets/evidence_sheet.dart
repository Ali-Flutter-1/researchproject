import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/status_dot.dart';
import '../../domain/entities/claim.dart';
import '../providers/research_providers.dart';

/// The source passage behind a claim. On mobile this is a bottom sheet;
/// on a laptop the same widget fills a side panel.
///
/// This is the most important interaction in the product: it is what lets a
/// researcher check the system's work in one tap instead of reopening the PDF.
class EvidenceView extends ConsumerWidget {
  const EvidenceView({super.key, required this.chunkId, this.claim});

  final String chunkId;
  final Claim? claim;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(evidenceProvider(chunkId));

    return Padding(
      padding: const EdgeInsets.all(Insets.lg),
      child: async.when(
        loading: () => const SizedBox(
          height: 160,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => SizedBox(
          height: 160,
          child: Center(child: Text('Could not load the source passage.\n$e')),
        ),
        data: (evidence) {
          if (evidence == null) {
            return const SizedBox(
              height: 160,
              child: Center(
                child: Text('The cited passage could not be located.'),
              ),
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (claim != null) ...[
                StatusChip(claim!.status),
                const SizedBox(height: Insets.sm),
                Text(claim!.text,
                    style: context.text.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                if (claim!.note.isNotEmpty) ...[
                  const SizedBox(height: Insets.xs),
                  Text(
                    claim!.note,
                    style: context.text.bodySmall?.copyWith(
                      color: StatusDot.colorFor(context, claim!.status),
                    ),
                  ),
                ],
                const SizedBox(height: Insets.md),
                const Divider(),
                const SizedBox(height: Insets.md),
              ],
              Text(
                evidence.paperTitle,
                style: context.text.labelLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                '${evidence.sectionTitle} · page ${evidence.pageNumber}',
                style: context.text.bodySmall
                    ?.copyWith(color: context.colors.onSurfaceVariant),
              ),
              const SizedBox(height: Insets.md),
              Container(
                padding: const EdgeInsets.all(Insets.md),
                decoration: BoxDecoration(
                  color: context.colors.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(Radii.card),
                  border: Border(
                    left: BorderSide(color: context.colors.primary, width: 3),
                  ),
                ),
                child: Text(
                  evidence.text,
                  // Serif marks this as the paper speaking, not the app.
                  style: AppTypography.quotation(
                    color: context.colors.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: Insets.md),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Open in paper'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

Future<void> showEvidenceSheet(
  BuildContext context, {
  required String chunkId,
  Claim? claim,
}) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (_) => SingleChildScrollView(
        child: EvidenceView(chunkId: chunkId, claim: claim),
      ),
    );
