import 'package:equatable/equatable.dart';

/// Where an uploaded PDF is in the ingest pipeline. The same stages the
/// searched papers go through — upload does not get a shortcut, because a
/// paper that was not parsed and embedded cannot be retrieved against.
enum IngestStatus {
  queued('Queued'),
  parsing('Reading'),
  chunking('Indexing'),
  ready('Ready'),
  failed('Could not read');

  const IngestStatus(this.label);
  final String label;

  bool get isTerminal => this == ready || this == failed;
  bool get isWorking => !isTerminal;
}

class LibraryPaper extends Equatable {
  const LibraryPaper({
    required this.id,
    required this.filename,
    required this.sizeBytes,
    required this.addedAt,
    this.status = IngestStatus.queued,
    this.title,
    this.authors = const [],
    this.year,
    this.pageCount,
    this.chunkCount,
    this.error,
  });

  final String id;
  final String filename;
  final int sizeBytes;
  final DateTime addedAt;
  final IngestStatus status;

  /// Filled in by the parser. Until then the filename is all we have to show.
  final String? title;
  final List<String> authors;
  final int? year;
  final int? pageCount;
  final int? chunkCount;
  final String? error;

  String get displayTitle => title ?? filename;

  String get sizeLabel {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  LibraryPaper copyWith({
    IngestStatus? status,
    String? title,
    List<String>? authors,
    int? year,
    int? pageCount,
    int? chunkCount,
    String? error,
  }) =>
      LibraryPaper(
        id: id,
        filename: filename,
        sizeBytes: sizeBytes,
        addedAt: addedAt,
        status: status ?? this.status,
        title: title ?? this.title,
        authors: authors ?? this.authors,
        year: year ?? this.year,
        pageCount: pageCount ?? this.pageCount,
        chunkCount: chunkCount ?? this.chunkCount,
        error: error ?? this.error,
      );

  @override
  List<Object?> get props => [id, status, title, chunkCount];
}

/// A file the user picked, before it becomes a [LibraryPaper].
class PickedPdf {
  const PickedPdf({
    required this.filename,
    required this.sizeBytes,
    this.path,
    this.bytes,
  });

  final String filename;
  final int sizeBytes;

  /// Set on mobile and desktop.
  final String? path;

  /// Set on web, where there is no filesystem path.
  final List<int>? bytes;
}
