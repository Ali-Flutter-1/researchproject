import 'dart:async';

import 'package:file_picker/file_picker.dart';

import '../domain/entities/library_paper.dart';
import '../domain/repositories/library_repository.dart';

/// The picker is real; the ingest behind it is simulated until the API lands.
/// The status progression and the failure case are modelled honestly, so the
/// list is built against the states it will actually see.
class LibraryRepositoryImpl implements LibraryRepository {
  final _papers = <LibraryPaper>[];
  final _controller = StreamController<List<LibraryPaper>>.broadcast();

  @override
  Future<List<PickedPdf>> pickPdfs() async {
    // file_picker 13: a static call that returns an empty list when the user
    // cancels — cancelling is not an error and must not be reported as one.
    final files = await FilePicker.pickFiles(
      dialogTitle: 'Add papers to your library',
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );

    final picked = <PickedPdf>[];
    for (final f in files) {
      // On web there is no path, so the bytes have to be read up front.
      // On mobile the path is enough and reading a 20MB PDF into memory
      // just to know its size would be wasteful.
      final path = f.path;
      final bytes = path == null ? await f.readAsBytes() : null;
      picked.add(PickedPdf(
        filename: f.name,
        sizeBytes: f.lengthSync() ?? await f.length() ?? bytes?.length ?? 0,
        path: path,
        bytes: bytes,
      ));
    }
    return picked;
  }

  @override
  Stream<List<LibraryPaper>> watchLibrary() async* {
    yield List.unmodifiable(_papers);
    yield* _controller.stream;
  }

  @override
  Future<void> add(List<PickedPdf> files) async {
    final added = <LibraryPaper>[];
    for (final f in files) {
      final paper = LibraryPaper(
        id: 'lib_${DateTime.now().microsecondsSinceEpoch}_${f.filename.hashCode}',
        filename: f.filename,
        sizeBytes: f.sizeBytes,
        addedAt: DateTime.now(),
      );
      _papers.insert(0, paper);
      added.add(paper);
    }
    _emit();

    // Ingest each in turn. Serial, because the real pipeline is bounded by
    // the GROBID pool rather than by client concurrency.
    for (final paper in added) {
      await _ingest(paper.id);
    }
  }

  @override
  Future<void> remove(String id) async {
    _papers.removeWhere((p) => p.id == id);
    _emit();
  }

  Future<void> _ingest(String id) async {
    Future<void> step(IngestStatus status, int ms) async {
      await Future<void>.delayed(Duration(milliseconds: ms));
      _update(id, (p) => p.copyWith(status: status));
    }

    await step(IngestStatus.parsing, 700);
    await step(IngestStatus.chunking, 900);
    await Future<void>.delayed(const Duration(milliseconds: 500));

    final paper = _papers.where((p) => p.id == id).firstOrNull;
    if (paper == null) return;

    // A scanned PDF has no text layer and cannot be parsed. Roughly one in
    // six real uploads hits this, so the UI must handle it as a normal case.
    final failed = paper.sizeBytes > 0 && paper.filename.hashCode % 6 == 0;
    _update(
      id,
      (p) => failed
          ? p.copyWith(
              status: IngestStatus.failed,
              error: 'No text layer found — this looks like a scanned PDF.',
            )
          : p.copyWith(
              status: IngestStatus.ready,
              title: _titleFrom(p.filename),
              pageCount: 8 + (p.filename.hashCode.abs() % 14),
              chunkCount: 40 + (p.filename.hashCode.abs() % 60),
            ),
    );
  }

  void _update(String id, LibraryPaper Function(LibraryPaper) f) {
    final i = _papers.indexWhere((p) => p.id == id);
    if (i == -1) return;
    _papers[i] = f(_papers[i]);
    _emit();
  }

  void _emit() => _controller.add(List.unmodifiable(_papers));

  /// Until the parser returns a real title, a cleaned-up filename beats
  /// showing "2403.01922v2.pdf".
  static String _titleFrom(String filename) {
    final stem = filename.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
    final cleaned = stem
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? filename : cleaned;
  }
}
