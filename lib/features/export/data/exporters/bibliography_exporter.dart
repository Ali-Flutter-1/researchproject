import 'dart:convert';

import '../../../research/domain/entities/paper.dart';
import '../../domain/entities/citation_style.dart';
import '../../domain/services/citation_formatter.dart';

/// Machine-readable bibliography output, for importing into a reference
/// manager. These are strict formats — a stray unescaped brace or a missing
/// "ER  -" line makes the whole file fail to import, usually silently.
abstract final class BibliographyExporter {
  static String export(List<Paper> papers, BibliographyFormat format) =>
      switch (format) {
        BibliographyFormat.bibtex => _bibtex(papers),
        BibliographyFormat.ris => _ris(papers),
        BibliographyFormat.csl => _csl(papers),
      };

  static String _bibtex(List<Paper> papers) => papers.map((p) {
        final key = CitationFormatter.bibtexKey(p);
        // Braces around the title preserve capitalisation; BibTeX otherwise
        // lowercases it, which mangles acronyms like "XLM-R".
        return '@inproceedings{$key,\n'
            '  title     = {{${_escape(p.title)}}},\n'
            '  author    = {${p.authors.map(_escape).join(' and ')}},\n'
            '  booktitle = {${_escape(p.venue)}},\n'
            '  year      = {${p.year}},\n'
            '${p.doi.isEmpty ? '' : '  doi       = {${p.doi}},\n'}'
            '}';
      }).join('\n\n');

  static String _ris(List<Paper> papers) => papers.map((p) {
        final b = StringBuffer()
          ..writeln('TY  - CONF')
          ..writeln('TI  - ${p.title}');
        for (final a in p.authors) {
          b.writeln('AU  - $a');
        }
        b.writeln('PY  - ${p.year}');
        if (p.venue.isNotEmpty) b.writeln('BT  - ${p.venue}');
        if (p.doi.isNotEmpty) b.writeln('DO  - ${p.doi}');
        if (p.openAccessUrl != null) b.writeln('UR  - ${p.openAccessUrl}');
        // ER terminates the record. Omitting it invalidates the file.
        b.writeln('ER  - ');
        return b.toString();
      }).join('\n');

  static String _csl(List<Paper> papers) {
    final items = papers.map((p) => {
          'id': CitationFormatter.bibtexKey(p),
          'type': 'paper-conference',
          'title': p.title,
          'author': p.authors.map((a) {
            final parts = a.split(',');
            return {
              'family': parts.first.trim(),
              if (parts.length > 1) 'given': parts[1].trim(),
            };
          }).toList(),
          'container-title': p.venue,
          'issued': {
            'date-parts': [
              [p.year]
            ]
          },
          if (p.doi.isNotEmpty) 'DOI': p.doi,
        });
    return const JsonEncoder.withIndent('  ').convert(items.toList());
  }

  /// BibTeX treats these as control characters.
  static String _escape(String s) => s
      .replaceAll(r'\', r'\textbackslash ')
      .replaceAll('{', r'\{')
      .replaceAll('}', r'\}')
      .replaceAll(r'&', r'\&')
      .replaceAll('%', r'\%')
      .replaceAll(r'$', r'\$')
      .replaceAll('#', r'\#')
      .replaceAll('_', r'\_');
}
