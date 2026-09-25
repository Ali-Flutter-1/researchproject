import '../entities/claim.dart';
import '../entities/research_run.dart';

/// The contract the presentation layer depends on. The mock data source and
/// the real ASP.NET client both satisfy it, so swapping them touches nothing
/// above this line.
abstract interface class ResearchRepository {
  /// POST /api/research -> runId
  Future<String> startRun({
    required String question,
    required RunOptions options,
  });

  /// GET /api/research/{id}/stream — server-sent events.
  /// Emits the run after every stage transition, so the UI can show papers
  /// as they land rather than waiting for the whole pipeline.
  Stream<ResearchRun> watchRun(String runId);

  /// GET /api/research/{id}
  Future<ResearchRun> getRun(String runId);

  /// Past runs, newest first.
  Future<List<ResearchRun>> history();

  /// The passage behind a claim or extracted fact.
  Future<Evidence?> evidenceForChunk(String chunkId);
}
