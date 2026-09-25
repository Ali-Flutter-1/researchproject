import 'dart:async';
import 'dart:math';

import '../../domain/entities/claim.dart';
import '../../domain/entities/gap.dart';
import '../../domain/entities/paper.dart';
import '../../domain/entities/research_run.dart';
import '../../domain/entities/run_stage.dart';

/// Stands in for the ASP.NET API until it exists. It emits the same shapes,
/// in the same order, with roughly the same timing as the real SSE stream —
/// including the long ingest stage and a partial-failure warning, because a
/// UI only tested against instant perfect data fails on contact with reality.
class MockResearchDataSource {
  final _runs = <String, ResearchRun>{};
  var _seq = 0;

  Future<String> startRun({
    required String question,
    required RunOptions options,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final id = 'run_${DateTime.now().millisecondsSinceEpoch}_${_seq++}';
    _runs[id] = ResearchRun(
      id: id,
      question: question,
      status: RunStatus.queued,
      createdAt: DateTime.now(),
      options: options,
      stages: [
        for (final s in RunStage.values)
          StageProgress(stage: s, status: StageStatus.pending),
      ],
    );
    return id;
  }

  Future<ResearchRun> getRun(String id) async {
    final run = _runs[id];
    if (run == null) throw StateError('No run $id');
    return run;
  }

  Future<List<ResearchRun>> history() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final seeded = _seedHistory();
    return [
      ..._runs.values.where((r) => r.isTerminal),
      ...seeded,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Drives a run through every stage, emitting after each transition.
  Stream<ResearchRun> watchRun(String id) async* {
    var run = _runs[id] ?? await getRun(id);
    run = run.copyWith(status: RunStatus.running);

    for (final stage in RunStage.values) {
      run = _mark(run, stage, StageStatus.running);
      _runs[id] = run;
      yield run;

      if (stage == RunStage.ingesting) {
        // The long pole. Papers land progressively — this is the entire
        // reason the run is async, so the mock must exercise it.
        final papers = _papers();
        for (var i = 0; i < papers.length; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 420));
          run = run
              .copyWith(papers: papers.take(i + 1).toList())
              .let((r) => _mark(r, stage, StageStatus.running,
                  done: i + 1, total: papers.length));
          _runs[id] = run;
          yield run;
        }
        run = run.copyWith(warnings: [
          const RunWarning(
            code: 'parse_failed',
            message: '2 papers could not be read (scanned PDFs).',
          ),
        ]);
      } else {
        await Future<void>.delayed(
          Duration(milliseconds: 500 + Random().nextInt(500)),
        );
      }

      if (stage == RunStage.analyzing) {
        run = run.copyWith(
          synthesis: _synthesis(),
          comparisonColumns: const [
            'Method', 'Family', 'Datasets', 'Metrics', 'Baselines', 'Limitations',
          ],
        );
      }
      if (stage == RunStage.verifying) {
        run = run.copyWith(claims: _claims());
      }
      if (stage == RunStage.gapAnalysis) {
        run = run.copyWith(gaps: _gaps());
      }

      run = _mark(run, stage, StageStatus.completed);
      _runs[id] = run;
      yield run;
    }

    // Partial, not completed — some papers failed to parse. This is a
    // first-class outcome, and the UI must be built to show it.
    run = run.copyWith(status: RunStatus.partial);
    _runs[id] = run;
    yield run;
  }

  Future<Evidence?> evidenceForChunk(String chunkId) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return _evidence[chunkId];
  }

  ResearchRun _mark(
    ResearchRun run,
    RunStage stage,
    StageStatus status, {
    int? done,
    int? total,
  }) =>
      run.copyWith(
        stages: [
          for (final s in run.stages)
            if (s.stage == stage)
              s.copyWith(status: status, done: done, total: total)
            else
              s,
        ],
      );
}

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

// ---------------------------------------------------------------------------
// Sample content. Long enough to expose real layout problems.
// ---------------------------------------------------------------------------

List<Paper> _papers() => const [
      Paper(
        id: 'p1',
        title: 'Cross-Lingual Transfer for Misinformation Detection in '
            'Low-Resource Settings',
        authors: ['Okonkwo, A.', 'Reyes, M.', 'Lindqvist, S.'],
        year: 2024,
        venue: 'ACL',
        doi: '10.48550/arXiv.2403.01922',
        citationCount: 142,
        relevance: 0.94,
        whyIncluded:
            'Directly addresses transfer learning for the target task and '
            'reports per-language results.',
        extraction: Extraction(
          problem:
              'Misinformation classifiers degrade sharply outside high-resource '
              'languages, where labelled data is scarce.',
          method: MethodRecord(
            name: 'XLM-R + adapter fine-tuning',
            family: 'Transformer',
            summary:
                'Language-specific adapters over a frozen multilingual encoder, '
                'trained on 2k labelled examples per language.',
            novelty: 'Adapter composition across typologically related languages.',
          ),
          datasets: [
            NamedFact(name: 'MultiFC', value: '36k claims', chunkId: 'c1'),
            NamedFact(name: 'CheckThat! 2023', value: '8k', chunkId: 'c2'),
          ],
          metrics: [
            NamedFact(name: 'Macro-F1', value: '71.4', chunkId: 'c3'),
            NamedFact(name: 'Accuracy', value: '78.2', chunkId: 'c3'),
          ],
          baselines: ['mBERT', 'Zero-shot XLM-R'],
          limitations: [
            Limitation(
              text: 'Evaluated on only 6 languages, all with Latin script.',
              chunkId: 'c4',
            ),
            Limitation(
              text: 'Requires 2k labelled examples per target language.',
              chunkId: 'c4',
            ),
          ],
          claimedContribution:
              'First adapter-composition approach to beat full fine-tuning at '
              'a fraction of the parameter cost.',
        ),
      ),
      Paper(
        id: 'p2',
        title: 'Do Multilingual Language Models Transfer Factuality? '
            'A Controlled Study',
        authors: ['Bhattacharya, R.', 'Novak, P.'],
        year: 2025,
        venue: 'EMNLP',
        doi: '10.48550/arXiv.2505.11238',
        citationCount: 38,
        relevance: 0.89,
        whyIncluded:
            'Provides the controlled ablation the other papers cite but do not run.',
        extraction: Extraction(
          problem:
              'It is unclear whether cross-lingual gains reflect transferred '
              'factual knowledge or surface-level cues.',
          method: MethodRecord(
            name: 'Controlled probing suite',
            family: 'Probing',
            summary:
                'Paired synthetic corpora isolating lexical overlap from '
                'factual content across 11 languages.',
          ),
          datasets: [
            NamedFact(name: 'SynthFact-11', value: '110k pairs', chunkId: 'c5'),
          ],
          metrics: [
            NamedFact(name: 'Probing accuracy', value: '64.0', chunkId: 'c6'),
          ],
          baselines: ['mBERT', 'XLM-R', 'mT5'],
          limitations: [
            Limitation(
              text: 'Synthetic data may not reflect natural misinformation.',
              chunkId: 'c7',
            ),
          ],
          claimedContribution:
              'Shows most reported transfer is attributable to lexical overlap.',
        ),
      ),
      Paper(
        id: 'p3',
        title: 'Graph-Based Claim Verification Without Parallel Corpora',
        authors: ['Tanaka, Y.', 'Mwangi, J.', 'Silva, C.', 'Ahmed, N.'],
        year: 2023,
        venue: 'NeurIPS',
        doi: '10.48550/arXiv.2311.04410',
        citationCount: 287,
        relevance: 0.81,
        whyIncluded: 'Most-cited alternative to transformer-only approaches.',
        parseConfidence: ParseConfidence.medium,
        extraction: Extraction(
          problem:
              'Parallel corpora are unavailable for most language pairs of interest.',
          method: MethodRecord(
            name: 'Evidence graph propagation',
            family: 'Graph neural network',
            summary:
                'Builds an entity-linked evidence graph and propagates '
                'veracity scores without requiring aligned text.',
          ),
          datasets: [
            NamedFact(name: 'FEVER', value: '185k', chunkId: 'c8'),
          ],
          metrics: [
            NamedFact(name: 'Macro-F1', value: '68.9', chunkId: 'c9'),
          ],
          baselines: ['BERT-concat'],
          limitations: [
            Limitation(
              text: 'Depends on entity linking, which is itself weak in '
                  'low-resource languages.',
              chunkId: 'c10',
            ),
          ],
          claimedContribution: 'Removes the parallel-corpus requirement entirely.',
        ),
      ),
      Paper(
        id: 'p4',
        title: 'A Survey of Low-Resource NLP for Social Good',
        authors: ['Fernández, L.', 'Osei, K.'],
        year: 2024,
        venue: 'TACL',
        doi: '10.48550/arXiv.2402.00771',
        citationCount: 96,
        relevance: 0.72,
        whyIncluded: 'Framing and terminology; no new method.',
        extraction: Extraction(
          problem: 'The subfield lacks shared evaluation conventions.',
          method: MethodRecord(name: 'Survey', family: 'Survey'),
          baselines: [],
          limitations: [
            Limitation(
              text: 'No empirical comparison; taxonomy only.',
              chunkId: 'c11',
            ),
          ],
        ),
      ),
      Paper(
        id: 'p5',
        title: 'Prompt-Based Detection with Large Language Models Across '
            '14 Languages',
        authors: ['Petrova, I.', 'Kim, D.', 'Rahman, S.'],
        year: 2025,
        venue: 'NAACL',
        doi: '10.48550/arXiv.2501.08833',
        citationCount: 54,
        relevance: 0.86,
        whyIncluded: 'Only paper covering non-Latin scripts at scale.',
        extraction: Extraction(
          problem:
              'Fine-tuning is impractical where no labelled data exists at all.',
          method: MethodRecord(
            name: 'Few-shot prompting with retrieval',
            family: 'LLM prompting',
            summary:
                'Retrieves 8 nearest labelled examples from any language and '
                'prompts a frozen instruction-tuned model.',
          ),
          datasets: [
            NamedFact(name: 'MultiFC', value: '36k claims', chunkId: 'c12'),
            NamedFact(name: 'X-Fact', value: '31k', chunkId: 'c13'),
          ],
          metrics: [
            NamedFact(name: 'Macro-F1', value: '69.8', chunkId: 'c14'),
          ],
          baselines: ['XLM-R fine-tuned'],
          limitations: [
            Limitation(
              text: 'Inference cost is prohibitive at moderation volumes.',
              chunkId: 'c15',
            ),
            Limitation(
              text: 'Requires 2k labelled examples per target language.',
              statedByAuthors: false,
              chunkId: 'c15',
            ),
          ],
          claimedContribution: 'Competitive without any target-language training.',
        ),
      ),
      Paper(
        id: 'p6',
        title: 'Annotation Quality in Multilingual Fact-Checking Corpora',
        authors: ['Haddad, F.'],
        year: 2023,
        venue: 'LREC',
        doi: '10.48550/arXiv.2309.15540',
        citationCount: 61,
        relevance: 0.68,
        whyIncluded: 'Questions the reliability of the benchmarks the others use.',
        parseConfidence: ParseConfidence.low,
        extraction: Extraction(
          problem: 'Benchmark labels may encode annotator bias.',
          method: MethodRecord(name: 'Re-annotation study', family: 'Analysis'),
          datasets: [NamedFact(name: 'MultiFC', value: 'subset', chunkId: 'c16')],
          metrics: [
            NamedFact(name: 'Inter-annotator κ', value: '0.41', chunkId: 'c17'),
          ],
          baselines: [],
          limitations: [
            Limitation(text: 'Single annotator re-labelled.', chunkId: 'c18'),
          ],
        ),
      ),
    ];

List<String> _synthesis() => const [
      'Work on this problem splits into three families. Adapter-based transfer '
          'over multilingual encoders is the most established approach [[cl1]], '
          'graph propagation avoids the parallel-corpus requirement altogether '
          '[[cl2]], and prompt-based methods with frozen large models are the '
          'newest entrant [[cl3]].',
      'On shared benchmarks the families are closer than their framing suggests. '
          'Adapter fine-tuning reports the highest macro-F1 at 71.4 [[cl4]], but '
          'prompting reaches 69.8 without any target-language training data '
          '[[cl5]] — a materially different practical proposition.',
      'The strongest caution in this set is methodological rather than technical. '
          'A controlled probing study finds most reported cross-lingual transfer '
          'is attributable to lexical overlap rather than transferred factual '
          'knowledge [[cl6]], and a separate re-annotation study reports '
          'inter-annotator agreement of only 0.41 on the most widely used '
          'benchmark [[cl7]]. Taken together these suggest the headline numbers '
          'across this literature are less comparable than they appear.',
    ];

List<Claim> _claims() => const [
      Claim(
        id: 'cl1',
        index: 1,
        text: 'Adapter-based transfer is the most established approach.',
        chunkId: 'c1',
        status: VerificationStatus.supported,
        note: 'Section 2 describes adapters as the dominant paradigm.',
      ),
      Claim(
        id: 'cl2',
        index: 2,
        text: 'Graph propagation avoids the parallel-corpus requirement.',
        chunkId: 'c8',
        status: VerificationStatus.supported,
        note: 'Abstract states the method removes this requirement.',
      ),
      Claim(
        id: 'cl3',
        index: 3,
        text: 'Prompt-based methods are the newest entrant.',
        chunkId: 'c12',
        status: VerificationStatus.partiallySupported,
        note: 'Paper is recent, but does not itself claim to be first.',
      ),
      Claim(
        id: 'cl4',
        index: 4,
        text: 'Adapter fine-tuning reports the highest macro-F1 at 71.4.',
        chunkId: 'c3',
        status: VerificationStatus.supported,
        note: 'Table 3 reports 71.4 macro-F1 against 68.9 and 69.8.',
      ),
      Claim(
        id: 'cl5',
        index: 5,
        text: 'Prompting reaches 69.8 without target-language training data.',
        chunkId: 'c14',
        status: VerificationStatus.supported,
        note: 'Table 2, zero-shot column.',
      ),
      Claim(
        id: 'cl6',
        index: 6,
        text: 'Most reported transfer is attributable to lexical overlap.',
        chunkId: 'c6',
        status: VerificationStatus.contradicted,
        note: 'The cited passage reports this for 4 of 11 languages, not most. '
            'The generalisation overstates the finding.',
      ),
      Claim(
        id: 'cl7',
        index: 7,
        text: 'Inter-annotator agreement is 0.41 on the most widely used benchmark.',
        chunkId: 'c17',
        status: VerificationStatus.notFound,
        note: 'κ = 0.41 is reported, but the passage does not establish that '
            'this benchmark is the most widely used.',
      ),
    ];

List<Gap> _gaps() => const [
      Gap(
        id: 'g1',
        kind: GapKind.uncoveredCombination,
        statement: 'No paper evaluates graph-based methods on non-Latin scripts.',
        evidence: '1 paper uses graph propagation, 1 paper covers non-Latin '
            'scripts, none do both.',
        confidence: 0.86,
        relatedPaperIds: ['p3', 'p5'],
      ),
      Gap(
        id: 'g2',
        kind: GapKind.unaddressedLimitation,
        statement:
            'The 2k-labelled-examples requirement is named as a limitation by '
            'two papers and addressed by none.',
        evidence: 'Stated in p1 (Section 6) and p5 (Section 5). No paper in '
            'this set proposes a method below that threshold.',
        confidence: 0.79,
        relatedPaperIds: ['p1', 'p5'],
      ),
      Gap(
        id: 'g3',
        kind: GapKind.singleSourceMetric,
        statement: 'Inter-annotator agreement is reported by only one paper.',
        evidence: '1 of 6 papers reports κ. The other 5 report F1 on corpora '
            'whose label reliability is therefore unknown.',
        confidence: 0.71,
        relatedPaperIds: ['p6'],
      ),
      Gap(
        id: 'g4',
        kind: GapKind.citationLeaf,
        statement:
            'The controlled probing study has not been built on despite its '
            'implications for every other paper here.',
        evidence: 'Published 2025, cited 38 times, 0 citations from within '
            'this result set.',
        confidence: 0.64,
        relatedPaperIds: ['p2'],
      ),
    ];

const _evidence = <String, Evidence>{
  'c1': Evidence(
    chunkId: 'c1',
    paperId: 'p1',
    paperTitle: 'Cross-Lingual Transfer for Misinformation Detection',
    sectionTitle: '2 Related Work',
    pageNumber: 2,
    text: 'Adapter-based approaches have become the dominant paradigm for '
        'cross-lingual transfer, offering a favourable tradeoff between '
        'parameter efficiency and downstream accuracy. Since Pfeiffer et al., '
        'the majority of published systems in this area adopt some adapter '
        'variant over a frozen multilingual encoder.',
  ),
  'c3': Evidence(
    chunkId: 'c3',
    paperId: 'p1',
    paperTitle: 'Cross-Lingual Transfer for Misinformation Detection',
    sectionTitle: '5.2 Main Results',
    pageNumber: 7,
    text: 'Our adapter composition reaches 71.4 macro-F1 averaged across the '
        'six target languages, compared to 68.9 for the graph baseline and '
        '69.8 for few-shot prompting. Accuracy follows the same ordering at '
        '78.2 / 75.1 / 76.4.',
  ),
  'c6': Evidence(
    chunkId: 'c6',
    paperId: 'p2',
    paperTitle: 'Do Multilingual Language Models Transfer Factuality?',
    sectionTitle: '4 Findings',
    pageNumber: 5,
    text: 'For four of the eleven languages studied, probing accuracy falls to '
        'near chance once lexical overlap with the source language is '
        'controlled. For the remaining seven, a smaller but consistent gap '
        'persists, suggesting genuine transfer does occur in some typological '
        'settings.',
  ),
  'c8': Evidence(
    chunkId: 'c8',
    paperId: 'p3',
    paperTitle: 'Graph-Based Claim Verification Without Parallel Corpora',
    sectionTitle: 'Abstract',
    pageNumber: 1,
    text: 'We remove the parallel-corpus requirement entirely by propagating '
        'veracity scores over an entity-linked evidence graph constructed '
        'independently in each language.',
  ),
  'c12': Evidence(
    chunkId: 'c12',
    paperId: 'p5',
    paperTitle: 'Prompt-Based Detection with Large Language Models',
    sectionTitle: '3 Method',
    pageNumber: 4,
    text: 'We retrieve the eight nearest labelled examples from a pooled '
        'multilingual index, without restricting retrieval to the target '
        'language, and present them as in-context demonstrations.',
  ),
  'c14': Evidence(
    chunkId: 'c14',
    paperId: 'p5',
    paperTitle: 'Prompt-Based Detection with Large Language Models',
    sectionTitle: '5 Results',
    pageNumber: 6,
    text: 'Without any target-language training data, the retrieval-augmented '
        'prompting approach attains 69.8 macro-F1 across the fourteen '
        'evaluation languages.',
  ),
  'c17': Evidence(
    chunkId: 'c17',
    paperId: 'p6',
    paperTitle: 'Annotation Quality in Multilingual Fact-Checking Corpora',
    sectionTitle: '4 Agreement',
    pageNumber: 5,
    text: 'Re-annotation of a 1,200-claim subset yields Cohen\'s κ of 0.41, '
        'which is conventionally read as moderate agreement and is low for a '
        'corpus used as ground truth in downstream evaluation.',
  ),
};

List<ResearchRun> _seedHistory() => [
      ResearchRun(
        id: 'seed1',
        question:
            'What methods are used for detecting fake news in low-resource '
            'languages?',
        status: RunStatus.partial,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        papers: _papers(),
        claims: _claims(),
        gaps: _gaps(),
        synthesis: _synthesis(),
      ),
      ResearchRun(
        id: 'seed2',
        question:
            'How do retrieval-augmented models handle contradictory sources?',
        status: RunStatus.completed,
        createdAt: DateTime.now().subtract(const Duration(days: 9)),
        papers: _papers().take(4).toList(),
      ),
    ];
