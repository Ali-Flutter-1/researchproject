import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../research/domain/entities/research_run.dart';
import '../../../research/domain/usecases/build_comparison.dart';
import '../../domain/entities/citation_style.dart';
import '../../domain/services/citation_formatter.dart';

/// A printable report.
///
/// The PDF package has its own widget tree — deliberately similar to Flutter's
/// but unrelated, so nothing here can be shared with the on-screen widgets.
abstract final class PdfExporter {
  static Future<List<int>> export(
    ResearchRun run,
    ExportRequest request,
  ) async {
    final doc = pw.Document(title: run.question);
    final theme = await _theme();

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          theme: theme,
          margin: const pw.EdgeInsets.fromLTRB(48, 54, 48, 54),
        ),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            '${ctx.pageNumber} / ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (ctx) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              run.question,
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Text(
            '${_date(run.createdAt)} · ${run.papers.length} papers analysed',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          if (run.claims.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _calloutBox(
              '${run.claims.length} claims · ${run.verifiedCount} verified '
              'against source · ${run.needsCheckCount} need checking',
            ),
          ],
          if (run.synthesis.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            _heading('Findings'),
            for (final p in run.synthesis) ...[
              pw.Paragraph(
                text: _stripMarkers(p),
                style: const pw.TextStyle(fontSize: 11, lineSpacing: 3.5),
              ),
            ],
          ],
          if (request.includeUnverifiedClaims && run.needsCheckCount > 0) ...[
            pw.SizedBox(height: 12),
            _heading('Statements needing verification'),
            for (final c in run.claims.where((c) => c.status.needsAttention))
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 8),
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.orange50,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      c.status.label.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.orange800,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(c.text, style: const pw.TextStyle(fontSize: 10)),
                    if (c.note.isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        c.note,
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey700,
                          fontStyle: pw.FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
          if (request.includeMatrix) ...[
            pw.SizedBox(height: 16),
            _heading('Comparison'),
            _matrix(run),
          ],
          if (request.includeGaps && run.gaps.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _heading('Research gaps'),
            for (final g in run.gaps)
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      g.statement,
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      g.evidence,
                      style: const pw.TextStyle(
                        fontSize: 9.5,
                        color: PdfColors.grey800,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          pw.SizedBox(height: 16),
          _heading('References'),
          for (var i = 0; i < run.papers.length; i++)
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 5),
              child: pw.Text(
                '${i + 1}. ${_plain(CitationFormatter.format(run.papers[i], request.citationStyle))}',
                style: const pw.TextStyle(fontSize: 9.5, lineSpacing: 2),
              ),
            ),
        ],
      ),
    );

    return doc.save();
  }

  /// The PDF package defaults to Helvetica, which has no Unicode support:
  /// an em dash, an accented author name (Fernández, Müller) or a Greek
  /// symbol (κ, ε) silently fails to draw. Research bibliographies are full
  /// of all three, so the app's own fonts are embedded instead.
  static Future<pw.ThemeData> _theme() async {
    final sans = pw.Font.ttf(
      await rootBundle.load('assets/fonts/HankenGrotesk.ttf'),
    );
    final serif = pw.Font.ttf(
      await rootBundle.load('assets/fonts/LibreCaslonText.ttf'),
    );
    return pw.ThemeData.withFont(
      base: serif,
      bold: sans,
      italic: serif,
      fontFallback: [sans, serif],
    );
  }

  static pw.Widget _heading(String text) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 8, top: 4),
        child: pw.Text(
          text,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
      );

  static pw.Widget _calloutBox(String text) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
      );

  static pw.Widget _matrix(ResearchRun run) {
    final rows = const BuildComparison()(run);
    if (rows.isEmpty) return pw.SizedBox();

    return pw.TableHelper.fromTextArray(
      cellStyle: const pw.TextStyle(fontSize: 7.5),
      headerStyle: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellAlignment: pw.Alignment.topLeft,
      cellPadding: const pw.EdgeInsets.all(4),
      columnWidths: {
        0: const pw.FlexColumnWidth(2.4),
        for (var i = 1; i <= BuildComparison.columns.length; i++)
          i: const pw.FlexColumnWidth(1.3),
      },
      data: [
        ['Paper', ...BuildComparison.columns],
        for (final r in rows)
          [
            '${r.paper.authorLine}, ${r.paper.year}',
            for (final c in BuildComparison.columns)
              r.cells[c]!.isEmpty ? '—' : r.cells[c]!.values.join('; '),
          ],
      ],
    );
  }

  /// The synthesis carries `[[claimId]]` markers and the citation strings
  /// carry Markdown emphasis. Neither means anything in a PDF text run.
  static String _stripMarkers(String s) =>
      s.replaceAll(RegExp(r'\[\[\w+\]\]'), '').replaceAll(RegExp(r'\s+\.'), '.');

  static String _plain(String s) => s.replaceAll('*', '');

  static String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
