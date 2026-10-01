import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/presentation/settings_providers.dart';
import '../data/model_download_manager.dart';
import '../data/on_device_llm_service.dart';
import '../data/ollama_llm_service.dart';
import '../domain/entities/downloadable_model.dart';
import '../domain/entities/llm_model.dart';
import '../domain/repositories/llm_service.dart';

/// Live connectivity. Note this reports whether a network exists, not whether
/// the internet is actually reachable — a captive wifi portal still reports
/// connected. Good enough to pick a default, never good enough to assume.
final connectivityProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  bool online(List<ConnectivityResult> r) =>
      r.isNotEmpty && !r.contains(ConnectivityResult.none);

  yield online(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(online);
});

final ollamaServiceProvider = Provider<LlmService>((ref) {
  final host = ref.watch(settingsProvider.select((s) => s.ollamaUrl));
  return OllamaLlmService(baseUrl: host);
});

final modelDownloadsProvider = Provider((ref) => ModelDownloadManager());

final onDeviceServiceProvider = Provider<OnDeviceLlmService>((ref) {
  final service = OnDeviceLlmService(ref.watch(modelDownloadsProvider));
  // A loaded model holds ~2GB resident. Dropping it when nothing is watching
  // is the difference between a backgrounded app surviving and being killed.
  ref.onDispose(service.release);
  return service;
});

/// Per-model state: not downloaded, downloading, ready, or failed.
final modelStateProvider =
    FutureProvider.autoDispose.family<ModelState, DownloadableModel>(
  (ref, model) => ref.watch(modelDownloadsProvider).stateOf(model),
);

final installedModelsProvider = FutureProvider<List<DownloadableModel>>(
  (ref) => ref.watch(modelDownloadsProvider).installed(),
);

final modelStorageProvider = FutureProvider<int>(
  (ref) => ref.watch(modelDownloadsProvider).usedBytes(),
);

/// Probes the local backend. Autodisposed and re-run when the address changes,
/// so editing it in Settings re-tests immediately instead of leaving a stale
/// "unreachable" on screen.
final backendStatusProvider = FutureProvider.autoDispose<BackendStatus>(
  (ref) {
    final backend = ref.watch(settingsProvider.select((s) => s.backend));
    return switch (backend) {
      InferenceBackend.onDevice => ref.watch(onDeviceServiceProvider).status(),
      _ => ref.watch(ollamaServiceProvider).status(),
    };
  },
);

/// The service a run will actually use.
final activeLlmProvider = Provider<LlmService>((ref) {
  final backend = ref.watch(effectiveBackendProvider);
  return switch (backend) {
    InferenceBackend.onDevice => ref.watch(onDeviceServiceProvider),
    _ => ref.watch(ollamaServiceProvider),
  };
});

/// The backend a run will actually use.
///
/// The user's preference is a *preference*: if they chose cloud and the
/// network is gone, the app falls back rather than failing. The UI always
/// states which backend was used, so a fallback is never silent.
final effectiveBackendProvider = Provider<InferenceBackend>((ref) {
  final preferred = ref.watch(settingsProvider.select((s) => s.backend));
  final online = ref.watch(connectivityProvider).valueOrNull ?? true;

  if (preferred.needsInternet && !online) return InferenceBackend.ollama;
  return preferred;
});

/// Whether the app is in a state where a cloud run can succeed at all.
final canRunOnlineProvider = Provider<bool>(
  (ref) => ref.watch(connectivityProvider).valueOrNull ?? true,
);
