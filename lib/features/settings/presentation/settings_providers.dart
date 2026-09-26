import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings_repository_impl.dart';
import '../domain/entities/app_settings.dart';
import '../domain/repositories/settings_repository.dart';

final settingsRepositoryProvider =
    Provider<SettingsRepository>((ref) => SettingsRepositoryImpl());

/// Settings are loaded once at startup and held in memory. Every write goes
/// straight to disk — there is no save button, and a setting that silently
/// failed to persist would be worse than no setting at all.
class SettingsController extends StateNotifier<AppSettings> {
  SettingsController(this._repository) : super(const AppSettings()) {
    _load();
  }

  final SettingsRepository _repository;

  Future<void> _load() async => state = await _repository.load();

  Future<void> update(AppSettings next) async {
    state = next;
    await _repository.save(next);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsController, AppSettings>(
  (ref) => SettingsController(ref.watch(settingsRepositoryProvider)),
);
