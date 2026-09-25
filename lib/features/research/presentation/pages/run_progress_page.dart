import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/common.dart';
import '../../domain/entities/research_run.dart';
import '../../domain/entities/run_stage.dart';
import '../providers/research_providers.dart';
import '../widgets/paper_card.dart';

/// Screen 2 — lives for two to four minutes, so it has to be worth looking at.
/// Papers appear as they are found, before analysis finishes: that is the whole
/// point of streaming. A user with no progress signal assumes it has crashed.
class RunProgressPage extends ConsumerWidget {
  const RunProgressPage({super.key, required this.runId});
  final String runId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(runProvider(runId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Researching'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'This run could not be started',
          message: '$e',
          action: FilledButton(
            onPressed: () => context.go('/'),
            child: const Text('Back'),
          ),
        ),
        data: (run) {
          // Hand off to the result screen the moment the pipeline finishes.
          if (run.isTerminal) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) context.go('/run/$runId/result');
            });
          }
          return context.isWide
              ? _WideLayout(run: run)
              : _NarrowLayout(run: run);
        },
      ),
    );
  }
}

class _WideLayout extends StatelessWidget {
  const _WideLayout({required this.run});
  final ResearchRun run;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 320,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Insets.lg),
              child: _StageList(run: run),
            ),
          ),
          const VerticalDivider(),
          Expanded(
            child: _PaperStream(run: run),
          ),
        ],
      );
}

class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout({required this.run});
  final ResearchRun run;

  @override
  Widget build(BuildContext context) => CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(Insets.md),
            sliver: SliverToBoxAdapter(child: _StageList(run: run)),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.md),
            sliver: SliverList.builder(
              itemCount: run.papers.length,
              itemBuilder: (_, i) => PaperCard(paper: run.papers[i]),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: Insets.xl)),
        ],
      );
}

class _PaperStream extends StatelessWidget {
  const _PaperStream({required this.run});
  final ResearchRun run;

  @override
  Widget build(BuildContext context) {
    if (run.papers.isEmpty) {
      return const EmptyState(
        icon: Icons.travel_explore,
        title: 'Searching',
        message: 'Papers will appear here as they are found.',
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(Insets.lg),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 420,
        mainAxisExtent: 190,
        crossAxisSpacing: Insets.md,
        mainAxisSpacing: Insets.md,
      ),
      itemCount: run.papers.length,
      itemBuilder: (_, i) => PaperCard(paper: run.papers[i], dense: true),
    );
  }
}

class _StageList extends StatelessWidget {
  const _StageList({required this.run});
  final ResearchRun run;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            run.question,
            style: context.text.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: Insets.lg),
          for (final stage in run.stages) _StageRow(stage: stage),
          if (run.warnings.isNotEmpty) ...[
            const SizedBox(height: Insets.md),
            for (final w in run.warnings) WarningBanner(w.message),
          ],
        ],
      );
}

class _StageRow extends StatelessWidget {
  const _StageRow({required this.stage});
  final StageProgress stage;

  @override
  Widget build(BuildContext context) {
    final running = stage.status == StageStatus.running;
    final done = stage.status == StageStatus.completed;

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: switch (stage.status) {
              StageStatus.completed => Icon(Icons.check_circle,
                  size: 20, color: AppColors.supported),
              StageStatus.running =>
                const CircularProgressIndicator(strokeWidth: 2),
              StageStatus.failed => Icon(Icons.error,
                  size: 20, color: AppColors.contradicted),
              StageStatus.pending => Icon(Icons.circle_outlined,
                  size: 20, color: context.colors.outlineVariant),
            },
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stage.stage.label,
                  style: context.text.bodyMedium?.copyWith(
                    fontWeight: running ? FontWeight.w700 : FontWeight.w400,
                    color: stage.status == StageStatus.pending
                        ? context.colors.onSurfaceVariant
                        : null,
                  ),
                ),
                // A counter on the slow stage. "Reading papers" is the long
                // pole and silently sits for minutes without one.
                if (running && stage.hasCounter) ...[
                  const SizedBox(height: Insets.xs),
                  Text('${stage.done} of ${stage.total}',
                      style: context.text.bodySmall
                          ?.copyWith(color: context.colors.onSurfaceVariant)),
                  const SizedBox(height: Insets.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: stage.fraction,
                      minHeight: 4,
                    ),
                  ),
                ],
                if (done && stage.durationMs != null)
                  Text('${(stage.durationMs! / 1000).toStringAsFixed(1)}s',
                      style: context.text.bodySmall
                          ?.copyWith(color: context.colors.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
