import '../../domain/entities/paper.dart';

/// DTO boundary. Entities never learn about JSON; models never leak upward.
extension PaperMapper on Map<String, dynamic> {
  Paper toPaper() => Paper(
        id: this['id'] as String,
        title: this['title'] as String,
        authors: (this['authors'] as List).cast<String>(),
        year: this['year'] as int,
        venue: this['venue'] as String? ?? '',
        doi: this['doi'] as String? ?? '',
        citationCount: this['citationCount'] as int? ?? 0,
        relevance: (this['relevance'] as num?)?.toDouble() ?? 0,
        whyIncluded: this['whyIncluded'] as String? ?? '',
        parseConfidence: switch (this['parseConfidence'] as String?) {
          'low' => ParseConfidence.low,
          'medium' => ParseConfidence.medium,
          _ => ParseConfidence.high,
        },
        openAccessUrl: this['oaUrl'] as String?,
        extraction: this['extraction'] == null
            ? null
            : (this['extraction'] as Map<String, dynamic>).toExtraction(),
      );

  Extraction toExtraction() => Extraction(
        problem: this['problem'] as String? ?? '',
        method: MethodRecord(
          name: (this['method']?['name'] as String?) ?? '',
          family: (this['method']?['family'] as String?) ?? '',
          summary: (this['method']?['summary'] as String?) ?? '',
          novelty: (this['method']?['novelty'] as String?) ?? '',
        ),
        datasets: _facts('datasets'),
        metrics: _facts('metrics'),
        baselines: (this['baselines'] as List?)?.cast<String>() ?? const [],
        limitations: ((this['limitations'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map((l) => Limitation(
                  text: l['text'] as String? ?? '',
                  statedByAuthors: l['statedByAuthors'] as bool? ?? true,
                  chunkId: l['chunkId'] as String?,
                ))
            .toList(),
        claimedContribution: this['claimedContribution'] as String? ?? '',
      );

  List<NamedFact> _facts(String key) =>
      ((this[key] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map((f) => NamedFact(
                name: f['name'] as String? ?? '',
                value: f['value'] as String? ?? '',
                chunkId: f['chunkId'] as String?,
              ))
          .toList();
}

Map<String, dynamic> paperToJson(Paper p) => {
      'id': p.id,
      'title': p.title,
      'authors': p.authors,
      'year': p.year,
      'venue': p.venue,
      'doi': p.doi,
      'citationCount': p.citationCount,
      'relevance': p.relevance,
      'whyIncluded': p.whyIncluded,
      'parseConfidence': p.parseConfidence.name,
      'oaUrl': p.openAccessUrl,
    };
