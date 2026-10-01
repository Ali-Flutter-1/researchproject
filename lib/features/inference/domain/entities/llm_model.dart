import 'package:equatable/equatable.dart';

/// Where inference happens for a given request.
enum InferenceBackend {
  /// Claude via the ASP.NET API. Full agent pipeline, needs internet.
  cloud('Cloud', 'Full pipeline — searches the web, compares papers, verifies '
      'every claim'),

  /// An Ollama server reachable over the network — typically the user's own
  /// laptop. No internet needed, but the laptop must be on and reachable.
  ollama('Local server (Ollama)', 'Runs on your computer. No internet needed, '
      'but your computer must be awake and on the same network'),

  /// A quantised model inside the app. Works on a plane.
  onDevice('On this device', 'Fully offline. Smaller model, so answers are '
      'shorter and less reliable');

  const InferenceBackend(this.label, this.description);
  final String label;
  final String description;

  bool get needsInternet => this == cloud;
  bool get isLocal => this != cloud;
}

/// A model offered by whichever backend is selected.
class LlmModel extends Equatable {
  const LlmModel({
    required this.id,
    required this.name,
    this.parameterCount,
    this.sizeBytes,
    this.contextTokens,
    this.installed = true,
  });

  final String id;
  final String name;

  /// e.g. "3B", "8B". Shown because it is the single best predictor of how
  /// good the answers will be, and users deserve to know before choosing.
  final String? parameterCount;

  final int? sizeBytes;
  final int? contextTokens;
  final bool installed;

  String get sizeLabel {
    if (sizeBytes == null) return '';
    final gb = sizeBytes! / (1024 * 1024 * 1024);
    return gb >= 1
        ? '${gb.toStringAsFixed(1)} GB'
        : '${(sizeBytes! / (1024 * 1024)).toStringAsFixed(0)} MB';
  }

  @override
  List<Object?> get props => [id];
}

/// Whether a local backend is actually usable right now.
sealed class BackendStatus {
  const BackendStatus();
}

class BackendReady extends BackendStatus {
  const BackendReady(this.models, {this.version});
  final List<LlmModel> models;
  final String? version;
}

class BackendUnreachable extends BackendStatus {
  const BackendUnreachable(this.reason, {this.hint});
  final String reason;

  /// What the user can actually do about it. An error without a next step
  /// is just a dead end.
  final String? hint;
}

class BackendChecking extends BackendStatus {
  const BackendChecking();
}
