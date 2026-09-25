import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/common.dart';

/// Screen 5 — the user's own papers.
///
/// Matters more than it looks: researchers already have a folder of PDFs, and
/// asking questions across it is often the first thing they actually want.
class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/'),
          ),
          title: const Text('Library'),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {},
          icon: const Icon(Icons.upload_file),
          label: const Text('Add PDFs'),
        ),
        body: const EmptyState(
          icon: Icons.folder_open_outlined,
          title: 'No papers yet',
          message: 'Upload PDFs and they go through the same pipeline as '
              'searched papers — parsed, chunked and searchable.',
        ),
      );
}
