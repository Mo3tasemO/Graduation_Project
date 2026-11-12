import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:mindspeak_flutter/main.dart';

void main() {
  testWidgets(
    'Welcome and account creation expose the updated registration controls',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MindSpeakApp());
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Get started'), findsOneWidget);

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
