import 'dart:async';

import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:yayma/src/features/core/theme/app_tokens.dart';
import 'package:yayma/src/features/core/views/widgets/common_ui.dart';
import 'package:yayma/src/features/playback/providers/playback_provider.dart';
import 'package:yayma/src/features/playback/providers/sleep_timer_provider.dart';

Future<void> showSleepTimerSheet(
  BuildContext context, {
  String? trackId,
}) {
  final currentTrack = trackId ?? currentTrackIdSignal.peek();
  return showAppBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => _SleepTimerSheet(trackId: currentTrack),
  );
}

class _SleepTimerSheet extends StatelessWidget {
  final String? trackId;

  const _SleepTimerSheet({required this.trackId});

  static const _presets = <({String title, Duration duration})>[
    (title: '15 минут', duration: Duration(minutes: 15)),
    (title: '30 минут', duration: Duration(minutes: 30)),
    (title: '45 минут', duration: Duration(minutes: 45)),
    (title: '1 час', duration: Duration(hours: 1)),
    (title: '1 час 30 минут', duration: Duration(minutes: 90)),
  ];

  String _formatRemaining(Duration value) {
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
        child: SignalBuilder(
          builder: (context) {
            final active = sleepTimerActiveSignal();
            final remaining = sleepTimerRemainingSignal();
            final endsAfterTrack = sleepTimerEndsAfterTrackSignal();

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Icon(Icons.bedtime_rounded, color: scheme.primary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Таймер сна',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              active
                                  ? (endsAfterTrack
                                      ? 'Остановка после текущего трека'
                                      : 'Осталось ${_formatRemaining(remaining ?? Duration.zero)}')
                                  : 'Остановить музыку автоматически',
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (active) ...[
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                          color: scheme.primary.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            endsAfterTrack
                                ? Icons.album_rounded
                                : Icons.hourglass_bottom_rounded,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              endsAfterTrack
                                  ? 'Текущий трек доиграет до конца'
                                  : 'Музыка остановится через ${_formatRemaining(remaining ?? Duration.zero)}',
                              style: TextStyle(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: SleepTimerController.cancel,
                            child: const Text('Отменить'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    'ОСТАНОВИТЬ ЧЕРЕЗ',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ..._presets.map(
                    (preset) => ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: Icon(
                        Icons.schedule_rounded,
                        color: scheme.onSurfaceVariant,
                      ),
                      title: Text(
                        preset.title,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        SleepTimerController.start(preset.duration);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  const Divider(height: 12),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: Icon(
                      Icons.music_note_rounded,
                      color: trackId == null
                          ? scheme.onSurfaceVariant.withValues(alpha: 0.35)
                          : scheme.primary,
                    ),
                    title: Text(
                      'До конца текущего трека',
                      style: TextStyle(
                        color: trackId == null
                            ? scheme.onSurfaceVariant
                            : scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      trackId == null
                          ? 'Сначала запусти воспроизведение'
                          : 'Не начнётся следующий трек',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    enabled: trackId != null,
                    onTap: trackId == null
                        ? null
                        : () {
                            SleepTimerController.startAfterTrack(trackId!);
                            Navigator.pop(context);
                          },
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Закрыть'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class SleepTimerIconButton extends StatefulWidget {
  const SleepTimerIconButton({super.key});

  @override
  State<SleepTimerIconButton> createState() => _SleepTimerIconButtonState();
}

class _SleepTimerIconButtonState extends State<SleepTimerIconButton> {
  Timer? _clock;

  bool get _isNight {
    final hour = DateTime.now().hour;
    return hour >= 21 || hour < 8;
  }

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        final active = sleepTimerActiveSignal();
        if (!active && !_isNight) return const SizedBox.shrink();

        final scheme = Theme.of(context).colorScheme;
        return IconButton(
          tooltip: active ? 'Таймер сна активен' : 'Таймер сна',
          onPressed: () => unawaited(
            showSleepTimerSheet(context, trackId: currentTrackIdSignal.peek()),
          ),
          visualDensity: VisualDensity.compact,
          icon: Icon(
            active ? Icons.bedtime_rounded : Icons.bedtime_outlined,
            color: active ? scheme.primary : scheme.onSurfaceVariant,
            size: 24,
          ),
        );
      },
    );
  }
}
