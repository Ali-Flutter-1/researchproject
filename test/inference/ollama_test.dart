import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:practsearch/features/inference/data/ollama_llm_service.dart';
import 'package:practsearch/features/inference/domain/entities/llm_model.dart';

/// Serves canned responses so the client's parsing is tested without a server.
class _FakeClient extends http.BaseClient {
  _FakeClient(this.handler);
  final Future<http.StreamedResponse> Function(http.BaseRequest) handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);
}

http.StreamedResponse _json(Object body, {int status = 200}) =>
    http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      status,
    );

void main() {
  group('status', () {
    test('lists installed models', () async {
      final service = OllamaLlmService(
        baseUrl: 'http://x:11434',
        client: _FakeClient((_) async => _json({
              'models': [
                {
                  'name': 'llama3.2:3b',
                  'size': 2019393189,
                  'details': {'parameter_size': '3.2B'},
                },
              ],
            })),
      );

      final status = await service.status();
      expect(status, isA<BackendReady>());
      final model = (status as BackendReady).models.single;
      expect(model.name, 'llama3.2:3b');
      expect(model.parameterCount, '3.2B');
      expect(model.sizeLabel, '1.9 GB');
    });

    test('names the localhost-binding trap when it cannot connect', () async {
      final service = OllamaLlmService(
        baseUrl: 'http://x:11434',
        client: _FakeClient((_) async => throw const SocketFailure()),
      );

      final status = await service.status();
      expect(status, isA<BackendUnreachable>());
      // This is THE reason local models appear broken to most people: Ollama
      // binds 127.0.0.1, so a phone on the same wifi cannot reach it.
      expect((status as BackendUnreachable).hint, contains('OLLAMA_HOST'));
    });

    test('distinguishes "connected but empty" from "unreachable"', () async {
      final service = OllamaLlmService(
        baseUrl: 'http://x:11434',
        client: _FakeClient((_) async => _json({'models': []})),
      );

      final status = await service.status();
      expect(status, isA<BackendUnreachable>());
      expect((status as BackendUnreachable).hint, contains('ollama pull'));
    });
  });

  group('generate', () {
    test('reassembles tokens from the newline-delimited stream', () async {
      final chunks = [
        '{"message":{"content":"A transformer "},"done":false}',
        '{"message":{"content":"uses self-attention."},"done":false}',
        '{"done":true}',
      ];
      final service = OllamaLlmService(
        baseUrl: 'http://x:11434',
        client: _FakeClient((_) async => http.StreamedResponse(
              Stream.fromIterable(
                chunks.map((c) => utf8.encode('$c\n')).toList(),
              ),
              200,
            )),
      );

      final out = await service
          .generate(
            systemPrompt: 's',
            userPrompt: 'u',
            model: 'llama3.2',
          )
          .join();
      expect(out, 'A transformer uses self-attention.');
    });

    test('survives a malformed line mid-stream', () async {
      // Chunk boundaries genuinely split JSON objects in the wild. Dropping
      // the whole generation over one bad line would be the wrong trade.
      final service = OllamaLlmService(
        baseUrl: 'http://x:11434',
        client: _FakeClient((_) async => http.StreamedResponse(
              Stream.fromIterable([
                utf8.encode('{"message":{"content":"good "},"done":false}\n'),
                utf8.encode('{"message":{"cont\n'),
                utf8.encode('{"message":{"content":"text"},"done":false}\n'),
                utf8.encode('{"done":true}\n'),
              ]),
              200,
            )),
      );

      expect(
        await service
            .generate(systemPrompt: 's', userPrompt: 'u', model: 'm')
            .join(),
        'good text',
      );
    });

    test('stops at the done marker', () async {
      final service = OllamaLlmService(
        baseUrl: 'http://x:11434',
        client: _FakeClient((_) async => http.StreamedResponse(
              Stream.fromIterable([
                utf8.encode('{"message":{"content":"one"},"done":false}\n'),
                utf8.encode('{"done":true}\n'),
                utf8.encode('{"message":{"content":" two"},"done":false}\n'),
              ]),
              200,
            )),
      );

      expect(
        await service
            .generate(systemPrompt: 's', userPrompt: 'u', model: 'm')
            .join(),
        'one',
      );
    });

    test('throws on a non-200 rather than yielding nothing', () async {
      final service = OllamaLlmService(
        baseUrl: 'http://x:11434',
        client: _FakeClient(
          (_) async => http.StreamedResponse(const Stream.empty(), 404),
        ),
      );

      expect(
        () => service
            .generate(systemPrompt: 's', userPrompt: 'u', model: 'missing')
            .join(),
        throwsA(isA<LlmFailure>()),
      );
    });
  });

  test('embed returns one vector per input', () async {
    final service = OllamaLlmService(
      baseUrl: 'http://x:11434',
      client: _FakeClient((_) async => _json({
            'embeddings': [
              [0.1, 0.2],
              [0.3, 0.4],
            ],
          })),
    );

    final vectors =
        await service.embed(texts: ['a', 'b'], model: 'nomic-embed-text');
    expect(vectors, hasLength(2));
    expect(vectors.first, [0.1, 0.2]);
  });
}

class SocketFailure implements Exception {
  const SocketFailure();
}
