import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/entities/citation_style.dart';

/// Gets the produced file to the user. Three destinations, because they are
/// genuinely different needs: share it somewhere, print/preview it, or copy
/// the text straight into what they are already writing.
class ExportService {
  const ExportService();

  /// The system share sheet. On iOS this covers AirDrop, Files, Mail and any
  /// reference manager that registers the type.
  Future<void> share(ExportResult result) async {
    final file = await _writeToTemp(result);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: result.mimeType)],
        fileNameOverrides: [result.filename],
      ),
    );
  }

  /// The print/preview dialog. PDF only — it is the only format with a page
  /// layout to preview.
  Future<void> printDocument(ExportResult result) async {
    if (result.bytes == null) return;
    await Printing.layoutPdf(
      onLayout: (_) async => Uint8List.fromList(result.bytes!),
      name: result.filename,
    );
  }

  Future<File> _writeToTemp(ExportResult result) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${result.filename}');
    if (result.isBinary) {
      await file.writeAsBytes(result.bytes!);
    } else {
      await file.writeAsString(result.text ?? '');
    }
    return file;
  }
}
