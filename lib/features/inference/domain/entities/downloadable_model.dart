import 'package:equatable/equatable.dart';

/// A model the app can download and run on-device.
///
/// Sizes are real. A 2GB download is a product moment, not a detail: it has to
/// be opt-in, wifi-aware, resumable and deletable, or users will uninstall the
/// app the first time it eats their data plan.
class DownloadableModel extends Equatable {
  const DownloadableModel({
    required this.id,
    required this.name,
    required this.url,
    required this.sizeBytes,
    required this.parameterCount,
    required this.contextTokens,
    required this.summary,
    this.recommended = false,
    this.minimumRamMb = 4096,
  });

  final String id;
  final String name;
  final String url;
  final int sizeBytes;
  final String parameterCount;
  final int contextTokens;
  final String summary;
  final bool recommended;

  /// Below this, the model will be killed by the OS mid-generation rather
  /// than running slowly. Worth checking before a 2GB download, not after.
  final int minimumRamMb;

  String get sizeLabel =>
      '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';

  String get filename => '$id.gguf';

  @override
  List<Object?> get props => [id];

  /// The catalogue. Deliberately short — three good choices beat twenty, and
  /// every extra option is a decision the user is not equipped to make.
  static const catalogue = <DownloadableModel>[
    DownloadableModel(
      id: 'qwen2.5-3b-instruct-q4',
      name: 'Qwen 2.5 3B',
      url: 'https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/'
          'qwen2.5-3b-instruct-q4_k_m.gguf',
      sizeBytes: 2100000000,
      parameterCount: '3B',
      contextTokens: 32768,
      summary: 'Better answers, but needs 6GB+ of RAM. On a 4GB phone iOS '
          'will kill the app mid-answer.',
      minimumRamMb: 6144,
    ),
    DownloadableModel(
      id: 'llama-3.2-1b-instruct-q4',
      name: 'Llama 3.2 1B',
      url: 'https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/'
          'resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf',
      sizeBytes: 808000000,
      parameterCount: '1B',
      contextTokens: 8192,
      summary: 'Runs on any phone. Answers are shorter and miss nuance, but '
          'it finishes — which the larger models will not on 4GB devices.',
      recommended: true,
      minimumRamMb: 2048,
    ),
    DownloadableModel(
      id: 'llama-3.2-3b-instruct-q4',
      name: 'Llama 3.2 3B',
      url: 'https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/'
          'resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf',
      sizeBytes: 2020000000,
      parameterCount: '3B',
      contextTokens: 8192,
      summary: 'Strong general comprehension, shorter context than Qwen.',
      minimumRamMb: 4096,
    ),
  ];

  static DownloadableModel? byId(String id) =>
      catalogue.where((m) => m.id == id).firstOrNull;
}

/// Where a model is in its lifecycle.
sealed class ModelState {
  const ModelState();
}

class NotDownloaded extends ModelState {
  const NotDownloaded();
}

class Downloading extends ModelState {
  const Downloading({required this.received, required this.total});
  final int received;
  final int total;

  double get fraction => total > 0 ? received / total : 0;
  String get label =>
      '${(received / (1024 * 1024)).toStringAsFixed(0)} MB '
      'of ${(total / (1024 * 1024)).toStringAsFixed(0)} MB';
}

class Downloaded extends ModelState {
  const Downloaded(this.path, this.sizeBytes);
  final String path;
  final int sizeBytes;
}

class DownloadFailed extends ModelState {
  const DownloadFailed(this.reason, {this.resumable = true});
  final String reason;
  final bool resumable;
}
