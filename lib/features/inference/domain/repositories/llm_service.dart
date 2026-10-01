import '../entities/llm_model.dart';

/// One interface over every backend, so the research pipeline never knows
/// whether it is talking to Claude, to a laptop, or to a model inside the app.
abstract interface class LlmService {
  InferenceBackend get backend;

  /// Is this backend usable right now, and what can it run?
  Future<BackendStatus> status();

  /// Streams tokens as they are produced. Local models are slow enough that
  /// waiting for a complete response feels broken — the stream is not a
  /// nicety here, it is what makes a 3B model tolerable.
  Stream<String> generate({
    required String systemPrompt,
    required String userPrompt,
    required String model,
    double temperature = 0.2,
    int? maxTokens,
  });

  /// Embeddings for retrieval. Separate from generation because the two can
  /// legitimately run on different backends — local embeddings with cloud
  /// reasoning is the configuration that makes the most sense of all.
  Future<List<List<double>>> embed({
    required List<String> texts,
    required String model,
  });
}
