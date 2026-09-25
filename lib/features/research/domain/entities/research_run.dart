import 'package:equatable/equatable.dart';

import 'claim.dart';
import 'gap.dart';
import 'paper.dart';
import 'run_stage.dart';

/// Filters the user may set before a run. Defaults are deliberately sane so
/// the Ask screen can stay almost empty.
class RunOptions extends Equatable {
  const RunOptions({
    this.yearFrom = 2019,
    this.yearTo = 2026,
    this.paperCount = 20,
    this.openAccessOnly = true,
    this.includeLibrary = false,
  });

  final int yearFrom;
  final int yearTo;
  final int paperCount;
  final bool openAccessOnly;
  final bool includeLibrary;

  RunOptions copyWith({
    int? yearFrom,
    int? yearTo,
    int? paperCount,
    bool? openAccessOnly,
    bool? includeLibrary,
  }) =>
      RunOptions(
        yearFrom: yearFrom ?? this.yearFrom,
        yearTo: yearTo ?? this.yearTo,
        paperCount: paperCount ?? this.paperCount,
        openAccessOnly: openAccessOnly ?? this.openAccessOnly,
        includeLibrary: includeLibrary ?? this.includeLibrary,
      );

  @override
  List<Object?> get props =>
      [yearFrom, yearTo, paperCount, openAccessOnly, includeLibrary];
}

class RunWarning extends Equatable {
  const RunWarning({required this.code, required this.message});
  final String code;
  final String message;

  @override
  List<Object?> get props => [code, message];
}

/// One immutable research run. Runs are records — an old one opens exactly
/// as it was.
class ResearchRun extends Equatable {
  const ResearchRun({
    required this.id,
    required this.question,
    required this.status,
    required this.createdAt,
    this.options = const RunOptions(),
    this.stages = const [],
    this.papers = const [],
    this.synthesis = const [],
    this.claims = const [],
    this.gaps = const [],
    this.warnings = const [],
    this.comparisonColumns = const [],
  });

  final String id;
  final String question;
  final RunStatus status;
  final DateTime createdAt;
  final RunOptions options;
  final List<StageProgress> stages;
  final List<Paper> papers;

  /// The synthesis, split into paragraphs. Claim references are embedded as
  /// `[[claimId]]` markers and resolved at render time.
  final List<String> synthesis;

  final List<Claim> claims;
  final List<Gap> gaps;
  final List<RunWarning> warnings;
  final List<String> comparisonColumns;

  bool get isTerminal =>
      status == RunStatus.completed ||
      status == RunStatus.partial ||
      status == RunStatus.failed;

  int get verifiedCount =>
      claims.where((c) => c.status == VerificationStatus.supported).length;

  int get needsCheckCount => claims.length - verifiedCount;

  Paper? paperById(String id) =>
      papers.where((p) => p.id == id).firstOrNull;

  Claim? claimById(String id) =>
      claims.where((c) => c.id == id).firstOrNull;

  ResearchRun copyWith({
    RunStatus? status,
    List<StageProgress>? stages,
    List<Paper>? papers,
    List<String>? synthesis,
    List<Claim>? claims,
    List<Gap>? gaps,
    List<RunWarning>? warnings,
    List<String>? comparisonColumns,
  }) =>
      ResearchRun(
        id: id,
        question: question,
        status: status ?? this.status,
        createdAt: createdAt,
        options: options,
        stages: stages ?? this.stages,
        papers: papers ?? this.papers,
        synthesis: synthesis ?? this.synthesis,
        claims: claims ?? this.claims,
        gaps: gaps ?? this.gaps,
        warnings: warnings ?? this.warnings,
        comparisonColumns: comparisonColumns ?? this.comparisonColumns,
      );

  @override
  List<Object?> get props => [id, status, stages, papers, claims, gaps];
}
