import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../export/domain/entities/citation_style.dart';
import '../domain/entities/app_settings.dart';
import '../domain/repositories/settings_repository.dart';

/// Persists to SharedPreferences.
///
/// Enums are stored by `name`, not by index — an index breaks the moment
/// someone reorders the enum, and it fails silently by loading the wrong
/// value rather than throwing.
class SettingsRepositoryImpl implements SettingsRepository {
  static const _themeMode = 'themeMode';
  static const _citationStyle = 'citationStyle';
  static const _exportFormat = 'exportFormat';
  static const _bibliographyFormat = 'bibliographyFormat';
  static const _paperCount = 'paperCount';
  static const _yearFrom = 'yearFrom';
  static const _yearTo = 'yearTo';
  static const _openAccessOnly = 'openAccessOnly';
  static const _includeLibrary = 'includeLibraryByDefault';

  @override
  Future<AppSettings> load() async {
    final p = await SharedPreferences.getInstance();
    const fallback = AppSettings();
    return AppSettings(
      themeMode: _enum(
        ThemeMode.values,
        p.getString(_themeMode),
        fallback.themeMode,
      ),
      citationStyle: _enum(
        CitationStyle.values,
        p.getString(_citationStyle),
        fallback.citationStyle,
      ),
      exportFormat: _enum(
        ExportFormat.values,
        p.getString(_exportFormat),
        fallback.exportFormat,
      ),
      bibliographyFormat: _enum(
        BibliographyFormat.values,
        p.getString(_bibliographyFormat),
        fallback.bibliographyFormat,
      ),
      paperCount: p.getInt(_paperCount) ?? fallback.paperCount,
      yearFrom: p.getInt(_yearFrom) ?? fallback.yearFrom,
      yearTo: p.getInt(_yearTo) ?? fallback.yearTo,
      openAccessOnly: p.getBool(_openAccessOnly) ?? fallback.openAccessOnly,
      includeLibraryByDefault:
          p.getBool(_includeLibrary) ?? fallback.includeLibraryByDefault,
    );
  }

  @override
  Future<void> save(AppSettings s) async {
    final p = await SharedPreferences.getInstance();
    await Future.wait([
      p.setString(_themeMode, s.themeMode.name),
      p.setString(_citationStyle, s.citationStyle.name),
      p.setString(_exportFormat, s.exportFormat.name),
      p.setString(_bibliographyFormat, s.bibliographyFormat.name),
      p.setInt(_paperCount, s.paperCount),
      p.setInt(_yearFrom, s.yearFrom),
      p.setInt(_yearTo, s.yearTo),
      p.setBool(_openAccessOnly, s.openAccessOnly),
      p.setBool(_includeLibrary, s.includeLibraryByDefault),
    ]);
  }

  /// Falls back rather than throwing: a stored value from an older build
  /// should degrade to the default, not crash the app on launch.
  static T _enum<T extends Enum>(List<T> values, String? stored, T fallback) =>
      values.where((v) => v.name == stored).firstOrNull ?? fallback;
}
