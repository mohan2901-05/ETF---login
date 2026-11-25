import 'package:etf_loans/features/eligibility/eligibility_models.dart';

/// In-app integration boundary. A backend adapter must authenticate the
/// borrower, enforce verified PAN and return authoritative assessment data.
abstract interface class EligibilityService {
  Future<EligibilityAssessment> check({
    required String accessToken,
    required EligibilityCheckKind kind,
  });
}

class EligibilityUnavailable implements Exception {
  const EligibilityUnavailable();
}

class UnavailableEligibilityService implements EligibilityService {
  const UnavailableEligibilityService();

  @override
  Future<EligibilityAssessment> check({
    required String accessToken,
    required EligibilityCheckKind kind,
  }) async {
    throw const EligibilityUnavailable();
  }
}
