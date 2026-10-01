import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../domain/entities/downloadable_model.dart';

/// Downloads and manages on-device model files.
///
/// Three properties matter more than speed here:
///
/// 1. **Resumable.** A 2GB download over mobile wifi will be interrupted.
///    Starting from zero each time makes the feature unusable, so this uses
///    HTTP Range requests against a partial file.
/// 2. **Verifiable.** A truncated GGUF does not error — it crashes llama.cpp
///    on load, which looks like an app bug. The size is checked before the
///    file is accepted.
/// 3. **Deletable.** Whatever the app downloads, the user can remove.
class ModelDownloadManager {
  ModelDownloadManager({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;
  final _controllers = <String, StreamController<ModelState>>{};
  final _cancelled = <String>{};

  Future<Directory> _dir() async {
    final docs = await getApplicationSupportDirectory();
    final dir = Directory('${docs.path}/models');
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> fileFor(DownloadableModel model) async =>
      File('${(await _dir()).path}/${model.filename}');

  Future<File> _partFor(DownloadableModel model) async =>
      File('${(await _dir()).path}/${model.filename}.part');

  /// Current state without starting anything.
  Future<ModelState> stateOf(DownloadableModel model) async {
    final file = await fileFor(model);
    if (file.existsSync()) {
      return Downloaded(file.path, file.lengthSync());
    }
    final part = await _partFor(model);
    if (part.existsSync()) {
      return Downloading(received: part.lengthSync(), total: model.sizeBytes);
    }
    return const NotDownloaded();
  }

  Future<List<DownloadableModel>> installed() async {
    final out = <DownloadableModel>[];
    for (final m in DownloadableModel.catalogue) {
      if ((await fileFor(m)).existsSync()) out.add(m);
    }
    return out;
  }

  Future<int> usedBytes() async {
    final dir = await _dir();
    var total = 0;
    await for (final e in dir.list()) {
      if (e is File) total += e.lengthSync();
    }
    return total;
  }

  Future<void> delete(DownloadableModel model) async {
    for (final f in [await fileFor(model), await _partFor(model)]) {
      if (f.existsSync()) await f.delete();
    }
  }

  void cancel(DownloadableModel model) => _cancelled.add(model.id);

  /// Streams progress. Resumes from a partial file when one exists.
  Stream<ModelState> download(DownloadableModel model) {
    final existing = _controllers[model.id];
    if (existing != null) return existing.stream;

    final controller = StreamController<ModelState>.broadcast(
      onCancel: () => _controllers.remove(model.id),
    );
    _controllers[model.id] = controller;
    _cancelled.remove(model.id);
    unawaited(_run(model, controller));
    return controller.stream;
  }

  Future<void> _run(
    DownloadableModel model,
    StreamController<ModelState> out,
  ) async {
    IOSink? sink;
    try {
      final target = await fileFor(model);
      if (target.existsSync()) {
        out.add(Downloaded(target.path, target.lengthSync()));
        return;
      }

      final part = await _partFor(model);
      var received = part.existsSync() ? part.lengthSync() : 0;

      final request = http.Request('GET', Uri.parse(model.url));
      // Ask only for the bytes we are missing.
      if (received > 0) request.headers['Range'] = 'bytes=$received-';

      final response = await _client.send(request);

      // 200 to a Range request means the server ignored it: start over rather
      // than appending a second full copy onto the partial file.
      if (received > 0 && response.statusCode == 200) {
        if (part.existsSync()) await part.delete();
        received = 0;
      } else if (response.statusCode != 200 && response.statusCode != 206) {
        out.add(DownloadFailed('Server returned ${response.statusCode}.'));
        return;
      }

      final total = received + (response.contentLength ?? model.sizeBytes);
      final writer = part.openWrite(mode: FileMode.append);
      sink = writer;
      out.add(Downloading(received: received, total: total));

      var lastEmit = DateTime.now();
      await for (final chunk in response.stream) {
        if (_cancelled.contains(model.id)) {
          await writer.close();
          sink = null;
          // The partial file is kept deliberately — cancelling should not
          // throw away 1.4GB the user already paid for.
          out.add(const NotDownloaded());
          return;
        }
        writer.add(chunk);
        received += chunk.length;

        // Emitting per chunk would rebuild the UI thousands of times a second.
        final now = DateTime.now();
        if (now.difference(lastEmit).inMilliseconds > 250) {
          lastEmit = now;
          out.add(Downloading(received: received, total: total));
        }
      }

      await writer.flush();
      await writer.close();
      sink = null;

      // A truncated GGUF crashes llama.cpp on load, which reads as an app
      // bug rather than a bad download. Catch it here instead.
      final downloaded = part.lengthSync();
      if (downloaded < model.sizeBytes * 0.95) {
        out.add(DownloadFailed(
          'Download was cut short (${downloaded ~/ (1024 * 1024)} MB of '
          '${model.sizeBytes ~/ (1024 * 1024)} MB). Tap to resume.',
        ));
        return;
      }

      await part.rename(target.path);
      out.add(Downloaded(target.path, downloaded));
    } catch (e) {
      await sink?.close();
      out.add(DownloadFailed('$e'));
    } finally {
      await out.close();
      _controllers.remove(model.id);
    }
  }
}
