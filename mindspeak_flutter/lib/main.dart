import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'auth_api.dart';
import 'bluetooth/headset_bluetooth.dart';
import 'design_tokens.dart';
import 'home/home_screen.dart';

final RouteObserver<PageRoute<dynamic>> _mindSpeakRouteObserver =
    RouteObserver<PageRoute<dynamic>>();

void main() => runApp(const MindSpeakApp());

void _logoutToLogin(NavigatorState navigator) {
  AuthApi.logout();
  navigator.pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => const AccessScreen(isLogin: true)),
    (_) => false,
  );
}

void _openHeadsetConnection(
  NavigatorState navigator,
  HeadsetBluetoothGateway gateway,
) {
  navigator.push(
    MaterialPageRoute<void>(
      builder: (_) => ConnectHeadsetScreen(
        needsCalibration: false,
        bluetoothGateway: gateway,
      ),
    ),
  );
}

class MindSpeakApp extends StatelessWidget {
  const MindSpeakApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'MindSpeak',
    debugShowCheckedModeBanner: false,
    navigatorObservers: [_mindSpeakRouteObserver],
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: navy, primary: navy),
      scaffoldBackgroundColor: bg,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(14),
        border: _border,
        enabledBorder: _border,
      ),
    ),
    home: const WelcomeScreen(),
  );
}

final _border = OutlineInputBorder(
  borderRadius: BorderRadius.circular(12),
  borderSide: const BorderSide(color: line),
);

class AppPage extends StatelessWidget {
  const AppPage({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
        child: child,
      ),
    ),
  );
}

class BrandWordmark extends StatelessWidget {
  const BrandWordmark({this.size = 25, super.key});
  final double size;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: 'Mind',
          style: TextStyle(
            color: navy,
            fontSize: size,
            fontWeight: FontWeight.w700,
          ),
        ),
        TextSpan(
          text: 'Speak',
          style: TextStyle(
            color: blue,
            fontSize: size,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class BrandLockup extends StatefulWidget {
  const BrandLockup({super.key});

  @override
  State<BrandLockup> createState() => _BrandLockupState();
}

class _BrandLockupState extends State<BrandLockup>
    with TickerProviderStateMixin, WidgetsBindingObserver, RouteAware {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2300),
  );
  late final AnimationController _activity = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2900),
  );
  PageRoute<dynamic>? _observedRoute;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic> && route != _observedRoute) {
      _mindSpeakRouteObserver.unsubscribe(this);
      _observedRoute = route;
      _mindSpeakRouteObserver.subscribe(this, route);
    }
    _applyMotionPreference();
  }

  @override
  void didPush() => _restartEntrance();

  @override
  void didPopNext() => _restartEntrance();

  @override
  void didChangeAccessibilityFeatures() => _applyMotionPreference();

  void _applyMotionPreference() {
    final reduceMotion =
        MediaQuery.disableAnimationsOf(context) ||
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .reduceMotion;
    if (reduceMotion) {
      _entrance.value = 1;
      _activity.value = .5;
      _activity.stop();
    } else {
      if (_entrance.status == AnimationStatus.dismissed) {
        _entrance.forward();
      }
      if (!_activity.isAnimating) _activity.repeat();
    }
  }

  void _restartEntrance() {
    final reduceMotion =
        MediaQuery.disableAnimationsOf(context) ||
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .reduceMotion;
    if (reduceMotion) {
      _applyMotionPreference();
      return;
    }
    _entrance.forward(from: 0);
    if (!_activity.isAnimating) _activity.repeat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mindSpeakRouteObserver.unsubscribe(this);
    _entrance.dispose();
    _activity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final breathing = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: .98,
          end: 1.02,
        ).chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.02,
          end: .98,
        ).chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 50,
      ),
    ]).animate(_activity);

    return FadeTransition(
      opacity: CurvedAnimation(parent: _entrance, curve: Curves.easeOut),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, .018), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic),
            ),
        child: ScaleTransition(
          scale: Tween<double>(begin: .985, end: 1).animate(
            CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic),
          ),
          child: AnimatedBuilder(
            animation: _activity,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, math.sin(_activity.value * 2 * math.pi) * 1.25),
              child: child,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _entrance,
                    curve: const Interval(0, .78, curve: Curves.easeOut),
                  ),
                  child: ScaleTransition(
                    alignment: const Alignment(-.093, -.089),
                    scale: breathing,
                    child: CustomPaint(
                      foregroundPainter: _MindActivityPainter(
                        _activity,
                        _entrance,
                      ),
                      child: const _BrandSymbol(),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _entrance,
                    curve: const Interval(.34, 1, curve: Curves.easeOut),
                  ),
                  child: SlideTransition(
                    position:
                        Tween<Offset>(
                          begin: const Offset(0, .12),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: _entrance,
                            curve: const Interval(
                              .34,
                              .92,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                        ),
                    child: AnimatedBuilder(
                      animation: _activity,
                      child: const BrandWordmark(),
                      builder: (context, child) => Transform.translate(
                        offset: Offset(
                          0,
                          math.sin(_activity.value * 2 * math.pi) * .8,
                        ),
                        child: child,
                      ),
                    ),
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

/// Adds light to the existing logo artwork without replacing or reshaping it.
/// Coordinates match the 150 × 112 icon crop used by [_BrandSymbol].
class _MindActivityPainter extends CustomPainter {
  _MindActivityPainter(this.animation, this.entrance)
    : super(repaint: Listenable.merge([animation, entrance]));

  final Animation<double> animation;
  final Animation<double> entrance;

  static final List<Path> _circuits = [
    Path()
      ..moveTo(36, 32)
      ..lineTo(42, 36)
      ..quadraticBezierTo(48, 36, 51, 34)
      ..lineTo(61, 34),
    Path()
      ..moveTo(29, 42)
      ..lineTo(39, 42)
      ..quadraticBezierTo(45, 49, 52, 44)
      ..quadraticBezierTo(56, 40, 63, 40),
    Path()
      ..moveTo(22, 49)
      ..lineTo(37, 49)
      ..quadraticBezierTo(43, 56, 49, 55)
      ..lineTo(70, 55),
    Path()
      ..moveTo(28, 56)
      ..lineTo(39, 56)
      ..quadraticBezierTo(44, 63, 50, 62)
      ..lineTo(58, 62),
    Path()
      ..moveTo(33, 65)
      ..lineTo(48, 65)
      ..quadraticBezierTo(54, 60, 59, 60)
      ..lineTo(62, 60),
    Path()
      ..moveTo(43, 74)
      ..lineTo(48, 74)
      ..quadraticBezierTo(54, 67, 59, 66)
      ..lineTo(62, 66),
  ];
  static final _circuitMetrics = _circuits
      .map((path) => path.computeMetrics().first)
      .toList(growable: false);

  static const _bars = <(double, double)>[
    (78, 8),
    (82, 11),
    (86, 15),
    (90, 20),
    (94, 17),
    (98, 22),
    (102, 16),
    (106, 12),
    (110, 8),
    (113, 5),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.scale(size.width / 150, size.height / 112);

    final phase = animation.value * 2 * 3.141592653589793;
    final brainPulse = (1 + math.sin(phase)) / 2;
    final glowRadius = 17 + brainPulse * 2;
    final brainGlow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              Color.fromRGBO(72, 177, 255, .08 + brainPulse * .08),
              Color.fromRGBO(72, 177, 255, 0),
            ],
          ).createShader(
            Rect.fromCircle(center: const Offset(68, 51), radius: glowRadius),
          );
    canvas.drawCircle(const Offset(68, 51), glowRadius, brainGlow);

    // Let the signal and equalizer effects remain visible after the entrance
    // animation has completed. They gently brighten as the logo appears.
    final activityOpacity = .7 + entrance.value * .3;
    {
      for (var i = 0; i < _circuitMetrics.length; i++) {
        final metric = _circuitMetrics[i];
        final travel = (animation.value + i * .17) % 1;
        final tangent = metric.getTangentForOffset(metric.length * travel);
        if (tangent == null) continue;
        final point = tangent.position;
        canvas.drawCircle(
          point,
          3.1,
          Paint()..color = Color.fromRGBO(43, 183, 255, .2 * activityOpacity),
        );
        canvas.drawCircle(
          point,
          1.25,
          Paint()..color = Color.fromRGBO(185, 236, 255, .8 * activityOpacity),
        );
      }

      const nodes = <Offset>[
        Offset(36, 32),
        Offset(29, 42),
        Offset(22, 49),
        Offset(28, 56),
        Offset(33, 65),
        Offset(43, 74),
      ];
      for (var i = 0; i < nodes.length; i++) {
        final pulse = (1 + math.sin(phase - i * .8)) / 2;
        canvas.drawCircle(
          nodes[i],
          2.2 + pulse * .8,
          Paint()
            ..color = Color.fromRGBO(
              93,
              195,
              255,
              (.08 + pulse * .14) * activityOpacity,
            ),
        );
      }

      for (var i = 0; i < _bars.length; i++) {
        final (x, baseHeight) = _bars[i];
        final wave = (1 + math.sin(phase - i * .68)) / 2;
        final height = 4 + (baseHeight - 4) * wave;
        final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, 65), width: 2.1, height: height),
          const Radius.circular(1.1),
        );
        canvas.drawRRect(
          rect,
          Paint()
            ..color = Color.fromRGBO(
              58,
              157,
              226,
              (.12 + wave * .2) * activityOpacity,
            ),
        );
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MindActivityPainter oldDelegate) =>
      oldDelegate.animation != animation || oldDelegate.entrance != entrance;
}

class _BrandSymbol extends StatelessWidget {
  const _BrandSymbol();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 150,
    height: 112,
    child: ClipRect(
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: .72,
        child: Image.asset(
          'assets/images/mindspeak_logo_transparent_navy.png',
          width: 150,
          fit: BoxFit.fitWidth,
        ),
      ),
    ),
  );
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) => const Align(
    alignment: Alignment.centerLeft,
    child: BrandWordmark(size: 19),
  );
}

class _BackHeader extends StatelessWidget {
  const _BackHeader({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
      ),
      const Expanded(child: _BrandHeader()),
    ],
  );
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) => AppPage(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 500;
        return Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _WelcomeNeuralBackgroundPainter()),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Spacer(flex: compact ? 1 : 3),
                const Center(child: BrandLockup()),
                Spacer(flex: compact ? 2 : 4),
                const Text(
                  'Express yourself with confidence.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: navy,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'A simple space for clearer communication.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 15),
                _WelcomePressButton(onPressed: () => _open(context, false)),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => _open(context, true),
                  child: const Text('I already have an account · Log in'),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );

  void _open(BuildContext context, bool login) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => AccessScreen(isLogin: login)),
    );
  }
}

class _WelcomePressButton extends StatefulWidget {
  const _WelcomePressButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_WelcomePressButton> createState() => _WelcomePressButtonState();
}

class _WelcomePressButtonState extends State<_WelcomePressButton> {
  var _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => _setPressed(true),
    onPointerUp: (_) => _setPressed(false),
    onPointerCancel: (_) => _setPressed(false),
    child: AnimatedScale(
      scale: _pressed ? .985 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: widget.onPressed,
          child: const Text('Get started'),
        ),
      ),
    ),
  );
}

class _WelcomeNeuralBackgroundPainter extends CustomPainter {
  const _WelcomeNeuralBackgroundPainter();

  static const _nodes = <Offset>[
    Offset(.04, .14),
    Offset(.19, .09),
    Offset(.31, .2),
    Offset(.05, .37),
    Offset(.18, .44),
    Offset(.06, .67),
    Offset(.21, .78),
    Offset(.36, .88),
    Offset(.83, .1),
    Offset(.96, .2),
    Offset(.88, .39),
    Offset(.76, .48),
    Offset(.97, .68),
    Offset(.83, .81),
    Offset(.65, .9),
  ];

  static const _connections = <(int, int)>[
    (0, 1),
    (1, 2),
    (0, 3),
    (3, 4),
    (3, 5),
    (5, 6),
    (6, 7),
    (4, 6),
    (8, 9),
    (9, 10),
    (10, 11),
    (10, 12),
    (12, 13),
    (13, 14),
    (11, 13),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = blue.withOpacity(.055)
      ..strokeWidth = .7;
    final nodePaint = Paint()..color = blue.withOpacity(.13);

    Offset locate(int index) =>
        Offset(_nodes[index].dx * size.width, _nodes[index].dy * size.height);

    for (final (start, end) in _connections) {
      canvas.drawLine(locate(start), locate(end), linePaint);
    }
    for (var i = 0; i < _nodes.length; i++) {
      canvas.drawCircle(locate(i), 1.2, nodePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WelcomeNeuralBackgroundPainter oldDelegate) =>
      false;
}

class AccessScreen extends StatefulWidget {
  const AccessScreen({required this.isLogin, super.key});
  final bool isLogin;

  @override
  State<AccessScreen> createState() => _AccessScreenState();
}

class _AccessScreenState extends State<AccessScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  bool get isLogin => widget.isLogin;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _validateName(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter your $label.';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (isLogin)
      return value == null || value.isEmpty ? 'Enter your password.' : null;
    if (value == null ||
        !RegExp(
          r'^(?=.*[A-Z])(?=.*[a-z])(?=.*[0-9])(?=.*[^A-Za-z0-9\s]).{8,128}$',
        ).hasMatch(value)) {
      return 'Use 8+ characters with uppercase, lowercase, a number, and a symbol.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (isLogin) {
        await AuthApi.login(
          email: _email.text.trim(),
          password: _password.text,
        );
      } else {
        final email = _email.text.trim().toLowerCase();
        await AuthApi.register(
          firstName: _firstName.text.trim().replaceAll(RegExp(r'\s+'), ' '),
          lastName: _lastName.text.trim().replaceAll(RegExp(r'\s+'), ' '),
          email: email,
          password: _password.text,
        );
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => VerificationCodeScreen(
              email: email,
              purpose: VerificationPurpose.registration,
            ),
          ),
        );
        return;
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ConnectHeadsetScreen(needsCalibration: !isLogin),
        ),
      );
    } on AuthApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted)
        setState(
          () => _error =
              'Could not reach MindSpeak. Check your connection and try again.',
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BackHeader(onBack: () => Navigator.of(context).pop()),
        const SizedBox(height: 36),
        Text(
          isLogin ? 'Welcome back!' : 'Create your account',
          style: const TextStyle(
            color: navy,
            fontSize: 25,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isLogin
              ? 'Sign in to connect your headset.'
              : 'New accounts complete calibration once.',
          style: const TextStyle(color: muted),
        ),
        const SizedBox(height: 22),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isLogin) ...[
                TextFormField(
                  controller: _firstName,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.givenName],
                  decoration: const InputDecoration(labelText: 'First name'),
                  validator: (value) => _validateName(value, 'first name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lastName,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.familyName],
                  decoration: const InputDecoration(labelText: 'Last name'),
                  validator: (value) => _validateName(value, 'last name'),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Email address'),
                validator: _validateEmail,
              ),
              const SizedBox(height: 16),
              _PasswordFormField(
                controller: _password,
                labelText: 'Password',
                validator: _validatePassword,
                onFieldSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
        if (isLogin)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _loading
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ForgotPasswordEmailScreen(),
                      ),
                    ),
              child: const Text('Forgot password?'),
            ),
          ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: const TextStyle(color: Colors.red, fontSize: 13),
          ),
        ],
        const Spacer(),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(isLogin ? 'Log in' : 'Create account'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => AccessScreen(isLogin: !isLogin),
            ),
          ),
          child: Text(
            isLogin ? 'Create new account' : 'I already have an account',
          ),
        ),
      ],
    ),
  );
}

class ForgotPasswordEmailScreen extends StatefulWidget {
  const ForgotPasswordEmailScreen({super.key});

  @override
  State<ForgotPasswordEmailScreen> createState() =>
      _ForgotPasswordEmailScreenState();
}

class _ForgotPasswordEmailScreenState extends State<ForgotPasswordEmailScreen> {
  final _email = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (_loading) return;
    final email = _email.text.trim();
    if (!_validEmail(email)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthApi.requestPasswordReset(email);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => VerificationCodeScreen(
            email: email,
            purpose: VerificationPurpose.passwordReset,
          ),
        ),
      );
    } on AuthApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted)
        setState(
          () => _error =
              'Could not reach MindSpeak. Check your connection and try again.',
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BackHeader(onBack: () => Navigator.of(context).pop()),
        const SizedBox(height: 36),
        const Text(
          'Forgot password?',
          style: TextStyle(
            color: navy,
            fontSize: 25,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter your registered email and we’ll send you a verification code.',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 22),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'Email address'),
          onSubmitted: (_) => _requestCode(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: const TextStyle(color: Colors.red, fontSize: 13),
          ),
        ],
        const Spacer(),
        FilledButton(
          onPressed: _loading ? null : _requestCode,
          child: _loading
              ? const _ButtonLoader()
              : const Text('Send verification code'),
        ),
      ],
    ),
  );
}

enum VerificationPurpose { registration, passwordReset }

class VerificationCodeScreen extends StatefulWidget {
  const VerificationCodeScreen({
    required this.email,
    required this.purpose,
    super.key,
  });
  final String email;
  final VerificationPurpose purpose;

  @override
  State<VerificationCodeScreen> createState() => _VerificationCodeScreenState();
}

class _VerificationCodeScreenState extends State<VerificationCodeScreen> {
  final _code = TextEditingController();
  bool _loading = false;
  String? _error;
  int _cooldown = 60;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldown <= 1) {
        timer.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown--);
      }
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    if (_loading) return;
    if (!RegExp(r'^\d{6}$').hasMatch(_code.text.trim())) {
      setState(() => _error = 'Enter the six-digit code from your email.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.purpose == VerificationPurpose.registration) {
        await AuthApi.verifyEmail(email: widget.email, code: _code.text.trim());
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => const ConnectHeadsetScreen(needsCalibration: true),
          ),
        );
      } else {
        final token = await AuthApi.verifyResetCode(
          email: widget.email,
          code: _code.text.trim(),
        );
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                ResetPasswordScreen(email: widget.email, resetToken: token),
          ),
        );
      }
    } on AuthApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted)
        setState(
          () => _error =
              'Could not reach MindSpeak. Check your connection and try again.',
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resendCode() async {
    if (_loading || _cooldown > 0) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.purpose == VerificationPurpose.registration) {
        await AuthApi.resendVerificationCode(widget.email);
      } else {
        await AuthApi.requestPasswordReset(widget.email);
      }
      if (mounted) setState(() => _cooldown = 60);
    } on AuthApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted)
        setState(
          () => _error =
              'Could not reach MindSpeak. Check your connection and try again.',
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BackHeader(onBack: () => Navigator.of(context).pop()),
        const SizedBox(height: 36),
        Text(
          widget.purpose == VerificationPurpose.registration
              ? 'Verify your email'
              : 'Check your email',
          style: const TextStyle(
            color: navy,
            fontSize: 25,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.purpose == VerificationPurpose.registration
              ? "We've sent a verification code to ${widget.email}. It expires in 5 minutes."
              : 'Enter the six-digit verification code sent to ${widget.email}. It expires in 5 minutes.',
          style: const TextStyle(color: muted),
        ),
        const SizedBox(height: 22),
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: 'Verification code',
            counterText: '',
          ),
          onSubmitted: (_) => _verifyCode(),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _loading || _cooldown > 0 ? null : _resendCode,
            child: Text(
              _cooldown > 0 ? 'Resend code in ${_cooldown}s' : 'Resend code',
            ),
          ),
        ),
        if (_error != null)
          Text(
            _error!,
            style: const TextStyle(color: Colors.red, fontSize: 13),
          ),
        const Spacer(),
        FilledButton(
          onPressed: _loading ? null : _verifyCode,
          child: _loading
              ? const _ButtonLoader()
              : Text(
                  widget.purpose == VerificationPurpose.registration
                      ? 'Verify email'
                      : 'Verify code',
                ),
        ),
      ],
    ),
  );
}

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({
    required this.email,
    required this.resetToken,
    super.key,
  });
  final String email;
  final String resetToken;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _validateNewPassword(String? value) {
    if (value == null ||
        !RegExp(
          r'^(?=.*[A-Z])(?=.*[a-z])(?=.*[0-9])(?=.*[^A-Za-z0-9\s]).{8,128}$',
        ).hasMatch(value)) {
      return 'Use 8+ characters with uppercase, lowercase, a number, and a symbol.';
    }
    return null;
  }

  Future<void> _savePassword() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthApi.resetPassword(
        email: widget.email,
        resetToken: widget.resetToken,
        newPassword: _password.text,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => const AccessScreen(isLogin: true),
        ),
        (_) => false,
      );
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Password updated. Log in with your new password.'),
        ),
      );
    } on AuthApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted)
        setState(
          () => _error =
              'Could not reach MindSpeak. Check your connection and try again.',
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BackHeader(onBack: () => Navigator.of(context).pop()),
        const SizedBox(height: 36),
        const Text(
          'Create a new password',
          style: TextStyle(
            color: navy,
            fontSize: 25,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Choose a strong password for your account.',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 22),
        Form(
          key: _formKey,
          child: Column(
            children: [
              _PasswordFormField(
                controller: _password,
                labelText: 'New password',
                validator: _validateNewPassword,
              ),
              const SizedBox(height: 16),
              _PasswordFormField(
                controller: _confirm,
                labelText: 'Confirm password',
                validator: (value) =>
                    value != _password.text ? 'Passwords do not match.' : null,
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: const TextStyle(color: Colors.red, fontSize: 13),
          ),
        ],
        const Spacer(),
        FilledButton(
          onPressed: _loading ? null : _savePassword,
          child: _loading
              ? const _ButtonLoader()
              : const Text('Reset password'),
        ),
      ],
    ),
  );
}

class _PasswordFormField extends StatefulWidget {
  const _PasswordFormField({
    required this.controller,
    required this.labelText,
    required this.validator,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String labelText;
  final FormFieldValidator<String> validator;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  State<_PasswordFormField> createState() => _PasswordFormFieldState();
}

class _PasswordFormFieldState extends State<_PasswordFormField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    obscureText: !_visible,
    enableSuggestions: false,
    autocorrect: false,
    validator: widget.validator,
    onFieldSubmitted: widget.onFieldSubmitted,
    decoration: InputDecoration(
      labelText: widget.labelText,
      suffixIcon: IconButton(
        tooltip: _visible ? 'Hide password' : 'Show password',
        onPressed: () => setState(() => _visible = !_visible),
        icon: Icon(
          _visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        ),
      ),
    ),
  );
}

class _ButtonLoader extends StatelessWidget {
  const _ButtonLoader();

  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: 22,
    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
  );
}

bool _validEmail(String email) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);

class ConnectHeadsetScreen extends StatefulWidget {
  const ConnectHeadsetScreen({
    required this.needsCalibration,
    this.bluetoothGateway,
    super.key,
  });

  final bool needsCalibration;
  final HeadsetBluetoothGateway? bluetoothGateway;

  @override
  State<ConnectHeadsetScreen> createState() => _ConnectHeadsetScreenState();
}

class _ConnectHeadsetScreenState extends State<ConnectHeadsetScreen> {
  late final HeadsetBluetoothGateway _gateway;
  late HeadsetSnapshot _snapshot;
  StreamSubscription<HeadsetSnapshot>? _snapshotSubscription;

  @override
  void initState() {
    super.initState();
    _gateway = widget.bluetoothGateway ?? mindSpeakHeadsetBluetooth;
    _snapshot = _gateway.snapshot;
    _snapshotSubscription = _gateway.changes.listen((snapshot) {
      if (mounted) setState(() => _snapshot = snapshot);
    });
    unawaited(_gateway.initialize());
  }

  @override
  Widget build(BuildContext context) => AppPage(
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BackHeader(onBack: () => Navigator.of(context).pop()),
          const SizedBox(height: 22),
          const Icon(Icons.bluetooth_rounded, color: navy, size: 62),
          const SizedBox(height: 14),
          const Text(
            'Connect your headset',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: navy,
              fontSize: 23,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Turn on your NINA BLE device and keep it nearby.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 18),
          _ConnectionStatusCard(snapshot: _snapshot),
          const SizedBox(height: 16),
          const Text(
            'AVAILABLE DEVICE',
            style: TextStyle(
              color: muted,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 7),
          if (_snapshot.devices.isEmpty)
            const _DeviceCard.empty()
          else
            for (final device in _snapshot.devices)
              _DeviceCard(
                device: device,
                selected: device.id == _snapshot.selectedDeviceId,
                onTap: () => _gateway.selectDevice(device.id),
              ),
          TextButton.icon(
            onPressed: _canScan ? _scanForDevices : null,
            icon: _snapshot.status == HeadsetConnectionStatus.scanning
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.bluetooth_searching_rounded),
            label: Text(
              _snapshot.status == HeadsetConnectionStatus.scanning
                  ? 'Scanning for devices…'
                  : 'Scan for devices',
            ),
          ),
          OutlinedButton.icon(
            onPressed: _canConnect ? _connectSelected : null,
            icon: const Icon(Icons.link_rounded),
            label: Text(
              _snapshot.status == HeadsetConnectionStatus.connecting
                  ? 'Connecting…'
                  : _snapshot.status == HeadsetConnectionStatus.connectionLost
                  ? 'Reconnect headset'
                  : 'Connect to selected device',
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _snapshot.isConnected ? _continue : null,
            child: const Text('Continue'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _openBluetoothSettings,
            child: const Text('Open Bluetooth settings'),
          ),
        ],
      ),
    ),
  );

  bool get _canScan =>
      !_snapshot.isInitializing &&
      _snapshot.status != HeadsetConnectionStatus.scanning &&
      _snapshot.status != HeadsetConnectionStatus.connecting &&
      !_snapshot.isConnected &&
      _snapshot.status != HeadsetConnectionStatus.bluetoothUnavailable;

  bool get _canConnect =>
      _snapshot.selectedDeviceId != null &&
      _snapshot.status != HeadsetConnectionStatus.scanning &&
      _snapshot.status != HeadsetConnectionStatus.connecting &&
      !_snapshot.isConnected;

  Future<void> _scanForDevices() async {
    try {
      await _gateway.scan();
    } catch (_) {
      if (mounted) {
        _showMessage(
          'Bluetooth scanning failed. Check permissions and try again.',
        );
      }
    }
  }

  Future<void> _connectSelected() async {
    try {
      await _gateway.connectSelected();
    } catch (_) {
      if (mounted) {
        _showMessage(
          'Could not connect. Check that the device is nearby and try again.',
        );
      }
    }
  }

  Future<void> _openBluetoothSettings() async {
    try {
      final opened = await _gateway.openBluetoothSettings();
      if (!mounted || opened) return;
      _showMessage(
        kIsWeb
            ? 'Chrome cannot open Windows Bluetooth settings. Use Scan for devices to open Chrome’s BLE chooser. To enable Bluetooth, open Windows Settings > Bluetooth & devices.'
            : 'Open Bluetooth settings from your device settings to continue.',
      );
    } catch (_) {
      if (mounted) {
        _showMessage('Bluetooth settings could not be opened on this device.');
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _continue() {
    if (!_gateway.snapshot.isConnected) {
      _showMessage('Connect the headset before continuing.');
      return;
    }

    final navigator = Navigator.of(context);
    final page = widget.needsCalibration
        ? _HeadsetConnectionGuard(
            gateway: _gateway,
            needsCalibration: true,
            child: CalibrationScreen(gateway: _gateway),
          )
        : HomeScreen(
            gateway: _gateway,
            onLogout: () => _logoutToLogin(navigator),
            onReconnect: () => _openHeadsetConnection(navigator, _gateway),
          );
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  void dispose() {
    _snapshotSubscription?.cancel();
    super.dispose();
  }
}

class _ConnectionStatusCard extends StatelessWidget {
  const _ConnectionStatusCard({required this.snapshot});

  final HeadsetSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final connected = snapshot.isConnected;
    final icon = switch (snapshot.status) {
      HeadsetConnectionStatus.bluetoothUnavailable =>
        Icons.bluetooth_disabled_rounded,
      HeadsetConnectionStatus.disconnected => Icons.bluetooth_disabled_rounded,
      HeadsetConnectionStatus.scanning => Icons.bluetooth_searching_rounded,
      HeadsetConnectionStatus.connecting => Icons.sync_rounded,
      HeadsetConnectionStatus.connected => Icons.bluetooth_connected_rounded,
      HeadsetConnectionStatus.connectionLost =>
        Icons.bluetooth_disabled_rounded,
      HeadsetConnectionStatus.connectionFailed => Icons.error_outline_rounded,
    };
    final label = snapshot.isInitializing
        ? 'Checking Bluetooth'
        : switch (snapshot.status) {
            HeadsetConnectionStatus.bluetoothUnavailable =>
              'Bluetooth unavailable',
            HeadsetConnectionStatus.disconnected => 'Disconnected',
            HeadsetConnectionStatus.scanning => 'Scanning for devices',
            HeadsetConnectionStatus.connecting => 'Connecting',
            HeadsetConnectionStatus.connected => 'Connected',
            HeadsetConnectionStatus.connectionLost => 'Connection lost',
            HeadsetConnectionStatus.connectionFailed => 'Connection failed',
          };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: connected ? green : blue),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: connected ? green : navy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (snapshot.message != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      snapshot.message!,
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              snapshot.batteryLevel == null
                  ? 'Battery unavailable'
                  : 'Battery ${snapshot.batteryLevel}%',
              style: const TextStyle(color: muted, fontSize: 11),
              textAlign: TextAlign.end,
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.device,
    required this.selected,
    required this.onTap,
  }) : empty = false;

  const _DeviceCard.empty()
    : device = null,
      selected = false,
      onTap = null,
      empty = true;

  final HeadsetDevice? device;
  final bool selected;
  final VoidCallback? onTap;
  final bool empty;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      side: BorderSide(color: selected ? blue : line),
      borderRadius: BorderRadius.circular(16),
    ),
    child: ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: soft,
        child: Icon(
          empty
              ? Icons.bluetooth_searching_rounded
              : Icons.settings_input_antenna_rounded,
          color: navy,
        ),
      ),
      title: Text(empty ? 'No BLE device selected' : device!.name),
      subtitle: Text(
        empty
            ? 'Scan to discover nearby Bluetooth LE devices.'
            : selected
            ? 'Selected device'
            : 'Tap to select',
        style: const TextStyle(color: muted),
      ),
      trailing: selected
          ? const Icon(Icons.check_circle_rounded, color: blue)
          : null,
    ),
  );
}

class _HeadsetConnectionGuard extends StatelessWidget {
  const _HeadsetConnectionGuard({
    required this.gateway,
    required this.needsCalibration,
    required this.child,
  });

  final HeadsetBluetoothGateway gateway;
  final bool needsCalibration;
  final Widget child;

  @override
  Widget build(BuildContext context) => StreamBuilder<HeadsetSnapshot>(
    stream: gateway.changes,
    initialData: gateway.snapshot,
    builder: (context, state) {
      if (state.data?.isConnected ?? false) return child;
      return AppPage(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.bluetooth_disabled_rounded, color: navy, size: 58),
            const SizedBox(height: 18),
            const Text(
              'Headset connection lost',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: navy,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Reconnect the headset before continuing.',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => ConnectHeadsetScreen(
                    needsCalibration: needsCalibration,
                    bluetoothGateway: gateway,
                  ),
                ),
              ),
              child: const Text('Reconnect headset'),
            ),
          ],
        ),
      );
    },
  );
}

class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({required this.gateway, super.key});

  final HeadsetBluetoothGateway gateway;

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  static const words = ['HELP', 'WATER', 'YES', 'NO', 'THANKS'];
  var index = 0;

  @override
  Widget build(BuildContext context) {
    final complete = index == words.length;
    final word = words[complete ? words.length - 1 : index];
    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _BrandHeader(),
              const Spacer(),
              Text(
                complete ? '5 of 5' : (index + 1).toString() + ' of 5',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 18),
          LinearProgressIndicator(
            value: index / words.length,
            minHeight: 7,
            borderRadius: BorderRadius.circular(99),
          ),
          const SizedBox(height: 14),
          const Center(
            child: Text(
              'Headset connected · Ready to record',
              style: TextStyle(color: green, fontSize: 12),
            ),
          ),
          const Spacer(),
          Icon(
            complete ? Icons.check_circle_rounded : Icons.psychology_rounded,
            size: 86,
            color: navy,
          ),
          const SizedBox(height: 18),
          Text(
            complete ? 'All set!' : 'Help us personalise\nyour model',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: navy,
              fontSize: 23,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 22),
          if (!complete)
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: line),
              ),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    const Text(
                      'Imagine saying',
                      style: TextStyle(color: muted),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      word,
                      style: const TextStyle(
                        color: navy,
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 14),
          Text(
            complete
                ? 'Your communication model is ready.'
                : 'Hold the thought for a few seconds while we record.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted),
          ),
          const Spacer(),
          FilledButton(
            onPressed: _next,
            child: Text(complete ? 'Continue to MindSpeak' : 'Record sample'),
          ),
        ],
      ),
    );
  }

  void _next() {
    if (index == words.length) {
      final navigator = Navigator.of(context);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => HomeScreen(
            gateway: widget.gateway,
            onLogout: () => _logoutToLogin(navigator),
            onReconnect: () =>
                _openHeadsetConnection(navigator, widget.gateway),
          ),
        ),
      );
      return;
    }
    setState(() => index++);
  }
}
