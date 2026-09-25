import 'package:equatable/equatable.dart';

enum GapKind {
  uncoveredCombination,
  singleSourceMetric,
  unaddressedLimitation,
  citationLeaf;

  String get label => switch (this) {
        uncoveredCombination => 'Untested combination',
        singleSourceMetric => 'Single-source metric',
        unaddressedLimitation => 'Unaddressed limitation',
        citationLeaf => 'Unfollowed work',
      };
}

/// A gap is enumerated in code and written up by the model (ADR / Gap Agent).
/// [evidence] carries the arithmetic that produced it — a gap without its
/// counting is just an opinion.
class Gap extends Equatable {
  const Gap({
    required this.id,
    required this.kind,
    required this.statement,
    required this.evidence,
    this.confidence = 0,
    this.relatedPaperIds = const [],
  });

  final String id;
  final GapKind kind;
  final String statement;
  final String evidence;
  final double confidence;
  final List<String> relatedPaperIds;

  @override
  List<Object?> get props => [id];
}
