import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/library_repository_impl.dart';
import '../domain/entities/library_paper.dart';
import '../domain/repositories/library_repository.dart';

final libraryRepositoryProvider =
    Provider<LibraryRepository>((ref) => LibraryRepositoryImpl());

final libraryProvider = StreamProvider<List<LibraryPaper>>(
  (ref) => ref.watch(libraryRepositoryProvider).watchLibrary(),
);
