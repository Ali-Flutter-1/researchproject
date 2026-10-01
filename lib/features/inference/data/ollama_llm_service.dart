import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/entities/llm_model.dart';
import '../domain/repositories/llm_service.dart';

/// Talks to an Ollama server over its REST API.
///
/// Ollama binds to 127.0.0.1 by default, which means a phone on the same wifi
/// cannot reach it. The user has to start it with OLLAMA_HOST=0.0.0.0 — the
/// single most common reason this appears broken, so [status] says so by name
/// rather than reporting a bare connection error.
class OllamaLlmService implements LlmService {
  OllamaLlmService({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  /// e.g. http://192.168.1.14:11434
  final String baseUrl;
  final http.Client _client;

  @override
  InferenceBackend get backend => InferenceBackend.ollama;

  static const _probeTimeout = Duration(seconds: 4);

  @override
  Future<BackendStatus> status() async {
    try {
      final res = await _client
          .get(Uri.parse('$baseUrl/api/tags'))
          .timeout(_probeTimeout);

      if (res.statusCode != 200) {
        return BackendUnreachable(
          'Server answered with ${res.statusCode}.',
          hint: 'Check the address in Settings.',
        );
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final models = ((body['models'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(_toModel)
          .toList();

      if (models.isEmpty) {
        return const BackendUnreachable(
          'Connected, but no models are installed.',
          hint: 'Run "ollama pull llama3.2" on your computer.',
        );
      }
      return BackendReady(models);
    } catch (e) {
      return BackendUnreachable(
        'Could not reach $baseUrl.',
        hint: 'Ollama only listens on localhost unless you start it with '
            'OLLAMA_HOST=0.0.0.0 ollama serve. Also check both devices are '
            'on the same network.',
      );
    }
  }

  @override
  Stream<String> generate({
    required String systemPrompt,
    required String userPrompt,
    required String model,
    double temperature = 0.2,
    int? maxTokens,
  }) async* {
    final request = http.Request('POST', Uri.parse('$baseUrl/api/chat'))
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({
        'model': model,
        'stream': true,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
        'options': {
          'temperature': temperature,
          'num_predict': ?maxTokens,
        },
      });

    final response = await _client.send(request);
    if (response.statusCode != 200) {
      throw LlmFailure('Ollama returned ${response.statusCode}.');
    }

    // Ollama streams newline-delimited JSON, one object per token batch.
    await for (final line in response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (line.trim().isEmpty) continue;
      try {
        final chunk = jsonDecode(line) as Map<String, dynamic>;
        final content = chunk['message']?['content'] as String?;
        if (content != null && content.isNotEmpty) yield content;
        if (chunk['done'] == true) return;
      } catch (_) {
        // A partial line at a chunk boundary is normal; skip it rather than
        // failing the whole generation.
        continue;
      }
    }
  }

  @override
  Future<List<List<double>>> embed({
    required List<String> texts,
    required String model,
  }) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/api/embed'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'model': model, 'input': texts}),
    );
    if (res.statusCode != 200) {
      throw LlmFailure('Embedding failed with ${res.statusCode}.');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return ((body['embeddings'] as List?) ?? const [])
        .map((e) => (e as List).cast<num>().map((n) => n.toDouble()).toList())
        .toList();
  }

  static LlmModel _toModel(Map<String, dynamic> j) {
    final details = j['details'] as Map<String, dynamic>?;
    return LlmModel(
      id: j['name'] as String,
      name: j['name'] as String,
      parameterCount: details?['parameter_size'] as String?,
      sizeBytes: (j['size'] as num?)?.toInt(),
    );
  }
}

class LlmFailure implements Exception {
  const LlmFailure(this.message);
  final String message;
  @override
  String toString() => message;
}
