import 'dart:async';

import 'package:etf_loans/core/errors/app_errors.dart';
import 'package:etf_loans/features/loan_application/loan_quote.dart';
import 'package:etf_loans/features/loan_application/loan_quote_service.dart';
import 'package:etf_loans/features/loan_application/loan_selection_screen.dart';
import 'package:etf_loans/theme/theme_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('blank offer does not request loan options', (tester) async {
    final service = _SyntheticService();
    await _open(tester, service, reference: ' ');
    await tester.pumpAndSettle();
    expect(service.loads, 0);
    expect(
      find.text('Loan options are currently unavailable.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'review retries and displays quoted terms, schedule and documents',
    (tester) async {
      final service = _SyntheticService();
      await _open(tester, service);
      await tester.pumpAndSettle();
      await _tap(tester, '6 months');
      await tester.tap(find.text('Review quote'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Loading your loan quote'), findsOneWidget);
      service.quote.completeError(NetworkException());
      await tester.pumpAndSettle();
      expect(find.text('We couldn’t load your loan quote.'), findsOneWidget);
      service.quote = Completer<LoanQuote>()..complete(_syntheticQuote);
      await _tap(tester, 'Retry');
      expect(service.selection, (5000000, 6));
      expect(find.text('40.05%'), findsOneWidget);
      expect(find.text('₹56,000'), findsOneWidget);

      await _tap(tester, 'Verification checklist');
      expect(
        find.text('Verification services are currently unavailable.'),
        findsOneWidget,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();

      for (final (action, result) in [
        ('View repayment schedule', 'Installment 6'),
        ('Loan agreement', 'Version synthetic-agreement-v1'),
        ('Key Facts Statement', 'Version synthetic-kfs-v1'),
      ]) {
        await _tap(tester, action);
        expect(find.text(result), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
      await _tap(
        tester,
        'I have read the loan agreement and Key Facts Statement.',
      );
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue,
      );
      final accept = find.ancestor(
        of: find.text('Accept loan'),
        matching: find.byType(ElevatedButton),
      );
      expect(tester.widget<ElevatedButton>(accept).onPressed, isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        tester.widget<ChoiceChip>(find.byType(ChoiceChip)).selected,
        isTrue,
      );
    },
  );

  testWidgets('unavailable quote shows no terms or consent', (tester) async {
    final service = _SyntheticService();
    await _open(tester, service);
    await tester.pumpAndSettle();
    await _tap(tester, '6 months');
    await tester.tap(find.text('Review quote'));
    await tester.pump();
    service.quote.completeError(const LoanQuoteUnavailable());
    await tester.pumpAndSettle();
    expect(
      find.text('Your loan quote is currently unavailable.'),
      findsOneWidget,
    );
    expect(find.byType(CheckboxListTile), findsNothing);
  });
}

// Synthetic values and documents used only by these widget tests.
final _syntheticQuote = LoanQuote(
  principalPaise: 5000000,
  months: 6,
  totalRepaymentPaise: 5600000,
  interestPaise: 600000,
  netProceedsPaise: 5000000,
  regularEmiPaise: 933300,
  finalEmiPaise: 933500,
  apr: '40.05%',
  schedule: [
    LoanInstallment(
      number: 6,
      dueDate: DateTime(2027, 7, 5),
      amountPaise: 933500,
    ),
  ],
  agreement: const LoanDisclosure(
    version: 'synthetic-agreement-v1',
    text: 'Synthetic test agreement placeholder.',
  ),
  keyFacts: const LoanDisclosure(
    version: 'synthetic-kfs-v1',
    text: 'Synthetic test KFS placeholder.',
  ),
);

class _SyntheticService implements LoanQuoteService {
  int loads = 0;
  var quote = Completer<LoanQuote>();
  (int, int)? selection;

  @override
  Future<List<LoanAmountOption>> loadOptions({
    required String accessToken,
    required String offerReference,
  }) async {
    loads++;
    expect(offerReference, 'synthetic-offer');
    return const [
      LoanAmountOption(amountPaise: 5000000, plans: [LoanPlan(months: 6)]),
    ];
  }

  @override
  Future<LoanQuote> requestQuote({
    required String accessToken,
    required String offerReference,
    required int amountPaise,
    required int months,
  }) {
    expect(accessToken, 'synthetic-session');
    expect(offerReference, 'synthetic-offer');
    selection = (amountPaise, months);
    return quote.future;
  }
}

Future<void> _open(
  WidgetTester tester,
  LoanQuoteService service, {
  String reference = 'synthetic-offer',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeConfig.lightTheme,
      home: LoanSelectionScreen(
        accessToken: 'synthetic-session',
        offerReference: reference,
        service: service,
        onSessionExpired: () {},
      ),
    ),
  );
}

Future<void> _tap(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
