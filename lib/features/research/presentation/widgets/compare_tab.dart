import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/common.dart';
import '../../domain/entities/research_run.dart';
import '../../domain/usecases/build_comparison.dart';
import '../providers/research_providers.dart';

/// Tab 3 — the comparison matrix.
///
/// Empty cells stay visibly empty. They are not a rendering failure: an empty
/// cell is a paper that did not report that thing, and the pattern of empty
/// cells is literally what the Gaps tab is computed from.
class CompareTab extends ConsumerWidget {
  const CompareTab({super.key, required this.run});
  final ResearchRun run;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(comparisonProvider(run));
    if (rows.isEmpty) {
      return const EmptyState(
        icon: Icons.grid_on_outlined,
        title: 'Nothing to compare yet',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Insets.lg, Insets.lg, Insets.lg, Insets.sm),
          child: Text(
            'Blank cells mean the paper did not report that. Scroll sideways '
            'to see every column.',
            style: context.text.bodySmall
                ?.copyWith(color: context.colors.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.xl),
              child: _Matrix(rows: rows),
            ),
          ),
        ),
      ],
    );
  }
}

class _Matrix extends StatelessWidget {
  const _Matrix({required this.rows});
  final List<MatrixRow> rows;

  static const _paperColumnWidth = 220.0;
  static const _cellWidth = 190.0;

  @override
  Widget build(BuildContext context) {
    final border = TableBorder(
      horizontalInside: BorderSide(color: context.colors.outlineVariant),
      verticalInside: BorderSide(color: context.colors.outlineVariant),
      borderRadius: BorderRadius.circular(Radii.card),
      top: BorderSide(color: context.colors.outlineVariant),
      bottom: BorderSide(color: context.colors.outlineVariant),
      left: BorderSide(color: context.colors.outlineVariant),
      right: BorderSide(color: context.colors.outlineVariant),
    );

    return Table(
      border: border,
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      columnWidths: {
        0: const FixedColumnWidth(_paperColumnWidth),
        for (var i = 1; i <= BuildComparison.columns.length; i++)
          i: const FixedColumnWidth(_cellWidth),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(
            color: context.colors.surfaceContainerHighest
                .withValues(alpha: 0.5),
          ),
          children: [
            _HeaderCell('Paper'),
            for (final c in BuildComparison.columns) _HeaderCell(c),
          ],
        ),
        for (final row in rows)
          TableRow(
            children: [
              _PaperCell(row: row),
              for (final column in BuildComparison.columns)
                _ValueCell(cell: row.cells[column]!),
            ],
          ),
      ],
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(Insets.sm),
        child: Text(
          label.toUpperCase(),
          style: context.text.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: context.colors.onSurfaceVariant,
          ),
        ),
      );
}

class _PaperCell extends StatelessWidget {
  const _PaperCell({required this.row});
  final MatrixRow row;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(Insets.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              row.paper.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600, height: 1.35),
            ),
            const SizedBox(height: 2),
            Text(
              '${row.paper.authorLine}, ${row.paper.year}',
              style: context.text.labelSmall
                  ?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ],
        ),
      );
}

class _ValueCell extends StatelessWidget {
  const _ValueCell({required this.cell});
  final MatrixCell cell;

  @override
  Widget build(BuildContext context) {
    if (cell.isEmpty) {
      // Deliberately quiet, but present. A dash reads as "nothing reported",
      // which is information; a blank reads as a bug.
      return Padding(
        padding: const EdgeInsets.all(Insets.sm),
        child: Text(
          '—',
          style: context.text.bodySmall
              ?.copyWith(color: context.colors.outlineVariant),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(Insets.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final value in cell.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                value,
                style: context.text.bodySmall?.copyWith(height: 1.35),
              ),
            ),
        ],
      ),
    );
  }
}
