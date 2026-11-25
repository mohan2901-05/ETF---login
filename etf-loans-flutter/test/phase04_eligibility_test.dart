import 'dart:async';

import 'package:etf_loans/core/errors/app_errors.dart';
import 'package:etf_loans/features/authentication/models/auth_models.dart';
import 'package:etf_loans/features/authentication/screens/home_screen.dart';
import 'package:etf_loans/features/eligibility/eligibility_flow.dart';
import 'package:etf_loans/features/eligibility/eligibility_models.dart';
import 'package:etf_loans/features/eligibility/eligibility_service.dart';
import 'package:etf_loans/features/onboarding/borrower_details.dart';
import 'package:etf_loans/features/onboarding/borrower_service.dart';
import 'package:etf_loans/theme/theme_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Synthetic eligibility fixtures for isolated widget tests only.
const _syntheticOffer = LoanOfferSummary(
  approvedLimitPaise: 14100025,
  affordableMonthlyEmiPaise: 1600000,
  applicationReference: 'synthetic-test-offer',
);
const _syntheticApproved = EligibilityAssessment(
  decision: EligibilityDecision.eligible,
  offer: _syntheticOffer,
  creditScore: CreditScore(
    value: 699,
    band: 'Fair',
    source: 'Synthetic test bureau',
    factors: [
      CreditScoreFactor(
        label: 'Payment history',
        description: 'Synthetic test factor',
      ),
    ],
  ),
);

void main() {
  testWidgets(
    'waits for an assessment before showing money or enabling handoff',
    (tester) async {
      final service = _TestEligibilityService();
      String? handoff;
      await _openFlow(
        tester,
        service,
        onLoanApplicationRequested: (value) => handoff = value,
      );
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Choose loan amount'), findsNothing);
      expect(service.kinds, [EligibilityCheckKind.initial]);

      service.requests.single.complete(_syntheticApproved);
      await tester.pumpAndSettle();
      expect(find.text('699'), findsOneWidget);
      expect(find.text('Fair'), findsOneWidget);
      expect(find.text('Source: Synthetic test bureau'), findsOneWidget);
      expect(find.text('₹1,41,000.25'), findsOneWidget);
      expect(find.text('₹16,000'), findsOneWidget);
      expect(find.text('Payment history'), findsOneWidget);
      await _tap(tester, 'Choose loan amount');
      expect(handoff, 'synthetic-test-offer');
    },
  );

  testWidgets('missing service shows unavailable without a decision or retry', (
    tester,
  ) async {
    await _openFlow(tester, const UnavailableEligibilityService());
    await tester.pumpAndSettle();
    expect(find.text('Eligibility check unavailable'), findsOneWidget);
    expect(find.text('Your eligibility result'), findsNothing);
    expect(find.text('Retry check'), findsNothing);
    expect(find.text('Update details'), findsOneWidget);
  });

  testWidgets(
    'failure can be retried and ineligible responses cannot hand off',
    (tester) async {
      final service = _TestEligibilityService();
      await _openFlow(
        tester,
        service,
        onLoanApplicationRequested: (_) => fail('Unexpected handoff'),
      );
      service.requests.single.completeError(NetworkException());
      await tester.pumpAndSettle();
      expect(find.text('Eligibility check interrupted'), findsOneWidget);
      await tester.tap(find.text('Retry check'));
      await tester.pump();
      expect(service.kinds, [
        EligibilityCheckKind.initial,
        EligibilityCheckKind.initial,
      ]);

      service.requests.last.complete(
        const EligibilityAssessment(
          decision: EligibilityDecision.ineligible,
          offer: _syntheticOffer,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('You’re currently ineligible for a loan.'),
        findsOneWidget,
      );
      expect(find.text('Credit score unavailable'), findsOneWidget);
      expect(find.text('Approved limit'), findsNothing);
      expect(find.text('Choose loan amount'), findsNothing);
    },
  );

  testWidgets(
    'Home checks only after an actual onboarding completion succeeds',
    (tester) async {
      final service = _TestEligibilityService();
      final borrower = _TestBorrowerService();
      await _openHome(tester, service, borrower);
      await _tap(tester, 'Personal details');
      expect(service.kinds, isEmpty);
      await _enter(tester, 'Date of birth', '20/05/1990');
      final employment = find.byType(DropdownButtonFormField<EmploymentType>);
      await tester.ensureVisible(employment);
      await tester.tap(employment);
      await tester.pumpAndSettle();
      await _tap(tester, 'Salaried');
      await _enter(tester, 'Monthly take-home income', '42500');
      await _enter(tester, 'Other monthly EMIs', '0');
      await _tap(tester, 'Continue to PAN verification');
      await _enter(tester, 'PAN', 'ABCDE1234F');
      await _tap(tester, 'I consent to verification of my PAN.');
      await tester.tap(find.text('Verify PAN'));
      await tester.pump();
      expect(service.kinds, isEmpty);

      borrower.onboarding.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(service.kinds, [EligibilityCheckKind.initial]);
      expect(find.text('Checking your eligibility'), findsOneWidget);
      service.requests.single.complete(_syntheticApproved);
      await tester.pumpAndSettle();
      expect(find.text('Your eligibility result'), findsOneWidget);
      expect(
        find.text('Loan selection is currently unavailable.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'result reuses ETF-014 and rechecks only after a confirmed save',
    (tester) async {
      final service = _TestEligibilityService();
      final borrower = _TestBorrowerService.withExistingProfile();
      await _openHome(tester, service, borrower);
      await _tap(tester, 'Manage Account');
      await tester.ensureVisible(find.text('Save and recheck eligibility'));
      await tester.tap(find.text('Save and recheck eligibility'));
      await tester.pump();
      expect(service.kinds, isEmpty);
      borrower.update.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(service.kinds, [EligibilityCheckKind.recheck]);
      service.requests.first.complete(_syntheticApproved);
      await tester.pumpAndSettle();

      await _tap(tester, 'Update details');
      expect(
        find.text('Name, PAN and date of birth are read-only.'),
        findsOneWidget,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Your eligibility result'), findsOneWidget);
      expect(service.kinds, [EligibilityCheckKind.recheck]);

      await _tap(tester, 'Update details');
      await _enter(tester, 'Monthly take-home income', '45000');
      borrower.update = Completer<void>();
      await tester.ensureVisible(find.text('Save and recheck eligibility'));
      await tester.tap(find.text('Save and recheck eligibility'));
      await tester.pump();
      expect(service.kinds, [EligibilityCheckKind.recheck]);
      borrower.update.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(service.kinds, [
        EligibilityCheckKind.recheck,
        EligibilityCheckKind.recheck,
      ]);
      expect(find.text('Your eligibility result'), findsNothing);
      service.requests.last.complete(_syntheticApproved);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'an expired assessment session is reported to the authenticated caller',
    (tester) async {
      final service = _TestEligibilityService();
      var expired = false;
      await _openFlow(tester, service, onSessionExpired: () => expired = true);
      service.requests.single.completeError(InvalidSessionException());
      await tester.pumpAndSettle();
      expect(expired, isTrue);
      expect(find.text('Your eligibility result'), findsNothing);
    },
  );
}

class _TestEligibilityService implements EligibilityService {
  final kinds = <EligibilityCheckKind>[];
  final requests = <Completer<EligibilityAssessment>>[];

  @override
  Future<EligibilityAssessment> check({
    required String accessToken,
    required EligibilityCheckKind kind,
  }) {
    expect(accessToken, 'synthetic-test-session');
    kinds.add(kind);
    final request = Completer<EligibilityAssessment>();
    requests.add(request);
    return request.future;
  }
}

class _TestBorrowerService implements BorrowerService {
  _TestBorrowerService() : profile = null;

  _TestBorrowerService.withExistingProfile()
    : profile = BorrowerProfile(
        details: BorrowerDetails(
          fullName: 'Test Borrower',
          dateOfBirth: DateTime(1990, 5, 20),
          finances: const BorrowerFinances(
            employment: EmploymentType.salaried,
            monthlyIncome: '42500',
            externalEmi: '0',
          ),
        ),
        maskedPan: '••••••234F',
      );

  final BorrowerProfile? profile;
  final onboarding = Completer<void>();
  Completer<void> update = Completer<void>();

  @override
  Future<BorrowerProfile?> loadProfile({required String accessToken}) async =>
      profile;

  @override
  Future<void> completeOnboarding({
    required String accessToken,
    required BorrowerDetails details,
    required String pan,
    required bool panConsent,
  }) => onboarding.future;

  @override
  Future<void> updateFinances({
    required String accessToken,
    required BorrowerFinances finances,
  }) => update.future;
}

Future<void> _openFlow(
  WidgetTester tester,
  EligibilityService service, {
  ValueChanged<String>? onLoanApplicationRequested,
  VoidCallback? onSessionExpired,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeConfig.lightTheme,
      home: EligibilityFlow(
        accessToken: 'synthetic-test-session',
        initialKind: EligibilityCheckKind.initial,
        service: service,
        onSessionExpired: onSessionExpired ?? () {},
        openUpdateDetails: () async => null,
        onLoanApplicationRequested: onLoanApplicationRequested,
      ),
    ),
  );
}

Future<void> _openHome(
  WidgetTester tester,
  EligibilityService service,
  BorrowerService borrower,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeConfig.lightTheme,
      home: HomeScreen(
        initialUser: UserProfile(
          id: 'synthetic-test-user',
          mobileNumber: '9000000000',
          name: 'Test Borrower',
        ),
        initialToken: 'synthetic-test-session',
        eligibilityService: service,
        borrowerService: borrower,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String label) async {
  final target = find.text(label);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String label, String value) async {
  final field = find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
}
