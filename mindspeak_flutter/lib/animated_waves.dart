import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Soft, slowly drifting waves for screen backgrounds. Three layers move at
/// slightly different speeds so the motion feels calm rather than repetitive.
/// Respects the system "reduce motion" setting by holding still.
class AnimatedWaves extends StatefulWidget {
  const AnimatedWaves({
    required this.color,
    this.period = const Duration(seconds: 6),
    super.key,
  });

  final Color color;
  final Duration period;

  /// Tests turn this off (see test/flutter_test_config.dart) so that
  /// `pumpAndSettle` can finish; the app always animates.
  static bool animate = true;

  @override
  State<AnimatedWaves> createState() => _AnimatedWavesState();
}

class _AnimatedWavesState extends State<AnimatedWaves>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!AnimatedWaves.animate || MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        painter: _WavesPainter(phase: _controller.value, color: widget.color),
        size: Size.infinite,
      ),
    ),
  );
}

class _WavesPainter extends CustomPainter {
  const _WavesPainter({required this.phase, required this.color});

  final double phase;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    // (height fraction, amplitude px, wavelength factor, speed, opacity factor)
    const layers = [
      (.28, 16.0, 1.1, 1.0, 1.0),
      (.50, 14.0, 1.5, -1.0, 1.3),
      (.70, 11.0, 1.9, 2.0, 1.6),
    ];
    for (final (base, amplitude, frequency, speed, alpha) in layers) {
      final path = Path()..moveTo(0, size.height);
      for (var x = 0.0; x <= size.width + 4; x += 4) {
        final t = x / size.width;
        final y = size.height * base +
            math.sin((t * frequency + phase * speed) * 2 * math.pi) * amplitude;
        path.lineTo(x, y);
      }
      path
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = color.withValues(alpha: (color.a * alpha).clamp(0.0, 1.0)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WavesPainter old) =>
      old.phase != phase || old.color != color;
}

/// The light blue used for background waves, softer in dark mode.
Color backgroundWaveColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFF6CAFE0).withValues(alpha: .13)
    : const Color(0xFF4FA3E0).withValues(alpha: .20);

/// Puts the moving waves along the bottom of a screen, behind its content.
/// Every MindSpeak screen uses this, so new screens get the waves too.
class WavesBackground extends StatelessWidget {
  const WavesBackground({required this.child, this.height = 190, super.key});

  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        height: height,
        child: IgnorePointer(
          child: AnimatedWaves(
            key: const Key('background_waves'),
            color: backgroundWaveColor(context),
          ),
        ),
      ),
      child,
    ],
  );
}
