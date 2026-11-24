import 'package:etf_loans/shared/loans/emi_estimate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('matches the documented six-month example', () {
    final estimate = EmiEstimate.calculate(
      principalRupees: 50000,
      tenure: EmiTenure.six,
    );
    expect(estimate.interestPaise, 600000);
    expect(estimate.regularEmiRupees, 9333);
    expect(estimate.finalEmiPaise, 933500);
    expect(estimate.totalPaise, 5600000);
  });

  test('applies each supported rate and reconciles all instalments', () {
    const expectedInterest = [60000, 120000, 270000, 360000, 540000, 720000];
    for (final (index, tenure) in EmiTenure.values.indexed) {
      final estimate = EmiEstimate.calculate(
        principalRupees: EmiEstimate.minPrincipalRupees,
        tenure: tenure,
      );
      expect(estimate.interestPaise, expectedInterest[index]);
      expect(
        estimate.regularEmiRupees * 100 * (tenure.months - 1) +
            estimate.finalEmiPaise,
        estimate.totalPaise,
      );
    }
  });

  test('floors the regular EMI and preserves paise in the final EMI', () {
    final estimate = EmiEstimate.calculate(
      principalRupees: 10001,
      tenure: EmiTenure.three,
    );
    expect(estimate.interestPaise, 60006);
    expect(estimate.regularEmiRupees, 3533);
    expect(estimate.finalEmiPaise, 353506);
  });

  test('enforces the public estimate bounds', () {
    expect(
      EmiEstimate.calculate(
        principalRupees: EmiEstimate.maxPrincipalRupees,
        tenure: EmiTenure.twentyFour,
      ).totalPaise,
      86000000,
    );
    for (final amount in [9999, 500001]) {
      expect(
        () => EmiEstimate.calculate(
          principalRupees: amount,
          tenure: EmiTenure.six,
        ),
        throwsRangeError,
      );
    }
  });
}
