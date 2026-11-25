import 'package:etf_loans/features/onboarding/borrower_form_widgets.dart';
import 'package:etf_loans/shared/widgets/brand_card.dart';
import 'package:etf_loans/shared/widgets/custom_widgets.dart';
import 'package:etf_loans/theme/theme_config.dart';
import 'package:flutter/material.dart';

enum EligibilityCheckState { loading, unavailable, failed }

class CheckingEligibilityScreen extends StatelessWidget {
  const CheckingEligibilityScreen({
    required this.state,
    required this.onUpdateDetails,
    required this.onRetry,
    super.key,
  });

  final EligibilityCheckState state;
  final VoidCallback onUpdateDetails;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final (title, description) = switch (state) {
      EligibilityCheckState.loading => (
        'Checking your eligibility',
        'We’re waiting for your eligibility assessment.',
      ),
      EligibilityCheckState.unavailable => (
        'Eligibility check unavailable',
        'You can return to your details while the service is unavailable.',
      ),
      EligibilityCheckState.failed => (
        'Eligibility check interrupted',
        'You can retry using the details you already saved.',
      ),
    };

    return BorrowerPage(
      title: title,
      description: description,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          switch (state) {
            EligibilityCheckState.loading => BrandCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      'Assessment in progress',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  if (!MediaQuery.disableAnimationsOf(context)) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(
                      color: ThemeConfig.primaryGreen,
                      backgroundColor: ThemeConfig.tintGreen,
                      semanticsLabel: 'Checking eligibility',
                    ),
                  ],
                ],
              ),
            ),
            EligibilityCheckState.unavailable => const BorrowerNotice(
              'The eligibility service is currently unavailable.',
            ),
            EligibilityCheckState.failed => const BorrowerNotice(
              'We couldn’t complete your eligibility check.',
              isError: true,
            ),
          },
          if (state == EligibilityCheckState.failed) ...[
            const SizedBox(height: 24),
            PrimaryButton(title: 'Retry check', onPressed: onRetry),
          ],
          if (state != EligibilityCheckState.loading) ...[
            const SizedBox(height: 12),
            OutlineButton(title: 'Update details', onPressed: onUpdateDetails),
          ],
        ],
      ),
    );
  }
}
