import 'dart:io';

import 'package:syncfusion_flutter_pdf/pdf.dart';

/// A chunk of real text pulled out of a real PDF.
class TextChunk {
  const TextChunk({
    required this.id,
    required this.paperId,
    required this.text,
    required this.pageNumber,
    required this.sectionTitle,
  });

  final String id;
  final String paperId;
  final String text;
  final int pageNumber;
  final String sectionTitle;
}

class ExtractionResult {
  const ExtractionResult({
    required this.chunks,
    required this.pageCount,
    this.title,
    this.authors = const [],
    this.failureReason,
  });

  final List<TextChunk> chunks;
  final int pageCount;
  final String? title;
  final List<String> authors;
  final String? failureReason;

  bool get succeeded => failureReason == null && chunks.isNotEmpty;
}

/// Pulls text out of a PDF entirely on-device — no server, no network.
///
/// This is deliberately simpler than GROBID, which the online pipeline uses:
/// no TEI, no parsed reference list, heuristic section detection only. It is
/// enough to retrieve against, which is all offline mode needs.
abstract final class PdfTextExtractor2 {
  /// ~900 characters, which lands around 200 tokens — small enough that a
  /// 3B model can hold a dozen of them, large enough to carry an argument.
  static const _chunkChars = 900;
  static const _overlapChars = 150;

  static Future<ExtractionResult> extract({
    required String paperId,
    required File file,
  }) async {
    PdfDocument? doc;
    try {
      doc = PdfDocument(inputBytes: await file.readAsBytes());
      final extractor = PdfTextExtractor(doc);
      final pageCount = doc.pages.count;

      final chunks = <TextChunk>[];
      var currentSection = 'Document';

      for (var page = 0; page < pageCount; page++) {
        final raw = extractor.extractText(startPageIndex: page, endPageIndex: page);
        final text = _clean(raw);
        if (text.trim().length < 40) continue;

        final heading = _detectSection(text);
        if (heading != null) currentSection = heading;

        for (final piece in _split(text)) {
          chunks.add(TextChunk(
            id: '${paperId}_p${page + 1}_${chunks.length}',
            paperId: paperId,
            text: piece,
            pageNumber: page + 1,
            sectionTitle: currentSection,
          ));
        }
      }

      if (chunks.isEmpty) {
        // A scanned PDF is images with no text layer. This is the single most
        // common real failure, and it needs saying plainly rather than
        // surfacing as an empty result.
        return ExtractionResult(
          chunks: const [],
          pageCount: pageCount,
          failureReason:
              'No text layer found — this looks like a scanned PDF. '
              'Run it through OCR first.',
        );
      }

      return ExtractionResult(
        chunks: chunks,
        pageCount: pageCount,
        title: _guessTitle(doc, chunks),
        authors: const [],
      );
    } catch (e) {
      return ExtractionResult(
        chunks: const [],
        pageCount: 0,
        failureReason: 'Could not read this PDF: $e',
      );
    } finally {
      doc?.dispose();
    }
  }

  /// PDF extraction leaves hard line breaks mid-sentence and hyphenated words
  /// split across lines. Both wreck retrieval if left in.
  static String _clean(String raw) => raw
      .replaceAll(RegExp(r'-\n\s*'), '')
      .replaceAll(RegExp(r'\n(?=[a-z,;])'), ' ')
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n');

  /// Heuristic only: numbered headings and the standard paper sections.
  /// Wrong sometimes, which is why offline mode does not weight by section
  /// the way the online pipeline does.
  static String? _detectSection(String pageText) {
    for (final line in pageText.split('\n').take(6)) {
      final t = line.trim();
      if (t.isEmpty || t.length > 60) continue;

      if (RegExp(r'^\d+\.?\s+[A-Z]').hasMatch(t)) return t;
      const known = [
        'abstract', 'introduction', 'related work', 'background', 'method',
        'methods', 'methodology', 'approach', 'experiments', 'evaluation',
        'results', 'discussion', 'conclusion', 'conclusions', 'references',
        'limitations',
      ];
      if (known.contains(t.toLowerCase())) return t;
    }
    return null;
  }

  /// Splits on sentence boundaries so a chunk never ends mid-clause.
  static List<String> _split(String text) {
    final sentences = text.split(RegExp(r'(?<=[.!?])\s+'));
    final chunks = <String>[];
    final buffer = StringBuffer();

    for (final sentence in sentences) {
      if (buffer.length + sentence.length > _chunkChars &&
          buffer.isNotEmpty) {
        final chunk = buffer.toString().trim();
        if (chunk.length > 80) chunks.add(chunk);

        // Carry the tail forward so an argument split across a boundary is
        // still retrievable from either side.
        final tail = chunk.length > _overlapChars
            ? chunk.substring(chunk.length - _overlapChars)
            : chunk;
        buffer
          ..clear()
          ..write('$tail ');
      }
      buffer.write('$sentence ');
    }

    final last = buffer.toString().trim();
    if (last.length > 80) chunks.add(last);
    return chunks;
  }

  static String? _guessTitle(PdfDocument doc, List<TextChunk> chunks) {
    final metaTitle = doc.documentInformation.title.trim();
    if (metaTitle.length > 5) return metaTitle;

    // Otherwise the first substantial line of page 1, which is the title in
    // most papers.
    final first = chunks.firstOrNull;
    if (first == null) return null;
    for (final line in first.text.split(RegExp(r'[.\n]'))) {
      final t = line.trim();
      if (t.length > 15 && t.length < 160) return t;
    }
    return null;
  }
}
