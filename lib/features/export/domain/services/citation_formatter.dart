import '../../../research/domain/entities/paper.dart';
import '../entities/citation_style.dart';

/// Formats a [Paper] into a reference-list entry.
///
/// Author names arrive as "Surname, I." from the parser, so every style here
/// starts by splitting that back into parts. Styles disagree about almost
/// everything — author order, initials, italics, how many authors before
/// "et al.", where the year goes — so each is written out rather than
/// derived from a shared template, which is clearer to correct later.
abstract final class CitationFormatter {
  static String format(Paper paper, CitationStyle style) => switch (style) {
        CitationStyle.apa => _apa(paper),
        CitationStyle.mla => _mla(paper),
        CitationStyle.chicago => _chicago(paper),
        CitationStyle.ieee => _ieee(paper),
        CitationStyle.harvard => _harvard(paper),
        CitationStyle.vancouver => _vancouver(paper),
      };

  /// An in-text marker, e.g. "(Okonkwo et al., 2024)" or "[1]".
  static String inText(Paper paper, CitationStyle style, int number) {
    final surname = _surname(paper.authors.firstOrNull ?? 'Unknown');
    final etAl = paper.authors.length > 2;
    return switch (style) {
      CitationStyle.ieee => '[$number]',
      CitationStyle.vancouver => '($number)',
      CitationStyle.mla => '($surname)',
      CitationStyle.apa ||
      CitationStyle.harvard =>
        '($surname${etAl ? ' et al.' : ''}, ${paper.year})',
      CitationStyle.chicago =>
        '($surname${etAl ? ' et al.' : ''} ${paper.year})',
    };
  }

  // --- Styles ---------------------------------------------------------------

  /// APA 7th: up to 20 authors listed; "&" before the last.
  static String _apa(Paper p) {
    final authors = _joinApa(p.authors);
    return '$authors (${p.year}). ${_stripTerminal(p.title)}. '
        '*${p.venue}*.${_doiSuffix(p, 'https://doi.org/')}';
  }

  /// MLA 9th: first author inverted, the rest natural; "et al." past two.
  static String _mla(Paper p) {
    final first = p.authors.firstOrNull ?? 'Unknown';
    final authors = switch (p.authors.length) {
      0 || 1 => first,
      2 => '$first, and ${_natural(p.authors[1])}',
      _ => '$first, et al.',
    };
    return '$authors. "${_stripTerminal(p.title)}." '
        '*${p.venue}*, ${p.year}.${_doiSuffix(p, 'https://doi.org/')}';
  }

  /// Chicago 17th, notes-bibliography form.
  static String _chicago(Paper p) {
    final first = p.authors.firstOrNull ?? 'Unknown';
    final rest = p.authors.skip(1).map(_natural).toList();
    final authors = rest.isEmpty
        ? first
        : rest.length == 1
            ? '$first and ${rest.first}'
            : '$first, ${rest.take(rest.length - 1).join(', ')}, '
                'and ${rest.last}';
    return '$authors. "${_stripTerminal(p.title)}." '
        '*${p.venue}* (${p.year}).${_doiSuffix(p, 'https://doi.org/')}';
  }

  /// IEEE: initials first, numbered reference list.
  static String _ieee(Paper p) {
    final authors = p.authors.map(_initialsFirst).toList();
    final joined = switch (authors.length) {
      0 => 'Unknown',
      1 => authors.first,
      _ => '${authors.take(authors.length - 1).join(', ')}, '
          'and ${authors.last}',
    };
    return '$joined, "${_stripTerminal(p.title)}," in *${p.venue}*, '
        '${p.year}.${_doiSuffix(p, 'doi: ', bare: true)}';
  }

  /// Harvard: close to APA, but no parentheses around the year in some
  /// variants — this uses the common author-date form.
  static String _harvard(Paper p) {
    final authors = _joinApa(p.authors);
    return '$authors ${p.year}, \'${_stripTerminal(p.title)}\', '
        '*${p.venue}*.${_doiSuffix(p, 'https://doi.org/')}';
  }

  /// Vancouver: no italics, initials without periods, up to 6 authors.
  static String _vancouver(Paper p) {
    final authors = p.authors.map(_vancouverName).toList();
    final joined = authors.length > 6
        ? '${authors.take(6).join(', ')}, et al.'
        : authors.join(', ');
    return '$joined. ${_stripTerminal(p.title)}. ${p.venue}. '
        '${p.year}.${_doiSuffix(p, 'doi:', bare: true)}';
  }

  // --- Name helpers ---------------------------------------------------------

  static String _surname(String name) => name.split(',').first.trim();

  static String _initials(String name) {
    final parts = name.split(',');
    return parts.length > 1 ? parts[1].trim() : '';
  }

  /// "Okonkwo, A." -> "A. Okonkwo"
  static String _natural(String name) {
    final initials = _initials(name);
    return initials.isEmpty ? name : '$initials ${_surname(name)}';
  }

  static String _initialsFirst(String name) => _natural(name);

  /// "Okonkwo, A." -> "Okonkwo A"
  static String _vancouverName(String name) {
    final initials = _initials(name).replaceAll('.', '').replaceAll(' ', '');
    return initials.isEmpty ? _surname(name) : '${_surname(name)} $initials';
  }

  static String _joinApa(List<String> authors) => switch (authors.length) {
        0 => 'Unknown',
        1 => authors.first,
        _ => '${authors.take(authors.length - 1).join(', ')}, '
            '& ${authors.last}',
      };

  // --- Small formatting rules ----------------------------------------------

  /// Titles already ending in "?" or "!" keep it; otherwise the style's own
  /// period is appended by the caller. Avoids "A Controlled Study..".
  static String _stripTerminal(String title) =>
      title.endsWith('.') ? title.substring(0, title.length - 1) : title;

  static String _doiSuffix(Paper p, String prefix, {bool bare = false}) {
    if (p.doi.isEmpty) return '';
    return bare ? ' $prefix${p.doi}' : ' $prefix${p.doi}';
  }

  /// A stable BibTeX key: surname + year + first title word, lowercased.
  static String bibtexKey(Paper p) {
    final surname = _surname(p.authors.firstOrNull ?? 'unknown')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z]'), '');
    final word = p.title
        .split(RegExp(r'\s+'))
        .firstWhere((w) => w.length > 3, orElse: () => 'paper')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z]'), '');
    return '$surname${p.year}$word';
  }
}
