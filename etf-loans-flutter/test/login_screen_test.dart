import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:etf_loans/features/authentication/screens/login_screen.dart';

void main() {
  group('LoginScreen', () {
    testWidgets('renders headline, mobile field and send code button',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      // Pump a few frames to let animations start, but don't wait for all to settle
      // (animations have long delays that cause test timeouts in CI)
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Sign in with your mobile'), findsOneWidget);
      expect(find.text('Mobile number'), findsOneWidget);
      expect(find.text('Send code'), findsOneWidget);
    });
  });
}
