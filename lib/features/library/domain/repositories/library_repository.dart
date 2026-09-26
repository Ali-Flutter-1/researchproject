import '../entities/library_paper.dart';

abstract interface class LibraryRepository {
  /// Opens the system file picker, PDFs only.
  /// Returns an empty list when the user cancels — cancelling is not an error.
  Future<List<PickedPdf>> pickPdfs();

  /// Adds picked files and starts ingest. Emits on every status change so the
  /// list can show per-paper progress.
  Stream<List<LibraryPaper>> watchLibrary();

  Future<void> add(List<PickedPdf> files);

  Future<void> remove(String id);
}
