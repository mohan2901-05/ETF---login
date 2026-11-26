import 'dart:async';

import 'package:etf_loans/features/verification/additional_verification_models.dart';
import 'package:etf_loans/features/verification/additional_verification_service.dart';
import 'package:etf_loans/features/verification/verification_checklist_screen.dart';
import 'package:etf_loans/features/verification/verification_models.dart';
import 'package:etf_loans/features/verification/verification_service.dart';
import 'package:etf_loans/theme/theme_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('unconnected bank screen has no editable fields', (tester) async {
    await _open(tester);
    await _tap(tester, 'Bank account');
    expect(
      find.text('This verification service is currently unavailable.'),
      findsOneWidget,
    );
    expect(tester.widget<TextField>(_field('Account number')).enabled, isFalse);
    expect(tester.widget<TextField>(_field('IFSC')).enabled, isFalse);
  });

  testWidgets(
    'Aadhaar requires consent and masks only the provider-confirmed suffix',
    (tester) async {
      final service = _SyntheticAdditionalService();
      await _open(tester, service: service);
      await _tap(tester, 'Aadhaar');
      final button = find.ancestor(
        of: find.text('Continue to DigiLocker'),
        matching: find.byType(ElevatedButton),
      );
      expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
      expect(find.byType(TextField), findsNothing);
      await _tap(
        tester,
        'I agree to share Aadhaar information through DigiLocker for this check.',
      );
      await tester.tap(find.text('Continue to DigiLocker'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Aadhaar verification result'), findsNothing);
      service.aadhaar.complete(const AadhaarResult(VerificationStatus.pending));
      await tester.pumpAndSettle();
      expect(find.text('Masked Aadhaar'), findsNothing);
      await _tap(tester, 'Check status');
      expect(find.text('•••• •••• 1234'), findsOneWidget);
      expect(
        const AadhaarResult(
          VerificationStatus.completed,
          lastFourDigits: '123456789012',
        ).maskedAadhaar,
        isNull,
      );
    },
  );

  testWidgets(
    'address validates PIN and preserves the draft across checklist navigation',
    (tester) async {
      await _open(tester, service: _SyntheticAdditionalService());
      await _tap(tester, 'Address and work');
      await _enter(tester, 'House, street and area', 'Synthetic test address');
      await _enter(tester, 'PIN code', '123');
      await _tap(tester, 'Save details');
      expect(find.text('Enter a six-digit PIN code.'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await _tap(tester, 'Address and work');
      expect(
        tester
            .widget<TextField>(_field('House, street and area'))
            .controller!
            .text,
        'Synthetic test address',
      );
      expect(
        tester.widget<TextField>(_field('PIN code')).controller!.text,
        '123',
      );
    },
  );

  testWidgets(
    'bank validates confirmation and IFSC, then reloads checklist without marking complete',
    (tester) async {
      final service = _SyntheticAdditionalService();
      await _open(tester, service: service);
      await _tap(tester, 'Bank account');
      await _enter(tester, 'Account holder name', 'Synthetic borrower');
      await _enter(tester, 'Account number', '00001234');
      await _enter(tester, 'Confirm account number', '00001235');
      await _enter(tester, 'IFSC', 'BAD');
      await _tap(tester, 'Verify account');
      expect(find.text('The account numbers must match.'), findsOneWidget);
      expect(find.text('Enter a valid 11-character IFSC.'), findsOneWidget);
      expect(service.bank, isNull);
      await _enter(tester, 'Confirm account number', '00001234');
      await _enter(tester, 'IFSC', 'test0abc123');
      await _tap(tester, 'Verify account');
      expect(service.bank?.ifsc, 'TEST0ABC123');
      await _tap(tester, 'Return to checklist');
      expect(find.text('Completed'), findsNothing);
      expect(find.text('Pending'), findsNWidgets(3));
    },
  );
}

// Isolated fixtures. They never connect to a real provider or store identifiers.
class _SyntheticChecklist extends UnavailableLoanVerificationService {
  const _SyntheticChecklist();

  @override
  Future<Map<VerificationKind, VerificationCheck>> loadChecklist({
    required String accessToken,
    required String offerReference,
  }) async => const {
    VerificationKind.aadhaar: VerificationCheck(
      VerificationStatus.pending,
      canStart: true,
    ),
    VerificationKind.address: VerificationCheck(
      VerificationStatus.pending,
      canStart: true,
    ),
    VerificationKind.bank: VerificationCheck(
      VerificationStatus.pending,
      canStart: true,
    ),
  };
}

class _SyntheticAdditionalService implements AdditionalVerificationService {
  final aadhaar = Completer<AadhaarResult>();
  BankAccountDetails? bank;

  @override
  Future<AadhaarResult> startAadhaar({
    required String accessToken,
    required String offerReference,
    required bool consent,
  }) {
    expect(consent, isTrue);
    return aadhaar.future;
  }

  @override
  Future<AadhaarResult> readAadhaarResult({
    required String accessToken,
    required String offerReference,
  }) async =>
      const AadhaarResult(VerificationStatus.completed, lastFourDigits: '1234');

  @override
  Future<void> submitAddress({
    required String accessToken,
    required String offerReference,
    required AddressDetails details,
  }) async {}

  @override
  Future<void> submitBankAccount({
    required String accessToken,
    required String offerReference,
    required BankAccountDetails details,
  }) async {
    bank = details;
  }
}

Future<void> _open(
  WidgetTester tester, {
  AdditionalVerificationService? service,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeConfig.lightTheme,
      home: VerificationChecklistScreen(
        accessToken: 'synthetic-session',
        offerReference: 'synthetic-offer',
        onSessionExpired: () {},
        service: const _SyntheticChecklist(),
        additionalService: service,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<void> _tap(WidgetTester tester, String label) async {
  final target = find.text(label);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String label, String value) async {
  final field = _field(label);
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
}
