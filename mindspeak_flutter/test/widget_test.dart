import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:mindspeak_flutter/main.dart';

void main() {
  testWidgets(
    'Welcome and account creation expose the updated registration controls',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MindSpeakApp());
      await tester.pump();

      // The animated splash comes first, with the project name and taglines.
      expect(find.byKey(const Key('mindspeak_splash')), findsOneWidget);
      expect(find.text('Bridging Thoughts to Words'), findsOneWidget);
      expect(find.text('Think It... We Speak It'), findsOneWidget);

      // After the intro it fades into the Welcome screen.
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const Key('mindspeak_splash')), findsNothing);

      expect(find.text('Get started'), findsOneWidget);
      expect(find.byKey(const Key('background_waves')), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(home: AccessScreen(isLogin: false)),
      );
      await tester.pump();

      expect(find.text('Create your account'), findsOneWidget);
      expect(find.text('First name'), findsOneWidget);
      expect(find.text('Last name'), findsOneWidget);

      final passwordField = find.byType(EditableText).last;
      expect(tester.widget<EditableText>(passwordField).obscureText, isTrue);

      await tester.enterText(passwordField, 'StrongPass1!');
      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();

      final visibleField = tester.widget<EditableText>(passwordField);
      expect(visibleField.obscureText, isFalse);
      expect(visibleField.controller.text, 'StrongPass1!');
    },
  );
}
