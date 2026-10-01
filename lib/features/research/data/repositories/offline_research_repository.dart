import 'dart:async';

import '../../../inference/domain/repositories/llm_service.dart';
import '../../../library/data/library_repository_impl.dart';
import '../../../library/domain/services/bm25_retriever.dart';
import '../../domain/entities/claim.dart';
import '../../domain/entities/paper.dart';
import '../../domain/entities/research_run.dart';
import '../../domain/entities/run_stage.dart';
import '../../domain/repositories/research_repository.dart';
import '../../domain/services/offline_pipeline.dart';

/// A real offline run: retrieve from the user's own PDFs, answer with a local
/// model, cite the passages the answer came from.
///
/// Nothing here is canned. If the library is empty, the run says so instead
/// of producing a result — which is the correct behaviour, and the reason an
/// empty-library run looks "worse" than the old mock did.
class OfflineResearchRepository implements ResearchRepository {
  OfflineResearchRepository({
    required LibraryRepositoryImpl library,
    required LlmService llm,
    required String model,
  })  : _library = library,
        _llm = llm,
        _model = model;

  final LibraryRepositoryImpl _library;
  final LlmService _llm;
  final String _model;

  final _runs = <String, ResearchRun>{};
  final _evidence = <String, Evidence>{};

  @override
  Future<String> startRun({
    required String question,
    required RunOptions options,
  }) async {
    final id = 'offline_${DateTime.now().millisecondsSinceEpoch}';
    _runs[id] = ResearchRun(
      id: id,
      question: question,
      status: RunStatus.queued,
      createdAt: DateTime.now(),
      options: options,
      stages: const [
        StageProgress(
            stage: RunStage.retrieving, status: StageStatus.pending),
        StageProgress(stage: RunStage.analyzing, status: StageStatus.pending),
      ],
    );
    return id;
  }

  @override
  Stream<ResearchRun> watchRun(String runId) async* {
    final initial = _runs[runId];
    if (initial == null) throw StateError('No run $runId');
    var run = initial;

    // --- Retrieve -----------------------------------------------------------
    run = _stage(run, RunStage.retrieving, StageStatus.running);
    yield run;

    final corpus = await _library.corpus();
    if (corpus.isEmpty) {
      yield _runs[runId] = run.copyWith(
        status: RunStatus.failed,
        warnings: const [
          RunWarning(
            code: 'empty_library',
            message: 'Your library has no readable papers yet. Add PDFs with '
                'a text layer, or go online to search published work.',
          ),
        ],
      );
      return;
    }

    final hits = const Bm25Retriever()
        .search(query: run.question, corpus: corpus, limit: 10);

    if (hits.isEmpty) {
      yield _runs[runId] = run.copyWith(
        status: RunStatus.partial,
        synthesis: [
          'Nothing in your library matches that question. '
              'Offline mode only searches the ${corpus.length} passages from '
              'the papers you have added — it cannot reach published work.',
        ],
        stages: run.stages
            .map((s) => s.copyWith(status: StageStatus.completed))
            .toList(),
      );
      return;
    }

    // Turn hits into evidence the UI can show, numbered as the model sees them.
    final passages = <Evidence>[];
    for (final hit in hits) {
      final paper = _library.paperFor(hit.chunk.id);
      final evidence = Evidence(
        chunkId: hit.chunk.id,
        paperId: hit.chunk.paperId,
        paperTitle: paper?.displayTitle ?? 'Your library',
        sectionTitle: hit.chunk.sectionTitle,
        pageNumber: hit.chunk.pageNumber,
        text: hit.chunk.text,
        score: hit.score,
      );
      passages.add(evidence);
      _evidence[evidence.chunkId] = evidence;
    }

    final papers = _papersFrom(passages);
    run = _stage(
      run.copyWith(papers: papers),
      RunStage.retrieving,
      StageStatus.completed,
    );
    yield _runs[runId] = run;

    // --- Answer -------------------------------------------------------------
    run = _stage(run, RunStage.analyzing, StageStatus.running);
    yield _runs[runId] = run;

    final buffer = StringBuffer();
    try {
      await for (final token in OfflinePipeline(_llm).answer(
        question: run.question,
        passages: passages,
        model: _model,
      )) {
        buffer.write(token);
        // Stream into the UI as it generates. On a local model this is the
        // difference between "working" and "frozen" — tokens arrive at
        // reading speed, not faster.
        run = run.copyWith(synthesis: [buffer.toString()]);
        yield _runs[runId] = run;
      }
    } catch (e) {
      yield _runs[runId] = run.copyWith(
        status: RunStatus.failed,
        warnings: [
          RunWarning(code: 'model_failed', message: '$e'),
        ],
      );
      return;
    }

    final answer = buffer.toString();
    run = _stage(
      run.copyWith(
        synthesis: [_renumber(answer)],
        claims: OfflinePipeline.extractClaims(answer, passages),
      ),
      RunStage.analyzing,
      StageStatus.completed,
    );

    yield _runs[runId] = run.copyWith(
      status: RunStatus.partial,
      warnings: const [
        RunWarning(
          code: 'offline',
          message: 'Offline answer from your library only. Claims are not '
              'verified against their sources.',
        ),
      ],
    );
  }

  @override
  Future<ResearchRun> getRun(String runId) async =>
      _runs[runId] ?? (throw StateError('No run $runId'));

  @override
  Future<List<ResearchRun>> history() async =>
      _runs.values.where((r) => r.isTerminal).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<Evidence?> evidenceForChunk(String chunkId) async =>
      _evidence[chunkId];

  /// One Paper per distinct source, so the Papers tab shows which of the
  /// user's documents the answer actually drew on.
  List<Paper> _papersFrom(List<Evidence> passages) {
    final byPaper = <String, List<Evidence>>{};
    for (final p in passages) {
      byPaper.putIfAbsent(p.paperId, () => []).add(p);
    }
    return byPaper.entries.map((e) {
      final first = e.value.first;
      return Paper(
        id: e.key,
        title: first.paperTitle,
        authors: const [],
        year: 0,
        venue: 'Your library',
        doi: '',
        relevance: (first.score / 20).clamp(0, 1),
        whyIncluded: '${e.value.length} matching '
            '${e.value.length == 1 ? 'passage' : 'passages'}',
      );
    }).toList();
  }

  /// The model writes `[1]`, `[2]`. The Answer tab renders `[[claimId]]`.
  static String _renumber(String answer) {
    var index = 0;
    return answer.replaceAllMapped(
      RegExp(r'\[(\d+)\]'),
      (_) => '[[offline_${++index}]]',
    );
  }

  static ResearchRun _stage(
    ResearchRun run,
    RunStage stage,
    StageStatus status,
  ) =>
      run.copyWith(
        status: RunStatus.running,
        stages: [
          for (final s in run.stages)
            if (s.stage == stage) s.copyWith(status: status) else s,
        ],
      );
}
