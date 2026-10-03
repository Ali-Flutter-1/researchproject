import 'dart:async';

import 'package:fllama/fllama.dart';
import 'package:fllama/fllama_type.dart';

import '../domain/entities/downloadable_model.dart';
import '../domain/entities/llm_model.dart';
import '../domain/repositories/llm_service.dart';
import 'model_download_manager.dart';

/// Runs a GGUF model inside the app via llama.cpp.
///
/// Truly offline — no server, no network, works on a plane. The cost is speed
/// (roughly 5–15 tokens/second on a modern phone) and quality: a 3B model is
/// a long way below Claude at anything requiring cross-document reasoning,
/// which is why offline mode runs the shorter pipeline.
///
/// The llama.cpp context is expensive to create (seconds, and ~2GB resident),
/// so it is created once and reused. It is released when the app no longer
/// needs it — holding 2GB after the user leaves offline mode is how an app
/// gets killed in the background.
class OnDeviceLlmService implements LlmService {
  OnDeviceLlmService(this._downloads);

  final ModelDownloadManager _downloads;

  double? _contextId;
  String? _loadedModelId;
  Completer<void>? _loading;

  @override
  InferenceBackend get backend => InferenceBackend.onDevice;

  @override
  Future<BackendStatus> status() async {
    final installed = await _downloads.installed();
    if (installed.isEmpty) {
      return const BackendUnreachable(
        'No model downloaded yet.',
        hint: 'Download one in Settings. Expect about 2 GB — use wifi.',
      );
    }
    return BackendReady([
      for (final m in installed)
        LlmModel(
          id: m.id,
          name: m.name,
          parameterCount: m.parameterCount,
          sizeBytes: m.sizeBytes,
          contextTokens: m.contextTokens,
        ),
    ]);
  }

  @override
  Stream<String> generate({
    required String systemPrompt,
    required String userPrompt,
    required String model,
    double temperature = 0.2,
    int? maxTokens,
  }) async* {
    final spec = DownloadableModel.byId(model);
    if (spec == null) {
      throw OnDeviceFailure('Unknown model "$model".');
    }

    await _ensureLoaded(spec);
    final contextId = _contextId;
    if (contextId == null) {
      throw const OnDeviceFailure('Model failed to load.');
    }

    final fllama = Fllama.instance()!;

    // Each model has its own chat template baked into the GGUF. Using the
    // model's own template matters — a mismatched one degrades output badly
    // while still producing plausible-looking text, so it fails silently.
    final prompt = await fllama.getFormattedChat(
      contextId,
      messages: [
        RoleContent(role: 'system', content: systemPrompt),
        RoleContent(role: 'user', content: userPrompt),
      ],
    );

    final tokens = StreamController<String>();
    late final StreamSubscription<Map<Object?, dynamic>> sub;

    sub = fllama.onTokenStream!.listen((event) {
      final token = event['token'] as String?;
      if (token != null && token.isNotEmpty) tokens.add(token);
    });

    unawaited(
      fllama
          .completion(
            contextId,
            prompt: prompt ?? userPrompt,
            temperature: temperature,
            nPredict: maxTokens ?? 1024,
            emitRealtimeCompletion: true,
          )
          .then((_) => tokens.close())
          .catchError((Object e) {
            tokens.addError(OnDeviceFailure('$e'));
            tokens.close();
          }),
    );

    try {
      yield* tokens.stream;
    } finally {
      await sub.cancel();
    }
  }

  /// Loads the model, reusing the context when the same model is already in
  /// memory. Concurrent callers wait on the same load rather than each paying
  /// the multi-second cost.
  Future<void> _ensureLoaded(DownloadableModel spec) async {
    if (_loadedModelId == spec.id && _contextId != null) return;
    if (_loading != null) return _loading!.future;

    final completer = Completer<void>();
    _loading = completer;
    try {
      await release();

      final file = await _downloads.fileFor(spec);
      if (!file.existsSync()) {
        throw OnDeviceFailure('${spec.name} is not downloaded.');
      }

      final fllama = Fllama.instance()!;
      final result = await fllama.initContext(
        file.path,
        // Capped well below the model's maximum: context memory grows with
        // this number and the OS will kill the app before llama.cpp complains.
        nCtx: spec.contextTokens.clamp(512, 2048),
        // CPU only. Offloading to Metal crashes this fllama build on older
        // A-series chips: llama.cpp reports "device Metal does not support
        // async, host buffers or events" and then dies with EXC_BAD_ACCESS
        // inside load_all_data. Verified on an iPhone 11 (A13) loading
        // Llama 3.2 1B Q4 — it offloads 17/17 layers, then segfaults.
        //
        // CPU inference on a 1B Q4 is a few tokens per second, which is slow
        // but works. A crash is not a tradeoff worth making for speed.
        nGpuLayers: 0,
        useMmap: true,
        // mlock pins the model in physical memory. On a 4GB phone that
        // invites the OS to kill the app outright rather than page.
        useMlock: false,
      );

      _contextId = (result?['contextId'] as num?)?.toDouble();
      if (_contextId == null) {
        throw const OnDeviceFailure('llama.cpp did not return a context.');
      }
      _loadedModelId = spec.id;
      completer.complete();
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      _loading = null;
    }
  }

  /// Frees the ~2GB the model holds. Call when leaving offline mode.
  Future<void> release() async {
    final id = _contextId;
    if (id == null) return;
    _contextId = null;
    _loadedModelId = null;
    try {
      await Fllama.instance()!.releaseContext(id);
    } catch (_) {
      // Releasing an already-dead context is not worth surfacing.
    }
  }

  @override
  Future<List<List<double>>> embed({
    required List<String> texts,
    required String model,
  }) async =>
      // llama.cpp can embed, but it needs a context opened in embedding mode,
      // which cannot share the generation context. Retrieval uses a dedicated
      // small embedding model instead — see the ONNX path.
      throw const OnDeviceFailure(
        'Embeddings do not run through the generation context.',
      );
}

class OnDeviceFailure implements Exception {
  const OnDeviceFailure(this.message);
  final String message;
  @override
  String toString() => message;
}
