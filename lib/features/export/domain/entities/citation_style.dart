/// Citation styles a researcher is likely to need. Each maps to a real
/// published convention — getting the punctuation wrong is the kind of detail
/// that makes a tool feel untrustworthy, so the formatters follow the actual
/// rules rather than approximating a generic "author, year" shape.
enum CitationStyle {
  apa('APA 7th', 'Psychology, education, social sciences'),
  mla('MLA 9th', 'Humanities, literature'),
  chicago('Chicago 17th', 'History, arts (notes-bibliography)'),
  ieee('IEEE', 'Engineering, computer science'),
  harvard('Harvard', 'Widely used in the UK and Australia'),
  vancouver('Vancouver', 'Medicine, biomedical sciences');

  const CitationStyle(this.label, this.usedFor);
  final String label;
  final String usedFor;
}

/// Machine-readable bibliography formats, for importing into a reference
/// manager rather than pasting into a document.
enum BibliographyFormat {
  bibtex('BibTeX', '.bib', 'LaTeX, Zotero, Mendeley'),
  ris('RIS', '.ris', 'EndNote, Zotero, Papers'),
  csl('CSL-JSON', '.json', 'Pandoc, Zotero');

  const BibliographyFormat(this.label, this.extension, this.usedBy);
  final String label;
  final String extension;
  final String usedBy;
}

/// What the user is exporting.
enum ExportFormat {
  markdown('Markdown report', '.md', 'Full report — synthesis, matrix, gaps'),
  pdf('PDF report', '.pdf', 'Formatted for printing and sharing'),
  bibliography('Bibliography', '', 'References only, for a reference manager'),
  csv('Comparison matrix (CSV)', '.csv', 'The matrix, for a spreadsheet'),
  json('Raw data (JSON)', '.json', 'Everything, for your own processing');

  const ExportFormat(this.label, this.extension, this.description);
  final String label;
  final String extension;
  final String description;
}

/// What the user chose. Kept as one object so the use case has a single input
/// and the sheet has a single piece of state.
class ExportRequest {
  const ExportRequest({
    this.format = ExportFormat.markdown,
    this.citationStyle = CitationStyle.apa,
    this.bibliographyFormat = BibliographyFormat.bibtex,
    this.includeUnverifiedClaims = true,
    this.includeGaps = true,
    this.includeMatrix = true,
    this.includeAbstracts = false,
  });

  final ExportFormat format;
  final CitationStyle citationStyle;
  final BibliographyFormat bibliographyFormat;

  /// Off would mean silently dropping the claims the system could not confirm.
  /// Defaults on, and the exporter marks them rather than hiding them.
  final bool includeUnverifiedClaims;

  final bool includeGaps;
  final bool includeMatrix;
  final bool includeAbstracts;

  ExportRequest copyWith({
    ExportFormat? format,
    CitationStyle? citationStyle,
    BibliographyFormat? bibliographyFormat,
    bool? includeUnverifiedClaims,
    bool? includeGaps,
    bool? includeMatrix,
    bool? includeAbstracts,
  }) =>
      ExportRequest(
        format: format ?? this.format,
        citationStyle: citationStyle ?? this.citationStyle,
        bibliographyFormat: bibliographyFormat ?? this.bibliographyFormat,
        includeUnverifiedClaims:
            includeUnverifiedClaims ?? this.includeUnverifiedClaims,
        includeGaps: includeGaps ?? this.includeGaps,
        includeMatrix: includeMatrix ?? this.includeMatrix,
        includeAbstracts: includeAbstracts ?? this.includeAbstracts,
      );
}

/// The produced artefact, ready to save or share.
class ExportResult {
  const ExportResult({
    required this.filename,
    required this.mimeType,
    this.text,
    this.bytes,
  });

  final String filename;
  final String mimeType;

  /// Set for text formats.
  final String? text;

  /// Set for binary formats (PDF).
  final List<int>? bytes;

  bool get isBinary => bytes != null;
}
