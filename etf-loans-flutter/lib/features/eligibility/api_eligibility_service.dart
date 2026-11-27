import 'package:etf_loans/core/errors/app_errors.dart';
import 'package:etf_loans/core/network/network_service.dart';
import 'package:etf_loans/features/eligibility/eligibility_models.dart';
import 'package:etf_loans/features/eligibility/eligibility_service.dart';

class ApiEligibilityService implements EligibilityService {
  const ApiEligibilityService(this._network);

  static const _endpoint = '/api/borrower/eligibility/assessments';
  static final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );
  final NetworkService _network;

  @override
  Future<EligibilityAssessment> check({
    required String accessToken,
    required EligibilityCheckKind kind,
    required int consentVersion,
    required String idempotencyKey,
    required bool Function() isCancelled,
  }) async {
    var response = await _network.post(
      _endpoint,
      authToken: accessToken,
      idempotencyKey: idempotencyKey,
      body: {'kind': kind.name, 'consentVersion': consentVersion},
    );
    String? pendingId;
    final elapsed = Stopwatch()..start();

    while (response['statusCode'] == 202) {
      final data = response['data'];
      if (data case {'id': final String id, 'state': 'pending'}
          when _uuid.hasMatch(id) &&
              (pendingId == null || pendingId == id) &&
              response['location'] == '$_endpoint/$id') {
        pendingId = id;
      } else {
        throw const FormatException('Invalid pending assessment.');
      }

      if (elapsed.elapsed >= const Duration(seconds: 25)) {
        throw TimeoutException('The assessment is still pending. Try again.');
      }
      await Future<void>.delayed(const Duration(milliseconds: 750));
      if (isCancelled()) throw StateError('Assessment view closed.');
      response = await _network.get(
        '$_endpoint/$pendingId',
        authToken: accessToken,
      );
    }
    return _completed(response, expectedId: pendingId);
  }

  @override
  Future<void> confirmOffer({
    required String accessToken,
    required EligibilityAssessment assessment,
  }) async {
    final id = assessment.id;
    final reference = assessment.offer?.applicationReference;
    if (id == null || !_uuid.hasMatch(id) || reference == null) {
      throw const EligibilityAssessmentStale();
    }
    final response = await _network.get(
      '$_endpoint/$id',
      authToken: accessToken,
      requireFresh: true,
    );
    final current = _completed(response, expectedId: id);
    if (current.offer?.applicationReference != reference ||
        current.synthetic != assessment.synthetic) {
      throw const EligibilityAssessmentStale();
    }
  }

  static EligibilityAssessment _completed(
    Map<String, dynamic> response, {
    String? expectedId,
  }) {
    switch (response['statusCode']) {
      case 401:
        throw InvalidSessionException();
      case 404:
      case 410:
        throw const EligibilityAssessmentStale();
      case 409:
        throw const EligibilityRequestRejected(
          'Eligibility could not be checked. Confirm your saved details and try again.',
        );
      case 503:
        throw const EligibilityUnavailable();
      case 502:
        throw const EligibilityRequestRejected(
          'The eligibility provider could not complete the check. Try again.',
        );
      case 504:
        throw const EligibilityRequestRejected(
          'The eligibility check timed out. Try again.',
        );
      case 200:
        break;
      default:
        throw const FormatException('Eligibility request failed.');
    }

    final data = response['data'];
    if (data
        case {
          'id': final String id,
          'state': 'completed',
          'decision': final String decisionName,
          'synthetic': final bool synthetic,
          'checkedAt': final String checkedAt,
          'expiresAt': final String expiresAt,
        }
        when _uuid.hasMatch(id) && (expectedId == null || id == expectedId)) {
      final decision = EligibilityDecision.values.byName(decisionName);
      final scoreData = data['creditScore'] as Map?;
      final offerData = data['offer'] as Map?;
      final checked = DateTime.parse(checkedAt);
      if (!DateTime.parse(expiresAt).isAfter(checked)) {
        throw const FormatException('Invalid assessment expiry.');
      }
      final reference = offerData?['applicationReference'] as String?;
      if (reference != null && !_uuid.hasMatch(reference)) {
        throw const FormatException('Invalid offer reference.');
      }
      return EligibilityAssessment(
        id: id,
        decision: decision,
        checkedAt: checked,
        synthetic: synthetic,
        creditScore: scoreData == null
            ? null
            : CreditScore(
                value: scoreData['value'] as int,
                band: scoreData['band'] as String?,
                source: scoreData['source'] as String?,
                factors: [
                  for (final factor in scoreData['factors'] as List? ?? [])
                    CreditScoreFactor(
                      label: factor['label'] as String,
                      description: factor['description'] as String,
                    ),
                ],
              ),
        offer: decision == EligibilityDecision.eligible && offerData != null
            ? LoanOfferSummary(
                approvedLimitPaise: offerData['approvedLimitPaise'] as int?,
                affordableMonthlyEmiPaise:
                    offerData['affordableMonthlyEmiPaise'] as int?,
                applicationReference: reference,
              )
            : null,
      );
    }
    throw const FormatException('Invalid completed assessment.');
  }
}
