import 'package:etf_loans/core/errors/app_errors.dart';
import 'package:etf_loans/features/loan_application/loan_amount_format.dart';
import 'package:etf_loans/features/loan_application/loan_load_widgets.dart';
import 'package:etf_loans/features/loan_application/loan_quote.dart';
import 'package:etf_loans/features/loan_application/loan_quote_service.dart';
import 'package:etf_loans/features/loan_application/loan_review_screen.dart';
import 'package:etf_loans/features/onboarding/borrower_form_widgets.dart';
import 'package:etf_loans/shared/widgets/brand_card.dart';
import 'package:etf_loans/shared/widgets/custom_widgets.dart';
import 'package:etf_loans/theme/theme_config.dart';
import 'package:etf_loans/features/verification/verification_checklist_screen.dart';
import 'package:etf_loans/features/verification/additional_verification_service.dart';
import 'package:etf_loans/features/verification/verification_service.dart';
import 'package:flutter/material.dart';

/// Opened by the authenticated eligibility handoff, never a public route.
class LoanSelectionScreen extends StatefulWidget {
  const LoanSelectionScreen({
    required this.accessToken,
    required this.offerReference,
    required this.onSessionExpired,
    this.service = const UnavailableLoanQuoteService(),
    this.verificationService = const UnavailableLoanVerificationService(),
    this.additionalVerificationService,
    super.key,
  });

  final String accessToken;
  final String offerReference;
  final VoidCallback onSessionExpired;
  final LoanQuoteService service;
  final LoanVerificationService verificationService;
  final AdditionalVerificationService? additionalVerificationService;

  @override
  State<LoanSelectionScreen> createState() => _LoanSelectionScreenState();
}

class _LoanSelectionScreenState extends State<LoanSelectionScreen> {
  late Future<List<LoanAmountOption>> _options = _loadOptions();
  int? _amountIndex;
  int? _planIndex;
  bool _reviewOpen = false;

  Future<List<LoanAmountOption>> _loadOptions() async {
    if (widget.accessToken.isEmpty || widget.offerReference.trim().isEmpty) {
      throw const LoanQuoteUnavailable();
    }
    try {
      final options = await widget.service.loadOptions(
        accessToken: widget.accessToken,
        offerReference: widget.offerReference,
      );
      return options.where((option) => option.plans.isNotEmpty).toList()
        ..sort((a, b) => a.amountPaise.compareTo(b.amountPaise));
    } on InvalidSessionException {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ModalRoute.isCurrentOf(context) == true)
          widget.onSessionExpired();
      });
      rethrow;
    }
  }

  void _selectAmount(int index) {
    if (_amountIndex == index) return;
    setState(() {
      _amountIndex = index;
      _planIndex = null;
    });
  }

  Future<void> _review(LoanAmountOption option, LoanPlan plan) async {
    if (_reviewOpen) return;
    _reviewOpen = true;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          settings: const RouteSettings(name: '/review'),
          builder: (reviewContext) => LoanReviewScreen(
            onSessionExpired: widget.onSessionExpired,
            openVerification: () async {
              if (ModalRoute.isCurrentOf(reviewContext) != true) return;
              await Navigator.of(reviewContext).push<void>(
                MaterialPageRoute(
                  builder: (_) => VerificationChecklistScreen(
                    accessToken: widget.accessToken,
                    offerReference: widget.offerReference,
                    service: widget.verificationService,
                    additionalService: widget.additionalVerificationService,
                    onSessionExpired: widget.onSessionExpired,
                  ),
                ),
              );
            },
            loadQuote: () => widget.service.requestQuote(
              accessToken: widget.accessToken,
              offerReference: widget.offerReference,
              amountPaise: option.amountPaise,
              months: plan.months,
            ),
          ),
        ),
      );
    } finally {
      _reviewOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) => BorrowerPage(
    title: 'Choose amount and EMI',
    description: 'Select a loan amount and repayment term from your offer.',
    child: FutureBuilder<List<LoanAmountOption>>(
      future: _options,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoanProgress('Loading loan options');
        }
        if (snapshot.error is InvalidSessionException) {
          return const BorrowerNotice('Your session has expired.');
        }
        if (snapshot.error is LoanQuoteUnavailable ||
            snapshot.data?.isEmpty == true) {
          return const BorrowerNotice(
            'Loan options are currently unavailable.',
          );
        }
        if (snapshot.hasError) {
          return LoanLoadError(
            'We couldn’t load your loan options.',
            onRetry: () {
              setState(() => _options = _loadOptions());
            },
          );
        }
        return _selection(context, snapshot.requireData);
      },
    ),
  );

  Widget _selection(BuildContext context, List<LoanAmountOption> options) {
    final typography = Theme.of(context).textTheme;
    final index = _amountIndex ?? 0;
    final option = options[index];
    final planIndex = _planIndex;
    final note = planIndex == null
        ? null
        : option.plans[planIndex].affordabilityNote;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BrandCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Loan amount', style: typography.labelLarge),
              const SizedBox(height: 8),
              DropdownButton<int>(
                isExpanded: true,
                itemHeight: null,
                value: index,
                items: [
                  for (final (index, choice) in options.indexed)
                    DropdownMenuItem(
                      value: index,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(formatLoanAmount(choice.amountPaise)),
                      ),
                    ),
                ],
                onChanged: options.length > 1
                    ? (value) {
                        if (value != null) _selectAmount(value);
                      }
                    : null,
              ),
              if (options.length > 1)
                Semantics(
                  label: 'Loan amount',
                  child: Slider(
                    max: (options.length - 1).toDouble(),
                    divisions: options.length - 1,
                    value: index.toDouble(),
                    semanticFormatterCallback: (value) =>
                        formatLoanAmount(options[value.round()].amountPaise),
                    onChanged: (value) => _selectAmount(value.round()),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text('Repayment term', style: typography.titleMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (index, plan) in option.plans.indexed)
              ChoiceChip(
                label: Text(
                  plan.emiPaise == null
                      ? '${plan.months} months'
                      : '${plan.months} months\n${formatLoanAmount(plan.emiPaise!)} EMI',
                ),
                selected: planIndex == index,
                selectedColor: ThemeConfig.tintGreen,
                onSelected: (selected) =>
                    setState(() => _planIndex = selected ? index : null),
              ),
          ],
        ),
        if (note != null) ...[const SizedBox(height: 12), BorrowerNotice(note)],
        const SizedBox(height: 24),
        PrimaryButton(
          title: 'Review quote',
          enabled: planIndex != null,
          onPressed: () {
            if (planIndex != null) _review(option, option.plans[planIndex]);
          },
        ),
      ],
    );
  }
}
