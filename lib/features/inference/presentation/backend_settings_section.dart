import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common.dart';
import '../../settings/presentation/settings_providers.dart';
import '../domain/entities/llm_model.dart';
import 'inference_providers.dart';
import 'model_download_section.dart';

/// Backend selection, with a live connection test.
///
/// A settings screen that lets you pick a local server and then says nothing
/// about whether it works is a trap: the user finds out only when a run fails
/// four minutes in. This probes immediately and says what to do when it fails.
class BackendSettingsSection extends ConsumerStatefulWidget {
  const BackendSettingsSection({super.key});

  @override
  ConsumerState<BackendSettingsSection> createState() =>
      _BackendSettingsSectionState();
}

class _BackendSettingsSectionState
    extends ConsumerState<BackendSettingsSection> {
  late final TextEditingController _url;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: ref.read(settingsProvider).ollamaUrl);
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final online = ref.watch(connectivityProvider).valueOrNull ?? true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Where answers come from'),
        Card(
          child: RadioGroup<InferenceBackend>(
            groupValue: s.backend,
            onChanged: (v) => controller.update(s.copyWith(backend: v)),
            child: Column(
              children: [
                for (final b in InferenceBackend.values)
                  RadioListTile<InferenceBackend>(
                    value: b,
                    title: Row(
                      children: [
                        Flexible(child: Text(b.label)),
                        if (b.needsInternet && !online) ...[
                          const SizedBox(width: Insets.sm),
                          const _Pill('No connection', AppColors.partial),
                        ],

                      ],
                    ),
                    subtitle:
                        Text(b.description, style: context.text.bodySmall),
                  ),
              ],
            ),
          ),
        ),

        if (s.backend == InferenceBackend.onDevice) ...[
          const SizedBox(height: Insets.md),
          const ModelDownloadSection(),
        ],

        if (s.backend == InferenceBackend.ollama) ...[
          const SizedBox(height: Insets.md),
          const SectionHeader('Ollama server'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Insets.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _url,
                    decoration: const InputDecoration(
                      labelText: 'Address',
                      hintText: 'http://192.168.1.10:11434',
                      helperText: 'Your computer’s address on this network',
                    ),
                    onSubmitted: (v) =>
                        controller.update(s.copyWith(ollamaUrl: v.trim())),
                  ),
                  const SizedBox(height: Insets.sm),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          controller
                              .update(s.copyWith(ollamaUrl: _url.text.trim()));
                          ref.invalidate(backendStatusProvider);
                        },
                        icon: const Icon(Icons.sync, size: 16),
                        label: const Text('Test connection'),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: Insets.sm),
                  _StatusView(
                    selectedModel: s.localModel,
                    onPick: (m) =>
                        controller.update(s.copyWith(localModel: m)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatusView extends ConsumerWidget {
  const _StatusView({required this.selectedModel, required this.onPick});

  final String selectedModel;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(backendStatusProvider);

    return status.when(
      loading: () => const Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: Insets.sm),
          Text('Checking…'),
        ],
      ),
      error: (e, _) => Text('$e'),
      data: (s) => switch (s) {
        BackendChecking() => const Text('Checking…'),
        BackendUnreachable(:final reason, :final hint) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.error_outline,
                      size: 16, color: AppColors.contradicted),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: Text(reason,
                        style: context.text.bodySmall
                            ?.copyWith(color: AppColors.contradicted)),
                  ),
                ],
              ),
              // The hint is the whole point. "Connection refused" with no
              // next step is where most people give up on local models.
              if (hint != null) ...[
                const SizedBox(height: Insets.xs),
                Text(hint,
                    style: context.text.bodySmall
                        ?.copyWith(color: context.colors.onSurfaceVariant)),
              ],
            ],
          ),
        BackendReady(:final models) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle_outline,
                      size: 16, color: AppColors.supported),
                  const SizedBox(width: Insets.sm),
                  Text('Connected · ${models.length} models',
                      style: context.text.bodySmall
                          ?.copyWith(color: AppColors.supported)),
                ],
              ),
              const SizedBox(height: Insets.sm),
              Wrap(
                spacing: Insets.sm,
                runSpacing: Insets.xs,
                children: [
                  for (final m in models)
                    ChoiceChip(
                      label: Text(
                        m.parameterCount == null
                            ? m.name
                            : '${m.name} · ${m.parameterCount}',
                      ),
                      selected: m.id == selectedModel,
                      onSelected: (_) => onPick(m.id),
                    ),
                ],
              ),
            ],
          ),
      },
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(Radii.chip),
        ),
        child: Text(
          text,
          style: context.text.labelSmall
              ?.copyWith(color: color, fontWeight: FontWeight.w700),
        ),
      );
}
