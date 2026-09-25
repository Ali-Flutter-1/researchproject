import '../entities/research_run.dart';
import '../repositories/research_repository.dart';

class WatchRun {
  const WatchRun(this._repository);
  final ResearchRepository _repository;

  Stream<ResearchRun> call(String runId) => _repository.watchRun(runId);
}

class GetRun {
  const GetRun(this._repository);
  final ResearchRepository _repository;

  Future<ResearchRun> call(String runId) => _repository.getRun(runId);
}

class GetHistory {
  const GetHistory(this._repository);
  final ResearchRepository _repository;

  Future<List<ResearchRun>> call() => _repository.history();
}
