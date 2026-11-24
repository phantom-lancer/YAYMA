import 'dart:io';

import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yayma/src/features/core/providers/android_player_preferences.dart';

/// Material Orange 500 is the stable fallback before a cover palette is ready.
const Color defaultAccentColor = Color(0xFFFF9800);

/// The scheme used when no cover palette is available. Computed once: these
/// colours only change with the app's own constants.
final ColorScheme baseColorScheme = M3EColorScheme.dark(
  seedColor: defaultAccentColor,
  variant: M3EColorVariant.expressive,
);

/// Merges a cover-derived scheme into the stable surface colours: the artwork
/// picks the accents, and the neutral base is re-seeded from the cover's own
/// primary so surfaces follow the track's hue too.
ColorScheme appColorScheme(ColorScheme? cover) {
  if (cover == null) return baseColorScheme;
  // The neutral base is seeded from the cover's own primary (not the fallback
  // orange), so surfaces carry the track's hue instead of one fixed warm tint.
  final base = M3EColorScheme.dark(
    seedColor: cover.primary,
    variant: M3EColorVariant.expressive,
  );
  return cover.copyWith(
    surface: base.surface,
    surfaceContainerLowest: base.surfaceContainerLowest,
    surfaceContainerLow: base.surfaceContainerLow,
    surfaceContainer: base.surfaceContainer,
    surfaceContainerHigh: base.surfaceContainerHigh,
    surfaceContainerHighest: base.surfaceContainerHighest,
    surfaceBright: base.surfaceBright,
    surfaceDim: base.surfaceDim,
    onPrimaryContainer: base.onPrimaryContainer,
    onSecondaryContainer: base.onSecondaryContainer,
    onTertiaryContainer: base.onTertiaryContainer,
    onErrorContainer: base.onErrorContainer,
  );
}

/// Elevated translucent surface used by the player bar, the mini plate and
/// dialogs. Kept in one place so they all darken by the same amount.
Color surfaceOverlay(Color? surface) =>
    Color.lerp(surface, Colors.black, 0.4) ?? const Color(0xFF181818);

/// The six accent colours the glow shader consumes, in its expected order.
List<double> vibePalette(ColorScheme scheme) {
  List<double> c(Color col) => [
    (col.r * 255.0).round().clamp(0, 255) / 255.0,
    (col.g * 255.0).round().clamp(0, 255) / 255.0,
    (col.b * 255.0).round().clamp(0, 255) / 255.0,
  ];
  return [
    ...c(scheme.primary),
    ...c(scheme.secondary),
    ...c(scheme.tertiary),
    ...c(scheme.primaryContainer),
    ...c(scheme.secondaryContainer),
    ...c(scheme.tertiaryContainer),
  ];
}

final ThemeData defaultAppTheme = buildAppTheme(baseColorScheme);

/// Applies a whole-app visual profile on top of the cover-derived theme.
///
/// Apple's profile is more than a recolour: it swaps the dark neutral surfaces
/// for the graphite iOS palette, tightens the large radii, and uses the Music
/// red as the single accent while keeping the artwork's hue only as a faint
/// ambient tint. The YAYMA profiles keep the existing theme untouched.
ThemeData applyAppearanceTheme(
  ThemeData base,
  AndroidAppearanceProfile profile,
) {
  if (profile != AndroidAppearanceProfile.appleMusic) return base;
  final cover = base.colorScheme;
  const graphite = Color(0xFF1C1C1E);
  final scheme = cover.copyWith(
    primary: const Color(0xFFFF375F),
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFF5C1020),
    onPrimaryContainer: const Color(0xFFFFD9DF),
    secondary: const Color(0xFFFF6482),
    onSecondary: Colors.white,
    surface: const Color(0xFF0E0E10),
    surfaceContainerLowest: const Color(0xFF08080A),
    surfaceContainerLow: const Color(0xFF141416),
    surfaceContainer: graphite,
    surfaceContainerHigh: const Color(0xFF242426),
    surfaceContainerHighest: const Color(0xFF2C2C2E),
    surfaceBright: const Color(0xFF3A3A3C),
    surfaceDim: const Color(0xFF0E0E10),
    onSurface: const Color(0xFFF5F5F7),
    onSurfaceVariant: const Color(0xFFA1A1A6),
    outline: const Color(0xFF3A3A3C),
  );
  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFF0A0A0C),
    textTheme: base.textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ),
    cardTheme: base.cardTheme.copyWith(
      color: graphite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dialogTheme: base.dialogTheme.copyWith(
      backgroundColor: const Color(0xF21C1C1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    bottomSheetTheme: base.bottomSheetTheme.copyWith(
      backgroundColor: const Color(0xF21C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    tabBarTheme: base.tabBarTheme.copyWith(
      labelColor: scheme.onSurface,
      unselectedLabelColor: scheme.onSurfaceVariant,
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      fillColor: Colors.white.withValues(alpha: 0.06),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF375F), width: 1.6),
      ),
    ),
  );
}

ThemeData buildAppTheme(ColorScheme scheme) {
  final base = ThemeData.dark(useMaterial3: true);
  final textTheme = M3ETypography.emphasized(base.textTheme);

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: Colors.black,
    textTheme: textTheme,
    splashFactory: InkRipple.splashFactory,
    highlightColor: scheme.primary.withValues(alpha: 0.08),
    hoverColor: Colors.white.withValues(alpha: 0.04),
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        for (final platform in TargetPlatform.values)
          platform: platform == TargetPlatform.android
              ? const PredictiveBackPageTransitionsBuilder()
              : const FadeForwardsPageTransitionsBuilder(),
      },
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHighest,
      circularTrackColor: scheme.surfaceContainerHighest,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surfaceOverlay(scheme.surfaceContainerHighest),
      surfaceTintColor: Colors.transparent,
      barrierColor: Platform.isAndroid ? Colors.transparent : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surfaceOverlay(scheme.surfaceContainerHighest),
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: Platform.isAndroid ? Colors.transparent : null,
      modalBackgroundColor: surfaceOverlay(scheme.surfaceContainerHighest),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      unselectedLabelStyle: textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w500,
      ),
      labelColor: scheme.onSurface,
      unselectedLabelColor: scheme.onSurfaceVariant,
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.28)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(color: scheme.onInverseSurface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    listTileTheme: const ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
  );
}
