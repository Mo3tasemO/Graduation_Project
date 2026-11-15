import 'package:flutter/material.dart';

import 'services/api_service.dart';

const navy = Color(0xFF173F5F);
const blue = Color(0xFF2874B6);
const bg = Color(0xFFF5F7FA);
const muted = Color(0xFF5C7185);
const soft = Color(0xFFDCE9F4);
const line = Color(0xFFD6E0E9);
const green = Color(0xFF237A62);

void main() => runApp(const MindSpeakApp());

class MindSpeakApp extends StatelessWidget {
  const MindSpeakApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'MindSpeak',
    debugShowCheckedModeBanner: false,
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

class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key});

  @override
  Widget build(BuildContext context) => const Column(
    mainAxisSize: MainAxisSize.min,
    children: [_BrandSymbol(), SizedBox(height: 3), BrandWordmark()],
  );
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
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(flex: 3),
        const Center(child: BrandLockup()),
        const Spacer(flex: 4),
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
        FilledButton(
          onPressed: () => _open(context, false),
          child: const Text('Get started'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => _open(context, true),
          child: const Text('I already have an account · Log in'),
        ),
      ],
    ),
  );

  void _open(BuildContext context, bool login) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => AccessScreen(isLogin: login)),
    );
  }
}

class AccessScreen extends StatefulWidget {
  const AccessScreen({required this.isLogin, super.key});
  final bool isLogin;

  @override
  State<AccessScreen> createState() => _AccessScreenState();
}

class _AccessScreenState extends State<AccessScreen> {
  final _api = MindSpeakApi();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _birthDate = TextEditingController();
  final _phone = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _birthDate.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppPage(
    child: ListView(
      children: [
        _BackHeader(onBack: () => Navigator.of(context).pop()),
        const SizedBox(height: 28),
        Text(
          widget.isLogin ? 'Welcome back!' : 'Create your account',
          style: const TextStyle(
            color: navy,
            fontSize: 25,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.isLogin
              ? 'Sign in to connect your headset.'
              : 'New accounts complete calibration once.',
          style: const TextStyle(color: muted),
        ),
        if (!widget.isLogin) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _username,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Username'),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email address'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Password',
            helperText: widget.isLogin
                ? null
                : '8+ characters, a number and a symbol',
          ),
        ),
        if (!widget.isLogin) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _birthDate,
            keyboardType: TextInputType.datetime,
            decoration: const InputDecoration(
              labelText: 'Birth date (YYYY-MM-DD)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone number'),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
          ),
        ],
        if (widget.isLogin)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {},
              child: const Text('Forgot password?'),
            ),
          ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(widget.isLogin ? 'Log in' : 'Create account'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => AccessScreen(isLogin: !widget.isLogin),
            ),
          ),
          child: Text(
            widget.isLogin ? 'Create new account' : 'I already have an account',
          ),
        ),
      ],
    ),
  );

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.isLogin) {
        final session = await _api.login(
          email: _email.text,
          password: _password.text,
        );
        if (!mounted) return;
        _openHeadset(session);
      } else {
        if (_username.text.trim().isEmpty ||
            _email.text.trim().isEmpty ||
            _password.text.isEmpty ||
            _birthDate.text.trim().isEmpty ||
            _phone.text.trim().isEmpty) {
          throw const ApiException('Please complete all account details.');
        }
        final email = await _api.register(
          username: _username.text,
          email: _email.text,
          password: _password.text,
          birthDate: _birthDate.text,
          phone: _phone.text,
        );
        if (!mounted) return;
        final code = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const _VerificationCodeDialog(),
        );
        if (code == null) return;
        await _api.verifyEmail(email: email, code: code);
        final session = await _api.login(
          email: email,
          password: _password.text,
        );
        if (!mounted) return;
        _openHeadset(session);
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openHeadset(AuthSession session) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ConnectHeadsetScreen(
          needsCalibration: !session.calibrated,
          token: session.token,
        ),
      ),
    );
  }
}

class _VerificationCodeDialog extends StatefulWidget {
  const _VerificationCodeDialog();

  @override
  State<_VerificationCodeDialog> createState() =>
      _VerificationCodeDialogState();
}

class _VerificationCodeDialogState extends State<_VerificationCodeDialog> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Verify your email'),
    content: TextField(
      controller: _code,
      autofocus: true,
      keyboardType: TextInputType.number,
      maxLength: 6,
      decoration: const InputDecoration(
        labelText: '6-digit verification code',
        helperText: 'Check your email for the code.',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(_code.text),
        child: const Text('Verify'),
      ),
    ],
  );
}

class ConnectHeadsetScreen extends StatefulWidget {
  const ConnectHeadsetScreen({
    required this.needsCalibration,
    required this.token,
    super.key,
  });
  final bool needsCalibration;
  final String token;

  @override
  State<ConnectHeadsetScreen> createState() => _ConnectHeadsetScreenState();
}

class _ConnectHeadsetScreenState extends State<ConnectHeadsetScreen> {
  var connected = false;

  @override
  Widget build(BuildContext context) => AppPage(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BackHeader(onBack: () => Navigator.of(context).pop()),
        const SizedBox(height: 48),
        const Icon(Icons.bluetooth_rounded, color: navy, size: 62),
        const SizedBox(height: 22),
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
        const SizedBox(height: 38),
        const Text(
          'AVAILABLE DEVICE',
          style: TextStyle(
            color: muted,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 10),
        _DeviceCard(connected: connected),
        const Spacer(),
        FilledButton(
          onPressed: connected
              ? _continue
              : () => setState(() => connected = true),
          child: Text(connected ? 'Continue' : 'Connect headset'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _openSettingsInfo,
          child: const Text('Open Bluetooth settings'),
        ),
      ],
    ),
  );

  void _continue() {
    final page = widget.needsCalibration
        ? CalibrationScreen(token: widget.token)
        : const HomeScreen();
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute<void>(builder: (_) => page));
  }

  void _openSettingsInfo() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Bluetooth settings will open here after BLE permissions are added.',
        ),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.connected});
  final bool connected;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: line),
      borderRadius: BorderRadius.circular(16),
    ),
    child: ListTile(
      leading: const CircleAvatar(
        backgroundColor: soft,
        child: Icon(Icons.settings_input_antenna_rounded, color: navy),
      ),
      title: const Text('MindSpeak Headset'),
      subtitle: Text(
        connected ? 'NINA BLE · Connected' : 'NINA BLE · Nearby',
        style: const TextStyle(color: green),
      ),
    ),
  );
}

class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({required this.token, super.key});
  final String token;

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  static const words = ['HELP', 'WATER', 'YES', 'NO', 'THANKS'];
  var index = 0;
  var saving = false;

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
                complete ? '5 of 5' : '${index + 1} of 5',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 18),
          LinearProgressIndicator(
            value: complete ? 1 : index / words.length,
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
            onPressed: saving ? null : _next,
            child: saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(complete ? 'Continue to MindSpeak' : 'Record sample'),
          ),
        ],
      ),
    );
  }

  Future<void> _next() async {
    if (index == words.length) {
      setState(() => saving = true);
      try {
        await MindSpeakApi().saveCalibration(widget.token);
      } on ApiException catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(error.message)));
          setState(() => saving = false);
        }
        return;
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
      );
      return;
    }
    setState(() => index++);
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => AppPage(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: _BrandHeader()),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.person_outline_rounded),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const _HeadsetStatus(),
        const SizedBox(height: 24),
        const Text(
          'YOUR MESSAGE',
          style: TextStyle(
            color: muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 9),
        const _MessageCard(text: 'I need water'),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.volume_up_rounded),
          label: const Text('Speak message'),
        ),
        const SizedBox(height: 26),
        const Text(
          'QUICK PHRASES',
          style: TextStyle(
            color: muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        const Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _QuickPhrase('I need help'),
            _QuickPhrase('I am thirsty'),
            _QuickPhrase('Yes'),
            _QuickPhrase('No'),
          ],
        ),
      ],
    ),
  );
}

class _HeadsetStatus extends StatelessWidget {
  const _HeadsetStatus();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: line),
    ),
    child: const ListTile(
      leading: CircleAvatar(
        backgroundColor: soft,
        child: Icon(Icons.signal_cellular_alt_rounded, color: navy),
      ),
      title: Text('MindSpeak Headset'),
      subtitle: Text('Connected · Good signal', style: TextStyle(color: green)),
    ),
  );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: line),
    ),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Text(text, style: Theme.of(context).textTheme.titleLarge),
    ),
  );
}

class _QuickPhrase extends StatelessWidget {
  const _QuickPhrase(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: () {},
    style: OutlinedButton.styleFrom(
      foregroundColor: muted,
      side: const BorderSide(color: line),
      backgroundColor: soft,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    child: Text(text),
  );
}
