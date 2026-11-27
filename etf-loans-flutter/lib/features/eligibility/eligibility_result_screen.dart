import 'package:etf_loans/features/eligibility/eligibility_models.dart';
import 'package:etf_loans/features/onboarding/borrower_form_widgets.dart';
import 'package:etf_loans/shared/widgets/brand_card.dart';
import 'package:etf_loans/shared/widgets/custom_widgets.dart';
import 'package:etf_loans/theme/theme_config.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EligibilityResultScreen extends StatelessWidget {
  const EligibilityResultScreen({
    required this.assessment,
    required this.onUpdateDetails,
    this.borrowerName,
    this.onLoanApplicationRequested,
    super.key,
  });

  final EligibilityAssessment assessment;
  final String? borrowerName;
  final VoidCallback onUpdateDetails;
  final ValueChanged<String>? onLoanApplicationRequested;

  @override
  Widget build(BuildContext context) {
    final name = borrowerName?.trim() ?? '';
    final score = assessment.creditScore;
    final eligible = assessment.decision == EligibilityDecision.eligible;
    final offer = eligible ? assessment.offer : null;
    final applicationReference = offer?.applicationReference;
    final chooseLoan = onLoanApplicationRequested;
    final canChooseLoan =
        chooseLoan != null &&
        applicationReference != null &&
        applicationReference.trim().isNotEmpty;

    return BorrowerPage(
      title: 'Your eligibility result',
      description: name.isEmpty
          ? 'Review your latest eligibility assessment.'
          : '$name, here’s your latest eligibility assessment.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (assessment.synthetic) ...[
            const BorrowerNotice('Synthetic development result'),
            const SizedBox(height: 18),
          ],
          _CreditScoreCard(score: score, checkedAt: assessment.checkedAt),
          const SizedBox(height: 18),
          if (eligible)
            _LoanOfferCard(offer: offer)
          else
            const BorrowerNotice('You’re currently ineligible for a loan.'),
          if (score != null && score.factors.isNotEmpty) ...[
            const SizedBox(height: 18),
            _ScoreFactorsCard(factors: score.factors),
          ],
          const SizedBox(height: 24),
          if (eligible) ...[
            if (!canChooseLoan) ...[
              Text(
                'Loan selection is currently unavailable.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
            ],
            PrimaryButton(
              title: 'Choose loan amount',
              enabled: canChooseLoan,
              onPressed: () {
                if (canChooseLoan) chooseLoan(applicationReference);
              },
            ),
            const SizedBox(height: 12),
          ],
          OutlineButton(title: 'Update details', onPressed: onUpdateDetails),
        ],
      ),
    );
  }
}

class _CreditScoreCard extends StatelessWidget {
  const _CreditScoreCard({required this.score, required this.checkedAt});

  static const _minimum = 300;
  static const _maximum = 900;

  final CreditScore? score;
  final DateTime? checkedAt;

  @override
  Widget build(BuildContext context) {
    final typography = Theme.of(context).textTheme;
    final value = score?.value;
    final band = score?.band?.trim();
    final source = score?.source?.trim();
    final date = checkedAt;
    return BrandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Credit score', style: typography.labelLarge),
          const SizedBox(height: 8),
          if (value == null)
            Text('Credit score unavailable', style: typography.bodyMedium)
          else
            Text('$value', style: typography.displayLarge),
          if (band != null && band.isNotEmpty)
            Text(band, style: typography.labelLarge),
          if (value != null && value >= _minimum && value <= _maximum) ...[
            const SizedBox(height: 16),
            ExcludeSemantics(
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: (value - _minimum) / (_maximum - _minimum),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(ThemeConfig.radiusPill),
                    color: ThemeConfig.primaryGreen,
                    backgroundColor: ThemeConfig.tintGreen,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('$_minimum', style: typography.labelMedium),
                      Text('$_maximum', style: typography.labelMedium),
                    ],
                  ),
                ],
              ),
            ),
          ],
          if (source != null && source.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Source: $source', style: typography.bodyMedium),
          ],
          if (date != null) ...[
            const SizedBox(height: 4),
            Text(
              'Checked ${MaterialLocalizations.of(context).formatCompactDate(date.toLocal())}',
              style: typography.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

class _LoanOfferCard extends StatelessWidget {
  const _LoanOfferCard({required this.offer});

  static final _rupeeGroups = NumberFormat.decimalPattern('en_IN');

  final LoanOfferSummary? offer;

  String _amount(int paise) {
    final rupees = _rupeeGroups.format(paise ~/ 100);
    final remainder = paise % 100;
    return remainder == 0
        ? '₹$rupees'
        : '₹$rupees.${'$remainder'.padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final typography = Theme.of(context).textTheme;
    final limit = offer?.approvedLimitPaise;
    final monthlyEmi = offer?.affordableMonthlyEmiPaise;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: ThemeConfig.heroGradientMobile,
        borderRadius: BorderRadius.circular(ThemeConfig.radiusLarge),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'You’re eligible for a loan',
              style: typography.labelLarge?.copyWith(color: ThemeConfig.onDeep),
            ),
            const SizedBox(height: 12),
            if (limit != null && limit >= 0) ...[
              Text(
                'Approved limit',
                style: typography.bodyMedium?.copyWith(
                  color: ThemeConfig.onDeepMuted,
                ),
              ),
              Text(
                _amount(limit),
                style: typography.displayMedium?.copyWith(
                  color: ThemeConfig.onDeep,
                ),
              ),
            ],
            if (monthlyEmi != null && monthlyEmi >= 0) ...[
              const SizedBox(height: 8),
              Text(
                'Affordable monthly EMI',
                style: typography.bodyMedium?.copyWith(
                  color: ThemeConfig.onDeepMuted,
                ),
              ),
              Text(
                _amount(monthlyEmi),
                style: typography.labelLarge?.copyWith(
                  color: ThemeConfig.onDeep,
                ),
              ),
            ],
            if ((limit == null || limit < 0) &&
                (monthlyEmi == null || monthlyEmi < 0))
              Text(
                'Loan offer details are unavailable.',
                style: typography.bodyMedium?.copyWith(
                  color: ThemeConfig.onDeepMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ScoreFactorsCard extends StatelessWidget {
  const _ScoreFactorsCard({required this.factors});

  final List<CreditScoreFactor> factors;

  @override
  Widget build(BuildContext context) {
    final typography = Theme.of(context).textTheme;
    return BrandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              'What affects your score',
              style: typography.titleMedium,
            ),
          ),
          for (final factor in factors) ...[
            const SizedBox(height: 12),
            Text(factor.label, style: typography.labelLarge),
            Text(factor.description, style: typography.bodyMedium),
          ],
        ],
      ),
    );
  }
}
