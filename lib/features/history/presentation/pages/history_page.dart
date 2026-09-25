import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/common.dart';
import '../../../research/presentation/providers/research_providers.dart';
import '../../../research/presentation/widgets/run_history_tile.dart';

/// Screen 6 — all past runs. Runs are immutable records, so an old one opens
/// exactly as it was, which is what lets you see how an answer changed as the
/// field moved.
class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('History'),
      ),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (runs) {
          final filtered = _query.isEmpty
              ? runs
              : runs
                  .where((r) =>
                      r.question.toLowerCase().contains(_query.toLowerCase()))
                  .toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(Insets.md),
                child: ReadableWidth(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search past questions',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const EmptyState(
                        icon: Icons.history,
                        title: 'Nothing here',
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(
                            Insets.md, 0, Insets.md, Insets.xl),
                        children: [
                          ReadableWidth(
                            child: Column(
                              children: [
                                for (final run in filtered)
                                  RunHistoryTile(
                                    run: run,
                                    onTap: () => context
                                        .go('/run/${run.id}/result'),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
