import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/common.dart';
import '../../../export/presentation/widgets/export_sheet.dart';
import '../../domain/entities/research_run.dart';
import '../providers/research_providers.dart';
import '../widgets/answer_tab.dart';
import '../widgets/compare_tab.dart';
import '../widgets/gaps_tab.dart';
import '../widgets/paper_card.dart';

/// Screen 3 — the main screen. Four tabs over one run.
class ResultPage extends ConsumerWidget {
  const ResultPage({super.key, required this.runId});
  final String runId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(runProvider(runId));

    return async.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load this run',
          message: '$e',
          action: FilledButton(
            onPressed: () => context.go('/'),
            child: const Text('Back'),
          ),
        ),
      ),
      data: (run) => _ResultScaffold(run: run),
    );
  }
}

class _ResultScaffold extends StatelessWidget {
  const _ResultScaffold({required this.run});
  final ResearchRun run;

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 4,
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/'),
            ),
            title: Text(
              run.question,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.titleSmall,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.ios_share),
                tooltip: 'Export',
                onPressed: () => showExportSheet(context, run),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(96),
              child: Column(
                children: [
                  if (run.warnings.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          Insets.md, 0, Insets.md, Insets.sm),
                      child: WarningBanner(run.warnings.first.message),
                    ),
                  TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: [
                      const Tab(text: 'Answer'),
                      Tab(text: 'Papers (${run.papers.length})'),
                      const Tab(text: 'Compare'),
                      Tab(text: 'Gaps (${run.gaps.length})'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          body: TabBarView(
            children: [
              AnswerTab(run: run),
              _PapersTab(run: run),
              CompareTab(run: run),
              GapsTab(run: run),
            ],
          ),
        ),
      );

}

/// Tab 2 — the papers, each with the one line explaining why it was included.
class _PapersTab extends StatelessWidget {
  const _PapersTab({required this.run});
  final ResearchRun run;

  @override
  Widget build(BuildContext context) {
    if (run.papers.isEmpty) {
      return const EmptyState(
        icon: Icons.library_books_outlined,
        title: 'No papers',
        message: 'Nothing survived the search and ingest stages.',
      );
    }

    if (context.isWide) {
      return GridView.builder(
        padding: const EdgeInsets.all(Insets.lg),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 420,
          mainAxisExtent: 200,
          crossAxisSpacing: Insets.md,
          mainAxisSpacing: Insets.md,
        ),
        itemCount: run.papers.length,
        itemBuilder: (_, i) =>
            PaperCard(paper: run.papers[i], dense: true, runId: run.id),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(Insets.md),
      itemCount: run.papers.length,
      itemBuilder: (_, i) => PaperCard(paper: run.papers[i], runId: run.id),
    );
  }
}
