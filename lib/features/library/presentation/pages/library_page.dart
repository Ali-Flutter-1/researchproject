import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/common.dart';
import '../../domain/entities/library_paper.dart';
import '../library_providers.dart';

/// Screen 5 — the user's own papers.
///
/// Researchers already have a folder of PDFs, and asking questions across it
/// is often the first thing they actually want from a tool like this.
class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  var _picking = false;

  Future<void> _addPdfs() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final repo = ref.read(libraryRepositoryProvider);
      final files = await repo.pickPdfs();
      // Cancelling the picker is a normal action, not an error to report.
      if (files.isEmpty) return;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Adding ${files.length} '
              '${files.length == 1 ? 'paper' : 'papers'}…',
            ),
          ),
        );
      }
      await repo.add(files);
      ref.invalidate(libraryUsageProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add files: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Library'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _picking ? null : _addPdfs,
        icon: _picking
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.upload_file),
        label: Text(_picking ? 'Opening…' : 'Add PDFs'),
      ),
      body: library.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (papers) {
          if (papers.isEmpty) {
            return EmptyState(
              icon: Icons.folder_open_outlined,
              title: 'No papers yet',
              message: 'Add PDFs and they go through the same pipeline as '
                  'searched papers — parsed, chunked and searchable.',
              action: FilledButton.icon(
                onPressed: _picking ? null : _addPdfs,
                icon: const Icon(Icons.upload_file),
                label: const Text('Add PDFs'),
              ),
            );
          }

          final ready = papers.where((p) => p.status == IngestStatus.ready);
          return ListView(
            padding: const EdgeInsets.fromLTRB(
                Insets.md, Insets.md, Insets.md, 96),
            children: [
              ReadableWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: Insets.sm),
                      child: Row(
                        children: [
                          Icon(Icons.phone_iphone,
                              size: 13,
                              color: context.colors.onSurfaceVariant),
                          const SizedBox(width: Insets.xs),
                          Expanded(
                            child: Text(
                              '${papers.length} papers · ${ready.length} ready '
                              'to search${_usage(ref)}',
                              style: context.text.bodySmall?.copyWith(
                                  color: context.colors.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (final paper in papers)
                      _LibraryTile(
                        paper: paper,
                        onRemove: () async {
                          await ref
                              .read(libraryRepositoryProvider)
                              .remove(paper.id);
                          ref.invalidate(libraryUsageProvider);
                        },
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

/// Papers are kept on this device, so the size is worth stating — it is the
/// user's storage being used, and they should not have to guess.
String _usage(WidgetRef ref) {
  final bytes = ref.watch(libraryUsageProvider).valueOrNull;
  if (bytes == null || bytes == 0) return '';
  final mb = bytes / (1024 * 1024);
  return mb < 1
      ? ' · ${(bytes / 1024).toStringAsFixed(0)} KB on device'
      : ' · ${mb.toStringAsFixed(1)} MB on device';
}

class _LibraryTile extends StatelessWidget {
  const _LibraryTile({required this.paper, required this.onRemove});

  final LibraryPaper paper;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final failed = paper.status == IngestStatus.failed;

    return Card(
      margin: const EdgeInsets.only(bottom: Insets.sm),
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusIcon(status: paper.status),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    paper.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _subtitle(paper),
                    style: context.text.bodySmall?.copyWith(
                      color: failed
                          ? AppColors.contradicted
                          : context.colors.onSurfaceVariant,
                    ),
                  ),
                  if (paper.status.isWorking) ...[
                    const SizedBox(height: Insets.sm),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: const LinearProgressIndicator(minHeight: 3),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Remove',
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }

  static String _subtitle(LibraryPaper p) => switch (p.status) {
        IngestStatus.failed => p.error ?? 'Could not read this PDF.',
        IngestStatus.ready =>
          '${p.pageCount} pages · ${p.chunkCount} searchable sections · '
              '${p.sizeLabel}',
        _ => '${p.status.label}… · ${p.sizeLabel}',
      };
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});
  final IngestStatus status;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 22,
        height: 22,
        child: switch (status) {
          IngestStatus.ready =>
            const Icon(Icons.check_circle, size: 20, color: AppColors.supported),
          IngestStatus.failed => const Icon(Icons.error_outline,
              size: 20, color: AppColors.contradicted),
          _ => const CircularProgressIndicator(strokeWidth: 2),
        },
      );
}
