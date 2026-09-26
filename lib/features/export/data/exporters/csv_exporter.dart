import 'dart:convert';

import '../../../research/domain/entities/research_run.dart';
import '../../../research/domain/usecases/build_comparison.dart';

abstract final class CsvExporter {
  static String export(ResearchRun run) {
    final rows = const BuildComparison()(run);
    final b = StringBuffer()
      ..writeln(_row([
        'Paper',
        'Authors',
        'Year',
        'Venue',
        'DOI',
        'Citations',
        ...BuildComparison.columns,
      ]));

    for (final r in rows) {
      b.writeln(_row([
        r.paper.title,
        r.paper.authors.join('; '),
        '${r.paper.year}',
        r.paper.venue,
        r.paper.doi,
        '${r.paper.citationCount}',
        for (final c in BuildComparison.columns)
          r.cells[c]!.values.join('; '),
      ]));
    }
    return b.toString();
  }

  /// RFC 4180: quote every field, double any inner quote. Cheaper than
  /// deciding per field which ones need it, and never wrong.
  static String _row(List<String> cells) =>
      cells.map((c) => '"${c.replaceAll('"', '""')}"').join(',');
}

abstract final class JsonExporter {
  static String export(ResearchRun run) {
    final data = {
      'question': run.question,
      'createdAt': run.createdAt.toIso8601String(),
      'status': run.status.name,
      'papers': run.papers
          .map((p) => {
                'id': p.id,
                'title': p.title,
                'authors': p.authors,
                'year': p.year,
                'venue': p.venue,
                'doi': p.doi,
                'citationCount': p.citationCount,
                'relevance': p.relevance,
                'parseConfidence': p.parseConfidence.name,
                if (p.extraction != null)
                  'extraction': {
                    'problem': p.extraction!.problem,
                    'method': {
                      'name': p.extraction!.method.name,
                      'family': p.extraction!.method.family,
                      'summary': p.extraction!.method.summary,
                    },
                    'datasets': p.extraction!.datasets
                        .map((d) => {'name': d.name, 'value': d.value})
                        .toList(),
                    'metrics': p.extraction!.metrics
                        .map((m) => {'name': m.name, 'value': m.value})
                        .toList(),
                    'baselines': p.extraction!.baselines,
                    'limitations': p.extraction!.limitations
                        .map((l) => {
                              'text': l.text,
                              'statedByAuthors': l.statedByAuthors,
                            })
                        .toList(),
                  },
              })
          .toList(),
      'synthesis': run.synthesis,
      'claims': run.claims
          .map((c) => {
                'id': c.id,
                'text': c.text,
                'chunkId': c.chunkId,
                'status': c.status.name,
                'note': c.note,
              })
          .toList(),
      'gaps': run.gaps
          .map((g) => {
                'id': g.id,
                'kind': g.kind.name,
                'statement': g.statement,
                'evidence': g.evidence,
                'confidence': g.confidence,
              })
          .toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }
}
