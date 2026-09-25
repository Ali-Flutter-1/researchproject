import 'package:equatable/equatable.dart';

enum ParseConfidence { high, medium, low }

class Paper extends Equatable {
  const Paper({
    required this.id,
    required this.title,
    required this.authors,
    required this.year,
    required this.venue,
    required this.doi,
    this.citationCount = 0,
    this.relevance = 0,
    this.whyIncluded = '',
    this.parseConfidence = ParseConfidence.high,
    this.openAccessUrl,
    this.extraction,
  });

  final String id;
  final String title;
  final List<String> authors;
  final int year;
  final String venue;
  final String doi;
  final int citationCount;

  /// 0..1 — how well this paper matched the question.
  final double relevance;

  /// One line explaining the selection, shown on the card. Users distrust
  /// a result set they cannot interrogate.
  final String whyIncluded;

  final ParseConfidence parseConfidence;
  final String? openAccessUrl;
  final Extraction? extraction;

  String get authorLine => switch (authors.length) {
        0 => 'Unknown',
        1 => authors.first,
        2 => '${authors[0]} & ${authors[1]}',
        _ => '${authors.first} et al.',
      };

  @override
  List<Object?> get props => [id];
}

/// The structured record produced by analysis pass 1. This schema is the
/// contract (ADR-011) — a field missing here is invisible downstream.
class Extraction extends Equatable {
  const Extraction({
    required this.problem,
    required this.method,
    this.datasets = const [],
    this.metrics = const [],
    this.baselines = const [],
    this.limitations = const [],
    this.claimedContribution = '',
  });

  final String problem;
  final MethodRecord method;
  final List<NamedFact> datasets;
  final List<NamedFact> metrics;
  final List<String> baselines;
  final List<Limitation> limitations;
  final String claimedContribution;

  @override
  List<Object?> get props =>
      [problem, method, datasets, metrics, baselines, limitations];
}

class MethodRecord extends Equatable {
  const MethodRecord({
    required this.name,
    required this.family,
    this.summary = '',
    this.novelty = '',
  });

  final String name;
  final String family;
  final String summary;
  final String novelty;

  @override
  List<Object?> get props => [name, family];
}

/// A fact with provenance. [chunkId] is what makes verification possible —
/// a fact without a source cannot be checked, and should never reach a user.
class NamedFact extends Equatable {
  const NamedFact({required this.name, this.value = '', this.chunkId});

  final String name;
  final String value;
  final String? chunkId;

  @override
  List<Object?> get props => [name, value, chunkId];
}

class Limitation extends Equatable {
  const Limitation({
    required this.text,
    this.statedByAuthors = true,
    this.chunkId,
  });

  final String text;
  final bool statedByAuthors;
  final String? chunkId;

  @override
  List<Object?> get props => [text, statedByAuthors];
}
