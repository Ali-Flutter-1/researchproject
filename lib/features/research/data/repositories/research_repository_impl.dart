import '../../domain/entities/claim.dart';
import '../../domain/entities/research_run.dart';
import '../../domain/repositories/research_repository.dart';
import '../datasources/mock_research_data_source.dart';

/// Backed by the mock today. When the ASP.NET API lands, this class gains an
/// HTTP data source and everything above the repository boundary is untouched.
class ResearchRepositoryImpl implements ResearchRepository {
  ResearchRepositoryImpl(this._remote);
  final MockResearchDataSource _remote;

  @override
  Future<String> startRun({
    required String question,
    required RunOptions options,
  }) =>
      _remote.startRun(question: question, options: options);

  @override
  Stream<ResearchRun> watchRun(String runId) => _remote.watchRun(runId);

  @override
  Future<ResearchRun> getRun(String runId) => _remote.getRun(runId);

  @override
  Future<List<ResearchRun>> history() => _remote.history();

  @override
  Future<Evidence?> evidenceForChunk(String chunkId) =>
      _remote.evidenceForChunk(chunkId);
}
