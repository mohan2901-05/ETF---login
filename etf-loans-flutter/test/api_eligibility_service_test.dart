import 'dart:convert';

import 'package:etf_loans/core/errors/app_errors.dart';
import 'package:etf_loans/core/network/network_service.dart';
import 'package:etf_loans/features/eligibility/api_eligibility_service.dart';
import 'package:etf_loans/features/eligibility/eligibility_models.dart';
import 'package:etf_loans/features/eligibility/eligibility_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _id = 'e2baf942-c98d-4743-925b-ceb042b04acd';
const _reference = '36469ebc-f43c-485e-91bd-783f8e94408c';
const _path = '/api/borrower/eligibility/assessments';

void main() {
  test(
    'posts consent, polls the owned location, and revalidates an offer',
    () async {
      var requests = 0;
      final service = ApiEligibilityService(
        NetworkService(
          client: MockClient((request) async {
            requests++;
            expect(request.headers['Authorization'], 'Bearer test-session');
            if (request.method == 'POST') {
              expect(request.url.path, _path);
              expect(request.headers['Idempotency-Key'], 'test-assessment-key');
              expect(jsonDecode(request.body), {
                'kind': 'recheck',
                'consentVersion': 1,
              });
              return _response(202, {
                'id': _id,
                'state': 'pending',
              }, location: '$_path/$_id');
            }
            expect(request.method, 'GET');
            expect(request.url.path, '$_path/$_id');
            if (requests == 3) {
              expect(request.headers['Cache-Control'], 'no-cache, no-store');
            }
            return requests == 2
                ? _response(200, _eligible)
                : _response(410, {});
          }),
        ),
      );

      final result = await _check(service);
      expect(result.decision, EligibilityDecision.eligible);
      expect(result.synthetic, isTrue);
      expect(result.creditScore?.factors.single.label, 'Example factor');
      expect(result.offer?.approvedLimitPaise, 14100025);
      expect(result.offer?.applicationReference, _reference);
      await expectLater(
        service.confirmOffer(accessToken: 'test-session', assessment: result),
        throwsA(isA<EligibilityAssessmentStale>()),
      );
      expect(requests, 3);
    },
  );

  test(
    'rejects a Location outside the assessment path without polling',
    () async {
      var requests = 0;
      final service = ApiEligibilityService(
        NetworkService(
          client: MockClient((_) async {
            requests++;
            return _response(202, {
              'id': _id,
              'state': 'pending',
            }, location: 'https://example.test/$_id');
          }),
        ),
      );
      await expectLater(_check(service), throwsFormatException);
      expect(requests, 1);
    },
  );

  test('distinguishes unsuccessful assessment and session outcomes', () async {
    for (final (status, matcher) in [
      (
        502,
        isA<EligibilityRequestRejected>().having(
          (e) => e.message,
          'message',
          contains('provider'),
        ),
      ),
      (
        504,
        isA<EligibilityRequestRejected>().having(
          (e) => e.message,
          'message',
          contains('timed out'),
        ),
      ),
      (503, isA<EligibilityUnavailable>()),
      (401, isA<InvalidSessionException>()),
    ]) {
      final service = ApiEligibilityService(
        NetworkService(client: MockClient((_) async => _response(status, {}))),
      );
      await expectLater(_check(service), throwsA(matcher));
    }
  });
}

Future<EligibilityAssessment> _check(ApiEligibilityService service) =>
    service.check(
      accessToken: 'test-session',
      kind: EligibilityCheckKind.recheck,
      consentVersion: 1,
      idempotencyKey: 'test-assessment-key',
      isCancelled: () => false,
    );

http.Response _response(
  int status,
  Map<String, Object?> body, {
  String? location,
}) => http.Response(
  jsonEncode(body),
  status,
  headers: {
    'Content-Type': 'application/json',
    if (location != null) 'Location': location,
  },
);

const _eligible = {
  'id': _id,
  'state': 'completed',
  'synthetic': true,
  'decision': 'eligible',
  'checkedAt': '2026-11-26T00:00:00Z',
  'expiresAt': '2026-11-27T00:00:00Z',
  'creditScore': {
    'value': 699,
    'source': 'Synthetic development data',
    'factors': [
      {'label': 'Example factor', 'description': 'Synthetic test data.'},
    ],
  },
  'offer': {
    'approvedLimitPaise': 14100025,
    'affordableMonthlyEmiPaise': 1600000,
    'applicationReference': _reference,
  },
};
