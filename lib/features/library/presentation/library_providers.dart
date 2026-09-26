import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/library_repository_impl.dart';
import '../data/library_storage.dart';
import '../domain/entities/library_paper.dart';
import '../domain/repositories/library_repository.dart';

final libraryStorageProvider = Provider((ref) => LibraryStorage());

final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => LibraryRepositoryImpl(ref.watch(libraryStorageProvider)),
);

/// Bytes held on this device, for the storage line in the library header.
final libraryUsageProvider = FutureProvider<int>(
  (ref) => ref.watch(libraryStorageProvider).usedBytes(),
);

final libraryProvider = StreamProvider<List<LibraryPaper>>(
  (ref) => ref.watch(libraryRepositoryProvider).watchLibrary(),
);
