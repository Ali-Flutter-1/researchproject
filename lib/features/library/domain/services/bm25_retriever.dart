import 'dart:math';

import '../../data/pdf_text_extractor.dart';

class ScoredChunk {
  const ScoredChunk(this.chunk, this.score);
  final TextChunk chunk;
  final double score;
}

/// Keyword retrieval over the user's library.
///
/// BM25 rather than embeddings, for three reasons: it needs no model, no
/// download and no network, so offline search works the moment a PDF is
/// added; it is genuinely strong on the *named things* researchers ask about
/// — "FlashAttention", "BLEU", "MIMIC-III" — which is exactly where dense
/// retrieval blurs; and it is fast enough to run over a whole library on a
/// phone without an index.
///
/// The online pipeline fuses this with dense retrieval (ADR-010). Offline
/// uses it alone, which is weaker on paraphrase and worth saying plainly.
class Bm25Retriever {
  const Bm25Retriever({this.k1 = 1.5, this.b = 0.75});

  final double k1;
  final double b;

  List<ScoredChunk> search({
    required String query,
    required List<TextChunk> corpus,
    int limit = 12,
  }) {
    if (corpus.isEmpty) return const [];

    final queryTerms = tokenize(query);
    if (queryTerms.isEmpty) return const [];

    final docs = corpus.map((c) => tokenize(c.text)).toList();
    final avgLength =
        docs.fold<int>(0, (sum, d) => sum + d.length) / docs.length;

    // How many documents contain each query term.
    final docFrequency = <String, int>{};
    for (final term in queryTerms.toSet()) {
      docFrequency[term] = docs.where((d) => d.contains(term)).length;
    }

    final scored = <ScoredChunk>[];
    for (var i = 0; i < corpus.length; i++) {
      final doc = docs[i];
      if (doc.isEmpty) continue;

      var score = 0.0;
      for (final term in queryTerms.toSet()) {
        final tf = doc.where((t) => t == term).length;
        if (tf == 0) continue;

        final df = docFrequency[term]!;
        final idf = log(1 + (docs.length - df + 0.5) / (df + 0.5));
        final norm = tf * (k1 + 1) /
            (tf + k1 * (1 - b + b * doc.length / avgLength));
        score += idf * norm;
      }
      if (score > 0) scored.add(ScoredChunk(corpus[i], score));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).toList();
  }

  /// Lowercase, strip punctuation, drop stopwords and single characters.
  /// Stopwords matter here: without them "what is a transformer" scores every
  /// chunk containing "is" and "a", which is all of them.
  static List<String> tokenize(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s-]'), ' ')
      .split(RegExp(r'\s+'))
      .where((t) => t.length > 1 && !_stopwords.contains(t))
      .toList();

  static const _stopwords = {
    'a', 'an', 'the', 'is', 'are', 'was', 'were', 'be', 'been', 'being',
    'of', 'to', 'in', 'on', 'at', 'for', 'with', 'by', 'from', 'as', 'and',
    'or', 'but', 'if', 'then', 'than', 'that', 'this', 'these', 'those',
    'it', 'its', 'we', 'they', 'their', 'our', 'you', 'your', 'he', 'she',
    'do', 'does', 'did', 'can', 'could', 'will', 'would', 'should', 'may',
    'what', 'which', 'who', 'how', 'when', 'where', 'why', 'not', 'no',
    'have', 'has', 'had', 'there', 'here', 'about', 'into', 'over', 'such',
  };
}
