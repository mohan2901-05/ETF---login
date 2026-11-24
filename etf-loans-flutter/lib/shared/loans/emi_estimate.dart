enum EmiTenure {
  three(3, 2),
  six(6, 2),
  nine(9, 3),
  twelve(12, 3),
  eighteen(18, 3),
  twentyFour(24, 3);

  const EmiTenure(this.months, this.monthlyFlatRatePercent);

  final int months;
  final int monthlyFlatRatePercent;
}

/// An illustrative flat-rate estimate, independent of borrower eligibility.
class EmiEstimate {
  const EmiEstimate._({
    required this.interestPaise,
    required this.totalPaise,
    required this.regularEmiRupees,
    required this.finalEmiPaise,
  });

  static const minPrincipalRupees = 10000;
  static const maxPrincipalRupees = 500000;
  static const _paisePerRupee = 100;

  final int interestPaise;
  final int totalPaise;
  final int regularEmiRupees;
  final int finalEmiPaise;

  factory EmiEstimate.calculate({
    required int principalRupees,
    required EmiTenure tenure,
  }) {
    RangeError.checkValueInInterval(
      principalRupees,
      minPrincipalRupees,
      maxPrincipalRupees,
      'principalRupees',
    );

    // A whole rupee times a whole percentage gives an exact number of paise.
    final interest =
        principalRupees * tenure.monthlyFlatRatePercent * tenure.months;
    final total = principalRupees * _paisePerRupee + interest;
    final regularEmi = total ~/ (tenure.months * _paisePerRupee);
    return EmiEstimate._(
      interestPaise: interest,
      totalPaise: total,
      regularEmiRupees: regularEmi,
      finalEmiPaise: total - regularEmi * _paisePerRupee * (tenure.months - 1),
    );
  }
}
