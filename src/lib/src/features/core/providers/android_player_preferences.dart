import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// Android's redesigned My Wave experience is the default.
/// The previous screen remains available as an explicit compatibility mode.
final FlutterSignal<bool> classicAndroidPlayerSignal = signal<bool>(false);

abstract final class AndroidPlayerPreferences {
  static const _fileName = 'yayma_ui_preferences.json';
  static const _key = 'classic_android_player';

  static Future<File> _file() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}${Platform.pathSeparator}$_fileName');
  }

  static Future<void> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) {
        classicAndroidPlayerSignal.value = decoded[_key] == true;
      }
    } on Object {
      // A damaged optional UI preference must never prevent startup.
    }
  }

  static Future<void> setClassicPlayer(bool enabled) async {
    classicAndroidPlayerSignal.value = enabled;
    try {
      final file = await _file();
      var values = <String, dynamic>{};
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map<String, dynamic>) values = decoded;
      }
      values[_key] = enabled;
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(values), flush: true);
    } on Object {
      // Keep the live choice for this session if storage is unavailable.
    }
  }
}
