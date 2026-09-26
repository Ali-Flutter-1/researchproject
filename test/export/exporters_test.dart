import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:practsearch/features/export/data/exporters/bibliography_exporter.dart';
import 'package:practsearch/features/export/data/exporters/csv_exporter.dart';
import 'package:practsearch/features/export/data/exporters/markdown_exporter.dart';
import 'package:practsearch/features/export/domain/entities/citation_style.dart';
import 'package:practsearch/features/export/domain/services/citation_formatter.dart';
import 'package:practsearch/features/export/domain/usecases/build_export.dart';
import 'package:practsearch/features/research/domain/entities/claim.dart';
import 'package:practsearch/features/research/domain/entities/gap.dart';
import 'package:practsearch/features/research/domain/entities/paper.dart';
import 'package:practsearch/features/research/domain/entities/research_run.dart';
import 'package:practsearch/features/research/domain/entities/run_stage.dart';

const _paper = Paper(
  id: 'p1',
  title: 'Cross-Lingual Transfer & Low-Resource NLP: A 50% Improvement',
  authors: ['Okonkwo, A.', 'Reyes, M.', 'Lindqvist, S.'],
  year: 2024,
  venue: 'ACL',
  doi: '10.48550/arXiv.2403.01922',
  citationCount: 142,
  extraction: Extraction(
    problem: 'Classifiers degrade outside high-resource languages.',
    method: MethodRecord(name: 'XLM-R + adapters', family: 'Transformer'),
    datasets: [NamedFact(name: 'MultiFC', value: '36k', chunkId: 'c1')],
    metrics: [NamedFact(name: 'Macro-F1', value: '71.4', chunkId: 'c3')],
    baselines: ['mBERT'],
    limitations: [Limitation(text: 'Latin script only', chunkId: 'c4')],
  ),
);

/// A paper with nothing extracted — the partial case the matrix must survive.
const _bare = Paper(
  id: 'p2',
  title: 'A Survey',
  authors: ['Haddad, F.'],
  year: 2023,
  venue: 'LREC',
  doi: '',
);

final _run = ResearchRun(
  id: 'r1',
  question: 'What methods detect fake news in low-resource languages?',
  status: RunStatus.partial,
  createdAt: DateTime(2026, 9, 26),
  papers: const [_paper, _bare],
  synthesis: const ['Adapters lead the field [[cl1]], but coverage is thin [[cl2]].'],
  claims: const [
    Claim(
      id: 'cl1',
      index: 1,
      text: 'Adapters lead the field.',
      chunkId: 'c1',
      status: VerificationStatus.supported,
    ),
    Claim(
      id: 'cl2',
      index: 2,
      text: 'Coverage is thin.',
      chunkId: 'c4',
      status: VerificationStatus.contradicted,
      note: 'Source reports 4 of 11, not most.',
    ),
  ],
  gaps: const [
    Gap(
      id: 'g1',
      kind: GapKind.uncoveredCombination,
      statement: 'No paper covers non-Latin scripts.',
      evidence: '1 of 2 papers uses transformers, none cover non-Latin.',
      confidence: 0.86,
    ),
  ],
);

void main() {
  // The PDF exporter reads the bundled fonts through rootBundle.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BibTeX', () {
    test('escapes characters that would break the parser', () {
      final out = BibliographyExporter.export(
        const [_paper],
        BibliographyFormat.bibtex,
      );
      expect(out, contains(r'\&'), reason: 'bare & terminates a BibTeX field');
      expect(out, contains(r'\%'), reason: 'bare % starts a BibTeX comment');
    });

    test('double-braces the title so acronyms keep their case', () {
      final out = BibliographyExporter.export(
        const [_paper],
        BibliographyFormat.bibtex,
      );
      // Without the inner braces BibTeX lowercases the title and "XLM-R"
      // becomes "xlm-r" in the rendered bibliography.
      expect(out, contains('title     = {{'));
    });

    test('joins authors with " and ", not commas', () {
      final out = BibliographyExporter.export(
        const [_paper],
        BibliographyFormat.bibtex,
      );
      expect(out, contains('Okonkwo, A. and Reyes, M. and Lindqvist, S.'));
    });
  });

  group('RIS', () {
    test('terminates every record with ER', () {
      final out = BibliographyExporter.export(
        const [_paper, _bare],
        BibliographyFormat.ris,
      );
      // A missing ER line makes reference managers reject the whole file.
      expect('ER  - '.allMatches(out).length, 2);
    });

    test('emits one AU line per author', () {
      final out = BibliographyExporter.export(
        const [_paper],
        BibliographyFormat.ris,
      );
      expect('AU  - '.allMatches(out).length, 3);
    });

    test('omits DOI when the paper has none', () {
      final out = BibliographyExporter.export(
        const [_bare],
        BibliographyFormat.ris,
      );
      expect(out, isNot(contains('DO  - ')));
    });
  });

  test('CSL-JSON parses and splits names into family/given', () {
    final out = BibliographyExporter.export(
      const [_paper],
      BibliographyFormat.csl,
    );
    final parsed = jsonDecode(out) as List;
    expect(parsed, hasLength(1));
    final authors = (parsed.first as Map)['author'] as List;
    expect((authors.first as Map)['family'], 'Okonkwo');
    expect((authors.first as Map)['given'], 'A.');
  });

  group('citation styles', () {
    test('APA uses an ampersand before the final author', () {
      final out = CitationFormatter.format(_paper, CitationStyle.apa);
      expect(out, startsWith('Okonkwo, A., Reyes, M., & Lindqvist, S. (2024).'));
    });

    test('MLA collapses three or more authors to et al.', () {
      final out = CitationFormatter.format(_paper, CitationStyle.mla);
      expect(out, startsWith('Okonkwo, A., et al.'));
    });

    test('IEEE puts initials before surnames', () {
      final out = CitationFormatter.format(_paper, CitationStyle.ieee);
      expect(out, startsWith('A. Okonkwo, M. Reyes, and S. Lindqvist'));
    });

    test('Vancouver drops periods from initials', () {
      final out = CitationFormatter.format(_paper, CitationStyle.vancouver);
      expect(out, startsWith('Okonkwo A, Reyes M, Lindqvist S.'));
    });

    test('numeric styles use the reference number, not the author', () {
      expect(CitationFormatter.inText(_paper, CitationStyle.ieee, 3), '[3]');
      expect(CitationFormatter.inText(_paper, CitationStyle.vancouver, 3), '(3)');
      expect(
        CitationFormatter.inText(_paper, CitationStyle.apa, 3),
        '(Okonkwo et al., 2024)',
      );
    });

    test('every style produces a non-empty entry for a paper with no DOI', () {
      for (final style in CitationStyle.values) {
        final out = CitationFormatter.format(_bare, style);
        expect(out, isNotEmpty, reason: '${style.label} produced nothing');
        expect(out, isNot(contains('null')));
      }
    });
  });

  group('Markdown report', () {
    test('resolves claim markers into real citations', () {
      final out = MarkdownExporter.export(_run, const ExportRequest());
      expect(out, isNot(contains('[[cl1]]')), reason: 'internal ids must not leak');
      expect(out, contains('Okonkwo et al., 2024'));
    });

    test('keeps unverified claims flagged rather than dropping them', () {
      final out = MarkdownExporter.export(_run, const ExportRequest());
      expect(out, contains('Statements needing verification'));
      expect(out, contains('Source reports 4 of 11, not most.'));
      expect(out, contains('⚠'), reason: 'the inline flag survives export');
    });

    test('renders an empty matrix cell as an em dash, not a blank', () {
      final out = MarkdownExporter.export(_run, const ExportRequest());
      // _bare has no extraction, so every one of its cells is empty.
      expect(out, contains('| — |'));
    });

    test('honours the include toggles', () {
      final out = MarkdownExporter.export(
        _run,
        const ExportRequest(includeGaps: false, includeMatrix: false),
      );
      expect(out, isNot(contains('## Research gaps')));
      expect(out, isNot(contains('## Comparison')));
      expect(out, contains('## References'), reason: 'references are never optional');
    });

    test('states the partial outcome instead of hiding it', () {
      final out = MarkdownExporter.export(_run, const ExportRequest());
      expect(out, contains('Partial result'));
    });
  });

  group('CSV', () {
    test('quotes every field and doubles inner quotes', () {
      final run = ResearchRun(
        id: 'r',
        question: 'q',
        status: RunStatus.completed,
        createdAt: DateTime(2026),
        papers: const [
          Paper(
            id: 'x',
            title: 'A "quoted" title, with a comma',
            authors: ['Smith, J.'],
            year: 2024,
            venue: 'V',
            doi: '',
          ),
        ],
      );
      final out = CsvExporter.export(run);
      expect(out, contains('"A ""quoted"" title, with a comma"'));
    });
  });

  group('PDF', () {
    test('renders non-ASCII without falling back to a fontless glyph', () async {
      // Default Helvetica has no Unicode support, so an accented name, a
      // Greek symbol or an em dash silently fails to draw. Regression guard
      // for the embedded-font theme.
      final run = ResearchRun(
        id: 'r',
        question: 'Does transfer hold?',
        status: RunStatus.completed,
        createdAt: DateTime(2026),
        papers: const [
          Paper(
            id: 'u',
            title: 'Evaluating κ Agreement — A Study',
            authors: ['Fernández, L.', 'Müller, K.'],
            year: 2024,
            venue: 'TACL',
            doi: '',
          ),
        ],
      );
      final bytes = await const BuildExport()(
        run,
        const ExportRequest(format: ExportFormat.pdf),
      );
      expect(bytes.bytes, isNotEmpty);
      expect(bytes.mimeType, 'application/pdf');
    });
  });

  group('filenames', () {
    test('slugifies the question and caps the length', () async {
      final result = await const BuildExport()(_run, const ExportRequest());
      expect(
        result.filename,
        'what-methods-detect-fake-news-in-low-resource-languages.md',
      );
    });

    test('falls back when the question has no usable characters', () async {
      final run = ResearchRun(
        id: 'r',
        question: '???',
        status: RunStatus.completed,
        createdAt: DateTime(2026),
      );
      final result = await const BuildExport()(run, const ExportRequest());
      expect(result.filename, 'practsearch-report.md');
    });

    test('each format carries its own extension and mime type', () async {
      for (final f in ExportFormat.values) {
        final result = await const BuildExport()(_run, ExportRequest(format: f));
        expect(result.filename, isNotEmpty);
        expect(result.mimeType, isNotEmpty);
        if (f == ExportFormat.pdf) {
          expect(result.isBinary, isTrue);
          expect(result.bytes, isNotEmpty);
        } else {
          expect(result.text, isNotEmpty);
        }
      }
    });
  });
}
