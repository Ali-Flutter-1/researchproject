import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/common.dart';
import '../../domain/entities/paper.dart';
import '../providers/research_providers.dart';
import '../widgets/evidence_sheet.dart';

/// Screen 4 — one paper, in depth.
///
/// The inline PDF viewer is the hardest part of this client on Flutter Web
/// and the one place this stack is genuinely weaker than a React app.
/// It is stubbed here deliberately: prototype it in week 1 before committing.
class PaperDetailPage extends ConsumerWidget {
  const PaperDetailPage({
    super.key,
    required this.runId,
    required this.paperId,
  });

  final String runId;
  final String paperId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(runProvider(runId));

    return async.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(appBar: AppBar(), body: Center(child: Text('$e'))),
      data: (run) {
        final paper = run.paperById(paperId);
        if (paper == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              icon: Icons.search_off,
              title: 'Paper not found in this run',
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/run/$runId/result'),
            ),
            title: Text(paper.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.titleSmall),
          ),
          body: context.isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 4, child: _Summary(paper: paper)),
                    const VerticalDivider(),
                    const Expanded(flex: 5, child: _PdfPane()),
                  ],
                )
              : DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      const TabBar(
                        tabs: [Tab(text: 'Summary'), Tab(text: 'Paper')],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [_Summary(paper: paper), const _PdfPane()],
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.paper});
  final Paper paper;

  @override
  Widget build(BuildContext context) {
    final e = paper.extraction;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Insets.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(paper.title,
              style: context.text.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600, height: 1.3)),
          const SizedBox(height: Insets.sm),
          Text(
            '${paper.authors.join(', ')}\n'
            '${paper.venue} ${paper.year} · ${paper.citationCount} citations',
            style: context.text.bodySmall
                ?.copyWith(color: context.colors.onSurfaceVariant, height: 1.5),
          ),
          const SizedBox(height: Insets.sm),
          Wrap(
            spacing: Insets.sm,
            children: [
              ActionChip(
                avatar: const Icon(Icons.link, size: 15),
                label: Text(paper.doi),
                onPressed: () {},
              ),
            ],
          ),
          if (paper.parseConfidence != ParseConfidence.high) ...[
            const SizedBox(height: Insets.md),
            WarningBanner(
              paper.parseConfidence == ParseConfidence.low
                  ? 'This PDF parsed poorly. Treat the extracted fields below '
                      'with caution and check them against the paper.'
                  : 'Parts of this PDF could not be read cleanly.',
            ),
          ],
          const SizedBox(height: Insets.lg),
          const Divider(),
          if (e == null)
            const Padding(
              padding: EdgeInsets.only(top: Insets.lg),
              child: EmptyState(
                icon: Icons.pending_outlined,
                title: 'Not analysed yet',
              ),
            )
          else ...[
            LabelledValue(label: 'Problem', child: Text(e.problem)),
            LabelledValue(
              label: 'Method',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.method.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (e.method.summary.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(e.method.summary),
                  ],
                ],
              ),
            ),
            if (e.datasets.isNotEmpty)
              LabelledValue(
                label: 'Datasets',
                onSource: e.datasets.first.chunkId == null
                    ? null
                    : () => showEvidenceSheet(context,
                        chunkId: e.datasets.first.chunkId!),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final d in e.datasets)
                      Text('• ${d.name}${d.value.isEmpty ? '' : ' (${d.value})'}'),
                  ],
                ),
              ),
            if (e.metrics.isNotEmpty)
              LabelledValue(
                label: 'Reported results',
                onSource: e.metrics.first.chunkId == null
                    ? null
                    : () => showEvidenceSheet(context,
                        chunkId: e.metrics.first.chunkId!),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final m in e.metrics) Text('• ${m.name} — ${m.value}'),
                  ],
                ),
              ),
            if (e.baselines.isNotEmpty)
              LabelledValue(
                label: 'Compared against',
                child: Text(e.baselines.join(', ')),
              ),
            if (e.limitations.isNotEmpty)
              LabelledValue(
                label: 'Limitations',
                onSource: e.limitations.first.chunkId == null
                    ? null
                    : () => showEvidenceSheet(context,
                        chunkId: e.limitations.first.chunkId!),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final l in e.limitations)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          '• ${l.text}'
                          '${l.statedByAuthors ? '' : '  (inferred)'}',
                        ),
                      ),
                  ],
                ),
              ),
            if (e.claimedContribution.isNotEmpty)
              LabelledValue(
                label: 'Claimed contribution',
                child: Text(e.claimedContribution),
              ),
          ],
          const SizedBox(height: Insets.xxl),
        ],
      ),
    );
  }
}

class _PdfPane extends StatelessWidget {
  const _PdfPane();

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: context.colors.surfaceContainerHighest.withValues(alpha: 0.3),
        child: const EmptyState(
          icon: Icons.picture_as_pdf_outlined,
          title: 'PDF viewer',
          message: 'Wire up an inline viewer here with cited passages '
              'highlighted. Prototype this early — it is the riskiest widget '
              'in the client on Flutter Web.',
        ),
      );
}
