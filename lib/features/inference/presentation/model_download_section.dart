import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common.dart';
import '../../settings/presentation/settings_providers.dart';
import '../domain/entities/downloadable_model.dart';
import 'inference_providers.dart';

/// Model download UI.
///
/// A 2GB download deserves honesty up front: the size is stated before the
/// button, progress is in MB rather than a percentage alone, and every model
/// can be deleted. Users do not forgive an app that quietly eats their
/// storage or their data plan.
class ModelDownloadSection extends ConsumerWidget {
  const ModelDownloadSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final used = ref.watch(modelStorageProvider).valueOrNull ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          'Offline models',
          trailing: used == 0
              ? null
              : Text(
                  '${(used / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB used',
                  style: context.text.bodySmall
                      ?.copyWith(color: context.colors.onSurfaceVariant),
                ),
        ),
        Text(
          'Downloaded once, then works with no connection at all. Use wifi — '
          'these are large files.',
          style: context.text.bodySmall
              ?.copyWith(color: context.colors.onSurfaceVariant),
        ),
        const SizedBox(height: Insets.sm),
        for (final model in DownloadableModel.catalogue)
          _ModelTile(model: model),
      ],
    );
  }
}

class _ModelTile extends ConsumerStatefulWidget {
  const _ModelTile({required this.model});
  final DownloadableModel model;

  @override
  ConsumerState<_ModelTile> createState() => _ModelTileState();
}

class _ModelTileState extends ConsumerState<_ModelTile> {
  ModelState? _live;

  void _start() {
    final manager = ref.read(modelDownloadsProvider);
    manager.download(widget.model).listen(
      (state) {
        if (!mounted) return;
        setState(() => _live = state);
        if (state is Downloaded) {
          ref.invalidate(installedModelsProvider);
          ref.invalidate(modelStorageProvider);
          ref.invalidate(backendStatusProvider);
        }
      },
      onError: (Object e) {
        if (mounted) setState(() => _live = DownloadFailed('$e'));
      },
    );
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete ${widget.model.name}?'),
        content: Text(
          'Frees ${widget.model.sizeLabel}. You can download it again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(modelDownloadsProvider).delete(widget.model);
    if (!mounted) return;
    setState(() => _live = const NotDownloaded());
    ref
      ..invalidate(installedModelsProvider)
      ..invalidate(modelStorageProvider)
      ..invalidate(backendStatusProvider);
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    final async = ref.watch(modelStateProvider(model));
    final state = _live ?? async.valueOrNull ?? const NotDownloaded();
    final selected =
        ref.watch(settingsProvider.select((s) => s.localModel)) == model.id;

    return Card(
      margin: const EdgeInsets.only(bottom: Insets.sm),
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(model.name,
                            style: context.text.titleSmall),
                      ),
                      const SizedBox(width: Insets.sm),
                      Text(
                        '${model.parameterCount} · ${model.sizeLabel}',
                        style: context.text.labelSmall?.copyWith(
                            color: context.colors.onSurfaceVariant),
                      ),
                      if (model.recommended) ...[
                        const SizedBox(width: Insets.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: context.colors.primaryContainer,
                            borderRadius: BorderRadius.circular(Radii.chip),
                          ),
                          child: Text(
                            'Recommended',
                            style: context.text.labelSmall?.copyWith(
                              color: context.colors.onPrimaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.xs),
            Text(model.summary, style: context.text.bodySmall),
            const SizedBox(height: Insets.sm),
            switch (state) {
              NotDownloaded() => Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _start,
                    icon: const Icon(Icons.download, size: 16),
                    label: Text('Download ${model.sizeLabel}'),
                  ),
                ),
              Downloading(:final fraction, :final label) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: fraction,
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: Insets.xs),
                    Row(
                      children: [
                        Expanded(
                          child: Text(label,
                              style: context.text.bodySmall?.copyWith(
                                  color: context.colors.onSurfaceVariant)),
                        ),
                        TextButton(
                          onPressed: () =>
                              ref.read(modelDownloadsProvider).cancel(model),
                          child: const Text('Stop'),
                        ),
                      ],
                    ),
                  ],
                ),
              Downloaded() => Row(
                  children: [
                    const Icon(Icons.check_circle_outline,
                        size: 16, color: AppColors.supported),
                    const SizedBox(width: Insets.xs),
                    Text(
                      selected ? 'Ready · in use' : 'Ready',
                      style: context.text.bodySmall
                          ?.copyWith(color: AppColors.supported),
                    ),
                    const Spacer(),
                    if (!selected)
                      TextButton(
                        onPressed: () => ref
                            .read(settingsProvider.notifier)
                            .update(ref
                                .read(settingsProvider)
                                .copyWith(localModel: model.id)),
                        child: const Text('Use'),
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      tooltip: 'Delete',
                      onPressed: _delete,
                    ),
                  ],
                ),
              DownloadFailed(:final reason) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(reason,
                        style: context.text.bodySmall
                            ?.copyWith(color: AppColors.contradicted)),
                    const SizedBox(height: Insets.xs),
                    // Resuming reuses the partial file — an interrupted 1.4GB
                    // is not thrown away.
                    OutlinedButton.icon(
                      onPressed: _start,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Resume'),
                    ),
                  ],
                ),
            },
          ],
        ),
      ),
    );
  }
}
