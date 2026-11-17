import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// Android appearance profiles. The original YAYAMA interface remains the
/// default; each alternative is an independent presentation, not a migration
/// that removes the existing player.
enum AndroidAppearanceProfile {
  yayama,
  yandexMusic,
  appleMusic,
  current,
}

extension AndroidAppearanceProfileLabel on AndroidAppearanceProfile {
  String get title => switch (this) {
    AndroidAppearanceProfile.yayama => 'YAYAMA',
    AndroidAppearanceProfile.yandexMusic => 'Yandex Music',
    AndroidAppearanceProfile.appleMusic => 'Apple Music / iOS 26',
    AndroidAppearanceProfile.current => 'Текущий интерфейс',
  };

  String get description => switch (this) {
    AndroidAppearanceProfile.yayama => 'Оригинальный интерфейс приложения',
    AndroidAppearanceProfile.yandexMusic => 'Компактная главная в стиле Яндекс Музыки',
    AndroidAppearanceProfile.appleMusic => 'Liquid Glass и оформление Apple Music',
    AndroidAppearanceProfile.current => 'Сохранённый Android-редизайн',
  };
}

final FlutterSignal<AndroidAppearanceProfile> androidAppearanceProfileSignal =
    signal<AndroidAppearanceProfile>(AndroidAppearanceProfile.yayama);

/// Kept for compatibility with code and preference files from earlier
/// previews. New UI code should use [androidAppearanceProfileSignal].
final FlutterSignal<bool> classicAndroidPlayerSignal =
    signal<bool>(true);

abstract final class AndroidPlayerPreferences {
  static const _fileName = 'yayma_ui_preferences.json';
  static const _profileKey = 'android_appearance_profile';
  static const _legacyKey = 'classic_android_player';

  static Future<File> _file() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}${Platform.pathSeparator}$_fileName');
  }

  static AndroidAppearanceProfile _parseProfile(Object? value) {
    return switch (value) {
      'yandexMusic' => AndroidAppearanceProfile.yandexMusic,
      'appleMusic' => AndroidAppearanceProfile.appleMusic,
      'current' => AndroidAppearanceProfile.current,
      'yayama' => AndroidAppearanceProfile.yayama,
      _ => AndroidAppearanceProfile.yayama,
    };
  }

  static Future<void> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) {
        final Object? storedProfile = decoded[_profileKey];
        final profile = storedProfile is String
            ? _parseProfile(storedProfile)
            : decoded[_legacyKey] == false
                ? AndroidAppearanceProfile.current
                : AndroidAppearanceProfile.yayama;
        androidAppearanceProfileSignal.value = profile;
        classicAndroidPlayerSignal.value =
            profile == AndroidAppearanceProfile.yayama;
      }
    } on Object {
      // A damaged optional UI preference must never prevent startup.
    }
  }

  static Future<void> setProfile(AndroidAppearanceProfile profile) async {
    androidAppearanceProfileSignal.value = profile;
    classicAndroidPlayerSignal.value =
        profile == AndroidAppearanceProfile.yayama;
    try {
      final file = await _file();
      var values = <String, dynamic>{};
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map<String, dynamic>) values = decoded;
      }
      values[_profileKey] = profile.name;
      // Keep the legacy key readable by older preview builds.
      values[_legacyKey] = profile == AndroidAppearanceProfile.yayama;
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(values), flush: true);
    } on Object {
      // Keep the live choice for this session if storage is unavailable.
    }
  }

  @Deprecated('Use setProfile(AndroidAppearanceProfile) instead.')
  static Future<void> setClassicPlayer(bool enabled) =>
      setProfile(
        enabled
            ? AndroidAppearanceProfile.yayama
            : AndroidAppearanceProfile.current,
      );
}
