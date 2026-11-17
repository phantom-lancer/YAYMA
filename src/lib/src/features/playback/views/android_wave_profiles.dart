import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:yayma/src/features/core/theme/app_tokens.dart';
import 'package:yayma/src/features/core/providers/visual_effects_provider.dart';
import 'package:yayma/src/features/core/views/widgets/app_cover.dart';
import 'package:yayma/src/features/core/views/widgets/common_ui.dart';
import 'package:yayma/src/features/core/views/widgets/track_elements.dart';
import 'package:yayma/src/features/playback/providers/playback_provider.dart';
import 'package:yayma/src/features/playback/providers/wave_provider.dart';
import 'package:yayma/src/rust/api/models.dart';
import 'package:yayma/src/features/playback/views/wave_view.dart'
    show showWaveSettingsSheet;

/// Compact Yandex Music-inspired presentation. The full-screen shader wave is
/// supplied by the app shell; this page keeps the track and controls compact.
class YandexMusicWaveView extends StatelessWidget {
  const YandexMusicWaveView({super.key});

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        final meta = trackMetadataSignal();
        final playing = stablePlayingSignal();
        final liked = isLikedSignal();
        final seeds = currentWaveSeedsSignal();
        final scheme = Theme.of(context).colorScheme;
        final width = MediaQuery.sizeOf(context).width;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            20,
            18,
            20,
            112 + MediaQuery.viewPaddingOf(context).bottom,
          ),
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
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: const Color(0xFFFF5A5F),
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.8,
                                  ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Музыка под настроение',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Настроить волну',
                        onPressed: () => showWaveSettingsSheet(context),
                        icon: const Icon(Icons.tune_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _YandexNowPlaying(
                    coverUrl: meta.coverUrl,
                    title: meta.title,
                    version: meta.version,
                    artists: meta.artists,
                    hasTrack: meta.id != null,
                    playing: playing,
                    liked: liked,
                    trackId: meta.id,
                  ),
                  const SizedBox(height: 26),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'ТВОЯ ВОЛНА',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.4,
                              ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => showWaveSettingsSheet(context),
                        child: const Text('Настроить'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 9,
                    runSpacing: 9,
                    children: [
                      _WavePresetPill(
                        title: 'Любимое',
                        icon: Icons.favorite_rounded,
                        seed: 'personal:collection',
                        selected: seeds.contains('personal:collection'),
                      ),
                      _WavePresetPill(
                        title: 'Новое',
                        icon: Icons.auto_awesome_rounded,
                        seed: 'personal:never-heard',
                        selected: seeds.contains('personal:never-heard'),
                      ),
                      _WavePresetPill(
                        title: 'Хиты',
                        icon: Icons.bolt_rounded,
                        seed: 'personal:hits',
                        selected: seeds.contains('personal:hits'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _YandexActionRow(
                    onStart: () => unawaited(WaveController.startMyWave()),
                    onSettings: () => showWaveSettingsSheet(context),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _YandexNowPlaying extends StatelessWidget {
  final String? coverUrl;
  final String title;
  final String? version;
  final List<TrackArtistDto> artists;
  final bool hasTrack;
  final bool playing;
  final bool liked;
  final String? trackId;

  const _YandexNowPlaying({
    required this.coverUrl,
    required this.title,
    required this.version,
    required this.artists,
    required this.hasTrack,
    required this.playing,
    required this.liked,
    required this.trackId,
  });

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 420;
    final artSize = narrow ? 92.0 : 112.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF342126), Color(0xFF1D1A20), Color(0xFF17171D)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEE454B).withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AppCover(
                coverUrl: coverUrl,
                size: artSize,
                radius: 18,
                canExpand: true,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasTrack ? 'СЕЙЧАС ИГРАЕТ' : 'ПЕРСОНАЛЬНОЕ РАДИО',
                      style: const TextStyle(
                        color: Color(0xFFFF777B),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text.rich(
                      trackTitleSpan(
                        context,
                        title: hasTrack ? title : 'Твоя волна',
                        version: version,
                        style: const TextStyle(
                          fontSize: 19,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.35,
                        ),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    if (artists.isNotEmpty)
                      ArtistNamesWidget(
                        artists: artists,
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.66),
                        maxLines: 1,
                      )
                    else
                      Text(
                        'Подборка музыки для тебя',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.62),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              if (trackId != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () =>
                      unawaited(PlaybackController.toggleLike(trackId: trackId!)),
                  icon: Icon(
                    liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: liked ? const Color(0xFFFF626A) : Colors.white70,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (hasTrack) ...[
            const SizedBox(height: 14),
            const CommonProgressSlider(
              compact: true,
              accentColor: Color(0xFFFF656B),
            ),
          ],
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: PlaybackController.prev,
                icon: const Icon(Icons.skip_previous_rounded),
                color: Colors.white,
                iconSize: 31,
              ),
              const SizedBox(width: 12),
              IconButton.filled(
                onPressed: PlaybackController.togglePlay,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5C62),
                  foregroundColor: Colors.white,
                  fixedSize: const Size(54, 54),
                ),
                icon: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 31,
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: PlaybackController.next,
                icon: const Icon(Icons.skip_next_rounded),
                color: Colors.white,
                iconSize: 31,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _YandexActionRow extends StatelessWidget {
  final VoidCallback onStart;
  final VoidCallback onSettings;

  const _YandexActionRow({required this.onStart, required this.onSettings});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.waves_rounded),
            label: const Text('Запустить волну'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF5B61),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton.filledTonal(
          onPressed: onSettings,
          icon: const Icon(Icons.tune_rounded),
          tooltip: 'Все настройки волны',
          style: IconButton.styleFrom(
            fixedSize: const Size(48, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
            ),
          ),
        ),
      ],
    );
  }
}

class _WavePresetPill extends StatelessWidget {
  final String title;
  final IconData icon;
  final String seed;
  final bool selected;

  const _WavePresetPill({
    required this.title,
    required this.icon,
    required this.seed,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? const Color(0xFFFF5B61).withValues(alpha: 0.18)
          : scheme.surfaceContainerHigh.withValues(alpha: 0.62),
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: () => unawaited(WaveController.toggleStation(seed)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: selected
                  ? const Color(0xFFFF5B61).withValues(alpha: 0.55)
                  : scheme.onSurface.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected
                    ? const Color(0xFFFF6A70)
                    : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 7),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Apple Music-inspired layout with a restrained iOS 26 glass treatment.
/// It keeps the artwork prominent and places transport controls immediately
/// beneath the progress track instead of inside a tall player card.
class AppleMusicWaveView extends StatelessWidget {
  const AppleMusicWaveView({super.key});

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        final meta = trackMetadataSignal();
        final playing = stablePlayingSignal();
        final liked = isLikedSignal();
        final scheme = Theme.of(context).colorScheme;
        final width = MediaQuery.sizeOf(context).width;
        final artSize = (width - 72).clamp(190.0, 300.0).toDouble();

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            112 + MediaQuery.viewPaddingOf(context).bottom,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'МОЯ ВОЛНА',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.5,
                                  ),
                            ),
                            Text(
                              'Apple Music',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      _AppleGlassIcon(
                        icon: Icons.tune_rounded,
                        onPressed: () => showWaveSettingsSheet(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _AppleGlassPanel(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          AppCover(
                            coverUrl: meta.coverUrl,
                            size: artSize,
                            radius: 22,
                            canExpand: true,
                          ),
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text.rich(
                                      trackTitleSpan(
                                        context,
                                        title: meta.id == null
                                            ? 'Твоя волна'
                                            : meta.title,
                                        version: meta.version,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge!
                                            .copyWith(
                                              fontSize: 21,
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 5),
                                    ArtistNamesWidget(
                                      artists: meta.artists,
                                      fontSize: 14,
                                      color: scheme.onSurfaceVariant,
                                      maxLines: 1,
                                    ),
                                  ],
                                ),
                              ),
                              if (meta.id != null)
                                _AppleGlassIcon(
                                  icon: liked
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  onPressed: () => unawaited(
                                    PlaybackController.toggleLike(
                                      trackId: meta.id!,
                                    ),
                                  ),
                                  accent: liked,
                                ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          if (meta.id != null) ...[
                            const SizedBox(height: 18),
                            const CommonProgressSlider(),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              IconButton(
                                onPressed: PlaybackController.prev,
                                icon: const Icon(Icons.skip_previous_rounded),
                                iconSize: 38,
                              ),
                              _ApplePlayButton(
                                playing: playing,
                                onPressed: PlaybackController.togglePlay,
                              ),
                              IconButton(
                                onPressed: PlaybackController.next,
                                icon: const Icon(Icons.skip_next_rounded),
                                iconSize: 38,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _AppleGlassPanel(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'НАСТРОЙ СВОЮ ВОЛНУ',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _AppleWaveChoice(
                                  title: 'Любимое',
                                  icon: Icons.favorite_rounded,
                                  seed: 'personal:collection',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _AppleWaveChoice(
                                  title: 'Новое',
                                  icon: Icons.auto_awesome_rounded,
                                  seed: 'personal:never-heard',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _AppleWaveChoice(
                                  title: 'Хиты',
                                  icon: Icons.bolt_rounded,
                                  seed: 'personal:hits',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () => showWaveSettingsSheet(context),
                    icon: const Icon(Icons.tune_rounded),
                    label: const Text('Персонализация волны'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AppleGlassPanel extends StatelessWidget {
  final Widget child;

  const _AppleGlassPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppRadius.xxxl);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        enabled: blurEffectsEnabledSignal.value,
        filter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            color: scheme.surfaceContainerHigh.withValues(alpha: 0.52),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.12),
                scheme.surfaceContainerHigh.withValues(alpha: 0.46),
                scheme.surfaceContainer.withValues(alpha: 0.32),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.20),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 30,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _AppleGlassIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool accent;

  const _AppleGlassIcon({
    required this.icon,
    required this.onPressed,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        enabled: blurEffectsEnabledSignal.value,
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Material(
          color: Colors.white.withValues(alpha: 0.10),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(
              icon,
              color: accent ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _ApplePlayButton extends StatelessWidget {
  final bool playing;
  final VoidCallback onPressed;

  const _ApplePlayButton({
    required this.playing,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        enabled: blurEffectsEnabledSignal.value,
        filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Material(
          color: Colors.white.withValues(alpha: 0.17),
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              width: 72,
              height: 72,
              child: Icon(
                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 40,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppleWaveChoice extends StatelessWidget {
  final String title;
  final IconData icon;
  final String seed;

  const _AppleWaveChoice({
    required this.title,
    required this.icon,
    required this.seed,
  });

  @override
  Widget build(BuildContext context) {
    final selected = currentWaveSeedsSignal().contains(seed);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? scheme.primary.withValues(alpha: 0.17)
          : Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => unawaited(WaveController.toggleStation(seed)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
          child: Column(
            children: [
              Icon(
                icon,
                size: 19,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 6),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
