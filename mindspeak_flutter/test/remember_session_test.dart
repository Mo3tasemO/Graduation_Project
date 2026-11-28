import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mindspeak_flutter/animated_waves.dart';
import 'package:mindspeak_flutter/auth_api.dart';
import 'package:mindspeak_flutter/remember_session_prompt.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final secureStorageCalls = <MethodCall>[];

  setUp(() {
    secureStorageCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async {
            secureStorageCalls.add(call);
            return null;
          },
        );
  });

  Future<void> openPrompt(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => askToRememberSession(context),
                child: const Text('signed in'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('signed in'));
    await tester.pumpAndSettle();
  }

  testWidgets('after sign-in the user is asked whether to stay signed in', (
    tester,
  ) async {
    await openPrompt(tester);

    expect(find.byKey(const Key('remember_session_dialog')), findsOneWidget);
    expect(find.text('Stay signed in on this device?'), findsOneWidget);
    expect(find.textContaining('password itself is never saved'), findsOneWidget);
  });

  testWidgets('"Not now" keeps nothing on the device', (tester) async {
    await openPrompt(tester);
    await tester.tap(find.byKey(const Key('remember_session_no')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('remember_session_dialog')), findsNothing);
    expect(AuthApi.isSessionRemembered, isFalse);
    expect(secureStorageCalls.where((c) => c.method == 'write'), isEmpty);
    expect(secureStorageCalls.where((c) => c.method == 'delete'), isNotEmpty);
  });

  testWidgets('"Stay signed in" remembers the choice', (tester) async {
    await openPrompt(tester);
    await tester.tap(find.byKey(const Key('remember_session_yes')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('remember_session_dialog')), findsNothing);
    expect(AuthApi.isSessionRemembered, isTrue);
    // Biometrics are not offered in tests (no device sensor), so no second dialog.
    expect(find.byKey(const Key('biometric_offer_dialog')), findsNothing);
    await AuthApi.setRememberSession(false);
  });

  testWidgets('background waves keep moving', (tester) async {
    AnimatedWaves.animate = true;
    addTearDown(() => AnimatedWaves.animate = false);
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          height: 140,
          child: AnimatedWaves(key: Key('waves'), color: Colors.blue),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('waves')), findsOneWidget);
    expect(tester.hasRunningAnimations, isTrue);
  });
}
