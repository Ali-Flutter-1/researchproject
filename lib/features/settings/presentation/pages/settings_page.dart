import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/common.dart';
import '../../../export/domain/entities/citation_style.dart';
import '../../domain/entities/app_settings.dart';
import '../settings_providers.dart';

/// Screen 7 — the defaults every run and every export starts from.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Settings'),
        actions: [
          TextButton(
            onPressed: () => controller.update(const AppSettings()),
            child: const Text('Reset'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(Insets.md),
        children: [
          ReadableWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader('Appearance'),
                Card(
                  child: RadioGroup<ThemeMode>(
                    groupValue: s.themeMode,
                    onChanged: (v) =>
                        controller.update(s.copyWith(themeMode: v)),
                    child: Column(
                      children: [
                        for (final m in ThemeMode.values)
                          RadioListTile<ThemeMode>(
                            value: m,
                            title: Text(switch (m) {
                              ThemeMode.system => 'Match system',
                              ThemeMode.light => 'Light',
                              ThemeMode.dark => 'Dark',
                            }),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: Insets.lg),
                const SectionHeader('Search defaults'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(Insets.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Papers per run: ${s.paperCount}',
                            style: context.text.labelLarge),
                        Slider(
                          value: s.paperCount.toDouble(),
                          min: 5,
                          max: 40,
                          divisions: 7,
                          label: '${s.paperCount}',
                          onChanged: (v) => controller
                              .update(s.copyWith(paperCount: v.round())),
                        ),
                        Text('Published ${s.yearFrom}–${s.yearTo}',
                            style: context.text.labelLarge),
                        RangeSlider(
                          values: RangeValues(
                            s.yearFrom.toDouble(),
                            s.yearTo.toDouble(),
                          ),
                          min: 2000,
                          max: 2026,
                          divisions: 26,
                          labels: RangeLabels('${s.yearFrom}', '${s.yearTo}'),
                          onChanged: (v) => controller.update(s.copyWith(
                            yearFrom: v.start.round(),
                            yearTo: v.end.round(),
                          )),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Open access only'),
                          subtitle: const Text(
                              'Only papers we can download and read in full'),
                          value: s.openAccessOnly,
                          onChanged: (v) =>
                              controller.update(s.copyWith(openAccessOnly: v)),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Search my library too'),
                          subtitle:
                              const Text('Include your uploaded PDFs by default'),
                          value: s.includeLibraryByDefault,
                          onChanged: (v) => controller.update(
                              s.copyWith(includeLibraryByDefault: v)),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: Insets.lg),
                const SectionHeader('Export defaults'),
                Card(
                  child: Column(
                    children: [
                      _PickerTile<CitationStyle>(
                        title: 'Citation style',
                        value: s.citationStyle,
                        values: CitationStyle.values,
                        labelOf: (v) => v.label,
                        detailOf: (v) => v.usedFor,
                        onChanged: (v) =>
                            controller.update(s.copyWith(citationStyle: v)),
                      ),
                      const Divider(height: 1),
                      _PickerTile<ExportFormat>(
                        title: 'Default format',
                        value: s.exportFormat,
                        values: ExportFormat.values,
                        labelOf: (v) => v.label,
                        detailOf: (v) => v.description,
                        onChanged: (v) =>
                            controller.update(s.copyWith(exportFormat: v)),
                      ),
                      const Divider(height: 1),
                      _PickerTile<BibliographyFormat>(
                        title: 'Bibliography format',
                        value: s.bibliographyFormat,
                        values: BibliographyFormat.values,
                        labelOf: (v) => v.label,
                        detailOf: (v) => 'For ${v.usedBy}',
                        onChanged: (v) => controller
                            .update(s.copyWith(bibliographyFormat: v)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: Insets.lg),
                const SectionHeader('About'),
                Card(
                  child: ListTile(
                    title: const Text('PractSearch'),
                    subtitle: Text(
                      'Research assistant — evidence-backed analysis with '
                      'verified citations.',
                      style: context.text.bodySmall,
                    ),
                  ),
                ),
                const SizedBox(height: Insets.xl),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A row that opens a picker. Generic so the three export defaults share one
/// implementation instead of three near-identical dialogs.
class _PickerTile<T> extends StatelessWidget {
  const _PickerTile({
    required this.title,
    required this.value,
    required this.values,
    required this.labelOf,
    required this.detailOf,
    required this.onChanged,
  });

  final String title;
  final T value;
  final List<T> values;
  final String Function(T) labelOf;
  final String Function(T) detailOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(title),
        subtitle: Text(labelOf(value)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final picked = await showModalBottomSheet<T>(
            context: context,
            showDragHandle: true,
            constraints: const BoxConstraints(maxWidth: 560),
            builder: (_) => SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        Insets.lg, 0, Insets.lg, Insets.sm),
                    child: Text(title, style: context.text.titleMedium),
                  ),
                  for (final v in values)
                    ListTile(
                      title: Text(labelOf(v)),
                      subtitle: Text(detailOf(v),
                          style: context.text.bodySmall),
                      trailing: v == value
                          ? Icon(Icons.check, color: context.colors.primary)
                          : null,
                      onTap: () => Navigator.pop(context, v),
                    ),
                ],
              ),
            ),
          );
          if (picked != null) onChanged(picked);
        },
      );
}
