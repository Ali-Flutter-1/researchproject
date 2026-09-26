import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../../export/domain/entities/citation_style.dart';
import '../../../research/domain/entities/research_run.dart';

/// Everything the user can set once and have apply to every future run.
///
/// These are genuine defaults, not preferences in the decorative sense: the
/// Ask screen and the export sheet both start from them, so a researcher who
/// works in Vancouver and reads 30 papers at a time sets that once.
class AppSettings extends Equatable {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.citationStyle = CitationStyle.apa,
    this.exportFormat = ExportFormat.markdown,
    this.bibliographyFormat = BibliographyFormat.bibtex,
    this.paperCount = 20,
    this.yearFrom = 2019,
    this.yearTo = 2026,
    this.openAccessOnly = true,
    this.includeLibraryByDefault = false,
  });

  final ThemeMode themeMode;
  final CitationStyle citationStyle;
  final ExportFormat exportFormat;
  final BibliographyFormat bibliographyFormat;
  final int paperCount;
  final int yearFrom;
  final int yearTo;
  final bool openAccessOnly;
  final bool includeLibraryByDefault;

  /// The run options a new question starts from.
  RunOptions toRunOptions() => RunOptions(
        yearFrom: yearFrom,
        yearTo: yearTo,
        paperCount: paperCount,
        openAccessOnly: openAccessOnly,
        includeLibrary: includeLibraryByDefault,
      );

  /// The export request the sheet opens on.
  ExportRequest toExportRequest() => ExportRequest(
        format: exportFormat,
        citationStyle: citationStyle,
        bibliographyFormat: bibliographyFormat,
      );

  AppSettings copyWith({
    ThemeMode? themeMode,
    CitationStyle? citationStyle,
    ExportFormat? exportFormat,
    BibliographyFormat? bibliographyFormat,
    int? paperCount,
    int? yearFrom,
    int? yearTo,
    bool? openAccessOnly,
    bool? includeLibraryByDefault,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        citationStyle: citationStyle ?? this.citationStyle,
        exportFormat: exportFormat ?? this.exportFormat,
        bibliographyFormat: bibliographyFormat ?? this.bibliographyFormat,
        paperCount: paperCount ?? this.paperCount,
        yearFrom: yearFrom ?? this.yearFrom,
        yearTo: yearTo ?? this.yearTo,
        openAccessOnly: openAccessOnly ?? this.openAccessOnly,
        includeLibraryByDefault:
            includeLibraryByDefault ?? this.includeLibraryByDefault,
      );

  @override
  List<Object?> get props => [
        themeMode,
        citationStyle,
        exportFormat,
        bibliographyFormat,
        paperCount,
        yearFrom,
        yearTo,
        openAccessOnly,
        includeLibraryByDefault,
      ];
}
