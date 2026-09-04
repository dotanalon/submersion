import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Guards the strings introduced by the grouped navigation rail.
///
/// Only non-emptiness is asserted per locale: "Import" and "Export" are
/// legitimately identical to English in German, so a "differs from English"
/// check would be wrong here.
void main() {
  group('nav strings', () {
    test('English values match the rail design', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(l10n.nav_log, 'Log');
      expect(l10n.nav_import, 'Import');
      expect(l10n.nav_export, 'Export');
      expect(l10n.nav_group_dives, 'Dives');
      expect(l10n.nav_group_gearTraining, 'Gear & Training');
      expect(l10n.nav_group_tools, 'Tools');
    });

    test('every supported locale provides all six strings', () {
      for (final locale in AppLocalizations.supportedLocales) {
        final l10n = lookupAppLocalizations(locale);
        for (final entry in {
          'nav_log': l10n.nav_log,
          'nav_import': l10n.nav_import,
          'nav_export': l10n.nav_export,
          'nav_group_dives': l10n.nav_group_dives,
          'nav_group_gearTraining': l10n.nav_group_gearTraining,
          'nav_group_tools': l10n.nav_group_tools,
        }.entries) {
          expect(
            entry.value.trim(),
            isNotEmpty,
            reason: '${entry.key} is empty for $locale',
          );
        }
      }
    });
  });
}
