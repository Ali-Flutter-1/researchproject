import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/common.dart';

final themeModeProvider = StateProvider<ThemeMode>((_) => ThemeMode.system);

/// Screen 7 — short, as it should be.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Settings'),
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
                    groupValue: mode,
                    onChanged: (v) =>
                        ref.read(themeModeProvider.notifier).state = v!,
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
                const SectionHeader('Export'),
                Card(
                  child: Column(
                    children: const [
                      ListTile(
                        title: Text('Default format'),
                        subtitle: Text('Markdown report'),
                        trailing: Icon(Icons.chevron_right),
                      ),
                      Divider(height: 1),
                      ListTile(
                        title: Text('Citation style'),
                        subtitle: Text('BibTeX'),
                        trailing: Icon(Icons.chevron_right),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
