import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// First screen of the app: a brain mark that draws itself, the MindSpeak name,
/// the taglines, and soft moving waves. Calls [onFinished] once the intro ends.
class MindSpeakSplashScreen extends StatefulWidget {
  const MindSpeakSplashScreen({required this.onFinished, super.key});

  final VoidCallback onFinished;

  /// Total intro length. Kept short so the splash never feels like a wait.
  static const duration = Duration(milliseconds: 2600);

  @override
  State<MindSpeakSplashScreen> createState() => _MindSpeakSplashScreenState();
}

class _MindSpeakSplashScreenState extends State<MindSpeakSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: MindSpeakSplashScreen.duration,
  );
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );
  var _started = false;
  var _finished = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _intro.value = 1;
      _loop.value = .25;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => Future<void>.delayed(const Duration(milliseconds: 900), _finish),
      );
      return;
    }
    _loop.repeat();
    _intro.forward().whenCompleteOrCancel(_finish);
  }

  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    widget.onFinished();
  }

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    super.dispose();
  }

  Animation<double> _interval(double begin, double end, [Curve curve = Curves.easeOutCubic]) =>
      CurvedAnimation(parent: _intro, curve: Interval(begin, end, curve: curve));

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final top = dark ? const Color(0xFF101B26) : Colors.white;
    final bottom = dark ? const Color(0xFF15283A) : const Color(0xFFE6F1FB);
    final titleNavy = dark ? const Color(0xFFEAF2F8) : navy;
    final accent = dark ? const Color(0xFF83BDF0) : blue;

    final draw = _interval(0, .5, Curves.easeInOutCubic);
    final logoIn = _interval(0, .3);
    final nameIn = _interval(.38, .66);
    final tagIn = _interval(.52, .8);
    final sloganIn = _interval(.64, .92);
    final barIn = _interval(.2, 1, Curves.easeInOut);

    Widget rise(Animation<double> a, Widget child) => FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, .35), end: Offset.zero).animate(a),
        child: child,
      ),
    );

    return Scaffold(
      key: const Key('mindspeak_splash'),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [top, bottom],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 170,
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _loop,
                  builder: (context, _) => CustomPaint(
                    painter: _SplashWavePainter(
                      phase: _loop.value,
                      color: accent.withValues(alpha: dark ? .10 : .14),
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const Spacer(flex: 5),
                    FadeTransition(
                      opacity: logoIn,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: .82, end: 1).animate(logoIn),
                        child: AnimatedBuilder(
                          animation: Listenable.merge([_intro, _loop]),
                          builder: (context, _) => CustomPaint(
                            size: const Size(132, 118),
                            painter: _BrainMarkPainter(
                              progress: draw.value,
                              pulse: _loop.value,
                              color: accent,
                              glow: accent.withValues(alpha: .18),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    rise(
                      nameIn,
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: 'Mind', style: TextStyle(color: titleNavy)),
                              TextSpan(text: 'Speak', style: TextStyle(color: accent)),
                            ],
                          ),
                          style: const TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    rise(
                      tagIn,
                      Text(
                        arabic ? 'نحوّل الأفكار إلى كلمات' : 'Bridging Thoughts to Words',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: titleNavy,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    rise(
                      sloganIn,
                      Text(
                        arabic ? 'فكّر... ونحن نتكلّم عنك' : 'Think It... We Speak It',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: accent,
                          fontSize: 15,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Spacer(flex: 6),
                    AnimatedBuilder(
                      animation: barIn,
                      builder: (context, _) => _ProgressBar(
                        value: barIn.value,
                        color: accent,
                        track: accent.withValues(alpha: .16),
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value, required this.color, required this.track});

  final double value;
  final Color color;
  final Color track;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 96,
    height: 4,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Stack(
        children: [
          Positioned.fill(child: ColoredBox(color: track)),
          FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            heightFactor: 1,
            child: ColoredBox(color: color),
          ),
        ],
      ),
    ),
  );
}

/// A line-art brain (two hemispheres with folds) with a small speech bubble,
/// drawn progressively by [progress] and gently pulsing with [pulse].
class _BrainMarkPainter extends CustomPainter {
  _BrainMarkPainter({
    required this.progress,
    required this.pulse,
    required this.color,
    required this.glow,
  });

  final double progress;
  final double pulse;
  final Color color;
  final Color glow;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    Offset p(double x, double y) => Offset(w * x, h * y);

    // Soft halo that breathes after the drawing completes.
    final breathe = .5 + .5 * math.sin(pulse * 2 * math.pi);
    canvas.drawCircle(
      p(.47, .5),
      w * (.42 + .03 * breathe) * progress,
      Paint()..color = glow.withValues(alpha: glow.a * (.6 + .4 * breathe)),
    );

    final left = Path()
      ..moveTo(w * .47, h * .12)
      ..cubicTo(w * .36, h * .02, w * .2, h * .08, w * .19, h * .22)
      ..cubicTo(w * .06, h * .25, w * .03, h * .42, w * .11, h * .52)
      ..cubicTo(w * .02, h * .62, w * .07, h * .8, w * .2, h * .82)
      ..cubicTo(w * .24, h * .95, w * .4, h * .98, w * .47, h * .88);
    final right = Path()
      ..moveTo(w * .47, h * .12)
      ..cubicTo(w * .58, h * .02, w * .74, h * .08, w * .75, h * .22)
      ..cubicTo(w * .88, h * .25, w * .91, h * .42, w * .83, h * .52)
      ..cubicTo(w * .92, h * .62, w * .87, h * .8, w * .74, h * .82)
      ..cubicTo(w * .7, h * .95, w * .54, h * .98, w * .47, h * .88);
    final folds = Path()
      ..moveTo(w * .47, h * .12)
      ..lineTo(w * .47, h * .88)
      ..moveTo(w * .19, h * .22)
      ..quadraticBezierTo(w * .3, h * .3, w * .29, h * .42)
      ..moveTo(w * .11, h * .52)
      ..quadraticBezierTo(w * .24, h * .5, w * .33, h * .6)
      ..moveTo(w * .2, h * .82)
      ..quadraticBezierTo(w * .28, h * .72, w * .38, h * .74)
      ..moveTo(w * .75, h * .22)
      ..quadraticBezierTo(w * .64, h * .3, w * .65, h * .42)
      ..moveTo(w * .83, h * .52)
      ..quadraticBezierTo(w * .7, h * .5, w * .61, h * .6)
      ..moveTo(w * .74, h * .82)
      ..quadraticBezierTo(w * .66, h * .72, w * .56, h * .74);
    final bubble = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * .8, h * .62, w * .2, h * .17),
          Radius.circular(w * .05),
        ),
      )
      ..moveTo(w * .84, h * .79)
      ..lineTo(w * .82, h * .87)
      ..lineTo(w * .89, h * .79);

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * .042
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final thin = Paint()
      ..color = color.withValues(alpha: .85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * .03
      ..strokeCap = StrokeCap.round;

    _drawPartial(canvas, left, stroke, progress);
    _drawPartial(canvas, right, stroke, progress);
    _drawPartial(canvas, folds, thin, ((progress - .35) / .65).clamp(0.0, 1.0));
    _drawPartial(canvas, bubble, thin, ((progress - .6) / .4).clamp(0.0, 1.0));

    // Neural nodes light up once the outline is in place.
    final nodes = [p(.29, .42), p(.33, .6), p(.38, .74), p(.65, .42), p(.61, .6), p(.56, .74)];
    final nodeIn = ((progress - .7) / .3).clamp(0.0, 1.0);
    for (var i = 0; i < nodes.length; i++) {
      final flicker = .55 + .45 * math.sin((pulse + i / nodes.length) * 2 * math.pi);
      canvas.drawCircle(
        nodes[i],
        w * .03 * nodeIn,
        Paint()..color = color.withValues(alpha: nodeIn * flicker),
      );
    }
    // Three "speaking" dots inside the bubble.
    if (progress >= 1) {
      for (var i = 0; i < 3; i++) {
        final bounce = math.sin((pulse * 2 + i * .25) * 2 * math.pi);
        canvas.drawCircle(
          Offset(w * (.855 + i * .045), h * (.705 - .012 * bounce)),
          w * .014,
          Paint()..color = color,
        );
      }
    }
  }

  void _drawPartial(Canvas canvas, Path path, Paint paint, double t) {
    if (t <= 0) return;
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * t), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BrainMarkPainter old) =>
      old.progress != progress || old.pulse != pulse || old.color != color;
}

class _SplashWavePainter extends CustomPainter {
  const _SplashWavePainter({required this.phase, required this.color});

  final double phase;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    void wave(double base, double amplitude, double shift, double alpha) {
      final path = Path()..moveTo(0, size.height);
      for (var x = 0.0; x <= size.width; x += 4) {
        final t = x / size.width;
        final y = size.height * base +
            math.sin((t * 1.6 + phase + shift) * 2 * math.pi) * amplitude;
        path.lineTo(x, y);
      }
      path
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: color.a * alpha));
    }

    wave(.42, 14, 0, 1);
    wave(.6, 12, .35, 1.4);
    wave(.78, 9, .7, 1.8);
  }

  @override
  bool shouldRepaint(covariant _SplashWavePainter old) =>
      old.phase != phase || old.color != color;
}
