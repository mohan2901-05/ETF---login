enum EligibilityCheckKind { initial, recheck }

enum EligibilityDecision { eligible, ineligible }

class CreditScore {
  const CreditScore({
    required this.value,
    this.band,
    this.source,
    this.factors = const [],
  });

  final int value;
  final String? band;
  final String? source;
  final List<CreditScoreFactor> factors;
}

class CreditScoreFactor {
  const CreditScoreFactor({required this.label, required this.description});

  final String label;
  final String description;
}

class LoanOfferSummary {
  const LoanOfferSummary({
    this.approvedLimitPaise,
    this.affordableMonthlyEmiPaise,
    this.applicationReference,
  });

  final int? approvedLimitPaise;
  final int? affordableMonthlyEmiPaise;

  /// An opaque reference returned by the service for the next phase, if any.
  final String? applicationReference;
}

class EligibilityAssessment {
  const EligibilityAssessment({
    required this.decision,
    this.id,
    this.synthetic = false,
    this.creditScore,
    this.checkedAt,
    this.offer,
  });

  final EligibilityDecision decision;
  final String? id;
  final bool synthetic;
  final CreditScore? creditScore;
  final DateTime? checkedAt;
  final LoanOfferSummary? offer;
}
