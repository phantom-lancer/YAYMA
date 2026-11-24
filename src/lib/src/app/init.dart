import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:yayma/src/app/session.dart';
import 'package:yayma/src/features/core/providers/navigation_provider.dart';
import 'package:yayma/src/features/core/providers/android_player_preferences.dart';
import 'package:yayma/src/features/core/providers/visual_effects_provider.dart';
import 'package:yayma/src/features/core/services/app_logger.dart';
import 'package:yayma/src/features/core/services/network_quality.dart';
import 'package:yayma/src/features/core/views/widgets/liquid_glass.dart';
import 'package:yayma/src/features/library/providers/library_provider.dart';
import 'package:yayma/src/features/playback/providers/audio_focus_manager.dart';
import 'package:yayma/src/features/playback/providers/audio_handler.dart';
import 'package:yayma/src/features/playback/providers/lyrics_provider.dart';
import 'package:yayma/src/features/playback/providers/playback_provider.dart';
import 'package:yayma/src/features/search/providers/search_provider.dart';
import 'package:yayma/src/features/settings/services/update_service.dart';
import 'package:yayma/src/rust/api/auth.dart';
import 'package:yayma/src/rust/api/simple.dart' as simple;
import 'package:yayma/src/rust/app/context.dart';
import 'package:yayma/src/rust/frb_generated.dart';

/// Centralized application initialization module
class AppInit {
  /// Bumped on every login/logout. An async step that finishes after the
  /// session changed compares its captured value and drops its result, so a
  /// slow init can't write the previous account's data into the new session.
  static int _authEpoch = 0;

  static Future<void> initialize() async {
    try {
      SignalsObserver.instance = null;

      await RustLib.init();
      await AndroidPlayerPreferences.load();
      await NetworkQualityController.init();

      unawaited(UpdateService.cleanupDownloadedApk());

      if (Platform.isAndroid) {
        await _initAudioService();
        unawaited(GlassShaderCache.ensureLoaded());
      }

      final appDir = await _resolveDataDir();
      await simple.initAppInfrastructure(basePath: appDir.path);

      try {
        final settings = await simple.getInitialSettings();
        autoHideNavbarSignal.value = settings.autoHideNavbar;
        closeToTraySignal.value = settings.closeToTray;
        customTitlebarSignal.value = settings.customTitlebar;
        vibeVisibleSignal.value = settings.vibeAnimationEnabled;
        vibeRenderScaleSignal.value = settings.vibeRenderScale;
        vibeStyleSignal.value = VibeStyle.fromName(settings.vibeStyle);
        crossfadeEnabledSignal.value = settings.crossfadeEnabled;
        aiContentReductionSignal.value = settings.aiContentReduction;
        blurEffectsEnabledSignal.value = settings.blurEffectsEnabled;
        liquidGlassV2EnabledSignal.value = settings.liquidGlassV2Enabled;
      } on Object catch (e) {
        // Defaults are fine, but the failure should be visible in the log.
        appLog(AppLogLevel.warn, 'initial settings load failed: $e');
      }

      unawaited(_initializeAuthAndServices());
    } on Object catch (e, st) {
      // RootScreen renders AsyncError, so a failed startup surfaces a message
      // instead of spinning forever. Both sinks: when the bridge itself died
      // appLog is swallowed, so debugPrint is the only trace (run from a
      // terminal to see it).
      debugPrint('Startup failed: $e\n$st');
      appLog(AppLogLevel.error, 'startup failed: $e | ${_stackExcerpt(st)}');
      authSignal.value = AsyncError(e, st);
    }
  }

  /// First frames only: appLog flattens newlines, and a full stack would
  /// flood the single-line file entry.
  static String _stackExcerpt(StackTrace st) =>
      st.toString().split('\n').take(4).join(' ');

  /// Rust backend storage (yamusic_v2.db, http/track caches) lives in the
  /// platform application-support directory, not Documents. One-time move
  /// for installs predating this: the auth token is stored inside the DB,
  /// so moving without migration would log every user out and orphan
  /// downloaded tracks.
  static Future<Directory> _resolveDataDir() async {
    final support = await getApplicationSupportDirectory();
    await _migrateLegacyDataDir(support);
    return support;
  }

  static Future<void> _migrateLegacyDataDir(Directory support) async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      if (docs.path == support.path) return;
      final legacyDb = File(
        '${docs.path}${Platform.pathSeparator}yamusic_v2.db',
      );
      if (!legacyDb.existsSync()) return;
      final targetDb = File(
        '${support.path}${Platform.pathSeparator}yamusic_v2.db',
      );
      if (targetDb.existsSync()) return;
      await support.create(recursive: true);
      for (final name in [
        'yamusic_v2.db',
        'yamusic_v2.db-wal',
        'yamusic_v2.db-shm',
        'http_cache',
        'offline_tracks',
      ]) {
        await _moveEntity(docs.path, support.path, name);
      }
    } on Object {
      // Migration is best-effort only; worst case the app starts fresh.
    }
  }

  static Future<void> _moveEntity(
    String fromDir,
    String toDir,
    String name,
  ) async {
    try {
      final srcDir = Directory('$fromDir${Platform.pathSeparator}$name');
      if (srcDir.existsSync()) {
        await srcDir.rename('$toDir${Platform.pathSeparator}$name');
        return;
      }
      final srcFile = File('$fromDir${Platform.pathSeparator}$name');
      if (srcFile.existsSync()) {
        await srcFile.rename('$toDir${Platform.pathSeparator}$name');
      }
    } on Object {
      // Best-effort per entry.
    }
  }

  static Future<void> _applyAndroidWavePreference(AppContext context) async {
    if (!Platform.isAndroid) return;
    final saved = AndroidPlayerPreferences.androidWaveVisibleOverrideSignal.value;
    // Older Android previews always persisted false because the shader was
    // unavailable. Enable it once on upgrade, then honor the user's choice.
    final enabled = saved ?? true;
    vibeVisibleSignal.value = enabled;
    await simple.setVibeAnimationEnabled(ctx: context, enabled: enabled);
    if (saved == null) {
      await AndroidPlayerPreferences.setWaveVisibleOverride(enabled);
    }
  }

  static Future<void> _initAudioService() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    await AudioFocusManager.initialize(session);

    await AudioService.init(
      builder: YaymaAudioHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'io.github.darkplayoff.yayma.playback',
        androidNotificationChannelName: 'YAYMA Playback',
        androidNotificationOngoing: true,
        androidShowNotificationBadge: true,
        androidNotificationIcon: 'drawable/ic_notification',
      ),
    );

    unawaited(requestIgnoreBatteryOptimizations());
  }

  static Future<void> _initializeAuthAndServices() async {
    final epoch = _authEpoch;
    try {
      final context = await tryAutoLogin();
      if (epoch != _authEpoch) return;
      appContextSignal.value = context;

      if (context == null) {
        authSignal.value = const AsyncData(false);
        return;
      }

      await _applyAndroidWavePreference(context);

      // Initialize playback locally before showing UI
      await initPlayback();
      if (epoch != _authEpoch) return;
      await NetworkQualityController.applyCurrent();

      // Fetch network-dependent data in the background
      unawaited(_loadAccountInfo(context, epoch));
      unawaited(_syncAiContentReduction(context, epoch));
      unawaited(initLibrary());

      authSignal.value = const AsyncData(true);
    } on Object catch (e, st) {
      if (epoch != _authEpoch) return;
      debugPrint('Auto-login failed: $e\n$st');
      appLog(AppLogLevel.error, 'auto-login failed: $e | ${_stackExcerpt(st)}');
      authSignal.value = AsyncError(e, st);
    }
  }

  /// "Меньше ИИ" lives in the account settings, so another client may have
  /// changed it since the last launch.
  static Future<void> _syncAiContentReduction(
    AppContext context,
    int epoch,
  ) async {
    try {
      final enabled = await simple.syncAiContentReduction(ctx: context);
      if (epoch != _authEpoch) return;
      aiContentReductionSignal.value = enabled;
    } on Object catch (e) {
      if (epoch != _authEpoch) return;
      appLog(AppLogLevel.warn, 'ai content reduction sync failed: $e');
    }
  }

  static Future<void> _loadAccountInfo(AppContext context, int epoch) async {
    try {
      final account = await getAccountInfo(ctx: context);
      if (epoch != _authEpoch) return;
      accountSignal.value = account;
    } on Exception {
      if (epoch != _authEpoch) return;
      accountSignal.value = null;
    }
  }

  static Future<void> login(String token) async {
    final epoch = ++_authEpoch;
    authSignal.value = const AsyncLoading();
    try {
      final context = await loginWithToken(token: token);
      if (epoch != _authEpoch) return;
      appContextSignal.value = context;

      await _applyAndroidWavePreference(context);
      await initPlayback();
      if (epoch != _authEpoch) return;
      await NetworkQualityController.applyCurrent();

      unawaited(_loadAccountInfo(context, epoch));
      unawaited(_syncAiContentReduction(context, epoch));
      unawaited(initLibrary());

      authSignal.value = const AsyncData(true);
    } on Object catch (e, st) {
      if (epoch != _authEpoch) return;
      debugPrint('Login failed: $e\n$st');
      appLog(AppLogLevel.error, 'login failed: $e | ${_stackExcerpt(st)}');
      authSignal.value = AsyncError(e, st);
    }
  }

  static Future<void> logout() async {
    _authEpoch++;

    // Each step is independent and bounded: one failed or stuck cancel must not
    // skip the rest (a skipped clearToken would auto-login the next launch) nor
    // leave the UI in the account, which forced the user to press "log out"
    // twice.
    Future<void> step(Future<void> Function() action) async {
      try {
        await action().timeout(const Duration(seconds: 5));
      } on Object catch (e) {
        appLog(AppLogLevel.error, 'logout teardown failed: $e');
      }
    }

    await step(PlaybackController.stop);
    await step(disposePlayback);
    await step(disposeLibrary);
    await step(() async => clearLyricsCache());
    await step(disposeSearch);
    await step(clearToken);
    accountSignal.value = null;
    appContextSignal.value = null;
    // Drop the previous account's open album/playlist stack.
    resetNavigation();
    authSignal.value = const AsyncData(false);
  }
}
