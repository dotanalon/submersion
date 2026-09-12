import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  test('deco stop settings default to visible', () {
    const settings = AppSettings();
    expect(settings.showDecoStopsOnProfile, isTrue);
  });

  test('copyWith updates the deco stop visibility independently', () {
    const settings = AppSettings();

    final hidden = settings.copyWith(showDecoStopsOnProfile: false);
    expect(hidden.showDecoStopsOnProfile, isFalse);
    // The ceiling setting must survive unchanged: this catches a copy-paste
    // error where the deco stop field was wired to the ceiling one.
    expect(hidden.showCeilingOnProfile, settings.showCeilingOnProfile);
  });
}
