import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:practsearch/features/inference/data/model_download_manager.dart';
import 'package:practsearch/features/inference/domain/entities/downloadable_model.dart';

class _FakePaths extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _FakePaths(this.root);
  final String root;
  @override
  Future<String?> getApplicationSupportPath() async => root;
}

class _FakeClient extends http.BaseClient {
  _FakeClient(this.handler);
  final Future<http.StreamedResponse> Function(http.BaseRequest) handler;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest r) => handler(r);
}

/// A tiny stand-in so a test does not download 2GB.
const _model = DownloadableModel(
  id: 'test-model',
  name: 'Test',
  url: 'https://example.com/m.gguf',
  sizeBytes: 100,
  parameterCount: '1B',
  contextTokens: 2048,
  summary: 's',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('models');
    PathProviderPlatform.instance = _FakePaths(tmp.path);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  http.StreamedResponse bytes(int n, {int status = 200}) =>
      http.StreamedResponse(
        Stream.value(utf8.encode('x' * n)),
        status,
        contentLength: n,
      );

  test('a complete download lands as a real file', () async {
    final manager =
        ModelDownloadManager(client: _FakeClient((_) async => bytes(100)));

    final states = await manager.download(_model).toList();
    expect(states.last, isA<Downloaded>());
    expect((await manager.fileFor(_model)).existsSync(), isTrue);
  });

  test('a truncated download is rejected, not silently accepted', () async {
    // A short GGUF does not error — it crashes llama.cpp on load, which reads
    // as an app bug rather than a bad download.
    final manager =
        ModelDownloadManager(client: _FakeClient((_) async => bytes(40)));

    final states = await manager.download(_model).toList();
    expect(states.last, isA<DownloadFailed>());
    expect((states.last as DownloadFailed).reason, contains('cut short'));
    expect((await manager.fileFor(_model)).existsSync(), isFalse,
        reason: 'a bad file must never be presented as usable');
  });

  test('resumes from a partial file with a Range request', () async {
    final part = File('${tmp.path}/models/${_model.filename}.part')
      ..createSync(recursive: true)
      ..writeAsStringSync('x' * 60);

    String? sentRange;
    final manager = ModelDownloadManager(
      client: _FakeClient((req) async {
        sentRange = req.headers['Range'];
        return bytes(40, status: 206);
      }),
    );

    final states = await manager.download(_model).toList();
    expect(sentRange, 'bytes=60-', reason: 'only the missing bytes are asked for');
    expect(states.last, isA<Downloaded>());
    expect((await manager.fileFor(_model)).lengthSync(), 100);
    expect(part.existsSync(), isFalse);
  });

  test('restarts cleanly when the server ignores the Range header', () async {
    // Answering 200 to a Range request means "here is the whole file".
    // Appending it would produce a 160-byte corrupt model.
    File('${tmp.path}/models/${_model.filename}.part')
      ..createSync(recursive: true)
      ..writeAsStringSync('x' * 60);

    final manager =
        ModelDownloadManager(client: _FakeClient((_) async => bytes(100)));

    await manager.download(_model).toList();
    expect((await manager.fileFor(_model)).lengthSync(), 100);
  });

  test('reports a server error rather than writing a partial file', () async {
    final manager = ModelDownloadManager(
      client: _FakeClient(
        (_) async => http.StreamedResponse(const Stream.empty(), 404),
      ),
    );

    final states = await manager.download(_model).toList();
    expect(states.last, isA<DownloadFailed>());
    expect((states.last as DownloadFailed).reason, contains('404'));
  });

  test('an already-downloaded model is not fetched again', () async {
    var calls = 0;
    final manager = ModelDownloadManager(client: _FakeClient((_) async {
      calls++;
      return bytes(100);
    }));

    await manager.download(_model).toList();
    await manager.download(_model).toList();
    expect(calls, 1);
  });

  test('delete removes the file and frees the space', () async {
    final manager =
        ModelDownloadManager(client: _FakeClient((_) async => bytes(100)));

    await manager.download(_model).toList();
    expect(await manager.usedBytes(), 100);

    await manager.delete(_model);
    expect(await manager.usedBytes(), 0);
    expect(await manager.stateOf(_model), isA<NotDownloaded>());
  });

  test('the catalogue only offers models a phone can actually hold', () {
    for (final m in DownloadableModel.catalogue) {
      expect(m.sizeBytes, lessThan(3 * 1024 * 1024 * 1024));
      expect(m.url, startsWith('https://'));
      expect(m.summary, isNotEmpty);
    }
    expect(
      DownloadableModel.catalogue.where((m) => m.recommended),
      hasLength(1),
      reason: 'exactly one default, or the user has to make a choice they '
          'are not equipped to make',
    );
  });
}
