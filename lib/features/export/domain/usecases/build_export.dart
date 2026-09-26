import '../../../research/domain/entities/research_run.dart';
import '../../data/exporters/bibliography_exporter.dart';
import '../../data/exporters/csv_exporter.dart';
import '../../data/exporters/markdown_exporter.dart';
import '../../data/exporters/pdf_exporter.dart';
import '../entities/citation_style.dart';

/// Produces the artefact for an [ExportRequest]. One entry point, so the sheet
/// does not need to know which exporter handles which format.
class BuildExport {
  const BuildExport();

  Future<ExportResult> call(ResearchRun run, ExportRequest request) async {
    final stem = _filenameStem(run.question);

    return switch (request.format) {
      ExportFormat.markdown => ExportResult(
          filename: '$stem.md',
          mimeType: 'text/markdown',
          text: MarkdownExporter.export(run, request),
        ),
      ExportFormat.pdf => ExportResult(
          filename: '$stem.pdf',
          mimeType: 'application/pdf',
          bytes: await PdfExporter.export(run, request),
        ),
      ExportFormat.bibliography => ExportResult(
          filename: '$stem${request.bibliographyFormat.extension}',
          mimeType: switch (request.bibliographyFormat) {
            BibliographyFormat.bibtex => 'application/x-bibtex',
            BibliographyFormat.ris => 'application/x-research-info-systems',
            BibliographyFormat.csl => 'application/json',
          },
          text: BibliographyExporter.export(
            run.papers,
            request.bibliographyFormat,
          ),
        ),
      ExportFormat.csv => ExportResult(
          filename: '$stem.csv',
          mimeType: 'text/csv',
          text: CsvExporter.export(run),
        ),
      ExportFormat.json => ExportResult(
          filename: '$stem.json',
          mimeType: 'application/json',
          text: JsonExporter.export(run),
        ),
    };
  }

  /// A filename from the question: lowercase, words joined by hyphens, capped
  /// so it survives every filesystem the file might land on.
  static String _filenameStem(String question) {
    final slug = question
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .trim()
        .split(RegExp(r'\s+'))
        .take(8)
        .join('-');
    return slug.isEmpty
        ? 'practsearch-report'
        : slug.substring(0, slug.length.clamp(0, 60));
  }
}
