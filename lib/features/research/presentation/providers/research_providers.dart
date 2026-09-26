import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/mock_research_data_source.dart';
import '../../data/repositories/research_repository_impl.dart';
import '../../domain/entities/claim.dart';
import '../../domain/entities/research_run.dart';
import '../../domain/repositories/research_repository.dart';
import '../../domain/usecases/build_comparison.dart';
import '../../domain/usecases/start_research.dart';
import '../../domain/usecases/watch_run.dart';
import '../../../settings/presentation/settings_providers.dart';

// --- Wiring -----------------------------------------------------------------

final _dataSourceProvider =
    Provider<MockResearchDataSource>((ref) => MockResearchDataSource());

final researchRepositoryProvider = Provider<ResearchRepository>(
  (ref) => ResearchRepositoryImpl(ref.watch(_dataSourceProvider)),
);

final startResearchProvider = Provider(
  (ref) => StartResearch(ref.watch(researchRepositoryProvider)),
);

final getHistoryProvider = Provider(
  (ref) => GetHistory(ref.watch(researchRepositoryProvider)),
);

// --- Ask screen state -------------------------------------------------------

class AskState {
  const AskState({
    this.options = const RunOptions(),
    this.submitting = false,
    this.error,
  });

  final RunOptions options;
  final bool submitting;
  final String? error;

  AskState copyWith({
    RunOptions? options,
    bool? submitting,
    String? error,
    bool clearError = false,
  }) =>
      AskState(
        options: options ?? this.options,
        submitting: submitting ?? this.submitting,
        error: clearError ? null : (error ?? this.error),
      );
}

class AskController extends StateNotifier<AskState> {
  /// Seeded from the user's saved defaults, so a researcher who set
  /// "30 papers, 2015-2026" once does not re-enter it every question.
  AskController(this._start, RunOptions defaults)
      : super(AskState(options: defaults));
  final StartResearch _start;

  void setOptions(RunOptions options) =>
      state = state.copyWith(options: options);

  /// Returns the new runId, or null if validation failed.
  Future<String?> submit(String question) async {
    state = state.copyWith(submitting: true, clearError: true);
    try {
      final id = await _start(question: question, options: state.options);
      state = state.copyWith(submitting: false);
      return id;
    } on ShortQuestionFailure catch (e) {
      state = state.copyWith(submitting: false, error: e.message);
      return null;
    } catch (_) {
      state = state.copyWith(
        submitting: false,
        error: 'Could not start the run. Check your connection and try again.',
      );
      return null;
    }
  }
}

final askControllerProvider =
    StateNotifierProvider<AskController, AskState>(
  (ref) => AskController(
    ref.watch(startResearchProvider),
    ref.watch(settingsProvider).toRunOptions(),
  ),
);

// --- Run state --------------------------------------------------------------

/// The live run. Autodisposed so leaving a run stops its stream.
final runProvider = StreamProvider.autoDispose.family<ResearchRun, String>(
  (ref, runId) => ref.watch(researchRepositoryProvider).watchRun(runId),
);

final comparisonProvider =
    Provider.autoDispose.family<List<MatrixRow>, ResearchRun>(
  (ref, run) => const BuildComparison()(run),
);

final evidenceProvider =
    FutureProvider.autoDispose.family<Evidence?, String>(
  (ref, chunkId) =>
      ref.watch(researchRepositoryProvider).evidenceForChunk(chunkId),
);

final historyProvider = FutureProvider<List<ResearchRun>>(
  (ref) => ref.watch(getHistoryProvider)(),
);
