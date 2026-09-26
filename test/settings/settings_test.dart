import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:practsearch/features/export/domain/entities/citation_style.dart';
import 'package:practsearch/features/settings/data/settings_repository_impl.dart';
import 'package:practsearch/features/settings/domain/entities/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('round-trips every setting', () async {
    final repo = SettingsRepositoryImpl();
    const saved = AppSettings(
      themeMode: ThemeMode.dark,
      citationStyle: CitationStyle.vancouver,
      exportFormat: ExportFormat.pdf,
      bibliographyFormat: BibliographyFormat.ris,
      paperCount: 35,
      yearFrom: 2010,
      yearTo: 2024,
      openAccessOnly: false,
      includeLibraryByDefault: true,
    );

    await repo.save(saved);
    expect(await repo.load(), saved);
  });

  test('returns defaults on a fresh install', () async {
    expect(await SettingsRepositoryImpl().load(), const AppSettings());
  });

  test('falls back rather than crashing on an unknown stored value', () async {
    // A value written by an older build whose enum has since been renamed.
    SharedPreferences.setMockInitialValues({
      'citationStyle': 'someStyleThatNoLongerExists',
      'paperCount': 25,
    });
    final loaded = await SettingsRepositoryImpl().load();
    expect(loaded.citationStyle, CitationStyle.apa);
    expect(loaded.paperCount, 25, reason: 'valid keys still load');
  });

  test('stores enums by name, so reordering them cannot corrupt a setting',
      () async {
    await SettingsRepositoryImpl()
        .save(const AppSettings(citationStyle: CitationStyle.ieee));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('citationStyle'), 'ieee');
    expect(prefs.getString('citationStyle'), isNot('3'));
  });

  group('settings feed the rest of the app', () {
    test('become the run options a new question starts from', () {
      const s = AppSettings(paperCount: 30, yearFrom: 2015, openAccessOnly: false);
      final options = s.toRunOptions();
      expect(options.paperCount, 30);
      expect(options.yearFrom, 2015);
      expect(options.openAccessOnly, isFalse);
    });

    test('become the export request the sheet opens on', () {
      const s = AppSettings(
        citationStyle: CitationStyle.chicago,
        exportFormat: ExportFormat.csv,
      );
      final request = s.toExportRequest();
      expect(request.citationStyle, CitationStyle.chicago);
      expect(request.format, ExportFormat.csv);
    });
  });
}
