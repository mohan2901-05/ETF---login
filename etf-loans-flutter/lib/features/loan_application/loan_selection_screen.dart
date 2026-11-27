import 'package:etf_loans/core/errors/app_errors.dart';
import 'package:etf_loans/features/eligibility/eligibility_service.dart';
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

enum LoanSelectionExit { staleOffer }

/// Opened by the authenticated eligibility handoff, never a public route.
class LoanSelectionScreen extends StatefulWidget {
  const LoanSelectionScreen({
    required this.accessToken,
    required this.offerReference,
    required this.onSessionExpired,
    this.service = const UnavailableLoanQuoteService(),
    this.verificationService = const UnavailableLoanVerificationService(),
    this.additionalVerificationService,
    this.syntheticOffer = false,
    this.revalidateOffer,
    super.key,
  });

  final String accessToken;
  final String offerReference;
  final VoidCallback onSessionExpired;
  final LoanQuoteService service;
  final LoanVerificationService verificationService;
  final AdditionalVerificationService? additionalVerificationService;
  final bool syntheticOffer;
  final Future<void> Function()? revalidateOffer;

  @override
  State<LoanSelectionScreen> createState() => _LoanSelectionScreenState();
}

class _LoanSelectionScreenState extends State<LoanSelectionScreen> {
  late Future<List<LoanAmountOption>> _options = _loadOptions();
  int? _amountPaise;
  int? _months;
  bool _reviewOpen = false;
  bool _validatingOffer = false;
  bool _offerCheckFailed = false;
  AppLifecycleListener? _offerLifecycle;

  @override
  void initState() {
    super.initState();
    if (widget.revalidateOffer != null) {
      _offerLifecycle = AppLifecycleListener(onResume: _verifyCurrentOffer);
    }
  }

  Future<void> _verifyCurrentOffer() async {
    final verify = widget.revalidateOffer;
    if (verify == null ||
        _validatingOffer ||
        ModalRoute.isCurrentOf(context) != true) {
      return;
    }
    setState(() {
      _validatingOffer = true;
      _offerCheckFailed = false;
    });
    try {
      await verify();
    } on EligibilityAssessmentStale {
      if (mounted && ModalRoute.isCurrentOf(context) == true) {
        Navigator.of(context).pop(LoanSelectionExit.staleOffer);
      }
    } on InvalidSessionException {
      if (mounted) widget.onSessionExpired();
    } catch (_) {
      _offerCheckFailed = true;
    } finally {
      if (mounted) setState(() => _validatingOffer = false);
    }
  }

  @override
  void dispose() {
    _offerLifecycle?.dispose();
    super.dispose();
  }

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
    } on LoanQuoteStale {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ModalRoute.isCurrentOf(context) == true) {
          Navigator.of(context).pop(LoanSelectionExit.staleOffer);
        }
      });
      rethrow;
    } on InvalidSessionException {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ModalRoute.isCurrentOf(context) == true)
          widget.onSessionExpired();
      });
      rethrow;
    }
  }

  void _selectAmount(int amountPaise) {
    if (_amountPaise == amountPaise) return;
    setState(() {
      _amountPaise = amountPaise;
      _months = null;
    });
  }

  Future<void> _review(LoanAmountOption option, LoanPlan plan) async {
    if (_reviewOpen) return;
    _reviewOpen = true;
    final service = widget.service;
    String? key;
    String? quoteId;
    Future<LoanQuote> load() async {
      if (service is PersistedLoanQuoteService) {
        if (quoteId case final id?) {
          return service.getQuote(accessToken: widget.accessToken, id: id);
        }
        final quote = await service.requestQuote(
          accessToken: widget.accessToken,
          offerReference: widget.offerReference,
          amountPaise: option.amountPaise,
          months: plan.months,
          idempotencyKey: key ??= newLoanQuoteKey(),
        );
        quoteId = quote.id;
        return quote;
      }
      return service.requestQuote(
        accessToken: widget.accessToken,
        offerReference: widget.offerReference,
        amountPaise: option.amountPaise,
        months: plan.months,
      );
    }

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
            loadQuote: load,
            revalidateQuote: service is PersistedLoanQuoteService ? load : null,
            renewQuote: service is PersistedLoanQuoteService
                ? () {
                    key = null;
                    quoteId = null;
                    return load();
                  }
                : null,
          ),
        ),
      );
      if (mounted && service is PersistedLoanQuoteService) {
        await _verifyCurrentOffer();
      }
    } finally {
      _reviewOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) => BorrowerPage(
    title: 'Choose amount and EMI',
    description: widget.syntheticOffer
        ? 'Synthetic development offer'
        : 'Select a loan amount and repayment term from your offer.',
    child: _validatingOffer
        ? const LoanProgress('Checking your offer')
        : _offerCheckFailed
        ? LoanLoadError(
            'We couldn’t check your offer.',
            onRetry: _verifyCurrentOffer,
          )
        : FutureBuilder<List<LoanAmountOption>>(
            future: _options,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LoanProgress('Loading loan options');
              }
              if (snapshot.error is InvalidSessionException) {
                return const BorrowerNotice('Your session has expired.');
              }
              if (snapshot.error is LoanQuoteStale) {
                return const BorrowerNotice('This offer is no longer current.');
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
    final selectedAmount = options.indexWhere(
      (option) => option.amountPaise == _amountPaise,
    );
    final index = selectedAmount < 0 ? 0 : selectedAmount;
    final option = options[index];
    final selectedPlan = option.plans.indexWhere(
      (plan) => plan.months == _months,
    );
    final planIndex = selectedPlan < 0 ? null : selectedPlan;
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
                style: typography.titleMedium,
                selectedItemBuilder: (context) => [
                  for (final choice in options)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        formatLoanAmount(choice.amountPaise),
                        style: typography.displayMedium,
                      ),
                    ),
                ],
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
                        if (value != null)
                          _selectAmount(options[value].amountPaise);
                      }
                    : null,
              ),
              if (options.length > 1)
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 5,
                    activeTrackColor: ThemeConfig.primaryGreen,
                    inactiveTrackColor: ThemeConfig.ruleStrong,
                    thumbColor: ThemeConfig.primaryGreenMid,
                    overlayColor: ThemeConfig.tintGreen,
                    tickMarkShape: const RoundSliderTickMarkShape(
                      tickMarkRadius: 0,
                    ),
                  ),
                  child: Semantics(
                    label: 'Loan amount',
                    child: Slider(
                      max: (options.length - 1).toDouble(),
                      divisions: options.length - 1,
                      value: index.toDouble(),
                      semanticFormatterCallback: (value) =>
                          formatLoanAmount(options[value.round()].amountPaise),
                      onChanged: (value) =>
                          _selectAmount(options[value.round()].amountPaise),
                    ),
                  ),
                ),
              if (options.length > 1)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        formatLoanAmount(options.first.amountPaise),
                        style: typography.bodySmall,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        formatLoanAmount(options.last.amountPaise),
                        style: typography.bodySmall,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text('Repayment term', style: typography.titleMedium),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 8.0;
            final minWidth =
                MediaQuery.textScalerOf(context).scale(14) * 6.8 + 12;
            final columns = ((constraints.maxWidth + gap) / (minWidth + gap))
                .floor()
                .clamp(1, 3);
            final width =
                (constraints.maxWidth - (columns - 1) * gap) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final (index, plan) in option.plans.indexed)
                  SizedBox(
                    width: width,
                    child: ChoiceChip(
                      label: SizedBox(
                        width: double.infinity,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 4,
                          children: [
                            Text(
                              '${plan.months} months',
                              textAlign: TextAlign.center,
                              style: typography.labelLarge,
                            ),
                            if (plan.emiPaise case final emi?)
                              Text(
                                '${formatLoanAmount(emi)} EMI',
                                textAlign: TextAlign.center,
                                style: typography.bodySmall,
                              ),
                          ],
                        ),
                      ),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 10,
                      ),
                      selected: planIndex == index,
                      showCheckmark: false,
                      backgroundColor: ThemeConfig.cardBg,
                      selectedColor: ThemeConfig.tintGreen,
                      side: BorderSide(
                        color: planIndex == index
                            ? ThemeConfig.primaryGreenMid
                            : ThemeConfig.ruleStrong,
                        width: planIndex == index ? 2 : 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          ThemeConfig.radiusBase,
                        ),
                      ),
                      onSelected: (selected) => setState(
                        () => _months = selected ? plan.months : null,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        if (note != null) ...[const SizedBox(height: 12), BorrowerNotice(note)],
        const SizedBox(height: 24),
        PrimaryButton(
          title: 'Review quote',
          enabled: planIndex != null && note == null,
          onPressed: () {
            if (planIndex != null && note == null)
              _review(option, option.plans[planIndex]);
          },
        ),
      ],
    );
  }
}
