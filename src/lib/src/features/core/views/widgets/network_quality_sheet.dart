import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:yayma/src/features/core/services/network_quality.dart';
import 'package:yayma/src/features/core/theme/app_tokens.dart';
import 'package:yayma/src/features/core/views/widgets/common_ui.dart';
import 'package:yayma/src/features/core/views/widgets/liquid_glass.dart';
import 'package:yayma/src/features/playback/providers/playback_provider.dart';
import 'package:yayma/src/rust/api/models.dart';

/// Dedicated quality screen: one profile for Wi-Fi/Ethernet and one for
/// mobile data, plus the live OS connection state.
Future<void> showNetworkQualitySheet(BuildContext context) {
  return showAppBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => const NetworkQualitySheet(),
  );
}

class NetworkQualitySheet extends StatelessWidget {
  const NetworkQualitySheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SignalBuilder(
        builder: (context) {
          final scheme = Theme.of(context).colorScheme;
          final kind = networkKindSignal.value;
          final auto = autoQualityByNetworkSignal.value;
          final current = audioQualitySignal.value;
          final accent = scheme.primary;

          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.86,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Icon(
                          Icons.graphic_eq_rounded,
                          color: accent,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Качество звука',
                              style: TextStyle(
                                color: scheme.onSurface,
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Отдельный профиль для каждой сети',
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _ConnectionCard(kind: kind, accent: accent),
                  const SizedBox(height: 14),
                  LiquidGlassSurface(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    // The sheet already blurs the app behind it; blurring
                    // again inside would only cost a second backdrop pass.
                    blurSigma: 0,
                    tintOpacity: 0.20,
                    shadows: false,
                    padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                    child: Row(
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          color: auto ? accent : scheme.onSurfaceVariant,
                          size: 21,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Подстраивать под сеть',
                                style: TextStyle(
                                  color: scheme.onSurface,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Wi-Fi → мобильный интернет без потери позиции',
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: auto,
                          onChanged: (value) => unawaited(
                            NetworkQualityController.setAutoByNetwork(value),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _QualityProfileCard(
                    title: 'Wi-Fi и Ethernet',
                    subtitle: 'Домашняя сеть — можно максимальное качество',
                    icon: Icons.wifi_rounded,
                    value: wifiQualitySignal.value,
                    accent: accent,
                    enabled: true,
                    onChanged: (quality) => unawaited(
                      NetworkQualityController.setWifiQuality(quality),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _QualityProfileCard(
                    title: 'Мобильный интернет',
                    subtitle: 'Экономнее к трафику, но без потери удобства',
                    icon: Icons.signal_cellular_alt_rounded,
                    value: mobileQualitySignal.value,
                    accent: accent,
                    enabled: true,
                    onChanged: (quality) => unawaited(
                      NetworkQualityController.setMobileQuality(quality),
                    ),
                  ),
                  if (!auto) ...[
                    const SizedBox(height: 18),
                    Text(
                      'ТЕКУЩЕЕ КАЧЕСТВО',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _ManualQualityRow(
                      value: current,
                      accent: accent,
                      onChanged: (quality) => unawaited(
                        _setManualQuality(quality),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Доступны реальные варианты потока Yandex Music: '
                          'экономный (LQ), стандартный (NQ ~192 kbps) и высокий '
                          '(HQ 320 kbps или lossless, если он есть у трека). '
                          'Смена качества перезапускает только текущий поток — '
                          'очередь и позиция сохраняются.',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 11.5,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static Future<void> _setManualQuality(AudioQuality quality) async {
    await PlaybackController.setQuality(quality);
    await NetworkQualityController.recordManualQuality(quality);
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.kind, required this.accent});

  final NetworkKind kind;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final known = kind.hasQualityProfile;
    final color = known ? accent : scheme.tertiary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Icon(
            switch (kind) {
              NetworkKind.wifi => Icons.wifi_rounded,
              NetworkKind.mobile => Icons.signal_cellular_alt_rounded,
              NetworkKind.ethernet => Icons.settings_ethernet_rounded,
              NetworkKind.vpn => Icons.vpn_lock_rounded,
              NetworkKind.none => Icons.wifi_off_rounded,
              _ => Icons.help_outline_rounded,
            },
            color: color,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Сейчас: ${kind.label}',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  known
                      ? 'Профиль применяется автоматически'
                      : 'Качество не меняется, пока сеть не определена',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: known ? color : scheme.onSurfaceVariant,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.55),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QualityProfileCard extends StatelessWidget {
  const _QualityProfileCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.accent,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final AudioQuality value;
  final Color accent;
  final bool enabled;
  final ValueChanged<AudioQuality> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LiquidGlassSurface(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      blurSigma: 0,
      tintOpacity: 0.22,
      shadows: false,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final quality in AudioQuality.values) ...[
                Expanded(
                  child: _QualityChoice(
                    quality: quality,
                    selected: value == quality,
                    accent: accent,
                    enabled: enabled,
                    onTap: () => onChanged(quality),
                  ),
                ),
                if (quality != AudioQuality.values.last)
                  const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _QualityChoice extends StatelessWidget {
  const _QualityChoice({
    required this.quality,
    required this.selected,
    required this.accent,
    required this.enabled,
    required this.onTap,
  });

  final AudioQuality quality;
  final bool selected;
  final Color accent;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected
            ? accent.withValues(alpha: 0.22)
            : scheme.onSurface.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: selected
              ? accent.withValues(alpha: 0.62)
              : scheme.onSurface.withValues(alpha: 0.07),
          width: selected ? 1.2 : 1,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            child: Column(
              children: [
                Text(
                  quality.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  switch (quality) {
                    AudioQuality.low => 'LQ',
                    AudioQuality.normal => 'NQ',
                    AudioQuality.high => 'HQ',
                  },
                  style: TextStyle(
                    color: selected
                        ? accent
                        : scheme.onSurfaceVariant.withValues(alpha: 0.6),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ManualQualityRow extends StatelessWidget {
  const _ManualQualityRow({
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  final AudioQuality value;
  final Color accent;
  final ValueChanged<AudioQuality> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final quality in AudioQuality.values) ...[
          Expanded(
            child: _QualityChoice(
              quality: quality,
              selected: value == quality,
              accent: accent,
              enabled: true,
              onTap: () => onChanged(quality),
            ),
          ),
          if (quality != AudioQuality.values.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}
