import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:yayma/src/features/core/services/app_logger.dart';
import 'package:yayma/src/features/playback/providers/playback_provider.dart';
import 'package:yayma/src/rust/api/models.dart';

/// The transport the OS reports for the current default network.
enum NetworkKind {
  wifi('Wi-Fi'),
  mobile('Мобильный интернет'),
  ethernet('Ethernet'),
  vpn('VPN'),
  other('Другое подключение'),
  none('Нет подключения'),
  unknown('Тип подключения не определён');

  const NetworkKind(this.label);

  final String label;

  bool get hasQualityProfile =>
      this == NetworkKind.wifi ||
      this == NetworkKind.ethernet ||
      this == NetworkKind.mobile;

  static NetworkKind fromChannel(String? value) => switch (value) {
    'wifi' => NetworkKind.wifi,
    'mobile' => NetworkKind.mobile,
    'ethernet' => NetworkKind.ethernet,
    'vpn' => NetworkKind.vpn,
    'other' => NetworkKind.other,
    'none' => NetworkKind.none,
    _ => NetworkKind.unknown,
  };
}

/// UI-facing state of the current connection.
final FlutterSignal<NetworkKind> networkKindSignal = signal<NetworkKind>(
  NetworkKind.unknown,
);

/// When enabled, switching between Wi-Fi and mobile applies the matching
/// quality profile without touching the queue or the playback position.
final FlutterSignal<bool> autoQualityByNetworkSignal = signal<bool>(true);
final FlutterSignal<AudioQuality> wifiQualitySignal = signal<AudioQuality>(
  AudioQuality.high,
);
final FlutterSignal<AudioQuality> mobileQualitySignal = signal<AudioQuality>(
  AudioQuality.normal,
);

extension AudioQualityLabel on AudioQuality {
  String get title => switch (this) {
    AudioQuality.low => 'Экономное',
    AudioQuality.normal => 'Стандартное',
    AudioQuality.high => 'Высокое',
  };

  String get detail => switch (this) {
    AudioQuality.low => 'LQ · минимальный трафик',
    AudioQuality.normal => 'NQ · ~192 kbps',
    AudioQuality.high => 'HQ · 320 kbps или lossless',
  };
}

/// Owns network detection and the persisted Wi-Fi/mobile quality profiles.
///
/// Rust already knows the three real stream qualities the Yandex API serves;
/// this controller only chooses which one to request. Changing it goes through
/// the existing `set_audio_quality` path, which reloads the current stream at
/// the saved position and leaves the queue untouched.
abstract final class NetworkQualityController {
  static const _channelName = 'io.github.darkplayoff.yayma/network';
  static const _fileName = 'yayma_audio_quality.json';
  static const _autoKey = 'auto_by_network';
  static const _wifiKey = 'wifi_quality';
  static const _mobileKey = 'mobile_quality';

  static final MethodChannel _method = const MethodChannel(_channelName);
  static final EventChannel _events = const EventChannel(
    '$_channelName/events',
  );

  static StreamSubscription<dynamic>? _subscription;
  static Timer? _poll;
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _load();
    if (!Platform.isAndroid) {
      networkKindSignal.value = NetworkKind.other;
      return;
    }
    try {
      _subscription = _events.receiveBroadcastStream().listen(
        (value) => _onNetworkChanged(NetworkKind.fromChannel(value as String?)),
        onError: (Object error) {
          appLog(AppLogLevel.warn, 'network event stream failed: $error');
        },
      );
    } on Object catch (error) {
      appLog(AppLogLevel.warn, 'network event stream unavailable: $error');
    }
    // The event channel sends the initial value, but a missed first event
    // (engine restart, Doze) must not leave the profile unapplied.
    _poll = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(refreshNetwork());
    });
    await refreshNetwork();
  }

  static Future<void> refreshNetwork() async {
    if (!Platform.isAndroid) return;
    try {
      final value = await _method.invokeMethod<String>('getNetworkType');
      _onNetworkChanged(NetworkKind.fromChannel(value));
    } on Object {
      // Keep the previous known network; an unavailable platform channel must
      // not silently switch the user to the mobile profile.
    }
  }

  static void _onNetworkChanged(NetworkKind kind) {
    if (networkKindSignal.value == kind) return;
    networkKindSignal.value = kind;
    if (autoQualityByNetworkSignal.value) {
      unawaited(_applyForNetwork(kind));
    }
  }

  static AudioQuality? _profileFor(NetworkKind kind) => switch (kind) {
    NetworkKind.wifi || NetworkKind.ethernet => wifiQualitySignal.value,
    NetworkKind.mobile => mobileQualitySignal.value,
    _ => null,
  };

  static Future<void> _applyForNetwork(NetworkKind kind) async {
    final target = _profileFor(kind);
    if (target == null) return;
    if (audioQualitySignal.value == target) return;
    // The Rust actor serializes the reload; a second, quick network flip is
    // rare enough that issuing both is cheaper than dropping the latest one.
    await PlaybackController.setQuality(target);
  }

  /// Applies the profile for the current connection, if one is known.
  static Future<void> applyCurrent() async {
    if (!autoQualityByNetworkSignal.value) return;
    await _applyForNetwork(networkKindSignal.value);
  }

  /// Called after the shared quality picker changes the stream quality: the
  /// choice becomes the preference for the network the user is on.
  static Future<void> recordManualQuality(AudioQuality quality) async {
    switch (networkKindSignal.value) {
      case NetworkKind.wifi:
      case NetworkKind.ethernet:
        wifiQualitySignal.value = quality;
      case NetworkKind.mobile:
        mobileQualitySignal.value = quality;
      default:
        break;
    }
    await _save();
  }

  static Future<void> setAutoByNetwork(bool enabled) async {
    autoQualityByNetworkSignal.value = enabled;
    await _save();
    if (enabled) await applyCurrent();
  }

  static Future<void> setWifiQuality(AudioQuality quality) async {
    wifiQualitySignal.value = quality;
    await _save();
    if (autoQualityByNetworkSignal.value &&
        (networkKindSignal.value == NetworkKind.wifi ||
            networkKindSignal.value == NetworkKind.ethernet)) {
      await _applyForNetwork(networkKindSignal.value);
    }
  }

  static Future<void> setMobileQuality(AudioQuality quality) async {
    mobileQualitySignal.value = quality;
    await _save();
    if (autoQualityByNetworkSignal.value &&
        networkKindSignal.value == NetworkKind.mobile) {
      await _applyForNetwork(NetworkKind.mobile);
    }
  }

  static AudioQuality _parseQuality(Object? value, AudioQuality fallback) =>
      switch (value) {
        'low' => AudioQuality.low,
        'normal' => AudioQuality.normal,
        'high' => AudioQuality.high,
        _ => fallback,
      };

  static Future<File> _file() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}${Platform.pathSeparator}$_fileName');
  }

  static Future<void> _load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return;
      final auto = decoded[_autoKey];
      if (auto is bool) autoQualityByNetworkSignal.value = auto;
      wifiQualitySignal.value = _parseQuality(
        decoded[_wifiKey],
        AudioQuality.high,
      );
      mobileQualitySignal.value = _parseQuality(
        decoded[_mobileKey],
        AudioQuality.normal,
      );
    } on Object {
      // A damaged optional preference must never block startup.
    }
  }

  static Future<void> _save() async {
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode({
          _autoKey: autoQualityByNetworkSignal.value,
          _wifiKey: wifiQualitySignal.value.name,
          _mobileKey: mobileQualitySignal.value.name,
        }),
        flush: true,
      );
    } on Object {
      // Keep the live selection for this session.
    }
  }

  static void dispose() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    _poll?.cancel();
    _poll = null;
    _initialized = false;
  }
}
