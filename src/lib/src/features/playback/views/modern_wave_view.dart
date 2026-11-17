import 'dart:async';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:yayma/src/features/core/theme/app_tokens.dart';
import 'package:yayma/src/features/core/views/widgets/app_cover.dart';
import 'package:yayma/src/features/core/views/widgets/common_ui.dart';
import 'package:yayma/src/features/core/views/widgets/responsive.dart';
import 'package:yayma/src/features/core/views/widgets/track_elements.dart';
import 'package:yayma/src/features/playback/providers/playback_provider.dart';
import 'package:yayma/src/features/playback/providers/wave_provider.dart';
import 'package:yayma/src/features/playback/views/wave_view.dart'
    show showWaveSettingsSheet;

/// Redesigned Android home for My Wave. The old screen remains intact in
/// [wave_view.dart] and can be restored from Settings.
class ModernMyWaveView extends StatelessWidget {
  const ModernMyWaveView({super.key});

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        final meta = trackMetadataSignal();
        final playing = stablePlayingSignal();
        final progress = trackProgressSignal();
        final buffering = showBufferingIndicatorSignal();
        final liked = isLikedSignal();
        final scheme = Theme.of(context).colorScheme;
        final horizontal = context.horizontalPadding;
        final hasTrack = meta.id != null;
        final duration = progress.durationMs;
        final position = progress.positionMs.clamp(0.0, duration).toDouble();
        final fraction = duration > 0
            ? (position / duration).clamp(0.0, 1.0)
            : 0.0;
        final coverSize = (MediaQuery.sizeOf(context).width - horizontal * 2 - 56)
            .clamp(160.0, 232.0);

        return Stack(
          children: [
            if (meta.coverUrl != null)
              Positioned(
                top: -100,
                left: -90,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.13,
                    child: ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(sigmaX: 64, sigmaY: 64),
                      child: AppCover(
                        coverUrl: meta.coverUrl,
                        size: 320,
                        radius: AppRadius.xxxl,
                      ),
                    ),
                  ),
                ),
              ),
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(horizontal, 22, horizontal, 28),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 680),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'МОЯ ВОЛНА',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium
                                            ?.copyWith(
                                              color: scheme.primary,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 2.2,
                                            ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        'Твой поток музыки',
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: -0.7,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                _GlassIconButton(
                                  icon: Icons.tune_rounded,
                                  tooltip: 'Настроить волну',
                                  onPressed: () => showWaveSettingsSheet(context),
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),
                            _NowPlayingGlass(
                              coverSize: coverSize,
                              hasTrack: hasTrack,
                              title: meta.title,
                              version: meta.version,
                              coverUrl: meta.coverUrl,
                              artists: meta.artists,
                              playing: playing,
                              buffering: buffering,
                              liked: liked,
                              trackId: meta.id,
                              fraction: fraction,
                              position: position,
                              duration: duration,
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'НАСТРОЙ СВОЙ ПОТОК',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.35,
                                        ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => showWaveSettingsSheet(context),
                                  child: const Text('Все фильтры'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: const [
                                Expanded(
                                  child: _WaveChoice(
                                    title: 'Любимое',
                                    subtitle: 'Твои треки',
                                    icon: Icons.favorite_rounded,
                                    seed: 'personal:collection',
                                  ),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: _WaveChoice(
                                    title: 'Новое',
                                    subtitle: 'Открытия',
                                    icon: Icons.auto_awesome_rounded,
                                    seed: 'personal:never-heard',
                                  ),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: _WaveChoice(
                                    title: 'Хиты',
                                    subtitle: 'Популярное',
                                    icon: Icons.bolt_rounded,
                                    seed: 'personal:hits',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _GlassActionTile(
                              icon: Icons.tune_rounded,
                              title: 'Персонализация волны',
                              subtitle: 'Жанры, настроение и другие фильтры',
                              onTap: () => showWaveSettingsSheet(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _NowPlayingGlass extends StatelessWidget {
  final double coverSize;
  final bool hasTrack;
  final String title;
  final String? version;
  final String? coverUrl;
  final List<dynamic> artists;
  final bool playing;
  final bool buffering;
  final bool liked;
  final String? trackId;
  final double fraction;
  final double position;
  final double duration;

  const _NowPlayingGlass({
    required this.coverSize,
    required this.hasTrack,
    required this.title,
    required this.version,
    required this.coverUrl,
    required this.artists,
    required this.playing,
    required this.buffering,
    required this.liked,
    required this.trackId,
    required this.fraction,
    required this.position,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(30);

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh.withValues(alpha: 0.72),
            borderRadius: radius,
            border: Border.all(
              color: scheme.onSurface.withValues(alpha: 0.12),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.surfaceContainerHigh.withValues(alpha: 0.82),
                scheme.surfaceContainer.withValues(alpha: 0.58),
              ],
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.graphic_eq_rounded, color: scheme.primary, size: 19),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasTrack ? 'СЕЙЧАС ИГРАЕТ' : 'ПЕРСОНАЛЬНОЕ РАДИО',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.35,
                          ),
                    ),
                  ),
                  _StatusPill(
                    text: buffering ? 'ЗАГРУЗКА' : playing ? 'ИГРАЕТ' : 'ПАУЗА',
                    active: buffering || playing,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              if (hasTrack && coverUrl != null)
                AppCover(
                  coverUrl: coverUrl,
                  size: coverSize,
                  radius: AppRadius.xxl,
                  canExpand: true,
                )
              else
                Container(
                  width: coverSize,
                  height: coverSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.xxl),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        scheme.primary.withValues(alpha: 0.36),
                        scheme.tertiary.withValues(alpha: 0.20),
                        scheme.surfaceContainerHighest,
                      ],
                    ),
                  ),
                  child: Icon(
                    Icons.graphic_eq_rounded,
                    size: 72,
                    color: scheme.onSurface.withValues(alpha: 0.76),
                  ),
                ),
              const SizedBox(height: 22),
              Text(
                hasTrack ? title : 'Волна ждёт запуска',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.65,
                      height: 1.12,
                    ),
              ),
              if (hasTrack && version != null && version!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    version!,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
                      fontSize: 12,
                    ),
                  ),
                ),
              if (hasTrack && artists.isNotEmpty) ...[
                const SizedBox(height: 8),
                ArtistNamesWidget(
                  artists: artists,
                  fontSize: 14,
                  color: scheme.onSurfaceVariant,
                  alignment: WrapAlignment.center,
                  maxLines: 1,
                ),
              ],
              if (hasTrack) ...[
                const SizedBox(height: 22),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 4,
                    backgroundColor: scheme.onSurface.withValues(alpha: 0.10),
                    valueColor: AlwaysStoppedAnimation(scheme.primary),
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formatDuration(position.round()),
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11,
                        fontFeatures: const [ui.FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      formatDuration(duration.round()),
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11,
                        fontFeatures: const [ui.FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 10),
                Text(
                  'Запусти волну, чтобы музыка подбиралась автоматически',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _GlassIconButton(
                    icon: Icons.skip_previous_rounded,
                    tooltip: 'Предыдущий трек',
                    onPressed: hasTrack
                        ? () => unawaited(PlaybackController.previousTrack())
                        : null,
                    large: false,
                  ),
                  const SizedBox(width: 18),
                  IconButton.filled(
                    onPressed: () {
                      if (hasTrack) {
                        unawaited(PlaybackController.togglePlay());
                      } else {
                        unawaited(WaveController.startMyWave());
                      }
                    },
                    style: IconButton.styleFrom(
                      fixedSize: const Size(68, 68),
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                    ),
                    iconSize: 34,
                    icon: Icon(
                      hasTrack && playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                  ),
                  const SizedBox(width: 18),
                  _GlassIconButton(
                    icon: Icons.skip_next_rounded,
                    tooltip: 'Следующий трек',
                    onPressed: hasTrack
                        ? () => unawaited(PlaybackController.next())
                        : null,
                    large: false,
                  ),
                ],
              ),
              if (hasTrack) ...[
                const SizedBox(height: 8),
                IconButton(
                  tooltip: liked ? 'Убрать из любимого' : 'В любимое',
                  onPressed: trackId == null
                      ? null
                      : () => unawaited(
                            PlaybackController.toggleLike(trackId: trackId!),
                          ),
                  icon: Icon(
                    liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: liked ? Colors.pinkAccent : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WaveChoice extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String seed;

  const _WaveChoice({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.seed,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SignalBuilder(
      builder: (context) {
        final selected = currentWaveSeedsSignal().contains(seed);
        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => unawaited(WaveController.toggleStation(seed)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            decoration: BoxDecoration(
              color: selected
                  ? scheme.primary.withValues(alpha: 0.16)
                  : scheme.surfaceContainerHigh.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? scheme.primary.withValues(alpha: 0.48)
                    : scheme.onSurface.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(height: 9),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GlassActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _GlassActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh.withValues(alpha: 0.58),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool large;

  const _GlassIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.large = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        fixedSize: Size.square(large ? 48 : 52),
        backgroundColor: scheme.onSurface.withValues(alpha: 0.07),
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.onSurface.withValues(alpha: 0.09)),
      ),
      icon: Icon(icon, size: large ? 22 : 27),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String text;
  final bool active;

  const _StatusPill({required this.text, required this.active});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = active ? scheme.primary : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
