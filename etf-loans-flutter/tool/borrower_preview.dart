import 'package:etf_loans/core/errors/app_errors.dart';
import 'package:etf_loans/features/eligibility/checking_eligibility_screen.dart';
import 'package:etf_loans/features/eligibility/eligibility_models.dart';
import 'package:etf_loans/features/eligibility/eligibility_result_screen.dart';
import 'package:etf_loans/features/loan_application/loan_quote.dart';
import 'package:etf_loans/features/loan_application/loan_quote_service.dart';
import 'package:etf_loans/features/loan_application/loan_review_screen.dart';
import 'package:etf_loans/features/loan_application/loan_selection_screen.dart';
import 'package:etf_loans/features/onboarding/borrower_details.dart';
import 'package:etf_loans/features/onboarding/borrower_service.dart';
import 'package:etf_loans/features/onboarding/pan_verification_screen.dart';
import 'package:etf_loans/features/onboarding/personal_details_screen.dart';
import 'package:etf_loans/features/onboarding/update_details_screen.dart';
import 'package:etf_loans/features/verification/aadhaar_verification_screen.dart';
import 'package:etf_loans/features/verification/additional_verification_models.dart';
import 'package:etf_loans/features/verification/address_verification_screen.dart';
import 'package:etf_loans/features/verification/bank_verification_screen.dart';
import 'package:etf_loans/features/verification/face_verification_screen.dart';
import 'package:etf_loans/features/verification/verification_checklist_screen.dart';
import 'package:etf_loans/features/verification/verification_models.dart';
import 'package:etf_loans/features/verification/verification_service.dart';
import 'package:etf_loans/theme/theme_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() {
  if (!kDebugMode)
    throw UnsupportedError('Borrower previews require a debug build.');
  runApp(
    MaterialApp(
      title: 'ETF Loans QA preview',
      theme: ThemeConfig.lightTheme,
      builder: (context, child) => Column(
        children: [
          Material(
            color: ThemeConfig.tintGreen,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'Synthetic QA preview. No backend connection.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ),
          ),
          Expanded(child: child!),
        ],
      ),
      home: const _PreviewMenu(),
    ),
  );
}

enum _Scenario { ready, loading, error, unavailable }

class _PreviewMenu extends StatefulWidget {
  const _PreviewMenu();
  @override
  State<_PreviewMenu> createState() => _PreviewMenuState();
}

class _PreviewMenuState extends State<_PreviewMenu> {
  _Scenario _scenario = _Scenario.ready;

  @override
  Widget build(BuildContext context) {
    final fixture = _Fixtures(_scenario);
    final unavailable = _scenario == _Scenario.unavailable;
    final screens = <String, Widget Function()>{
      '010 Personal details': () => PersonalDetailsScreen(
        service: fixture,
        accessToken: _session,
        accountName: 'QA Borrower',
        profileUnavailable: unavailable,
      ),
      '011 PAN verification': () => _PanPreview(service: fixture),
      '012 Checking eligibility': () => CheckingEligibilityScreen(
        state: switch (_scenario) {
          _Scenario.error => EligibilityCheckState.failed,
          _Scenario.unavailable => EligibilityCheckState.unavailable,
          _ => EligibilityCheckState.loading,
        },
        onUpdateDetails: () => Navigator.of(context).pop(),
        onRetry: () => Navigator.of(context).pop(),
      ),
      '013 Eligibility result': () => EligibilityResultScreen(
        assessment: _scenario == _Scenario.ready
            ? const EligibilityAssessment(
                decision: EligibilityDecision.eligible,
                creditScore: CreditScore(
                  value: 699,
                  band: 'Fair',
                  source: 'Synthetic bureau',
                ),
                offer: LoanOfferSummary(
                  approvedLimitPaise: 5000000,
                  affordableMonthlyEmiPaise: 1000000,
                ),
              )
            : const EligibilityAssessment(
                decision: EligibilityDecision.ineligible,
              ),
        borrowerName: 'QA Borrower',
        onUpdateDetails: () => Navigator.of(context).pop(),
      ),
      '014 Update details': () => UpdateDetailsScreen(
        service: fixture,
        accessToken: _session,
        profile: unavailable ? null : _profile,
        profileUnavailable: unavailable,
      ),
      '015 Face instructions': () => FaceVerificationInstructions(
        openSession: (_) => fixture.openFace(),
        onSessionExpired: () {},
      ),
      '016 Live face check': () => LiveFaceVerificationScreen(
        openSession: fixture.openFace,
        onSessionExpired: () {},
      ),
      '017 Face result': () => FaceVerificationResultScreen(
        result: FaceVerificationResult(status: fixture.status),
        onRetry: () {},
      ),
      '018 Verification checklist': () => VerificationChecklistScreen(
        accessToken: _session,
        offerReference: _offer,
        service: fixture,
        onSessionExpired: () {},
      ),
      '019 Verify Aadhaar': () => AadhaarVerificationScreen(
        start: unavailable ? null : (_) => fixture.load(fixture.aadhaar),
        onSessionExpired: () {},
      ),
      '020 Aadhaar result': () =>
          AadhaarVerificationResultScreen(result: fixture.aadhaar),
      '021 Address and work': () => AddressVerificationScreen(
        draft: AddressDraft(),
        submit: unavailable ? null : (_) => fixture.load<void>(null),
        onSessionExpired: () {},
      ),
      '022 Bank account': () => BankVerificationScreen(
        submit: unavailable ? null : (_) => fixture.load<void>(null),
        onSessionExpired: () {},
      ),
      '023 Loan selection': () => LoanSelectionScreen(
        accessToken: _session,
        offerReference: _offer,
        service: fixture,
        onSessionExpired: () {},
      ),
      '024 Loan review': () => LoanReviewScreen(
        loadQuote: () =>
            fixture.load(_quote, unavailable: const LoanQuoteUnavailable()),
        onSessionExpired: () {},
      ),
      '025 Repayment schedule': () => RepaymentScheduleScreen(
        installments: unavailable ? [] : _quote.schedule,
      ),
      '026 Loan agreement': () => LoanDisclosureScreen(
        title: 'Loan agreement',
        document: unavailable ? null : _quote.agreement,
      ),
      '026 Key Facts Statement': () => LoanDisclosureScreen(
        title: 'Key Facts Statement',
        document: unavailable ? null : _quote.keyFacts,
      ),
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Borrower UI previews')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<_Scenario>(
              initialValue: _scenario,
              decoration: const InputDecoration(labelText: 'Fixture scenario'),
              items: [
                for (final mode in _Scenario.values)
                  DropdownMenuItem(value: mode, child: Text(mode.name)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _scenario = value);
              },
            ),
            const SizedBox(height: 12),
            const Text(
              'Scenarios apply where the screen supports that state. Use synthetic inputs only.',
            ),
            for (final entry in screens.entries)
              ListTile(
                title: Text('ETF-${entry.key}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(
                  context,
                ).push<void>(MaterialPageRoute(builder: (_) => entry.value())),
              ),
          ],
        ),
      ),
    );
  }
}

const _session = 'synthetic-session';
const _offer = 'synthetic-offer';
final _profile = BorrowerProfile(
  maskedPan: '••••••000X',
  details: BorrowerDetails(
    fullName: 'QA Borrower',
    dateOfBirth: DateTime(1990, 1, 15),
    finances: const BorrowerFinances(
      employment: EmploymentType.salaried,
      monthlyIncome: '42000',
      externalEmi: '0',
    ),
  ),
);
final _quote = LoanQuote(
  principalPaise: 5000000,
  months: 6,
  totalRepaymentPaise: 5600000,
  interestPaise: 600000,
  netProceedsPaise: 5000000,
  regularEmiPaise: 933300,
  finalEmiPaise: 933500,
  apr: '40.05%',
  firstDueDate: DateTime(2027, 1, 5),
  schedule: [
    for (var n = 1; n <= 6; n++)
      LoanInstallment(
        number: n,
        dueDate: DateTime(2027, n, 5),
        amountPaise: n == 6 ? 933500 : 933300,
      ),
  ],
  agreement: const LoanDisclosure(
    version: 'QA-1',
    text: 'Synthetic agreement placeholder. No legal terms apply.',
  ),
  keyFacts: const LoanDisclosure(
    version: 'QA-1',
    text: 'Synthetic Key Facts Statement placeholder.',
  ),
);
const _smallQuote = LoanQuote(
  principalPaise: 3000000,
  months: 6,
  totalRepaymentPaise: 3360000,
  interestPaise: 360000,
  netProceedsPaise: 3000000,
  regularEmiPaise: 560000,
  finalEmiPaise: 560000,
  apr: '40.05%',
);

class _PanPreview extends StatefulWidget {
  const _PanPreview({required this.service});
  final BorrowerService service;
  @override
  State<_PanPreview> createState() => _PanPreviewState();
}

class _PanPreviewState extends State<_PanPreview> {
  final _controller = TextEditingController(text: 'ABCDE0000X');
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PanVerificationScreen(
    service: widget.service,
    accessToken: _session,
    details: _profile.details,
    panController: _controller,
    initialConsent: false,
    onConsentChanged: (_) {},
    profileUnavailable: false,
  );
}

class _Fixtures
    implements BorrowerService, LoanQuoteService, LoanVerificationService {
  const _Fixtures(this.scenario);
  final _Scenario scenario;
  VerificationStatus get status => switch (scenario) {
    _Scenario.ready => VerificationStatus.completed,
    _Scenario.loading => VerificationStatus.pending,
    _Scenario.error => VerificationStatus.failed,
    _Scenario.unavailable => VerificationStatus.unavailable,
  };
  AadhaarResult get aadhaar => AadhaarResult(status, lastFourDigits: '0000');

  Future<T> load<T>(
    T value, {
    Object unavailable = VerificationIssue.unavailable,
  }) async => switch (scenario) {
    _Scenario.ready => value,
    _Scenario.loading => await Future<T>.delayed(
      const Duration(seconds: 8),
      () => throw NetworkException(),
    ),
    _Scenario.error => throw NetworkException(),
    _Scenario.unavailable => throw unavailable,
  };

  Future<FaceVerificationSession> openFace() => load(_SyntheticFaceSession());
  @override
  Future<BorrowerProfile?> loadProfile({required String accessToken}) =>
      load(_profile);
  @override
  Future<void> completeOnboarding({
    required String accessToken,
    required BorrowerDetails details,
    required String pan,
    required bool panConsent,
  }) => load<void>(
    null,
    unavailable: BorrowerServiceUnavailable(
      'Synthetic PAN service unavailable.',
    ),
  );
  @override
  Future<void> updateFinances({
    required String accessToken,
    required BorrowerFinances finances,
  }) => load<void>(
    null,
    unavailable: BorrowerServiceUnavailable(
      'Synthetic profile service unavailable.',
    ),
  );
  @override
  Future<List<LoanAmountOption>> loadOptions({
    required String accessToken,
    required String offerReference,
  }) => load(const [
    LoanAmountOption(
      amountPaise: 3000000,
      plans: [LoanPlan(months: 6, emiPaise: 560000)],
    ),
    LoanAmountOption(
      amountPaise: 5000000,
      plans: [LoanPlan(months: 6, emiPaise: 933300)],
    ),
  ], unavailable: const LoanQuoteUnavailable());
  @override
  Future<LoanQuote> requestQuote({
    required String accessToken,
    required String offerReference,
    required int amountPaise,
    required int months,
  }) => load(
    amountPaise == _smallQuote.principalPaise ? _smallQuote : _quote,
    unavailable: const LoanQuoteUnavailable(),
  );
  @override
  Future<Map<VerificationKind, VerificationCheck>> loadChecklist({
    required String accessToken,
    required String offerReference,
  }) => load(const {
    VerificationKind.pan: VerificationCheck(VerificationStatus.completed),
    VerificationKind.face: VerificationCheck(
      VerificationStatus.pending,
      canStart: true,
    ),
    VerificationKind.aadhaar: VerificationCheck(VerificationStatus.failed),
  });
  @override
  Future<FaceVerificationSession> openFaceSession({
    required String accessToken,
    required String offerReference,
    required bool consent,
  }) => openFace();
}

class _SyntheticFaceSession implements FaceVerificationSession {
  @override
  int? get textureId => null;
  @override
  Future<FaceVerificationResult> captureAndVerify() async =>
      const FaceVerificationResult(status: VerificationStatus.completed);
  @override
  void close() {}
}
