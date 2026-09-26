import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/common.dart';
import '../../../research/domain/entities/research_run.dart';
import '../../domain/entities/citation_style.dart';
import '../export_providers.dart';

/// The export sheet. Format first, then only the options that format actually
/// has — showing a citation-style picker above a CSV export would be noise.
class ExportSheet extends ConsumerStatefulWidget {
  const ExportSheet({super.key, required this.run});
  final ResearchRun run;

  @override
  ConsumerState<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends ConsumerState<ExportSheet> {
  var _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _share() => _run(() async {
        final result = await ref.read(buildExportProvider)(
          widget.run,
          ref.read(exportRequestProvider),
        );
        await ref.read(exportServiceProvider).share(result);
      });

  Future<void> _print() => _run(() async {
        final result = await ref.read(buildExportProvider)(
          widget.run,
          ref.read(exportRequestProvider),
        );
        await ref.read(exportServiceProvider).printDocument(result);
      });

  Future<void> _copy() => _run(() async {
        final result = await ref.read(buildExportProvider)(
          widget.run,
          ref.read(exportRequestProvider),
        );
        await Clipboard.setData(ClipboardData(text: result.text ?? ''));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Copied to clipboard')),
          );
        }
      });

  @override
  Widget build(BuildContext context) {
    final request = ref.watch(exportRequestProvider);
    final notifier = ref.read(exportRequestProvider.notifier);
    final isPdf = request.format == ExportFormat.pdf;
    final isBibliography = request.format == ExportFormat.bibliography;
    final hasCitations =
        request.format == ExportFormat.markdown || isPdf;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Insets.lg, Insets.sm, Insets.lg, 0),
              child: Row(
                children: [
                  Text('Export', style: context.text.titleLarge),
                  const Spacer(),
                  Text(
                    '${widget.run.papers.length} papers',
                    style: context.text.bodySmall
                        ?.copyWith(color: context.colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(Insets.lg),
                children: [
                  const SectionHeader('Format'),
                  RadioGroup<ExportFormat>(
                    groupValue: request.format,
                    onChanged: (v) =>
                        notifier.state = request.copyWith(format: v),
                    child: Column(
                      children: [
                        for (final f in ExportFormat.values)
                          RadioListTile<ExportFormat>(
                            contentPadding: EdgeInsets.zero,
                            value: f,
                            title: Text(f.label),
                            subtitle: Text(
                              f.description,
                              style: context.text.bodySmall,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Only shown where it changes the output.
                  if (isBibliography) ...[
                    const SizedBox(height: Insets.md),
                    const SectionHeader('Bibliography format'),
                    Wrap(
                      spacing: Insets.sm,
                      children: [
                        for (final f in BibliographyFormat.values)
                          ChoiceChip(
                            label: Text(f.label),
                            selected: request.bibliographyFormat == f,
                            onSelected: (_) => notifier.state =
                                request.copyWith(bibliographyFormat: f),
                          ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: Insets.xs),
                      child: Text(
                        'For ${request.bibliographyFormat.usedBy}',
                        style: context.text.bodySmall?.copyWith(
                            color: context.colors.onSurfaceVariant),
                      ),
                    ),
                  ],

                  if (hasCitations) ...[
                    const SizedBox(height: Insets.md),
                    const SectionHeader('Citation style'),
                    Wrap(
                      spacing: Insets.sm,
                      runSpacing: Insets.xs,
                      children: [
                        for (final s in CitationStyle.values)
                          ChoiceChip(
                            label: Text(s.label),
                            selected: request.citationStyle == s,
                            onSelected: (_) => notifier.state =
                                request.copyWith(citationStyle: s),
                          ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: Insets.xs),
                      child: Text(
                        request.citationStyle.usedFor,
                        style: context.text.bodySmall?.copyWith(
                            color: context.colors.onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(height: Insets.md),
                    const SectionHeader('Include'),
                    _Toggle(
                      title: 'Comparison matrix',
                      value: request.includeMatrix,
                      onChanged: (v) =>
                          notifier.state = request.copyWith(includeMatrix: v),
                    ),
                    _Toggle(
                      title: 'Research gaps',
                      value: request.includeGaps,
                      onChanged: (v) =>
                          notifier.state = request.copyWith(includeGaps: v),
                    ),
                    _Toggle(
                      title: 'Unverified statements',
                      subtitle: widget.run.needsCheckCount > 0
                          ? '${widget.run.needsCheckCount} could not be '
                              'confirmed — they stay flagged in the export'
                          : 'Nothing flagged in this run',
                      value: request.includeUnverifiedClaims,
                      onChanged: (v) => notifier.state =
                          request.copyWith(includeUnverifiedClaims: v),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(Insets.md),
              child: Row(
                children: [
                  if (!isPdf)
                    IconButton.outlined(
                      onPressed: _busy ? null : _copy,
                      icon: const Icon(Icons.copy_all_outlined),
                      tooltip: 'Copy to clipboard',
                    ),
                  if (isPdf)
                    IconButton.outlined(
                      onPressed: _busy ? null : _print,
                      icon: const Icon(Icons.print_outlined),
                      tooltip: 'Print or preview',
                    ),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _share,
                      icon: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.ios_share),
                      label: Text(_busy ? 'Preparing…' : 'Share'),
                      style: FilledButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: Insets.md),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title),
        subtitle: subtitle == null
            ? null
            : Text(subtitle!, style: context.text.bodySmall),
        value: value,
        onChanged: onChanged,
      );
}

Future<void> showExportSheet(BuildContext context, ResearchRun run) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => ExportSheet(run: run),
    );
