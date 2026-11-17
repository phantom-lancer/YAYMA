import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:yayma/src/features/core/providers/visual_effects_provider.dart';
import 'package:yayma/src/features/core/theme/app_tokens.dart';
import 'package:yayma/src/features/core/views/widgets/app_cover.dart';
import 'package:yayma/src/features/core/views/widgets/common_ui.dart';
import 'package:yayma/src/features/core/views/widgets/responsive.dart';
import 'package:yayma/src/features/core/views/widgets/smooth_scroll.dart';
import 'package:yayma/src/features/core/views/widgets/track_elements.dart';
import 'package:yayma/src/features/playback/providers/playback_provider.dart';
import 'package:yayma/src/features/playback/providers/wave_provider.dart';
import 'package:yayma/src/rust/api/models.dart';

/// Android's My Wave home: playback first, tuning second.
/// It reuses the app's live playback state, cached artwork and visual settings.
class MyWaveView extends StatelessWidget {
  const MyWaveView({super.key});

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        final meta = trackMetadataSignal();
        final seeds = currentWaveSeedsSignal();
        final horizontalPadding = context.horizontalPadding;
        final scheme = Theme.of(context).colorScheme;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            if (meta.coverUrl != null && blurEffectsEnabledSignal.value)
              _WaveAmbientBackdrop(coverUrl: meta.coverUrl!),
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                24,
                horizontalPadding,
                140,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CommonPageTitle(title: 'Моя волна'),
                                SizedBox(height: 6),
                                Text(
                                  'Музыка, которая подстраивается под тебя',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            tooltip: 'Настроить волну',
                            onPressed: () => showWaveSettingsSheet(context),
                            icon: const Icon(Icons.tune_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const _WaveNowPlayingCard(),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'БЫСТРЫЙ ВЫБОР',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    letterSpacing: 1.4,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => showWaveSettingsSheet(context),
                            icon: const Icon(Icons.tune_rounded, size: 17),
                            label: const Text('Все настройки'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _WavePresetCard(
                              title: 'Любимое',
                              subtitle: 'Знакомое',
                              icon: Icons.favorite_rounded,
                              seed: 'personal:collection',
                              selected: seeds.contains('personal:collection'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _WavePresetCard(
                              title: 'Открывать',
                              subtitle: 'Новое',
                              icon: Icons.auto_awesome_rounded,
                              seed: 'personal:never-heard',
                              selected: seeds.contains('personal:never-heard'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _WavePresetCard(
                              title: 'Хиты',
                              subtitle: 'Популярное',
                              icon: Icons.bolt_rounded,
                              seed: 'personal:hits',
                              selected: seeds.contains('personal:hits'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _WaveSettingsTile(
                        activeFilters: seeds.length,
                        onTap: () => showWaveSettingsSheet(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The same station settings, now opened separately from the main player page.
Future<void> showWaveSettingsSheet(BuildContext context) {
  return showAppBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.68,
      minChildSize: 0.42,
      maxChildSize: 0.92,
      expand: false,
      snap: true,
      builder: (context, scrollController) => WaveSettingsPanel(
        onSelected: () => Navigator.pop(context),
        scrollController: scrollController,
      ),
    ),
  );
}

class _WaveAmbientBackdrop extends StatelessWidget {
  final String coverUrl;

  const _WaveAmbientBackdrop({required this.coverUrl});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: -108,
      right: -118,
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.16,
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 38, sigmaY: 38),
            child: AppCover(
              coverUrl: coverUrl,
              size: 360,
              radius: AppRadius.xxxl,
            ),
          ),
        ),
      ),
    );
  }
}

class _WaveNowPlayingCard extends StatelessWidget {
  const _WaveNowPlayingCard();

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        final meta = trackMetadataSignal();
        final progress = trackProgressSignal();
        final playing = stablePlayingSignal();
        final liked = isLikedSignal();
        final buffering = showBufferingIndicatorSignal();
        final trackId = meta.id;
        final hasTrack = trackId != null;
        final scheme = Theme.of(context).colorScheme;
        final coverSize = (MediaQuery.sizeOf(context).width - 100)
            .clamp(156.0, 216.0);

        final duration = progress.durationMs;
        final position = progress.positionMs.clamp(0.0, duration).toDouble();
        final fraction = duration > 0
            ? (position / duration).clamp(0.0, 1.0)
            : 0.0;

        return _WaveGlassSurface(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.graphic_eq_rounded,
                    size: 18,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasTrack ? 'СЕЙЧАС ИГРАЕТ' : 'ПЕРСОНАЛЬНАЯ РАДИОСТАНЦИЯ',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  _WaveLiveBadge(
                    label: buffering
                        ? 'ЗАГРУЗКА'
                        : playing
                        ? 'В ЭФИРЕ'
                        : 'ПАУЗА',
                    active: playing || buffering,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              if (hasTrack && meta.coverUrl != null)
                AppCover(
                  coverUrl: meta.coverUrl,
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
                        scheme.primary.withValues(alpha: 0.32),
                        scheme.secondary.withValues(alpha: 0.16),
                        scheme.surfaceContainerHighest,
                      ],
                    ),
                    border: Border.all(
                      color: scheme.onSurface.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Icon(
                    Icons.graphic_eq_rounded,
                    size: 76,
                    color: scheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              const SizedBox(height: 20),
              Text(
                hasTrack ? meta.title : 'Волна ждёт запуска',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: 23,
                  height: 1.12,
                  letterSpacing: -0.5,
                  fontWeight: FontWeight.w900,
                  color: scheme.onSurface,
                ),
              ),
              if (hasTrack && meta.version != null && meta.version!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    meta.version!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.65),
                      fontSize: 12,
                    ),
                  ),
                ),
              if (hasTrack && meta.artists.isNotEmpty) ...[
                const SizedBox(height: 7),
                ArtistNamesWidget(
                  artists: meta.artists,
                  fontSize: 14,
                  color: scheme.onSurfaceVariant,
                  alignment: WrapAlignment.center,
                  maxLines: 1,
                ),
              ] else if (!hasTrack) ...[
                const SizedBox(height: 7),
                Text(
                  'Запусти радио, и музыка начнёт подбираться автоматически',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 22),
              if (hasTrack) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 4,
                    backgroundColor: scheme.onSurface.withValues(alpha: 0.10),
                    valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
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
                const SizedBox(height: 12),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    tooltip: 'В предыдущий трек',
                    onPressed: hasTrack
                        ? () => unawaited(PlaybackController.previousTrack())
                        : null,
                    icon: const Icon(Icons.skip_previous_rounded),
                    iconSize: 28,
                  ),
                  const SizedBox(width: 16),
                  IconButton.filled(
                    tooltip: hasTrack
                        ? (playing ? 'Пауза' : 'Продолжить')
                        : 'Запустить Мою волну',
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
                  const SizedBox(width: 16),
                  IconButton.filledTonal(
                    tooltip: 'Следующий трек',
                    onPressed: hasTrack
                        ? () => unawaited(PlaybackController.next())
                        : null,
                    icon: const Icon(Icons.skip_next_rounded),
                    iconSize: 28,
                  ),
                ],
              ),
              if (hasTrack) ...[
                const SizedBox(height: 12),
                IconButton(
                  tooltip: liked ? 'Убрать из любимого' : 'Добавить в любимое',
                  onPressed: () {
                    PlaybackController.toggleLike(trackId: trackId);
                  },
                  icon: Icon(
                    liked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: liked ? Colors.pinkAccent : scheme.onSurfaceVariant,
                    size: 24,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => unawaited(WaveController.startMyWave()),
                  icon: const Icon(Icons.waves_rounded),
                  label: const Text('Запустить Мою волну'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _WaveLiveBadge extends StatelessWidget {
  final String label;
  final bool active;

  const _WaveLiveBadge({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = active ? scheme.primary : scheme.onSurfaceVariant;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

class _WaveGlassSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const _WaveGlassSurface({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppRadius.xxl);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        enabled: blurEffectsEnabledSignal.value,
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh.withValues(alpha: 0.78),
            borderRadius: radius,
            border: Border.all(
              color: scheme.onSurface.withValues(alpha: 0.09),
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class _WavePresetCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String seed;
  final bool selected;

  const _WavePresetCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.seed,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => unawaited(WaveController.toggleStation(seed)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minHeight: 104),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: 0.14)
                : scheme.surfaceContainerHigh.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected
                  ? scheme.primary.withValues(alpha: 0.58)
                  : scheme.onSurface.withValues(alpha: 0.08),
              width: selected ? 1.3 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
                size: 23,
              ),
              const SizedBox(height: 9),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WaveSettingsTile extends StatelessWidget {
  final int activeFilters;
  final VoidCallback onTap;

  const _WaveSettingsTile({
    required this.activeFilters,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _WaveGlassSurface(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(Icons.tune_rounded, color: scheme.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Настроить Мою волну',
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        activeFilters == 0
                            ? 'Выбрать настроение, жанр и язык'
                            : 'Активных параметров: ' + activeFilters.toString(),
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WaveSettingsPanel extends StatelessWidget {
  final VoidCallback onSelected;
  final ScrollController? scrollController;
  const WaveSettingsPanel({
    required this.onSelected,
    this.scrollController,
    super.key,
  });
  static const List<_VibeItem> _vibes = [
    _VibeItem('Просыпаюсь', 'activity:wake-up'),
    _VibeItem('В дороге', 'activity:road-trip'),
    _VibeItem('Работаю', 'activity:work-background'),
    _VibeItem('Тренируюсь', 'activity:workout'),
    _VibeItem('Засыпаю', 'activity:fall-asleep'),
  ];

  static const List<_VibeItem> _languages = [
    _VibeItem('Русский', 'local-language:russian'),
    _VibeItem('Иностранный', 'local-language:english'),
    _VibeItem('Без слов', 'local-language:instrumental'),
  ];

  static const List<_MoodItem> _moods = [
    _MoodItem('Бодрое', [Colors.orange, Colors.deepOrange], 'mood:energetic'),
    _MoodItem('Весёлое', [Colors.lightGreen, Colors.lime], 'mood:happy'),
    _MoodItem('Спокойное', [Colors.cyan, Colors.teal], 'mood:calm'),
    _MoodItem('Грустное', [Colors.blue, Colors.indigo], 'mood:sad'),
  ];

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        final currentSeeds = currentWaveSeedsSignal();

        return Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(context, currentSeeds),
                    const SizedBox(height: 24),
                    _buildSectionTitle(context, 'Под занятие'),
                    _buildChips(context, _vibes, currentSeeds),
                    const SizedBox(height: 24),
                    _buildSectionTitle(context, 'По характеру'),
                    _buildCharacters(context, currentSeeds),
                    const SizedBox(height: 24),
                    _buildSectionTitle(context, 'Под настроение'),
                    _buildMoods(_moods, currentSeeds),
                    const SizedBox(height: 24),
                    _buildSectionTitle(context, 'По языку'),
                    _buildChips(context, _languages, currentSeeds),
                    const SizedBox(height: 24),
                    if (currentSeeds.isNotEmpty &&
                        !currentSeeds.contains('user:onyourwave') &&
                        !_isMainSeed(currentSeeds.first))
                      _buildActiveExtraStation(context, currentSeeds.first),
                  ],
                ),
              ),
              if (context.isNarrow) _buildStartButton(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, List<String> currentSeeds) {
    final iconColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final canReset =
        currentSeeds.isNotEmpty && !currentSeeds.contains('user:onyourwave');

    return Row(
      children: [
        Expanded(
          child: Text(
            'Настроить Мою волну',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 40,
          height: 40,
          child: canReset
              ? _HeaderIcon(
                  icon: Icons.refresh,
                  color: iconColor,
                  onTap: () => unawaited(WaveController.resetStations()),
                )
              : null,
        ),
        SizedBox(
          width: 40,
          height: 40,
          child: _HeaderIcon(
            icon: Icons.explore,
            color: iconColor,
            onTap: () => showAppBottomSheet<void>(
              context: context,
              builder: (context) => const _AllStationsSheet(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCharacters(BuildContext context, List<String> currentSeeds) {
    return Row(
      children: [
        _CharacterCard(
          label: 'Любимое',
          icon: Icons.favorite,
          color: Colors.red,
          seed: 'personal:collection',
          onSelected: onSelected,
          isSelected: currentSeeds.contains('personal:collection'),
        ),
        const SizedBox(width: 12),
        _CharacterCard(
          label: 'Незнакомое',
          icon: Icons.auto_awesome,
          color: Colors.amber,
          seed: 'personal:never-heard',
          onSelected: onSelected,
          isSelected: currentSeeds.contains('personal:never-heard'),
        ),
        const SizedBox(width: 12),
        _CharacterCard(
          label: 'Популярное',
          icon: Icons.bolt,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          seed: 'personal:hits',
          onSelected: onSelected,
          isSelected: currentSeeds.contains('personal:hits'),
        ),
      ],
    );
  }

  Widget _buildStartButton(BuildContext context) {
    return Positioned(
      right: 24,
      bottom: 32,
      child: M3EFloatingActionButton(
        onPressed: () {
          unawaited(WaveController.startMyWave());
          onSelected();
        },
        containerColor: Theme.of(context).colorScheme.primary,
        contentColor: Colors.black,
        elevation: 8,
        child: const Icon(Icons.play_arrow_rounded, size: 28),
      ),
    );
  }

  bool _isMainSeed(String seed) {
    const mainSeeds = {
      'activity:wake-up',
      'activity:road-trip',
      'activity:work-background',
      'activity:workout',
      'activity:fall-asleep',
      'personal:collection',
      'personal:never-heard',
      'personal:hits',
      'mood:energetic',
      'mood:happy',
      'mood:calm',
      'mood:sad',
      'local-language:russian',
      'local-language:english',
      'local-language:instrumental',
    };
    return mainSeeds.contains(seed);
  }

  Widget _buildActiveExtraStation(BuildContext context, String seed) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Активный режим'),
        SignalBuilder(
          builder: (context) {
            final catsFuture = waveStationsSignal.value;
            var label = seed;

            if (seed.startsWith('track:')) {
              // Display hint is everything after the second ':'.
              // indexOf-based so titles containing ':' don't break parsing.
              final first = seed.indexOf(':');
              final second = first >= 0 ? seed.indexOf(':', first + 1) : -1;
              if (second >= 0 && second + 1 < seed.length) {
                label = seed.substring(second + 1);
              }
            }

            if (catsFuture.hasValue) {
              for (final cat in catsFuture.value!) {
                for (final item in cat.items) {
                  if (item.seed == seed) {
                    label = item.label;
                    break;
                  }
                }
              }
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _RoundedChip(
                item: _VibeItem(label, seed),
                onSelected: onSelected,
                isSelected: true,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(
            context,
          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildChips(
    BuildContext context,
    List<_VibeItem> items,
    List<String> currentSeeds,
  ) {
    if (!context.isNarrow) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items
            .map(
              (i) => _RoundedChip(
                item: i,
                onSelected: onSelected,
                isSelected: currentSeeds.contains(i.seed),
              ),
            )
            .toList(),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: items.asMap().entries.map((entry) {
          final i = entry.value;
          final isLast = entry.key == items.length - 1;
          return Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 8),
            child: _RoundedChip(
              item: i,
              onSelected: onSelected,
              isSelected: currentSeeds.contains(i.seed),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMoods(List<_MoodItem> moods, List<String> currentSeeds) {
    return Row(
      children: moods
          .map(
            (m) => Expanded(
              child: _MoodCircle(
                mood: m,
                onSelected: onSelected,
                isSelected: currentSeeds.contains(m.seed),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _VibeItem {
  final String label;
  final String seed;
  const _VibeItem(this.label, this.seed);
}

class _MoodItem {
  final String label;
  final List<Color> colors;
  final String seed;
  const _MoodItem(this.label, this.colors, this.seed);
}

/// Square tap target with a plain icon, used in the sheet header.
class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _HeaderIcon({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

class _RoundedChip extends StatelessWidget {
  final _VibeItem item;
  final VoidCallback onSelected;
  final bool isSelected;
  const _RoundedChip({
    required this.item,
    required this.onSelected,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isNarrow = context.isNarrow;
    final panelWidth = isNarrow ? (screenWidth - 48) : 480.0;
    final maxLabelWidth = panelWidth - 48 - 40; // Subtract padding for safety

    return FilterChip(
      selected: isSelected,
      label: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxLabelWidth > 0 ? maxLabelWidth : 100,
        ),
        child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      onSelected: (_) {
        unawaited(WaveController.toggleStation(item.seed));
        onSelected();
      },
      backgroundColor: Theme.of(
        context,
      ).colorScheme.onSurface.withValues(alpha: 0.05),
      selectedColor: Theme.of(
        context,
      ).colorScheme.onSurface.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected
            ? Theme.of(context).colorScheme.onSurface
            : Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: isSelected
          ? BorderSide(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.24),
            )
          : BorderSide.none,
      showCheckmark: false,
    );
  }
}

class _CharacterCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final String seed;
  final VoidCallback onSelected;
  final bool isSelected;
  const _CharacterCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.seed,
    required this.onSelected,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: () {
          unawaited(WaveController.toggleStation(seed));
          onSelected();
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 90,
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)
                : Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.3)
                  : Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoodCircle extends StatelessWidget {
  final _MoodItem mood;
  final VoidCallback onSelected;
  final bool isSelected;
  const _MoodCircle({
    required this.mood,
    required this.onSelected,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        unawaited(WaveController.toggleStation(mood.seed));
        onSelected();
      },
      borderRadius: BorderRadius.circular(40),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isSelected ? 56 : 50,
            height: isSelected ? 56 : 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(
                      color: Theme.of(context).colorScheme.onSurface,
                      width: 2,
                    )
                  : null,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: mood.colors,
              ),
              boxShadow: [
                BoxShadow(
                  color: mood.colors[0].withValues(
                    alpha: isSelected ? 0.6 : 0.4,
                  ),
                  blurRadius: isSelected ? 15 : 10,
                  spreadRadius: isSelected ? 3 : 1,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            mood.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _AllStationsSheet extends StatefulWidget {
  const _AllStationsSheet();

  @override
  State<_AllStationsSheet> createState() => _AllStationsSheetState();
}

class _AllStationsSheetState extends State<_AllStationsSheet> {
  final FlutterSignal<String> _searchQuery = signal('');
  final _controller = TextEditingController();
  final _scrollController = SmoothScrollController(debugLabel: 'stations');

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        final stationsFuture = waveStationsSignal.value;
        if (stationsFuture.isLoading) {
          return const Center(child: M3ELoadingIndicator());
        }

        final currentSeeds = currentWaveSeedsSignal();
        final query = _searchQuery().toLowerCase();
        final cats = _filterCategories(stationsFuture.value ?? const [], query);

        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                _buildSearchField(context),
                Expanded(
                  child: _buildStationList(context, cats, currentSeeds, query),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Keeps only station categories that still have a matching item.
  List<StationCategoryDto> _filterCategories(
    List<StationCategoryDto> cats,
    String query,
  ) {
    if (query.isEmpty) return cats;
    return cats
        .map(
          (cat) => StationCategoryDto(
            title: cat.title,
            items: cat.items
                .where((i) => i.label.toLowerCase().contains(query))
                .toList(),
          ),
        )
        .where((cat) => cat.items.isNotEmpty)
        .toList();
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Row(
        children: [
          Text(
            'Каталог станций',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              Icons.close,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: TextField(
        controller: _controller,
        onChanged: (v) => _searchQuery.value = v,
        style: TextStyle(color: cs.onSurface),
        decoration: InputDecoration(
          hintText: 'Поиск по жанрам, настроениям...',
          hintStyle: TextStyle(
            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          prefixIcon: Icon(
            Icons.search,
            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          filled: true,
          fillColor: cs.onSurface.withValues(alpha: 0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildStationList(
    BuildContext context,
    List<StationCategoryDto> cats,
    List<String> currentSeeds,
    String query,
  ) {
    if (cats.isEmpty && query.isNotEmpty) {
      return Center(
        child: Text(
          'Ничего не найдено',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final maxLabelWidth = MediaQuery.sizeOf(context).width - 48 - 40;

    return Scrollbar(
      controller: _scrollController,
      child: CustomScrollView(
        scrollCacheExtent: const ScrollCacheExtent.pixels(1000),
        controller: _scrollController,
        slivers: [
          for (final cat in cats) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              sliver: SliverToBoxAdapter(
                child: Text(
                  cat.title.toUpperCase(),
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverToBoxAdapter(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in cat.items)
                      _buildStationChip(
                        context,
                        item,
                        currentSeeds.contains(item.seed),
                        maxLabelWidth,
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
        ],
      ),
    );
  }

  Widget _buildStationChip(
    BuildContext context,
    StationItemDto item,
    bool isSelected,
    double maxLabelWidth,
  ) {
    final cs = Theme.of(context).colorScheme;
    return FilterChip(
      selected: isSelected,
      label: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxLabelWidth > 0 ? maxLabelWidth : 100,
        ),
        child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      onSelected: (_) {
        unawaited(WaveController.toggleStation(item.seed));
        Navigator.pop(context);
      },
      backgroundColor: cs.onSurface.withValues(alpha: 0.05),
      selectedColor: cs.onSurface.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? cs.onSurface : cs.onSurfaceVariant,
        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: isSelected
          ? BorderSide(color: cs.onSurface.withValues(alpha: 0.24))
          : BorderSide.none,
      showCheckmark: false,
    );
  }
}
