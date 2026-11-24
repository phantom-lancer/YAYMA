import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yayma/src/features/core/providers/android_player_preferences.dart';
import 'package:yayma/src/features/core/theme/app_theme.dart';

void main() {
  group('applyAppearanceTheme', () {
    test('leaves the YAYMA profiles exactly as they were', () {
      final base = buildAppTheme(baseColorScheme);
      for (final profile in [
        AndroidAppearanceProfile.yayama,
        AndroidAppearanceProfile.yandexMusic,
        AndroidAppearanceProfile.current,
      ]) {
        final themed = applyAppearanceTheme(base, profile);
        expect(identical(themed, base), isTrue, reason: profile.name);
      }
    });

    test('swaps the Apple profile to graphite surfaces and one red accent', () {
      final themed = applyAppearanceTheme(
        buildAppTheme(baseColorScheme),
        AndroidAppearanceProfile.appleMusic,
      );
      final scheme = themed.colorScheme;

      expect(scheme.primary, const Color(0xFFFF375F));
      expect(scheme.surface, const Color(0xFF0E0E10));
      expect(scheme.surfaceContainer, const Color(0xFF1C1C1E));
      // Apple's own surfaces are neutral; the artwork hue must not leak in.
      expect((scheme.surface.r - scheme.surface.b).abs(), lessThan(0.02));
      expect(themed.scaffoldBackgroundColor, const Color(0xFF0A0A0C));
      expect(
        themed.inputDecorationTheme.focusedBorder,
        isA<OutlineInputBorder>(),
      );
    });
  });

  group('appearance profile labels', () {
    test('exposes the two primary styles and the two legacy ones', () {
      expect(
        AndroidAppearanceProfile.yandexMusic.title,
        'YAYMA / Liquid Glass',
      );
      expect(AndroidAppearanceProfile.appleMusic.title, 'Apple Music');
      expect(AndroidAppearanceProfile.yayama.title, 'YAYMA Classic');
      expect(AndroidAppearanceProfile.current.title, 'YAYMA Compact');
    });
  });
}
