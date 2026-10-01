import 'package:flutter_test/flutter_test.dart';
import 'package:practsearch/features/library/domain/entities/library_paper.dart';
import 'package:practsearch/features/research/domain/entities/claim.dart';
import 'package:practsearch/features/inference/domain/entities/llm_model.dart';
import 'package:practsearch/features/inference/domain/repositories/llm_service.dart';
import 'package:practsearch/features/research/domain/services/offline_pipeline.dart';

const _passages = [
  Evidence(
    chunkId: 'c1',
    paperId: 'p1',
    paperTitle: 'Attention Is All You Need',
    sectionTitle: '3 Model Architecture',
    pageNumber: 3,
    text: 'The Transformer follows an encoder-decoder structure using stacked '
        'self-attention and point-wise fully connected layers.',
  ),
  Evidence(
    chunkId: 'c2',
    paperId: 'p2',
    paperTitle: 'BERT',
    sectionTitle: '2 Related Work',
    pageNumber: 2,
    text: 'Bidirectional pre-training allows the model to condition on both '
        'left and right context in all layers.',
  ),
];

void main() {
  group('prompt construction', () {
    test('numbers passages so the model can cite them', () {
      final prompt = OfflinePipeline.buildPrompt(
        question: 'What is a transformer?',
        passages: _passages,
      );
      expect(prompt, contains('[1] From "Attention Is All You Need"'));
      expect(prompt, contains('[2] From "BERT"'));
      expect(prompt, contains('page 3'));
    });

    test('carries the question', () {
      final prompt = OfflinePipeline.buildPrompt(
        question: 'What is a transformer?',
        passages: _passages,
      );
      expect(prompt, startsWith('Question: What is a transformer?'));
    });
  });

  group('claim extraction', () {
    test('binds each cited sentence to its real passage', () {
      const answer = 'A transformer uses stacked self-attention [1]. '
          'BERT extends this with bidirectional pre-training [2].';
      final claims = OfflinePipeline.extractClaims(answer, _passages);

      expect(claims, hasLength(2));
      expect(claims[0].chunkId, 'c1');
      expect(claims[1].chunkId, 'c2');
      expect(claims[0].text, isNot(contains('[1]')),
          reason: 'the marker is stripped from the displayed sentence');
    });

    test('never marks an offline claim as verified', () {
      const answer = 'A transformer uses self-attention [1].';
      final claims = OfflinePipeline.extractClaims(answer, _passages);
      // Offline mode runs no verification stage. Marking these "supported"
      // would borrow the online pipeline's credibility without its work.
      expect(claims.single.status, VerificationStatus.partiallySupported);
      expect(claims.single.note, contains('does not verify'));
    });

    test('drops citations that point outside the passage list', () {
      const answer = 'Something invented entirely [7]. Real thing [1].';
      final claims = OfflinePipeline.extractClaims(answer, _passages);
      expect(claims, hasLength(1));
      expect(claims.single.chunkId, 'c1');
    });

    test('ignores sentences with no citation at all', () {
      const answer = 'Transformers are popular. They use attention [1].';
      final claims = OfflinePipeline.extractClaims(answer, _passages);
      expect(claims, hasLength(1));
    });
  });

  group('empty library', () {
    test('says so instead of answering from the model\'s own knowledge', () async {
      final out = await const OfflinePipeline(_NeverCalled())
          .answer(question: 'What is a transformer?', passages: [], model: 'x')
          .join();
      expect(out, contains('Nothing in your library'));
      // The whole value proposition is "your papers". Silently answering from
      // pretraining would make the feature a lie.
      expect(out, isNot(contains('self-attention')));
    });
  });

  group('library mapping', () {
    test('only exposes papers that finished ingesting', () {
      final papers = OfflinePipeline.toPapers([
        LibraryPaper(
          id: 'a',
          filename: 'ready.pdf',
          sizeBytes: 1,
          addedAt: DateTime(2026),
          status: IngestStatus.ready,
          title: 'Ready Paper',
        ),
        LibraryPaper(
          id: 'b',
          filename: 'broken.pdf',
          sizeBytes: 1,
          addedAt: DateTime(2026),
          status: IngestStatus.failed,
        ),
        LibraryPaper(
          id: 'c',
          filename: 'working.pdf',
          sizeBytes: 1,
          addedAt: DateTime(2026),
          status: IngestStatus.parsing,
        ),
      ]);
      expect(papers, hasLength(1));
      expect(papers.single.title, 'Ready Paper');
    });
  });
}

/// Proves the empty-library path short-circuits before touching the model:
/// every method here throws, so reaching one fails the test loudly.
class _NeverCalled implements LlmService {
  const _NeverCalled();

  @override
  InferenceBackend get backend => InferenceBackend.onDevice;

  @override
  Future<BackendStatus> status() => throw StateError('must not be called');

  @override
  Stream<String> generate({
    required String systemPrompt,
    required String userPrompt,
    required String model,
    double temperature = 0.2,
    int? maxTokens,
  }) =>
      throw StateError('model must not be called with no passages');

  @override
  Future<List<List<double>>> embed({
    required List<String> texts,
    required String model,
  }) =>
      throw StateError('must not be called');
}
