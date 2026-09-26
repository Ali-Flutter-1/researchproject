import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/entities/library_paper.dart';

/// Keeps uploaded PDFs on the device.
///
/// Two things live on disk: the PDF bytes, under a stable per-paper filename,
/// and a JSON index of the metadata. The index is the source of truth for what
/// the library contains; the PDFs are content-addressed by paper id so a file
/// can never be confused for another paper's.
///
/// Files go in the documents directory rather than the cache directory —
/// iOS and Android both evict caches under storage pressure, and a library
/// that silently empties itself is worse than one that never persisted.
class LibraryStorage {
  static const _indexFile = 'library_index.json';
  static const _folder = 'library';

  Directory? _root;

  Future<Directory> _dir() async {
    if (_root != null) return _root!;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$_folder');
    if (!dir.existsSync()) await dir.create(recursive: true);
    return _root = dir;
  }

  Future<File> pdfFile(String paperId) async =>
      File('${(await _dir()).path}/$paperId.pdf');

  /// Copies the picked file in. Takes the path on mobile and desktop, bytes on
  /// web — where this whole class is a no-op that only writes the index.
  Future<int> store(String paperId, PickedPdf picked) async {
    final target = await pdfFile(paperId);
    if (picked.bytes != null) {
      await target.writeAsBytes(picked.bytes!);
    } else if (picked.path != null) {
      // The picker hands back a path in a temp/inbox location the OS may
      // clear at any time, so copy rather than referencing it.
      await File(picked.path!).copy(target.path);
    } else {
      return 0;
    }
    return target.lengthSync();
  }

  Future<void> delete(String paperId) async {
    final file = await pdfFile(paperId);
    if (file.existsSync()) await file.delete();
  }

  Future<bool> exists(String paperId) async =>
      (await pdfFile(paperId)).existsSync();

  /// Total bytes held, for the storage line in the UI.
  Future<int> usedBytes() async {
    final dir = await _dir();
    var total = 0;
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.pdf')) {
        total += entity.lengthSync();
      }
    }
    return total;
  }

  // --- Index ----------------------------------------------------------------

  Future<List<LibraryPaper>> loadIndex() async {
    final file = File('${(await _dir()).path}/$_indexFile');
    if (!file.existsSync()) return [];
    try {
      final raw = jsonDecode(await file.readAsString()) as List;
      final papers = raw
          .cast<Map<String, dynamic>>()
          .map(_fromJson)
          .toList();

      // Drop entries whose PDF is gone — a restored backup or a manual file
      // deletion would otherwise leave rows that open to nothing.
      final surviving = <LibraryPaper>[];
      for (final p in papers) {
        if (await exists(p.id)) surviving.add(p);
      }
      if (surviving.length != papers.length) await saveIndex(surviving);
      return surviving;
    } catch (_) {
      // A corrupt index must not brick the library. Start clean; the PDFs
      // themselves are still on disk and can be re-added.
      return [];
    }
  }

  Future<void> saveIndex(List<LibraryPaper> papers) async {
    final file = File('${(await _dir()).path}/$_indexFile');
    await file.writeAsString(
      jsonEncode(papers.map(_toJson).toList()),
    );
  }

  static Map<String, dynamic> _toJson(LibraryPaper p) => {
        'id': p.id,
        'filename': p.filename,
        'sizeBytes': p.sizeBytes,
        'addedAt': p.addedAt.toIso8601String(),
        // An in-flight ingest cannot survive a restart, so anything that was
        // mid-parse is written back as queued and picked up again on launch.
        'status': p.status.isTerminal ? p.status.name : IngestStatus.queued.name,
        'title': p.title,
        'authors': p.authors,
        'year': p.year,
        'pageCount': p.pageCount,
        'chunkCount': p.chunkCount,
        'error': p.error,
      };

  static LibraryPaper _fromJson(Map<String, dynamic> j) => LibraryPaper(
        id: j['id'] as String,
        filename: j['filename'] as String,
        sizeBytes: j['sizeBytes'] as int? ?? 0,
        addedAt: DateTime.tryParse(j['addedAt'] as String? ?? '') ??
            DateTime.now(),
        status: IngestStatus.values
                .where((s) => s.name == j['status'])
                .firstOrNull ??
            IngestStatus.queued,
        title: j['title'] as String?,
        authors: ((j['authors'] as List?) ?? const []).cast<String>(),
        year: j['year'] as int?,
        pageCount: j['pageCount'] as int?,
        chunkCount: j['chunkCount'] as int?,
        error: j['error'] as String?,
      );
}
