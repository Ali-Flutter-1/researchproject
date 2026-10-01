import 'package:flutter_test/flutter_test.dart';
import 'package:practsearch/features/library/data/pdf_text_extractor.dart';
import 'package:practsearch/features/library/domain/services/bm25_retriever.dart';

TextChunk _c(String id, String text) => TextChunk(
      id: id,
      paperId: 'p',
      text: text,
      pageNumber: 1,
      sectionTitle: 'Body',
    );

final _corpus = [
  _c('1', 'The Transformer follows an encoder-decoder structure using '
      'stacked self-attention and point-wise fully connected layers.'),
  _c('2', 'Recurrent neural networks process sequences one step at a time, '
      'which prevents parallelisation within training examples.'),
  _c('3', 'We evaluate on the MIMIC-III clinical database and report an '
      'AUROC of 0.84 against the logistic regression baseline.'),
  _c('4', 'Convolutional architectures reduce sequential computation but '
      'still require many layers to relate distant positions.'),
];

void main() {
  const retriever = Bm25Retriever();

  test('finds the chunk that actually answers the question', () {
    final hits = retriever.search(
      query: 'What is a transformer?',
      corpus: _corpus,
    );
    expect(hits.first.chunk.id, '1');
  });

  test('matches exact named entities, which is BM25 s whole advantage', () {
    // Dense retrieval blurs rare tokens like dataset names; keyword search
    // nails them. This is why offline mode uses BM25 rather than nothing.
    final hits = retriever.search(query: 'MIMIC-III', corpus: _corpus);
    expect(hits.first.chunk.id, '3');
  });

  test('stopwords do not drag in every chunk', () {
    // "what is a" appears in effectively every document. Without stopword
    // removal this query would return the whole corpus ranked by length.
    final hits = retriever.search(query: 'what is a', corpus: _corpus);
    expect(hits, isEmpty);
  });

  test('returns nothing when the library has no match', () {
    final hits = retriever.search(
      query: 'photosynthesis chlorophyll',
      corpus: _corpus,
    );
    expect(hits, isEmpty,
        reason: 'an empty result is what makes the UI say "nothing in your '
            'library matches" rather than inventing an answer');
  });

  test('handles an empty corpus without throwing', () {
    expect(retriever.search(query: 'anything', corpus: const []), isEmpty);
  });

  test('ranks by relevance, not document order', () {
    final hits = retriever.search(
      query: 'self-attention layers encoder',
      corpus: _corpus,
    );
    expect(hits.first.chunk.id, '1');
    expect(hits.first.score, greaterThan(hits.last.score));
  });

  test('respects the limit', () {
    final hits = retriever.search(query: 'layers', corpus: _corpus, limit: 1);
    expect(hits, hasLength(1));
  });

  group('tokenizer', () {
    test('keeps hyphenated technical terms intact', () {
      expect(Bm25Retriever.tokenize('MIMIC-III'), contains('mimic-iii'));
    });

    test('drops punctuation and single characters', () {
      expect(
        Bm25Retriever.tokenize('A transformer, indeed!'),
        ['transformer', 'indeed'],
      );
    });
  });
}
