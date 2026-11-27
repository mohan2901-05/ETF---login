import 'dart:async';

import 'package:etf_loans/core/errors/app_errors.dart';
import 'package:etf_loans/features/authentication/models/auth_models.dart';
import 'package:etf_loans/features/authentication/screens/home_screen.dart';
import 'package:etf_loans/features/onboarding/borrower_details.dart';
import 'package:etf_loans/features/onboarding/borrower_flow.dart';
import 'package:etf_loans/features/onboarding/borrower_service.dart';
import 'package:etf_loans/theme/theme_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('authenticated Home opens both borrower entry points', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeConfig.lightTheme,
        home: HomeScreen(
          initialUser: UserProfile(
            id: 'test-user',
            mobileNumber: '9000000000',
            name: 'Asha Rao',
          ),
          initialToken: 'test-session',
          borrowerService: const UnavailableBorrowerService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _tap(tester, 'Personal details');
    expect(find.text('Your details'), findsOneWidget);
    expect(_text(tester, 'Full name'), 'Asha Rao');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await _tap(tester, 'Manage Account');
    expect(find.text('Update details'), findsOneWidget);
    expect(
      find.text('Your borrower profile is currently unavailable.'),
      findsOneWidget,
    );
  });

  testWidgets('Home without a session does not expose borrower actions', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Personal details'), findsNothing);
    expect(find.text('Manage Account'), findsNothing);
  });

  testWidgets(
    'validates the draft and preserves fields when navigating back from PAN',
    (tester) async {
      await _openFlow(tester, const UnavailableBorrowerService());
      await _tap(tester, 'Continue to PAN verification');
      expect(find.text('Enter your full name.'), findsOneWidget);
      expect(find.text('Choose your employment type.'), findsOneWidget);

      await _enter(tester, 'Date of birth', '31/02/1990');
      await _tap(tester, 'Continue to PAN verification');
      expect(
        find.text('Enter a valid date in DD/MM/YYYY format.'),
        findsOneWidget,
      );
      await _fillPersonalDetails(tester);
      await _tap(tester, 'Continue to PAN verification');

      await _enter(tester, 'PAN', 'invalid');
      await _tap(tester, 'Verify PAN');
      expect(
        find.text('Enter a PAN in the format ABCDE1234F.'),
        findsOneWidget,
      );
      expect(
        find.text('Consent to PAN verification to continue.'),
        findsOneWidget,
      );
      await _enter(tester, 'PAN', 'abcde1234f');
      await _tap(tester, 'I consent to verification of my PAN.');
      await _tap(tester, 'Verify PAN');
      expect(
        find.text(
          'PAN verification and saving your details are currently unavailable.',
        ),
        findsOneWidget,
      );
      expect(find.text('Verify your PAN'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(_text(tester, 'Full name'), 'Asha Rao');
      expect(_text(tester, 'Monthly take-home income'), '42500.50');
      expect(_text(tester, 'Other monthly EMIs'), '0');
      _expectVisibleEmployment(tester, 'Salaried');
      await _tap(tester, 'Continue to PAN verification');
      expect(_text(tester, 'PAN'), 'abcde1234f');
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue,
      );
    },
  );

  testWidgets(
    'waits for server confirmation before handing off to eligibility',
    (tester) async {
      final service = _BorrowerTestService();
      BorrowerFlowResult? result;
      await _openFlow(tester, service, onResult: (value) => result = value);
      await _fillPersonalDetails(tester);
      await _tap(tester, 'Continue to PAN verification');
      await _enter(tester, 'PAN', 'abcde1234f');
      await _tap(tester, 'I consent to verification of my PAN.');
      await tester.tap(find.text('Verify PAN'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(service.submittedPan, 'ABCDE1234F');
      expect(service.submittedConsent, isTrue);
      expect(service.submittedFinances?.employment, EmploymentType.salaried);
      expect(result, isNull);

      service.onboarding.completeError(NetworkException());
      await tester.pumpAndSettle();
      expect(
        find.text('We couldn’t verify your PAN. Please try again.'),
        findsOneWidget,
      );
      expect(result, isNull);
      service.onboarding = Completer<void>()..complete();
      await _tap(tester, 'Verify PAN');
      expect(result, BorrowerFlowResult.checkEligibility);
    },
  );

  testWidgets(
    'returning borrowers can edit finances while identity stays locked',
    (tester) async {
      final service = _BorrowerTestService(profile: _existingProfile);
      BorrowerFlowResult? result;
      await _openFlow(tester, service, onResult: (value) => result = value);
      expect(find.text('Update details'), findsOneWidget);
      expect(find.text('Asha Rao'), findsOneWidget);
      expect(find.textContaining('1990'), findsOneWidget);
      expect(find.text('••••••234F'), findsOneWidget);
      expect(_field('Full name'), findsNothing);
      expect(_field('PAN'), findsNothing);
      expect(_field('Date of birth'), findsNothing);
      expect(_text(tester, 'Monthly take-home income'), '40000');
      _expectVisibleEmployment(tester, 'Self-employed');
      await _enter(tester, 'Monthly take-home income', '-1');
      await _tap(tester, 'Save and recheck eligibility');
      expect(service.savedFinances, isNull);
      await _enter(tester, 'Monthly take-home income', '41000.25');
      await _selectEmployment(tester, 'Salaried');
      _expectVisibleEmployment(tester, 'Salaried');
      await _tap(tester, 'Save and recheck eligibility');
      expect(service.savedFinances?.monthlyIncome, '41000.25');
      expect(service.savedFinances?.employment, EmploymentType.salaried);
      expect(result, BorrowerFlowResult.recheckEligibility);
    },
  );

  testWidgets('profile loading and retry report an expired session to Home', (
    tester,
  ) async {
    final service = _BorrowerTestService()
      ..profileRequest = Completer<BorrowerProfile?>();
    BorrowerFlowResult? result;
    await _openFlow(
      tester,
      service,
      settle: false,
      onResult: (value) => result = value,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    service.profileRequest!.completeError(NetworkException());
    await tester.pumpAndSettle();
    expect(
      find.text('We couldn’t load your borrower profile.'),
      findsOneWidget,
    );
    service.profileRequest = Completer<BorrowerProfile?>();
    await tester.tap(find.text('Retry'));
    await tester.pump();
    service.profileRequest!.completeError(InvalidSessionException());
    await tester.pumpAndSettle();
    expect(result, BorrowerFlowResult.sessionExpired);
  });

  testWidgets('update form scrolls on a narrow screen with large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = _BorrowerTestService(profile: _existingProfile);
    await _openFlow(tester, service, textScale: 2, openUpdate: true);
    await tester.ensureVisible(find.text('Save and recheck eligibility'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

final _existingProfile = BorrowerProfile(
  maskedPan: '••••••234F',
  details: BorrowerDetails(
    fullName: 'Asha Rao',
    dateOfBirth: DateTime(1990, 5, 20),
    finances: const BorrowerFinances(
      employment: EmploymentType.selfEmployed,
      monthlyIncome: '40000',
      externalEmi: '2500',
    ),
  ),
);

class _BorrowerTestService implements BorrowerService {
  _BorrowerTestService({this.profile});

  final BorrowerProfile? profile;
  Completer<BorrowerProfile?>? profileRequest;
  Completer<void> onboarding = Completer<void>();
  String? submittedPan;
  bool? submittedConsent;
  BorrowerFinances? submittedFinances;
  BorrowerFinances? savedFinances;

  @override
  Future<BorrowerProfile?> loadProfile({required String accessToken}) async {
    expect(accessToken, 'test-session');
    if (profileRequest case final request?) return request.future;
    return profile;
  }

  @override
  Future<void> completeOnboarding({
    required String accessToken,
    required BorrowerDetails details,
    required String pan,
    required bool panConsent,
  }) {
    expect(accessToken, 'test-session');
    submittedPan = pan;
    submittedConsent = panConsent;
    submittedFinances = details.finances;
    return onboarding.future;
  }

  @override
  Future<void> updateFinances({
    required String accessToken,
    required BorrowerFinances finances,
  }) async {
    expect(accessToken, 'test-session');
    savedFinances = finances;
  }
}

Future<void> _openFlow(
  WidgetTester tester,
  BorrowerService service, {
  ValueChanged<BorrowerFlowResult?>? onResult,
  bool settle = true,
  bool openUpdate = false,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeConfig.lightTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: TextButton(
              onPressed: () async {
                final result = await Navigator.of(context)
                    .push<BorrowerFlowResult>(
                      MaterialPageRoute(
                        builder: (_) => BorrowerFlow(
                          accessToken: 'test-session',
                          openUpdate: openUpdate,
                          service: service,
                        ),
                      ),
                    );
                onResult?.call(result);
              },
              child: const Text('Open borrower flow'),
            ),
          );
        },
      ),
    ),
  );
  await tester.tap(find.text('Open borrower flow'));
  await tester.pump();
  if (settle) await tester.pumpAndSettle();
}

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

String _text(WidgetTester tester, String label) =>
    tester.widget<TextField>(_field(label)).controller!.text;

Future<void> _enter(WidgetTester tester, String label, String value) async {
  final field = _field(label);
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String label) async {
  final target = find.text(label);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _fillPersonalDetails(WidgetTester tester) async {
  await _enter(tester, 'Full name', 'Asha Rao');
  await _enter(tester, 'Date of birth', '20/05/1990');
  await _selectEmployment(tester, 'Salaried');
  _expectVisibleEmployment(tester, 'Salaried');
  await _enter(tester, 'Monthly take-home income', '42500.50');
  await _enter(tester, 'Other monthly EMIs', '0');
}

Future<void> _selectEmployment(WidgetTester tester, String label) async {
  final employment = find.byType(DropdownButtonFormField<EmploymentType>);
  await tester.ensureVisible(employment);
  await tester.tap(employment);
  await tester.pumpAndSettle();
  final option = find.text(label).last;
  await tester.ensureVisible(option);
  await tester.tap(option);
  await tester.pumpAndSettle();
}

void _expectVisibleEmployment(WidgetTester tester, String label) {
  final button = find.byType(DropdownButton<EmploymentType>);
  final text = find.descendant(of: button, matching: find.text(label));
  final labelBounds = tester.getRect(text);
  final buttonBounds = tester.getRect(button);
  expect(labelBounds.height, greaterThan(0));
  expect(labelBounds.top, greaterThanOrEqualTo(buttonBounds.top));
  expect(labelBounds.bottom, lessThanOrEqualTo(buttonBounds.bottom + 0.01));
}
