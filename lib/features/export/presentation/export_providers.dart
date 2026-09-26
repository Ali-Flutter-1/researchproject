import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/export_service.dart';
import '../domain/entities/citation_style.dart';
import '../domain/usecases/build_export.dart';

final exportServiceProvider = Provider((ref) => const ExportService());
final buildExportProvider = Provider((ref) => const BuildExport());

/// The sheet's own state. Kept in a provider rather than local widget state so
/// the chosen citation style survives closing and reopening the sheet — a
/// researcher works in one style and should not re-pick it every time.
final exportRequestProvider =
    StateProvider<ExportRequest>((ref) => const ExportRequest());
