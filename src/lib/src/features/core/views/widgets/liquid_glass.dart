import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:yayma/src/features/core/providers/android_player_preferences.dart';
import 'package:yayma/src/features/core/providers/visual_effects_provider.dart';
import 'package:yayma/src/features/core/theme/app_tokens.dart';

/// Loads and owns the single Liquid Glass fragment program.
abstract final class GlassShaderCache {
  static ui.FragmentProgram? _program;
  static Future<void>? _loading;
  static bool _unavailable = false;

  static bool get isReady => _program != null;

  static Future<void> ensureLoaded() {
    final existing = _loading;
    if (existing != null) return existing;
    if (_program != null || _unavailable) return Future.value();

    final loading = ui.FragmentProgram.fromAsset(
      'shaders/liquid_glass.frag',
    ).then((program) {
      _program = program;
    }).catchError((Object error, StackTrace stack) {
      // A driver without runtime shader support must not take the UI down.
      _unavailable = true;
      debugPrint('Liquid Glass shader unavailable: $error');
    });
    _loading = loading;
    return loading;
  }

  static ui.FragmentShader? createShader() {
    final program = _program;
    if (program == null) return null;
    try {
      return program.fragmentShader();
    } on Object catch (error) {
      debugPrint('Liquid Glass shader could not be created: $error');
      return null;
    }
  }
}

/// One design-system surface for every translucent layer in the app.
///
/// It is deliberately more than a blur:
/// * the backdrop is sampled and blurred by [BackdropFilter];
/// * [GlassShaderCache]'s shader adds a warped refraction field, caustics, a
///   displaced tint, a Fresnel rim with slight dispersion and a specular lobe;
/// * a palette-derived gradient keeps each pane tied to the current artwork
///   instead of showing one fixed frosted texture everywhere;
/// * a light border and a real drop shadow give the pane thickness.
///
/// When the shader, the blur preference or Liquid Glass itself is disabled the
/// same widget degrades to a quiet translucent surface, never to an opaque box.
class LiquidGlassSurface extends StatefulWidget {
  const LiquidGlassSurface({
    required this.child,
    super.key,
    this.borderRadius,
    this.blurSigma = 24,
    this.tintColor,
    this.tintOpacity = 0.30,
    this.intensity = 1,
    this.animated = false,
    this.useShader = true,
    this.shadows = true,
    this.borderColor,
    this.padding,
    this.lightAlignment = const Alignment(-0.55, -0.7),
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final double blurSigma;
  final Color? tintColor;
  final double tintOpacity;
  final double intensity;
  final bool animated;
  final bool useShader;
  final bool shadows;
  final Color? borderColor;
  final EdgeInsetsGeometry? padding;
  final Alignment lightAlignment;
  final Clip clipBehavior;

  @override
  State<LiquidGlassSurface> createState() => _LiquidGlassSurfaceState();
}

class _LiquidGlassSurfaceState extends State<LiquidGlassSurface>
    with SingleTickerProviderStateMixin {
  AnimationController? _clock;
  ui.FragmentShader? _shader;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    if (widget.animated) {
      _clock = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 24),
      )..repeat();
    }
    unawaited(
      GlassShaderCache.ensureLoaded().then((_) {
        if (!mounted) return;
        setState(() => _shader = GlassShaderCache.createShader());
      }),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce == _reduceMotion) return;
    _reduceMotion = reduce;
    final clock = _clock;
    if (clock == null) return;
    if (reduce) {
      clock.stop();
      clock.value = 0;
    } else {
      clock.repeat();
    }
  }

  @override
  void dispose() {
    _clock?.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        final enabled = liquidGlassV2EnabledSignal.value;
        final blur = blurEffectsEnabledSignal.value;
        final scheme = Theme.of(context).colorScheme;
        final radius =
            widget.borderRadius ?? BorderRadius.circular(AppRadius.xxl);
        final tint = widget.tintColor ?? scheme.surfaceContainerHigh;
        // Apple's own profile is lighter and quieter than the YAYMA glass.
        final apple =
            androidAppearanceProfileSignal.value ==
            AndroidAppearanceProfile.appleMusic;
        final effectiveIntensity = (widget.intensity * (apple ? 0.72 : 1.0))
            .clamp(0.0, 1.0)
            .toDouble();
        final border =
            widget.borderColor ??
            (apple
                ? Colors.white.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.16));

        if (!enabled) {
          return _QuietSurface(
            borderRadius: radius,
            tint: tint,
            tintOpacity: widget.tintOpacity,
            borderColor: border,
            shadows: widget.shadows,
            padding: widget.padding,
            child: widget.child,
          );
        }

        if (_shader == null && widget.useShader) {
          _shader = GlassShaderCache.createShader();
        }

        final canUseShader =
            widget.useShader && Platform.isAndroid && _shader != null;

        final content = Material(
          type: MaterialType.transparency,
          child: Padding(
            padding: widget.padding ?? EdgeInsets.zero,
            child: widget.child,
          ),
        );

        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: widget.shadows
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.24),
                      blurRadius: 30,
                      spreadRadius: -4,
                      offset: const Offset(0, 14),
                    ),
                    BoxShadow(
                      color: tint.withValues(alpha: 0.10),
                      blurRadius: 42,
                      spreadRadius: -8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: radius,
            clipBehavior: widget.clipBehavior,
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                Positioned.fill(
                  child: BackdropFilter(
                    enabled: blur,
                    filter: ui.ImageFilter.blur(
                      sigmaX: widget.blurSigma,
                      sigmaY: widget.blurSigma,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: widget.tintOpacity),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: apple ? 0.14 : 0.10),
                          tint.withValues(
                            alpha: (widget.tintOpacity * 0.72)
                                .clamp(0.0, 1.0)
                                .toDouble(),
                          ),
                          scheme.surface.withValues(alpha: 0.06),
                        ],
                        stops: const [0, 0.55, 1],
                      ),
                    ),
                  ),
                ),
                if (canUseShader)
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _GlassOpticsPainter(
                          shader: _shader!,
                          clock: _reduceMotion ? null : _clock,
                          tint: scheme.primary,
                          tint2: scheme.tertiary,
                          intensity: effectiveIntensity,
                          radius: radius.topLeft.x,
                          light: widget.lightAlignment,
                        ),
                      ),
                    ),
                  ),
                // A very thin top light line: the optical edge catches the
                // key light even when the shader is not available.
                Positioned(
                  top: 0,
                  left: 18,
                  right: 18,
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0),
                          Colors.white.withValues(alpha: apple ? 0.36 : 0.28),
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: radius,
                        border: Border.all(
                          color: border,
                          width: apple ? 1.0 : 0.9,
                        ),
                      ),
                    ),
                  ),
                ),
                content,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Non-optical fallback used when Liquid Glass is switched off entirely.
class _QuietSurface extends StatelessWidget {
  const _QuietSurface({
    required this.borderRadius,
    required this.tint,
    required this.tintOpacity,
    required this.borderColor,
    required this.shadows,
    required this.child,
    this.padding,
  });

  final BorderRadius borderRadius;
  final Color tint;
  final double tintOpacity;
  final Color borderColor;
  final bool shadows;
  final EdgeInsetsGeometry? padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: tintOpacity),
        borderRadius: borderRadius,
        border: Border.all(color: borderColor),
        boxShadow: shadows
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.20),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

class _GlassOpticsPainter extends CustomPainter {
  _GlassOpticsPainter({
    required this.shader,
    required this.clock,
    required this.tint,
    required this.tint2,
    required this.intensity,
    required this.radius,
    required this.light,
  }) : super(repaint: clock);

  final ui.FragmentShader shader;
  final Animation<double>? clock;
  final Color tint;
  final Color tint2;
  final double intensity;
  final double radius;
  final Alignment light;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = (clock?.value ?? 0) * 18;
    // Uniform slots must follow the declaration order in liquid_glass.frag.
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, t)
      ..setFloat(3, tint.r)
      ..setFloat(4, tint.g)
      ..setFloat(5, tint.b)
      ..setFloat(6, 1)
      ..setFloat(7, tint2.r)
      ..setFloat(8, tint2.g)
      ..setFloat(9, tint2.b)
      ..setFloat(10, 1)
      ..setFloat(11, (light.x + 1) * 0.5)
      ..setFloat(12, (light.y + 1) * 0.5)
      ..setFloat(13, radius)
      ..setFloat(14, intensity);

    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_GlassOpticsPainter oldDelegate) =>
      oldDelegate.shader != shader ||
      oldDelegate.tint != tint ||
      oldDelegate.tint2 != tint2 ||
      oldDelegate.intensity != intensity ||
      oldDelegate.radius != radius ||
      oldDelegate.light != light ||
      oldDelegate.clock != clock;
}
