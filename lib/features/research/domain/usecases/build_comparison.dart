import '../entities/paper.dart';
import '../entities/research_run.dart';

/// One cell of the comparison matrix. [isEmpty] matters as much as the value —
/// empty cells are what gaps are made of, so they stay visibly empty.
class MatrixCell {
  const MatrixCell({required this.values, this.chunkId});
  final List<String> values;
  final String? chunkId;

  bool get isEmpty => values.isEmpty;
}

class MatrixRow {
  const MatrixRow({required this.paper, required this.cells});
  final Paper paper;
  final Map<String, MatrixCell> cells;
}

/// Derives the comparison matrix from the structured extractions.
/// This is deliberately pure computation — the model produced the records,
/// but the table is arithmetic, and arithmetic belongs in code.
class BuildComparison {
  const BuildComparison();

  static const columns = <String>[
    'Method',
    'Family',
    'Datasets',
    'Metrics',
    'Baselines',
    'Limitations',
  ];

  List<MatrixRow> call(ResearchRun run) {
    return run.papers.map((paper) {
      final e = paper.extraction;
      return MatrixRow(
        paper: paper,
        cells: {
          'Method': MatrixCell(values: [if (e != null) e.method.name]),
          'Family': MatrixCell(values: [if (e != null) e.method.family]),
          'Datasets': MatrixCell(
            values: e?.datasets.map((d) => d.name).toList() ?? const [],
          ),
          'Metrics': MatrixCell(
            values: e?.metrics
                    .map((m) => m.value.isEmpty
                        ? m.name
                        : '${m.name} ${m.value}')
                    .toList() ??
                const [],
          ),
          'Baselines': MatrixCell(values: e?.baselines ?? const []),
          'Limitations': MatrixCell(
            values: e?.limitations.map((l) => l.text).toList() ?? const [],
          ),
        },
      );
    }).toList();
  }
}
