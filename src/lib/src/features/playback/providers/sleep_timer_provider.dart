import 'dart:async';

import 'package:signals_flutter/signals_flutter.dart';
import 'package:yayma/src/features/core/providers/notification_provider.dart';
import 'package:yayma/src/features/playback/providers/playback_provider.dart';

final FlutterSignal<bool> sleepTimerActiveSignal = signal(false);
final FlutterSignal<Duration?> sleepTimerRemainingSignal = signal(null);
final FlutterSignal<bool> sleepTimerEndsAfterTrackSignal = signal(false);

class SleepTimerController {
  static Timer? _timer;
  static DateTime? _deadline;
  static String? _targetTrackId;
  static bool _finishing = false;

  static void start(Duration duration) {
    _reset();
    _deadline = DateTime.now().add(duration);
    sleepTimerActiveSignal.value = true;
    sleepTimerEndsAfterTrackSignal.value = false;
    sleepTimerRemainingSignal.value = duration;
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(_tick()),
    );
    showAppSuccess('Таймер сна: ${_formatDuration(duration)}');
  }

  static bool startAfterTrack(String trackId) {
    if (trackId.isEmpty) return false;
    _reset();
    _targetTrackId = trackId;
    sleepTimerActiveSignal.value = true;
    sleepTimerEndsAfterTrackSignal.value = true;
    sleepTimerRemainingSignal.value = null;
    _timer = Timer.periodic(
      const Duration(milliseconds: 300),
      (_) => unawaited(_tick()),
    );
    showAppSuccess('Воспроизведение остановится после этого трека');
    return true;
  }

  static void cancel() {
    _reset();
    showAppSuccess('Таймер сна отключён');
  }

  static void _reset() {
    _timer?.cancel();
    _timer = null;
    _deadline = null;
    _targetTrackId = null;
    sleepTimerActiveSignal.value = false;
    sleepTimerEndsAfterTrackSignal.value = false;
    sleepTimerRemainingSignal.value = null;
  }

  static Future<void> _tick() async {
    if (_finishing) return;

    final target = _targetTrackId;
    if (target != null) {
      final state = playerStateSignal.peek();
      final progress = playerProgressSignal.peek();
      final changedTrack = currentTrackIdSignal.peek() != target;
      final finishedLastTrack =
          state != null &&
          !state.isPlaying &&
          progress != null &&
          progress.durationMs > 0 &&
          progress.positionMs >= progress.durationMs - 500;
      if (changedTrack || finishedLastTrack) {
        await _finish();
      }
      return;
    }

    final deadline = _deadline;
    if (deadline == null) return;

    final remaining = deadline.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      await _finish();
    } else {
      sleepTimerRemainingSignal.value = remaining;
    }
  }

  static Future<void> _finish() async {
    if (_finishing || !sleepTimerActiveSignal.peek()) return;
    _finishing = true;
    final shouldPause = isPlayingSignal.peek();
    _reset();
    try {
      if (shouldPause) await PlaybackController.pause();
      showAppSuccess('Таймер сна остановил воспроизведение');
    } on Object {
      showAppError('Таймер сработал, но не удалось остановить музыку');
    } finally {
      _finishing = false;
    }
  }

  static String _formatDuration(Duration value) {
    final seconds = value.inSeconds.clamp(0, 24 * 60 * 60);
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) {
      return '${hours.toString()}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${secs.toString().padLeft(2, '0')}';
  }
}
