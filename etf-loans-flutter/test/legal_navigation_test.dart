import 'package:etf_loans/features/legal/privacy_screen.dart';
import 'package:etf_loans/features/legal/terms_screen.dart';
import 'package:etf_loans/features/welcome/welcome_screen.dart';
import 'package:etf_loans/main.dart';
import 'package:etf_loans/theme/theme_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final documents = [
    ('Terms of Service', TermsScreen, '9. Governing law'),
    ('Privacy Policy', PrivacyScreen, '8. Contact'),
  ];
  for (final (title, screen, lastSection) in documents) {
    testWidgets(
      '$title opens from Welcome and Back restores its scroll position',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(const ETFLoansApp());

        final link = find.text(title);
        await tester.ensureVisible(link);
        final linkPosition = tester.getTopLeft(link);
        await tester.tap(link);
        await tester.pumpAndSettle();
        expect(find.byType(screen), findsOneWidget);
        expect(find.text(title), findsOneWidget);
        expect(find.text('Last updated 13 November 2026'), findsOneWidget);
        final logo = tester.widget<Image>(find.byType(Image));
        expect((logo.image as AssetImage).assetName, 'assets/logos/logo.png');
        await tester.ensureVisible(find.text(lastSection));
        expect(find.text(lastSection).hitTestable(), findsOneWidget);
        await tester.tap(find.text('Back'));
        await tester.pumpAndSettle();

        expect(find.byType(WelcomeScreen), findsOneWidget);
        expect(tester.getTopLeft(link), linkPosition);
      },
    );
  }

  for (final (width, scale) in [
    (360.0, 1.0),
    (390.0, 1.0),
    (412.0, 1.0),
    (360.0, 2.0),
    (1200.0, 1.0),
  ]) {
    testWidgets('public screens fit at width $width with text scale $scale', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final (screen, landmark) in [
        (const WelcomeScreen(), 'Check my eligibility'),
        (const TermsScreen(), '9. Governing law'),
        (const PrivacyScreen(), '8. Contact'),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeConfig.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: screen,
          ),
        );
        final end = find.text(landmark);
        await tester.ensureVisible(end);
        await tester.pumpAndSettle();
        expect(end.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  }
}
