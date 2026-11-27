import 'dart:async';

import 'package:etf_loans/core/errors/app_errors.dart';
import 'package:etf_loans/features/loan_application/loan_amount_format.dart';
import 'package:etf_loans/features/loan_application/loan_quote.dart';
import 'package:etf_loans/features/loan_application/loan_quote_service.dart';
import 'package:etf_loans/features/loan_application/loan_load_widgets.dart';
import 'package:etf_loans/features/onboarding/borrower_form_widgets.dart';
import 'package:etf_loans/shared/widgets/brand_card.dart';
import 'package:etf_loans/shared/widgets/custom_widgets.dart';
import 'package:etf_loans/theme/theme_config.dart';
import 'package:flutter/material.dart';

class LoanReviewScreen extends StatefulWidget {
  const LoanReviewScreen({
    required this.loadQuote,
    required this.onSessionExpired,
    this.openVerification,
    this.revalidateQuote,
    this.renewQuote,
    super.key,
  });

  final Future<LoanQuote> Function() loadQuote;
  final VoidCallback onSessionExpired;
  final VoidCallback? openVerification;
  final Future<LoanQuote> Function()? revalidateQuote;
  final Future<LoanQuote> Function()? renewQuote;

  @override
  State<LoanReviewScreen> createState() => _LoanReviewScreenState();
}

class _LoanReviewScreenState extends State<LoanReviewScreen> {
  late Future<LoanQuote> _quote = _loadQuote();
  AppLifecycleListener? _lifecycle;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.revalidateQuote != null) {
      _lifecycle = AppLifecycleListener(
        onResume: () {
          if (ModalRoute.isCurrentOf(context) == true) _refresh();
        },
      );
    }
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  Future<LoanQuote> _loadQuote([Future<LoanQuote> Function()? load]) async {
    _loading = true;
    try {
      return await (load ?? widget.loadQuote)();
    } on InvalidSessionException {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ModalRoute.isCurrentOf(context) == true)
          widget.onSessionExpired();
      });
      rethrow;
    } finally {
      _loading = false;
    }
  }

  void _refresh() {
    if (!_loading) {
      final next = _loadQuote();
      setState(() {
        _quote = next;
      });
    }
  }

  void _renew() {
    if (!_loading) {
      final next = _loadQuote(widget.renewQuote);
      setState(() {
        _quote = next;
      });
    }
  }

  Future<void> _schedule(LoanQuote quote) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RepaymentScheduleScreen(
          installments: quote.schedule,
          loadCurrentQuote: widget.revalidateQuote,
          onSessionExpired: widget.onSessionExpired,
        ),
      ),
    );
    if (mounted && widget.revalidateQuote != null) _refresh();
  }

  @override
  Widget build(BuildContext context) => BorrowerPage(
    title: 'Review your loan',
    description: 'Check the quoted cost, repayment dates and documents.',
    child: FutureBuilder<LoanQuote>(
      future: _quote,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const LoanProgress('Loading your loan quote');
        if (snapshot.error is InvalidSessionException)
          return const BorrowerNotice('Your session has expired.');
        if (snapshot.error is LoanQuoteUnavailable)
          return const BorrowerNotice(
            'Your loan quote is currently unavailable.',
          );
        if (snapshot.error is LoanQuoteStale)
          return LoanLoadError(
            'This quote or offer has expired, or your borrower details changed.',
            onRetry: _renew,
          );
        if (snapshot.error is LoanQuoteRejected)
          return const BorrowerNotice(
            'This selection is unavailable. Go back and choose another amount or term.',
          );
        if (snapshot.hasError)
          return LoanLoadError(
            'We couldn’t load your loan quote.',
            onRetry: _refresh,
          );
        return _QuoteDetails(
          quote: snapshot.requireData,
          onRefresh: _renew,
          openSchedule: () => _schedule(snapshot.requireData),
          openVerification: widget.openVerification,
        );
      },
    ),
  );
}

class _QuoteDetails extends StatefulWidget {
  const _QuoteDetails({
    required this.quote,
    required this.onRefresh,
    required this.openVerification,
    required this.openSchedule,
  });

  final LoanQuote quote;
  final VoidCallback onRefresh;
  final VoidCallback? openVerification;
  final VoidCallback openSchedule;

  @override
  State<_QuoteDetails> createState() => _QuoteDetailsState();
}

class _QuoteDetailsState extends State<_QuoteDetails> {
  bool _consent = false;
  Timer? _expiryTimer;

  @override
  void initState() {
    super.initState();
    final expiry = widget.quote.expiresAt;
    if (expiry != null) {
      final remaining = expiry.difference(DateTime.now());
      if (remaining > Duration.zero) {
        _expiryTimer = Timer(remaining, () => setState(() => _consent = false));
      }
    }
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }

  void _open(Widget page) =>
      Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final quote = widget.quote;
    final expiry = quote.expiresAt;
    final expired = expiry != null && !expiry.isAfter(DateTime.now());
    final openVerification = widget.openVerification;
    final documentsReady =
        quote.agreement?.isAvailable == true &&
        quote.keyFacts?.isAvailable == true;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (expired) ...[
          const BorrowerNotice(
            'This quote has expired. Request a current quote to review the latest terms.',
          ),
          const SizedBox(height: 12),
          PrimaryButton(title: 'Refresh quote', onPressed: widget.onRefresh),
          const SizedBox(height: 18),
        ],
        BrandCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Total repayment', style: text.labelLarge),
              const SizedBox(height: 6),
              Text(
                formatLoanAmount(quote.totalRepaymentPaise),
                style: text.displayMedium,
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: ThemeConfig.ruleLight),
              const SizedBox(height: 8),
              _QuoteRow('Loan amount', formatLoanAmount(quote.principalPaise)),
              _QuoteRow('Repayment term', '${quote.months} months'),
              _QuoteRow(
                'Total interest',
                formatLoanAmount(quote.interestPaise),
              ),
              if (quote.interestRate case final rate?)
                _QuoteRow('Interest rate', rate),
              for (final charge in quote.charges)
                _QuoteRow(charge.label, formatLoanAmount(charge.amountPaise)),
              _QuoteRow('APR', quote.apr),
              _QuoteRow(
                'Net proceeds',
                formatLoanAmount(quote.netProceedsPaise),
              ),
              _QuoteRow(
                'Regular installment',
                formatLoanAmount(quote.regularEmiPaise),
              ),
              _QuoteRow(
                'Final installment',
                formatLoanAmount(quote.finalEmiPaise),
              ),
              if (quote.firstDueDate case final date?)
                _QuoteRow('First due date', _date(context, date)),
              if (expiry != null)
                _QuoteRow(
                  'Quote expires',
                  '${_date(context, expiry.toLocal())} ${TimeOfDay.fromDateTime(expiry.toLocal()).format(context)}',
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OutlineButton(
          title: 'View repayment schedule',
          enabled: !expired,
          onPressed: widget.openSchedule,
        ),
        const SizedBox(height: 12),
        OutlineButton(
          title: 'Loan agreement',
          onPressed: () => _open(
            LoanDisclosureScreen(
              title: 'Loan agreement',
              document: quote.agreement,
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlineButton(
          title: 'Key Facts Statement',
          onPressed: () => _open(
            LoanDisclosureScreen(
              title: 'Key Facts Statement',
              document: quote.keyFacts,
            ),
          ),
        ),
        const SizedBox(height: 16),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text(
            'I have read the loan agreement and Key Facts Statement.',
          ),
          value: _consent && !expired,
          onChanged: documentsReady && !expired
              ? (value) => setState(() => _consent = value ?? false)
              : null,
        ),
        if (!documentsReady)
          const BorrowerNotice(
            'Both documents are required before you can acknowledge them.',
          ),
        const SizedBox(height: 12),
        if (!expired && openVerification != null) ...[
          OutlineButton(
            title: 'Verification checklist',
            onPressed: openVerification,
          ),
          const SizedBox(height: 12),
        ],
        const BorrowerNotice('Loan acceptance is currently unavailable.'),
        const SizedBox(height: 12),
        PrimaryButton(title: 'Accept loan', enabled: false, onPressed: () {}),
      ],
    );
  }
}

class RepaymentScheduleScreen extends StatefulWidget {
  const RepaymentScheduleScreen({
    required this.installments,
    this.loadCurrentQuote,
    this.onSessionExpired,
    super.key,
  });

  final List<LoanInstallment> installments;
  final Future<LoanQuote> Function()? loadCurrentQuote;
  final VoidCallback? onSessionExpired;

  @override
  State<RepaymentScheduleScreen> createState() =>
      _RepaymentScheduleScreenState();
}

class _RepaymentScheduleScreenState extends State<RepaymentScheduleScreen> {
  Future<LoanQuote>? _current;
  AppLifecycleListener? _lifecycle;
  Timer? _expiryTimer;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.loadCurrentQuote != null) {
      _current = _load();
      _lifecycle = AppLifecycleListener(onResume: _refresh);
    }
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    _expiryTimer?.cancel();
    super.dispose();
  }

  Future<LoanQuote> _load() async {
    _expiryTimer?.cancel();
    _loading = true;
    try {
      final quote = await widget.loadCurrentQuote!();
      final remaining = quote.expiresAt?.difference(DateTime.now());
      if (mounted && remaining != null && remaining > Duration.zero) {
        _expiryTimer = Timer(remaining, () => setState(() {}));
      }
      return quote;
    } on InvalidSessionException {
      if (mounted && ModalRoute.isCurrentOf(context) == true) {
        widget.onSessionExpired?.call();
      }
      rethrow;
    } finally {
      _loading = false;
    }
  }

  void _refresh() {
    if (!_loading) {
      final next = _load();
      setState(() {
        _current = next;
      });
    }
  }

  @override
  Widget build(BuildContext context) => BorrowerPage(
    title: 'Repayment schedule',
    description: 'Review the amounts and due dates in your quote.',
    child: _current == null
        ? _rows(context, widget.installments)
        : FutureBuilder<LoanQuote>(
            future: _current,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LoanProgress('Checking your loan quote');
              }
              if (snapshot.error is LoanQuoteStale ||
                  (snapshot.data?.expiresAt?.isAfter(DateTime.now()) ==
                      false)) {
                return const BorrowerNotice('This quote is no longer current.');
              }
              if (snapshot.error is InvalidSessionException) {
                return const BorrowerNotice('Your session has expired.');
              }
              if (snapshot.hasError) {
                return LoanLoadError(
                  'We couldn’t load your schedule.',
                  onRetry: _refresh,
                );
              }
              return _rows(context, snapshot.requireData.schedule);
            },
          ),
  );

  Widget _rows(BuildContext context, List<LoanInstallment> installments) =>
      installments.isEmpty
      ? const BorrowerNotice('The repayment schedule is currently unavailable.')
      : BrandCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, item) in installments.indexed) ...[
                if (index > 0)
                  const Divider(height: 24, color: ThemeConfig.ruleLight),
                _QuoteRow(
                  'Installment ${item.number}',
                  formatLoanAmount(item.amountPaise),
                ),
                _QuoteRow('Due date', _date(context, item.dueDate)),
                if (item.principalPaise case final amount?)
                  _QuoteRow('Principal', formatLoanAmount(amount)),
                if (item.interestPaise case final amount?)
                  _QuoteRow('Interest', formatLoanAmount(amount)),
              ],
            ],
          ),
        );
}

class LoanDisclosureScreen extends StatelessWidget {
  const LoanDisclosureScreen({
    required this.title,
    required this.document,
    super.key,
  });

  final String title;
  final LoanDisclosure? document;

  @override
  Widget build(BuildContext context) {
    final disclosure = document;
    return BorrowerPage(
      title: title,
      description: 'Review the document supplied with your quote.',
      child: disclosure == null || !disclosure.isAvailable
          ? const BorrowerNotice('This document is currently unavailable.')
          : BrandCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Version ${disclosure.version}',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    disclosure.text,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
    );
  }
}

String _date(BuildContext context, DateTime date) =>
    MaterialLocalizations.of(context).formatCompactDate(date);

class _QuoteRow extends StatelessWidget {
  const _QuoteRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
      ],
    ),
  );
}
