import 'package:go_router/go_router.dart';

import '../../features/history/presentation/pages/history_page.dart';
import '../../features/library/presentation/pages/library_page.dart';
import '../../features/research/presentation/pages/ask_page.dart';
import '../../features/research/presentation/pages/paper_detail_page.dart';
import '../../features/research/presentation/pages/result_page.dart';
import '../../features/research/presentation/pages/run_progress_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';

/// Routes mirror the API shape, so a run is deep-linkable and the browser
/// back button behaves on Flutter Web.
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, _) => const AskPage()),
    GoRoute(
      path: '/run/:runId',
      builder: (_, s) =>
          RunProgressPage(runId: s.pathParameters['runId']!),
      routes: [
        GoRoute(
          path: 'result',
          builder: (_, s) => ResultPage(runId: s.pathParameters['runId']!),
        ),
        GoRoute(
          path: 'paper/:paperId',
          builder: (_, s) => PaperDetailPage(
            runId: s.pathParameters['runId']!,
            paperId: s.pathParameters['paperId']!,
          ),
        ),
      ],
    ),
    GoRoute(path: '/library', builder: (_, _) => const LibraryPage()),
    GoRoute(path: '/history', builder: (_, _) => const HistoryPage()),
    GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
  ],
);
