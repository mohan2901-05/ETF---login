import 'dart:convert';

import 'package:etf_loans/core/errors/app_errors.dart';
import 'package:etf_loans/core/network/network_service.dart';
import 'package:etf_loans/features/loan_application/api_loan_quote_service.dart';
import 'package:etf_loans/features/loan_application/loan_quote_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const offer = '00000000-0000-4000-8000-000000000001';
  const id = '00000000-0000-4000-8000-000000000002';
  const root = '/api/borrower/loans';
  final quotePayload = {
    'id': id,
    'offerReference': offer,
    'principalPaise': 1000000,
    'months': 3,
    'totalRepaymentPaise': 1060000,
    'interestPaise': 60000,
    'netProceedsPaise': 1000000,
    'regularEmiPaise': 353300,
    'finalEmiPaise': 353400,
    'monthlyFlatRatePercent': 2,
    'expiresAt': '2027-01-31T12:00:00Z',
    'firstDueDate': '2027-02-28',
    'charges': [
      {'label': 'Processing fee', 'amountPaise': 0},
    ],
    'schedule': [
      {
        'number': 1,
        'dueDate': '2027-02-28',
        'amountPaise': 353300,
        'principalPaise': 333301,
        'interestPaise': 19999,
      },
    ],
  };

  test(
    'authenticates options, creates with idempotency and reads fresh terms',
    () async {
      final network = NetworkService(
        client: MockClient((request) async {
          expect(request.headers['authorization'], 'Bearer fixture');
          switch (request.url.path) {
            case '$root/offers/$offer/options':
              expect(request.method, 'GET');
              return http.Response(
                jsonEncode({
                  'options': [
                    {
                      'amountPaise': 1000000,
                      'plans': [
                        {
                          'months': 3,
                          'emiPaise': 353300,
                          'affordabilityNote': 'Limit exceeded',
                        },
                      ],
                    },
                  ],
                }),
                200,
              );
            case '$root/offers/$offer/quotes':
              expect(request.method, 'POST');
              expect(request.headers['idempotency-key'], 'quote-retry');
              expect(jsonDecode(request.body), {
                'amountPaise': 1000000,
                'months': 3,
              });
              return http.Response(jsonEncode(quotePayload), 200);
            case '$root/quotes/$id':
              expect(request.method, 'GET');
              expect(request.headers['cache-control'], 'no-cache, no-store');
              return http.Response(jsonEncode(quotePayload), 200);
            default:
              fail('Unexpected path ${request.url.path}');
          }
        }),
      );
      addTearDown(network.close);
      final service = ApiLoanQuoteService(network);
      final options = await service.loadOptions(
        accessToken: 'fixture',
        offerReference: offer,
      );
      expect(options.single.plans.single.affordabilityNote, 'Limit exceeded');
      final quote = await service.requestQuote(
        accessToken: 'fixture',
        offerReference: offer,
        amountPaise: 1000000,
        months: 3,
        idempotencyKey: 'quote-retry',
      );
      expect(quote.id, id);
      expect(quote.schedule.single.interestPaise, 19999);
      expect(quote.firstDueDate, DateTime(2027, 2, 28));
      expect(quote.finalEmiPaise, 353400);
      expect(quote.keyFacts, isNull);
      expect((await service.getQuote(accessToken: 'fixture', id: id)).id, id);
    },
  );

  test(
    'maps session, stale quote, rejection and unavailable pricing',
    () async {
      for (final (status, error) in [
        (401, isA<InvalidSessionException>()),
        (404, isA<LoanQuoteStale>()),
        (410, isA<LoanQuoteStale>()),
        (422, isA<LoanQuoteRejected>()),
        (503, isA<LoanQuoteUnavailable>()),
      ]) {
        final network = NetworkService(
          client: MockClient((_) async => http.Response('{}', status)),
        );
        addTearDown(network.close);
        await expectLater(
          ApiLoanQuoteService(network).getQuote(accessToken: 'fixture', id: id),
          throwsA(error),
        );
      }
    },
  );
}
