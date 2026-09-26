import '../../../research/domain/entities/research_run.dart';
import '../../../research/domain/entities/run_stage.dart';
import '../../../research/domain/usecases/build_comparison.dart';
import '../../domain/entities/citation_style.dart';
import '../../domain/services/citation_formatter.dart';

/// The full report as Markdown. This is the format a researcher actually
/// pastes into their own writing, so the claim markers become real numbered
/// citations rather than internal ids.
abstract final class MarkdownExporter {
  static String export(ResearchRun run, ExportRequest request) {
    final b = StringBuffer();
    final papers = run.papers;
    final numbers = {
      for (var i = 0; i < papers.length; i++) papers[i].id: i + 1,
    };

    b
      ..writeln('# ${run.question}')
      ..writeln()
      ..writeln('*Generated ${_date(run.createdAt)} · '
          '${papers.length} papers analysed*');

    if (run.status == RunStatus.partial) {
      b
        ..writeln()
        ..writeln('> **Partial result.** Some papers could not be read. '
            'The analysis below covers the ${papers.length} that were.');
    }

    // --- Verification summary, stated before the findings -------------------
    if (run.claims.isNotEmpty) {
      b
        ..writeln()
        ..writeln('> **Citation check:** ${run.claims.length} claims · '
            '${run.verifiedCount} verified against source · '
            '${run.needsCheckCount} need checking.');
    }

    // --- Synthesis ----------------------------------------------------------
    if (run.synthesis.isNotEmpty) {
      b
        ..writeln()
        ..writeln('## Findings')
        ..writeln();
      for (final paragraph in run.synthesis) {
        b
          ..writeln(_resolveMarkers(paragraph, run, request, numbers))
          ..writeln();
      }
    }

    // --- Unverified claims, surfaced rather than dropped --------------------
    if (request.includeUnverifiedClaims && run.needsCheckCount > 0) {
      b
        ..writeln('## Statements needing verification')
        ..writeln()
        ..writeln('The citation check could not fully confirm these against '
            'their sources. Read the passage before relying on them.')
        ..writeln();
      for (final c in run.claims.where((c) => c.status.needsAttention)) {
        b
          ..writeln('- **${c.status.label}** — ${c.text}')
          ..writeln('  - *${c.note}*');
      }
      b.writeln();
    }

    // --- Comparison matrix --------------------------------------------------
    if (request.includeMatrix) {
      final rows = const BuildComparison()(run);
      if (rows.isNotEmpty) {
        b
          ..writeln('## Comparison')
          ..writeln()
          ..writeln('| Paper | ${BuildComparison.columns.join(' | ')} |')
          ..writeln('|---|${'---|' * BuildComparison.columns.length}');
        for (final row in rows) {
          final cells = BuildComparison.columns.map((c) {
            final cell = row.cells[c]!;
            // An em dash, not a blank. A blank cell reads as a broken table;
            // "—" reads as "this paper did not report that", which is the
            // information the gaps are computed from.
            return cell.isEmpty
                ? '—'
                : cell.values.map(_escapePipe).join('; ');
          }).join(' | ');
          b.writeln(
            '| ${_escapePipe(row.paper.title)} '
            '(${row.paper.year}) | $cells |',
          );
        }
        b.writeln();
      }
    }

    // --- Gaps ---------------------------------------------------------------
    if (request.includeGaps && run.gaps.isNotEmpty) {
      b
        ..writeln('## Research gaps')
        ..writeln();
      for (final gap in run.gaps) {
        b
          ..writeln('### ${gap.statement}')
          ..writeln()
          ..writeln('*${gap.kind.label} · '
              '${(gap.confidence * 100).round()}% confidence*')
          ..writeln()
          ..writeln('> ${gap.evidence}')
          ..writeln();
      }
    }

    // --- References ---------------------------------------------------------
    b
      ..writeln('## References')
      ..writeln();
    for (var i = 0; i < papers.length; i++) {
      b.writeln(
        '${i + 1}. ${CitationFormatter.format(papers[i], request.citationStyle)}',
      );
    }

    b
      ..writeln()
      ..writeln('---')
      ..writeln()
      ..writeln('*Citations formatted in ${request.citationStyle.label}. '
          'Produced by PractSearch — verify before citing.*');

    return b.toString();
  }

  /// Turns `[[claimId]]` into a real citation marker in the chosen style.
  static String _resolveMarkers(
    String text,
    ResearchRun run,
    ExportRequest request,
    Map<String, int> numbers,
  ) =>
      text.replaceAllMapped(RegExp(r'\[\[(\w+)\]\]'), (m) {
        final claim = run.claimById(m.group(1)!);
        if (claim == null) return '';
        final paper = _paperForChunk(run, claim.chunkId);
        final marker = paper == null
            ? ''
            : CitationFormatter.inText(
                paper,
                request.citationStyle,
                numbers[paper.id] ?? 0,
              );
        // An unverified claim stays flagged in the exported document. Dropping
        // the flag on export would undo the whole point of verifying.
        final flag = claim.status.needsAttention ? ' ⚠' : '';
        return '$marker$flag';
      });

  static dynamic _paperForChunk(ResearchRun run, String chunkId) {
    for (final p in run.papers) {
      final e = p.extraction;
      if (e == null) continue;
      final ids = [
        ...e.datasets.map((d) => d.chunkId),
        ...e.metrics.map((m) => m.chunkId),
        ...e.limitations.map((l) => l.chunkId),
      ];
      if (ids.contains(chunkId)) return p;
    }
    return run.papers.firstOrNull;
  }

  static String _escapePipe(String s) =>
      s.replaceAll('|', r'\|').replaceAll('\n', ' ');

  static String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
