import 'package:etf_loans/features/authentication/screens/login_screen.dart';
import 'package:etf_loans/features/welcome/welcome_screen.dart';
import 'package:etf_loans/main.dart';
import 'package:etf_loans/shared/widgets/emi_calculator.dart';
import 'package:etf_loans/theme/theme_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('sign-in and eligibility open the existing login', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const ETFLoansApp());
    expect(find.byType(WelcomeScreen), findsOneWidget);

    final actions = [
      find.text('Already a customer? Sign in'),
      find.text('Check my eligibility').first,
      find.text('Check my eligibility').last,
    ];
    for (final action in actions) {
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeScreen), findsOneWidget);
    }
  });

  testWidgets('calculator updates the estimate for tenure and amount', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(460, 840));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeConfig.lightTheme,
        home: const Scaffold(body: EmiCalculator()),
      ),
    );
    expect(find.text('₹9,333'), findsOneWidget);
    expect(find.text('₹9,335'), findsOneWidget);
    expect(find.text('₹56,000'), findsOneWidget);
    expect(find.textContaining('Illustrative estimate only'), findsOneWidget);
    await tester.tap(find.text('9 mo'));
    await tester.pumpAndSettle();
    expect(find.text('3% a month, flat'), findsOneWidget);
    expect(find.text('₹63,500'), findsOneWidget);

    final slider = find.byType(Slider);
    await tester.drag(slider, const Offset(460, 0));
    await tester.pumpAndSettle();
    expect(tester.widget<Slider>(slider).value, 500000);
    expect(find.text('₹6,35,000'), findsOneWidget);
  });

  testWidgets('FAQ expands and collapses on a narrow, large-text layout', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 680));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeConfig.lightTheme,
        home: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: WelcomeScreen(),
        ),
      ),
    );
    final question = find.text('Will checking my limit lower my credit score?');
    final answer = find.text(
      'This demo simulates credit checks. No bureau enquiry is made.',
    );
    expect(answer, findsNothing);
    await tester.ensureVisible(question);
    await tester.tap(question);
    await tester.pumpAndSettle();
    expect(answer, findsOneWidget);
    await tester.tap(question);
    await tester.pumpAndSettle();
    expect(answer, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide layout exposes the footer navigation callbacks', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeConfig.lightTheme,
        home: WelcomeScreen(
          onTerms: () => opened.add('terms'),
          onPrivacy: () => opened.add('privacy'),
        ),
      ),
    );
    expect(
      tester.getTopLeft(find.text('Work out your EMI')).dx,
      tester.getTopLeft(find.text('Who can apply')).dx,
    );
    final nineMonths = find.text('9 mo');
    await tester.ensureVisible(nineMonths);
    await tester.tap(nineMonths);
    await tester.pumpAndSettle();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpAndSettle();
    expect(find.text('₹1,27,000'), findsOneWidget);

    final terms = find.text('Terms of Service');
    await tester.ensureVisible(terms);
    await tester.tap(terms);
    await tester.tap(find.text('Privacy Policy'));
    expect(opened, ['terms', 'privacy']);
    expect(tester.takeException(), isNull);
  });
}
