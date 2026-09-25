import 'package:equatable/equatable.dart';

/// Outcome of the citation-verification stage (ADR-012).
/// Anything other than [supported] is surfaced, never hidden.
enum VerificationStatus {
  supported,
  partiallySupported,
  contradicted,
  notFound;

  bool get needsAttention => this != VerificationStatus.supported;

  String get label => switch (this) {
        supported => 'Supported',
        partiallySupported => 'Partially supported',
        contradicted => 'Contradicted',
        notFound => 'Source not found',
      };
}

/// A passage retrieved from a paper, with enough provenance to show the user
/// exactly where a claim came from.
class Evidence extends Equatable {
  const Evidence({
    required this.chunkId,
    required this.paperId,
    required this.paperTitle,
    required this.sectionTitle,
    required this.pageNumber,
    required this.text,
    this.score = 0,
  });

  final String chunkId;
  final String paperId;
  final String paperTitle;
  final String sectionTitle;
  final int pageNumber;
  final String text;
  final double score;

  @override
  List<Object?> get props => [chunkId];
}

/// One factual sentence from the synthesis, bound to its source.
class Claim extends Equatable {
  const Claim({
    required this.id,
    required this.text,
    required this.chunkId,
    required this.status,
    this.note = '',
    this.index = 0,
  });

  final String id;
  final String text;
  final String chunkId;
  final VerificationStatus status;

  /// The verifier's reasoning, e.g. "Table 3 reports 84.1 vs 80.9 F1."
  final String note;

  /// 1-based superscript number shown inline in the synthesis.
  final int index;

  @override
  List<Object?> get props => [id, status];
}
