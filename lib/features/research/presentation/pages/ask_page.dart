import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/common.dart';
import '../../domain/entities/research_run.dart';
import '../providers/research_providers.dart';
import '../widgets/run_history_tile.dart';

/// Screen 1 — the entry point. Deliberately close to empty.
/// Researchers do not know what to set before their first run, and a wall of
/// controls makes the tool feel like work.
class AskPage extends ConsumerStatefulWidget {
  const AskPage({super.key});

  @override
  ConsumerState<AskPage> createState() => _AskPageState();
}

class _AskPageState extends ConsumerState<AskPage> {
  final _controller = TextEditingController();
  var _filtersOpen = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final runId =
        await ref.read(askControllerProvider.notifier).submit(_controller.text);
    if (runId != null && mounted) context.go('/run/$runId');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(askControllerProvider);
    final history = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PractSearch'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_outlined),
            tooltip: 'Library',
            onPressed: () => context.go('/library'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Insets.lg),
        child: ReadableWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: Insets.xl),
              Text('What do you want to know?',
                  style: context.text.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: Insets.sm),
              Text(
                'Ask a real research question. The system searches, reads and '
                'compares the papers, then shows what it could verify.',
                style: context.text.bodyMedium
                    ?.copyWith(color: context.colors.onSurfaceVariant),
              ),
              const SizedBox(height: Insets.lg),
              TextField(
                controller: _controller,
                maxLines: 4,
                minLines: 3,
                textInputAction: TextInputAction.newline,
                autofocus: context.isWide,
                decoration: InputDecoration(
                  // A real example teaches what "good" looks like without
                  // a tooltip explaining it.
                  hintText: 'What methods are used for detecting fake news in '
                      'low-resource languages?',
                  hintMaxLines: 2,
                  errorText: state.error,
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: Insets.md),
              _Filters(
                open: _filtersOpen,
                options: state.options,
                onToggle: () => setState(() => _filtersOpen = !_filtersOpen),
                onChanged: (o) =>
                    ref.read(askControllerProvider.notifier).setOptions(o),
              ),
              const SizedBox(height: Insets.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: state.submitting ? null : _submit,
                  icon: state.submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  label: Text(state.submitting ? 'Starting…' : 'Research'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: Insets.md),
                  ),
                ),
              ),
              const SizedBox(height: Insets.xxl),
              history.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (runs) => runs.isEmpty
                    ? const SizedBox.shrink()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionHeader(
                            'Recent',
                            trailing: TextButton(
                              onPressed: () => context.go('/history'),
                              child: const Text('All'),
                            ),
                          ),
                          for (final run in runs.take(3))
                            RunHistoryTile(
                              run: run,
                              onTap: () => context.go('/run/${run.id}'),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.open,
    required this.options,
    required this.onToggle,
    required this.onChanged,
  });

  final bool open;
  final RunOptions options;
  final VoidCallback onToggle;
  final ValueChanged<RunOptions> onChanged;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: onToggle,
            icon: Icon(open ? Icons.expand_less : Icons.tune, size: 18),
            label: Text(open
                ? 'Hide options'
                : '${options.paperCount} papers · '
                    '${options.yearFrom}–${options.yearTo}'),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState:
                open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Card(
              child: Padding(
                padding: const EdgeInsets.all(Insets.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Papers to analyse: ${options.paperCount}',
                        style: context.text.labelLarge),
                    Slider(
                      value: options.paperCount.toDouble(),
                      min: 5,
                      max: 40,
                      divisions: 7,
                      label: '${options.paperCount}',
                      onChanged: (v) =>
                          onChanged(options.copyWith(paperCount: v.round())),
                    ),
                    Text('Published ${options.yearFrom}–${options.yearTo}',
                        style: context.text.labelLarge),
                    RangeSlider(
                      values: RangeValues(
                        options.yearFrom.toDouble(),
                        options.yearTo.toDouble(),
                      ),
                      min: 2000,
                      max: 2026,
                      divisions: 26,
                      labels: RangeLabels(
                        '${options.yearFrom}',
                        '${options.yearTo}',
                      ),
                      onChanged: (v) => onChanged(options.copyWith(
                        yearFrom: v.start.round(),
                        yearTo: v.end.round(),
                      )),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Open access only'),
                      subtitle: const Text(
                          'Papers we can download and read in full'),
                      value: options.openAccessOnly,
                      onChanged: (v) =>
                          onChanged(options.copyWith(openAccessOnly: v)),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Search my library too'),
                      value: options.includeLibrary,
                      onChanged: (v) =>
                          onChanged(options.copyWith(includeLibrary: v)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
}
