import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:yayma/src/features/core/providers/navigation_provider.dart';
import 'package:yayma/src/features/core/theme/app_tokens.dart';
import 'package:yayma/src/features/core/views/widgets/app_cover.dart';
import 'package:yayma/src/features/core/views/widgets/common_ui.dart';
import 'package:yayma/src/features/core/views/widgets/liquid_glass.dart';
import 'package:yayma/src/features/playback/providers/playback_provider.dart';
import 'package:yayma/src/features/playback/providers/wave_provider.dart';
import 'package:yayma/src/features/playback/views/wave_view.dart'
    show showWaveSettingsSheet;
import 'package:yayma/src/rust/api/models.dart';

typedef _TrackMeta = ({
  String? id,
  String title,
  String? version,
  List<TrackArtistDto> artists,
  String? album,
  String? albumId,
  String? coverUrl,
  int durationMs,
  String? codec,
});

typedef _TrackProgress = ({double durationMs, double positionMs});

/// Android's main "Моя волна" page.
///
/// The composition follows the official app: an add button, a centred yellow
/// title and search in the top bar; an oversized now-playing title; the cover;
/// a row of pause / current-mode / like controls; then a horizontally
/// scrolling shelf of real, tappable wave stations.
///
/// It is deliberately a complete tab, not a decorative hero: every control is
/// wired to the shared playback and wave controllers, and the cover opens the
/// full-size artwork while the mode pill opens the full wave settings sheet.
class MyWaveReferenceView extends StatelessWidget {
  const MyWaveReferenceView({super.key});

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        final meta = trackMetadataSignal();
        final playing = stablePlayingSignal();
        final buffering = showBufferingIndicatorSignal();
        final liked = isLikedSignal();
        final seeds = currentWaveSeedsSignal();
        final hasTrack = meta.id != null;

        return LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 700;
            final width = constraints.maxWidth;
            final horizontal = width < 380 ? 16.0 : 20.0;

            return Padding(
              padding: EdgeInsets.fromLTRB(horizontal, 6, horizontal, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _WaveTopBar(),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Flexible(
                          flex: 5,
                          child: _GiantTrackTitle(
                            title: hasTrack ? meta.title : 'Моя волна',
                            compact: compact,
                          ),
                        ),
                        Flexible(
                          flex: 7,
                          child: _CoverAndControls(
                            meta: meta,
                            playing: playing,
                            buffering: buffering,
                            liked: liked,
                            hasTrack: hasTrack,
                            seeds: seeds,
                            compact: compact,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: compact ? 142 : 172,
                    child: const _WaveStationShelf(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _WaveTopBar extends StatelessWidget {
  const _WaveTopBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              button: true,
              label: 'Добавить станцию',
              child: GestureDetector(
                onTap: () => showWaveSettingsSheet(context),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFF5BA8), Color(0xFFFFC24B)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF5BA8).withValues(alpha: 0.34),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 27,
                  ),
                ),
              ),
            ),
          ),
          const Text(
            'Моя волна',
            style: TextStyle(
              color: Color(0xFFFFE500),
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Semantics(
              button: true,
              label: 'Поиск',
              child: GestureDetector(
                onTap: () => setSection(AppSection.search),
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(
                    Icons.search_rounded,
                    color: Colors.white,
                    size: 29,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GiantTrackTitle extends StatelessWidget {
  const _GiantTrackTitle({required this.title, required this.compact});

  final String title;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = title.trim().toUpperCase();
    return LayoutBuilder(
      builder: (context, constraints) {
        var size = (constraints.maxWidth * (compact ? 0.115 : 0.135))
            .clamp(26.0, 60.0)
            .toDouble();
        final style = TextStyle(
          color: Colors.white,
          fontSize: size,
          height: 0.94,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.6,
        );
        var painter = TextPainter(
          text: TextSpan(text: text, style: style),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          maxLines: 2,
          ellipsis: '…',
        )..layout(maxWidth: constraints.maxWidth);
        while (painter.didExceedMaxLines && size > 20) {
          size -= 1.5;
          painter = TextPainter(
            text: TextSpan(
              text: text,
              style: style.copyWith(fontSize: size),
            ),
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            maxLines: 2,
            ellipsis: '…',
          )..layout(maxWidth: constraints.maxWidth);
        }
        return Semantics(
          header: true,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 380),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.08),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: Text(
              text,
              key: ValueKey(text),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: style.copyWith(fontSize: size),
            ),
          ),
        );
      },
    );
  }
}

class _CoverAndControls extends StatelessWidget {
  const _CoverAndControls({
    required this.meta,
    required this.playing,
    required this.buffering,
    required this.liked,
    required this.hasTrack,
    required this.seeds,
    required this.compact,
  });

  final _TrackMeta meta;
  final bool playing;
  final bool buffering;
  final bool liked;
  final bool hasTrack;
  final List<String> seeds;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final coverSize = (width * (compact ? 0.29 : 0.315))
        .clamp(92.0, 196.0)
        .toDouble();
    final mode = _modeLabel(seeds);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _AnimatedCover(
          meta: meta,
          coverSize: coverSize,
          hasTrack: hasTrack,
        ),
        SizedBox(height: compact ? 14 : 20),
        Row(
          children: [
            _CircleGlassAction(
              label: playing ? 'Пауза' : 'Играть',
              size: compact ? 58 : 64,
              onTap: () {
                if (hasTrack) {
                  unawaited(PlaybackController.togglePlay());
                } else {
                  unawaited(WaveController.startMyWave());
                }
              },
              child: buffering
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: compact ? 28 : 32,
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: LiquidGlassSurface(
                borderRadius: BorderRadius.circular(AppRadius.full),
                blurSigma: 22,
                tintOpacity: 0.22,
                animated: true,
                intensity: 0.9,
                padding: EdgeInsets.zero,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  onTap: () => showWaveSettingsSheet(context),
                  child: SizedBox(
                    height: compact ? 58 : 64,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            mode.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: compact ? 14 : 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.info_outline_rounded,
                          color: Colors.white70,
                          size: 17,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _CircleGlassAction(
              label: liked ? 'Убрать из избранного' : 'В избранное',
              size: compact ? 58 : 64,
              onTap: hasTrack
                  ? () => unawaited(
                      PlaybackController.toggleLike(trackId: meta.id!),
                    )
                  : null,
              child: Icon(
                liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: liked ? const Color(0xFFFF6B8A) : Colors.white,
                size: compact ? 26 : 29,
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 10 : 14),
        SignalBuilder(
          builder: (context) => _ThinWaveProgress(
            progress: trackProgressSignal(),
            enabled: hasTrack,
          ),
        ),
      ],
    );
  }

  String _modeLabel(List<String> seeds) {
    if (seeds.isEmpty || seeds.contains('user:onyourwave')) return 'Моя волна';
    const labels = {
      'personal:collection': 'Любимое',
      'personal:never-heard': 'Незнакомое',
      'personal:hits': 'Хиты',
      'mood:energetic': 'Бодрое',
      'mood:happy': 'Весёлое',
      'mood:calm': 'Спокойное',
      'mood:sad': 'Грустное',
      'activity:work': 'Работа',
      'activity:sport': 'Спорт',
      'activity:fall-asleep': 'Засыпаю',
    };
    final direct = labels[seeds.first];
    if (direct != null) return direct;
    final stations = waveStationsSignal.value;
    if (stations.hasValue) {
      for (final category in stations.value!) {
        for (final item in category.items) {
          if (item.seed == seeds.first) return item.label;
        }
      }
    }
    if (seeds.length > 1) return '${seeds.length} настроения';
    return 'Моя волна';
  }
}

class _AnimatedCover extends StatelessWidget {
  const _AnimatedCover({
    required this.meta,
    required this.coverSize,
    required this.hasTrack,
  });

  final _TrackMeta meta;
  final double coverSize;
  final bool hasTrack;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
      child: Container(
        key: ValueKey(meta.coverUrl ?? 'empty'),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.46),
              blurRadius: 34,
              spreadRadius: -6,
              offset: const Offset(0, 18),
            ),
            if (hasTrack)
              BoxShadow(
                color: accentColorSignal.value.withValues(alpha: 0.22),
                blurRadius: 44,
                spreadRadius: 2,
              ),
          ],
        ),
        child: hasTrack
            ? AppCover(
                coverUrl: meta.coverUrl,
                size: coverSize,
                radius: 8,
                canExpand: true,
              )
            : GestureDetector(
                onTap: () => unawaited(WaveController.startMyWave()),
                child: LiquidGlassSurface(
                  borderRadius: BorderRadius.circular(10),
                  blurSigma: 22,
                  tintOpacity: 0.18,
                  padding: EdgeInsets.zero,
                  child: SizedBox(
                    width: coverSize,
                    height: coverSize,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.radio_rounded,
                          color: Colors.white.withValues(alpha: 0.9),
                          size: coverSize * 0.30,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Начать волну',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _CircleGlassAction extends StatelessWidget {
  const _CircleGlassAction({
    required this.child,
    required this.label,
    required this.size,
    required this.onTap,
  });

  final Widget child;
  final String label;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Opacity(
        opacity: onTap == null ? 0.42 : 1,
        child: LiquidGlassSurface(
          borderRadius: BorderRadius.circular(AppRadius.full),
          blurSigma: 22,
          tintOpacity: 0.22,
          intensity: 0.95,
          shadows: false,
          padding: EdgeInsets.zero,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: size,
              height: size,
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThinWaveProgress extends StatelessWidget {
  const _ThinWaveProgress({required this.progress, required this.enabled});

  final _TrackProgress progress;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final duration = progress.durationMs;
    final position = progress.positionMs.clamp(0, duration > 0 ? duration : 1);
    final fraction = duration > 0 ? position / duration : 0.0;

    return SizedBox(
      width: 260,
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              void seek(Offset local) {
                if (!enabled || duration <= 0) return;
                final ratio = (local.dx / constraints.maxWidth).clamp(0.0, 1.0);
                unawaited(
                  PlaybackController.seekTo(
                    Duration(milliseconds: (ratio * duration).round()),
                  ),
                );
              }

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) => seek(details.localPosition),
                onHorizontalDragUpdate: (details) => seek(details.localPosition),
                child: SizedBox(
                  height: 14,
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Stack(
                        children: [
                          Container(
                            height: 3,
                            color: Colors.white.withValues(alpha: 0.20),
                          ),
                          FractionallySizedBox(
                            widthFactor: fraction.clamp(0.0, 1.0).toDouble(),
                            child: Container(
                              height: 3,
                              color: Colors.white.withValues(alpha: 0.86),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatDuration(position.toInt()),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.56),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                formatDuration(duration.toInt()),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.56),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WaveStationShelf extends StatelessWidget {
  const _WaveStationShelf();

  static const _fallback = <_StationVisual>[
    _StationVisual(
      label: 'Любимое',
      seed: 'personal:collection',
      icon: Icons.favorite_rounded,
      colors: [Color(0xFFFF2045), Color(0xFF8A0C2A)],
    ),
    _StationVisual(
      label: 'Незнакомое',
      seed: 'personal:never-heard',
      icon: Icons.auto_awesome_rounded,
      colors: [Color(0xFFFF8A1E), Color(0xFF7A3400)],
    ),
    _StationVisual(
      label: 'Хиты',
      seed: 'personal:hits',
      icon: Icons.bolt_rounded,
      colors: [Color(0xFF4A5BFF), Color(0xFF121C8A)],
    ),
    _StationVisual(
      label: 'Бодрое',
      seed: 'mood:energetic',
      icon: Icons.rocket_launch_rounded,
      colors: [Color(0xFF19C37D), Color(0xFF075439)],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        final seeds = currentWaveSeedsSignal();
        final future = waveStationsSignal.value;
        final items = _realStations(future.hasValue ? future.value : null);
        final visuals = items.isEmpty ? _fallback : items;

        return LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = (constraints.maxWidth * 0.44)
                .clamp(146.0, 208.0)
                .toDouble();
            return ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(right: 20),
              itemCount: visuals.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final visual = visuals[index];
                return _StationBlob(
                  visual: visual,
                  width: cardWidth,
                  selected: seeds.contains(visual.seed),
                );
              },
            );
          },
        );
      },
    );
  }

  List<_StationVisual> _realStations(List<StationCategoryDto>? categories) {
    if (categories == null) return const [];
    final result = <_StationVisual>[];
    final seen = <String>{};
    const palette = [
      [Color(0xFFFF2045), Color(0xFF8A0C2A)],
      [Color(0xFFFF8A1E), Color(0xFF7A3400)],
      [Color(0xFF4A5BFF), Color(0xFF121C8A)],
      [Color(0xFF19C37D), Color(0xFF075439)],
      [Color(0xFF9B5CFF), Color(0xFF3A147E)],
      [Color(0xFF17B8C4), Color(0xFF06444F)],
      [Color(0xFFFF5BA8), Color(0xFF7A1748)],
      [Color(0xFFE0B21A), Color(0xFF5C4700)],
    ];
    const icons = [
      Icons.favorite_rounded,
      Icons.auto_awesome_rounded,
      Icons.bolt_rounded,
      Icons.explore_rounded,
      Icons.nightlight_round,
      Icons.rocket_launch_rounded,
      Icons.graphic_eq_rounded,
      Icons.celebration_rounded,
    ];
    for (final category in categories) {
      for (final item in category.items) {
        if (item.seed.isEmpty || !seen.add(item.seed)) continue;
        final index = result.length % palette.length;
        result.add(
          _StationVisual(
            label: item.label,
            seed: item.seed,
            icon: icons[index],
            colors: palette[index],
          ),
        );
        if (result.length >= 10) return result;
      }
    }
    return result;
  }
}

class _StationVisual {
  const _StationVisual({
    required this.label,
    required this.seed,
    required this.icon,
    required this.colors,
  });

  final String label;
  final String seed;
  final IconData icon;
  final List<Color> colors;
}

class _StationBlob extends StatefulWidget {
  const _StationBlob({
    required this.visual,
    required this.width,
    required this.selected,
  });

  final _StationVisual visual;
  final double width;
  final bool selected;

  @override
  State<_StationBlob> createState() => _StationBlobState();
}

class _StationBlobState extends State<_StationBlob> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final visual = widget.visual;
    final color = visual.colors.first;
    return Semantics(
      button: true,
      selected: widget.selected,
      label: visual.label,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: () => unawaited(WaveController.toggleStation(visual.seed)),
        child: AnimatedScale(
          scale: _pressed ? 0.965 : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: widget.width,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: visual.colors,
              ),
              border: Border.all(
                color: Colors.white.withValues(
                  alpha: widget.selected ? 0.88 : 0.10,
                ),
                width: widget.selected ? 1.6 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.38),
                  blurRadius: 26,
                  spreadRadius: -4,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    right: -18,
                    top: -22,
                    child: Icon(
                      visual.icon,
                      size: widget.width * 0.46,
                      color: Colors.white.withValues(alpha: 0.09),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                visual.icon,
                                color: Colors.white,
                                size: 19,
                              ),
                            ),
                            const Spacer(),
                            if (widget.selected)
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.check_rounded,
                                  size: 15,
                                  color: visual.colors.last,
                                ),
                              ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          visual.label,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            height: 1.12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
