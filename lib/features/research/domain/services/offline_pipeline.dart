import '../../../inference/domain/repositories/llm_service.dart';
import '../../../library/domain/entities/library_paper.dart';
import '../entities/claim.dart';
import '../entities/paper.dart';
import '../entities/run_stage.dart';

/// The offline path: the user's own library, a local model, no network.
///
/// Deliberately a *shorter* pipeline than the online one. A 3B model cannot
/// hold twenty papers in context, cannot reliably verify its own citations,
/// and will invent gaps if asked to find them. Rather than run the full
/// pipeline badly, offline mode runs fewer stages honestly:
///
///   retrieve from library -> read the retrieved passages -> answer with quotes
///
/// No gap analysis, no cross-paper matrix from scratch, no claim verification
/// beyond "here is the passage this came from". What it does do — find the
/// relevant parts of papers you already have and summarise them with sources
/// attached — is genuinely useful and within a small model's reach.
class OfflinePipeline {
  const OfflinePipeline(this._llm);

  final LlmService _llm;

  /// Stages offline mode actually runs. Shown to the user so the difference
  /// from online mode is visible rather than a silent downgrade.
  static const stages = [
    RunStage.retrieving,
    RunStage.analyzing,
  ];

  static const systemPrompt = '''
You are helping a researcher search their own library of papers.

You will be given passages extracted from papers they have saved. Answer their
question using ONLY those passages.

Rules:
- Every factual sentence must end with the passage number it came from, like [2].
- If the passages do not answer the question, say so plainly. Do not fill the
  gap from your own knowledge — the researcher is asking about THEIR papers.
- If papers disagree, say that they disagree and show both.
- Be concise. Three short paragraphs at most.
''';

  /// Builds the prompt from retrieved passages. Numbering is explicit so the
  /// model's [n] markers map back to real sources we can show.
  static String buildPrompt({
    required String question,
    required List<Evidence> passages,
  }) {
    final b = StringBuffer()
      ..writeln('Question: $question')
      ..writeln()
      ..writeln('Passages from the library:')
      ..writeln();

    for (var i = 0; i < passages.length; i++) {
      final p = passages[i];
      b
        ..writeln('[${i + 1}] From "${p.paperTitle}", '
            '${p.sectionTitle}, page ${p.pageNumber}:')
        ..writeln(p.text)
        ..writeln();
    }
    return b.toString();
  }

  /// Streams the answer. The caller renders tokens as they arrive — on a local
  /// model this is the difference between "working" and "frozen".
  Stream<String> answer({
    required String question,
    required List<Evidence> passages,
    required String model,
  }) {
    if (passages.isEmpty) {
      return Stream.value(
        'Nothing in your library matches that question. Add papers on this '
        'topic, or go online to search published work.',
      );
    }
    return _llm.generate(
      systemPrompt: systemPrompt,
      userPrompt: buildPrompt(question: question, passages: passages),
      model: model,
      temperature: 0.1,
    );
  }

  /// Turns the model's `[n]` markers into claims bound to real passages.
  ///
  /// Offline claims are marked [VerificationStatus.partiallySupported], never
  /// `supported`: nothing verified them. Claiming otherwise would borrow the
  /// online pipeline's credibility without doing its work.
  static List<Claim> extractClaims(String answer, List<Evidence> passages) {
    final claims = <Claim>[];
    final sentences = answer.split(RegExp(r'(?<=[.!?])\s+'));
    var index = 0;

    for (final sentence in sentences) {
      final match = RegExp(r'\[(\d+)\]').firstMatch(sentence);
      if (match == null) continue;
      final n = int.tryParse(match.group(1)!) ?? 0;
      if (n < 1 || n > passages.length) continue;

      index++;
      claims.add(Claim(
        id: 'offline_$index',
        index: index,
        text: sentence.replaceAll(RegExp(r'\s*\[\d+\]'), '').trim(),
        chunkId: passages[n - 1].chunkId,
        status: VerificationStatus.partiallySupported,
        note: 'Offline mode does not verify claims against their source. '
            'Open the passage to check it yourself.',
      ));
    }
    return claims;
  }

  /// Library papers as research papers, so the result screen can render an
  /// offline run with the widgets it already has.
  static List<Paper> toPapers(List<LibraryPaper> library) => library
      .where((p) => p.status == IngestStatus.ready)
      .map((p) => Paper(
            id: p.id,
            title: p.displayTitle,
            authors: p.authors,
            year: p.year ?? 0,
            venue: 'Your library',
            doi: '',
            whyIncluded: 'From your library',
          ))
      .toList();
}
