import '../../domain/entities/claim.dart';
import '../../domain/entities/gap.dart';
import '../../domain/entities/research_run.dart';
import '../../domain/entities/run_stage.dart';
import 'paper_model.dart';

ResearchRun runFromJson(Map<String, dynamic> json) => ResearchRun(
      id: json['id'] as String,
      question: json['question'] as String,
      status: _status(json['status'] as String?),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
              DateTime.now(),
      stages: ((json['stages'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(_stage)
          .toList(),
      papers: ((json['papers'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map((p) => p.toPaper())
          .toList(),
      synthesis: ((json['synthesis'] as List?) ?? const []).cast<String>(),
      claims: ((json['claims'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(_claim)
          .toList(),
      gaps: ((json['gaps'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(_gap)
          .toList(),
      warnings: ((json['warnings'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map((w) => RunWarning(
                code: w['code'] as String? ?? 'unknown',
                message: w['detail'] as String? ?? '',
              ))
          .toList(),
    );

RunStatus _status(String? raw) => switch (raw) {
      'queued' => RunStatus.queued,
      'completed' => RunStatus.completed,
      'partial' => RunStatus.partial,
      'failed' => RunStatus.failed,
      _ => RunStatus.running,
    };

StageProgress _stage(Map<String, dynamic> j) => StageProgress(
      stage: RunStage.values.firstWhere(
        (s) => s.name == j['stage'],
        orElse: () => RunStage.planning,
      ),
      status: switch (j['status'] as String?) {
        'started' || 'running' => StageStatus.running,
        'completed' => StageStatus.completed,
        'failed' => StageStatus.failed,
        _ => StageStatus.pending,
      },
      done: j['done'] as int?,
      total: j['total'] as int?,
      durationMs: j['durationMs'] as int?,
    );

Claim _claim(Map<String, dynamic> j) => Claim(
      id: j['claimId'] as String,
      text: j['text'] as String? ?? '',
      chunkId: j['chunkId'] as String? ?? '',
      status: switch (j['status'] as String?) {
        'partially_supported' => VerificationStatus.partiallySupported,
        'contradicted' => VerificationStatus.contradicted,
        'not_found' => VerificationStatus.notFound,
        _ => VerificationStatus.supported,
      },
      note: j['note'] as String? ?? '',
      index: j['index'] as int? ?? 0,
    );

Gap _gap(Map<String, dynamic> j) => Gap(
      id: j['id'] as String,
      kind: GapKind.values.firstWhere(
        (k) => k.name == j['kind'],
        orElse: () => GapKind.uncoveredCombination,
      ),
      statement: j['statement'] as String? ?? '',
      evidence: j['evidence'] as String? ?? '',
      confidence: (j['confidence'] as num?)?.toDouble() ?? 0,
      relatedPaperIds:
          ((j['relatedPaperIds'] as List?) ?? const []).cast<String>(),
    );
