import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/presentation/pages/settings_page.dart';

void main() => runApp(const ProviderScope(child: PractSearchApp()));

class PractSearchApp extends ConsumerWidget {
  const PractSearchApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
        title: 'PractSearch',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ref.watch(themeModeProvider),
        routerConfig: appRouter,
      );
}
