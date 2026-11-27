import 'package:etf_loans/features/eligibility/eligibility_models.dart';

/// In-app integration boundary. A backend adapter must authenticate the
/// borrower, enforce verified PAN and return authoritative assessment data.
abstract interface class EligibilityService {
  Future<EligibilityAssessment> check({
    required String accessToken,
    required EligibilityCheckKind kind,
    required int consentVersion,
    required String idempotencyKey,
    required bool Function() isCancelled,
  });

  Future<void> confirmOffer({
    required String accessToken,
    required EligibilityAssessment assessment,
  });
}

class EligibilityUnavailable implements Exception {
  const EligibilityUnavailable();
}

class EligibilityAssessmentStale implements Exception {
  const EligibilityAssessmentStale();
}

class EligibilityRequestRejected implements Exception {
  const EligibilityRequestRejected(this.message);

  final String message;
}

class UnavailableEligibilityService implements EligibilityService {
  const UnavailableEligibilityService();

  @override
  Future<EligibilityAssessment> check({
    required String accessToken,
    required EligibilityCheckKind kind,
    required int consentVersion,
    required String idempotencyKey,
    required bool Function() isCancelled,
  }) async {
    throw const EligibilityUnavailable();
  }

  @override
  Future<void> confirmOffer({
    required String accessToken,
    required EligibilityAssessment assessment,
  }) async {
    throw const EligibilityUnavailable();
  }
}
