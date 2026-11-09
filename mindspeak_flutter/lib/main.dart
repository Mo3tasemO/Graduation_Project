import 'package:flutter/material.dart';

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
  Widget build(BuildContext context) =>
      const Align(alignment: Alignment.centerLeft, child: BrandWordmark(size: 19));
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
              style: TextStyle(color: navy, fontSize: 15, fontWeight: FontWeight.w600),
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

class AccessScreen extends StatelessWidget {
  const AccessScreen({required this.isLogin, super.key});
  final bool isLogin;

  @override
  Widget build(BuildContext context) => AppPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BackHeader(onBack: () => Navigator.of(context).pop()),
            const SizedBox(height: 36),
            Text(
              isLogin ? 'Welcome back!' : 'Create your account',
              style: const TextStyle(color: navy, fontSize: 25, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              isLogin
                  ? 'Sign in to connect your headset.'
                  : 'New accounts complete calibration once.',
              style: const TextStyle(color: muted),
            ),
            if (!isLogin) ...[
              const SizedBox(height: 22),
              const TextField(decoration: InputDecoration(labelText: 'Full name')),
            ],
            const SizedBox(height: 16),
            const TextField(
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: 'Email address'),
            ),
            const SizedBox(height: 16),
            const TextField(
              obscureText: true,
              decoration: InputDecoration(labelText: 'Password'),
            ),
            if (isLogin)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () {}, child: const Text('Forgot password?')),
              ),
            const Spacer(),
            FilledButton(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => ConnectHeadsetScreen(needsCalibration: !isLogin),
                ),
              ),
              child: Text(isLogin ? 'Log in' : 'Create account'),
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

class ConnectHeadsetScreen extends StatefulWidget {
  const ConnectHeadsetScreen({required this.needsCalibration, super.key});
  final bool needsCalibration;

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
              style: TextStyle(color: navy, fontSize: 23, fontWeight: FontWeight.w700),
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
              style: TextStyle(color: muted, fontWeight: FontWeight.w700, fontSize: 12),
            ),
            const SizedBox(height: 10),
            _DeviceCard(connected: connected),
            const Spacer(),
            FilledButton(
              onPressed: connected ? _continue : () => setState(() => connected = true),
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
    final page = widget.needsCalibration ? const CalibrationScreen() : const HomeScreen();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  void _openSettingsInfo() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bluetooth settings will open here after BLE permissions are added.'),
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
  const CalibrationScreen({super.key});

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
            style: const TextStyle(color: navy, fontSize: 23, fontWeight: FontWeight.w700),
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
                    const Text('Imagine saying', style: TextStyle(color: muted)),
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
              style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w700),
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
              style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w700),
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
