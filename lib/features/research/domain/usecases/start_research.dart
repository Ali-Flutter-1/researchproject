import '../entities/research_run.dart';
import '../repositories/research_repository.dart';

/// Starts a run and returns its id. Validation lives here, not in the widget:
/// a question too short to retrieve against should never reach the network.
class StartResearch {
  const StartResearch(this._repository);
  final ResearchRepository _repository;

  static const minQuestionLength = 15;

  Future<String> call({
    required String question,
    RunOptions options = const RunOptions(),
  }) {
    final trimmed = question.trim();
    if (trimmed.length < minQuestionLength) {
      throw const ShortQuestionFailure();
    }
    return _repository.startRun(question: trimmed, options: options);
  }
}

class ShortQuestionFailure implements Exception {
  const ShortQuestionFailure();
  String get message =>
      'Ask a fuller question — a few words will not retrieve well.';
}
