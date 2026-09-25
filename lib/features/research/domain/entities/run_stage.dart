/// The fixed pipeline stages. Order is known at design time (ADR-009),
/// so this is an enum, not data returned by the server.
enum RunStage {
  planning('Planning'),
  searching('Searching papers'),
  ingesting('Reading papers'),
  retrieving('Retrieving evidence'),
  analyzing('Analysing'),
  verifying('Verifying citations'),
  gapAnalysis('Finding gaps');

  const RunStage(this.label);
  final String label;
}

enum StageStatus { pending, running, completed, failed }

/// Terminal outcomes. [partial] is a first-class result, not an error:
/// 17 of 20 papers is a useful answer.
enum RunStatus { queued, running, completed, partial, failed }

class StageProgress {
  const StageProgress({
    required this.stage,
    required this.status,
    this.done,
    this.total,
    this.durationMs,
  });

  final RunStage stage;
  final StageStatus status;
  final int? done;
  final int? total;
  final int? durationMs;

  bool get hasCounter => done != null && total != null;
  double? get fraction =>
      hasCounter && total! > 0 ? done! / total! : null;

  StageProgress copyWith({
    StageStatus? status,
    int? done,
    int? total,
    int? durationMs,
  }) =>
      StageProgress(
        stage: stage,
        status: status ?? this.status,
        done: done ?? this.done,
        total: total ?? this.total,
        durationMs: durationMs ?? this.durationMs,
      );
}
