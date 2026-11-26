import 'package:etf_loans/features/onboarding/borrower_form_widgets.dart';
import 'package:etf_loans/shared/widgets/brand_card.dart';
import 'package:etf_loans/shared/widgets/custom_widgets.dart';
import 'package:flutter/material.dart';

class LoanProgress extends StatelessWidget {
  const LoanProgress(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) => BrandCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(liveRegion: true, child: Text(label)),
        if (!MediaQuery.disableAnimationsOf(context)) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
        ],
      ],
    ),
  );
}

class LoanLoadError extends StatelessWidget {
  const LoanLoadError(this.message, {required this.onRetry, super.key});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      BorrowerNotice(message, isError: true),
      const SizedBox(height: 16),
      PrimaryButton(title: 'Retry', onPressed: onRetry),
    ],
  );
}
