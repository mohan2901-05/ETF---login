import 'dart:math';

import 'package:etf_loans/core/errors/app_errors.dart';
import 'package:etf_loans/features/eligibility/checking_eligibility_screen.dart';
import 'package:etf_loans/features/eligibility/eligibility_models.dart';
import 'package:etf_loans/features/eligibility/eligibility_result_screen.dart';
import 'package:etf_loans/features/eligibility/eligibility_service.dart';
import 'package:etf_loans/features/onboarding/borrower_details.dart';
import 'package:etf_loans/features/onboarding/borrower_form_widgets.dart';
import 'package:etf_loans/shared/widgets/custom_widgets.dart';
import 'package:flutter/material.dart';

/// Opened from authenticated Home only after Phase 03 confirms a write.
class EligibilityFlow extends StatefulWidget {
  const EligibilityFlow({
    required this.accessToken,
    required this.initialKind,
    required this.openUpdateDetails,
    required this.onSessionExpired,
    this.borrowerName,
    this.service = const UnavailableEligibilityService(),
    this.onLoanApplicationRequested,
    super.key,
  });

  final String accessToken;
  final EligibilityCheckKind initialKind;
  final Future<BorrowerFlowResult?> Function() openUpdateDetails;
  final VoidCallback onSessionExpired;
  final String? borrowerName;
  final EligibilityService service;

  /// Returns true when the selection screen discovers that the offer is stale.
  final Future<bool> Function(EligibilityAssessment)?
  onLoanApplicationRequested;

  @override
  State<EligibilityFlow> createState() => _EligibilityFlowState();
}

class _EligibilityFlowState extends State<EligibilityFlow> {
  static const _consentVersion = 1;
  late EligibilityCheckKind _kind = widget.initialKind;
  Future<EligibilityAssessment>? _assessment;
  String? _requestKey;
  Object? _offerError;
  bool _consented = false;
  bool _requestPending = false;
  bool _checkingOffer = false;
  bool _editing = false;
  bool _staleAssessment = false;

  Future<EligibilityAssessment> _check(String key) async {
    try {
      return await widget.service.check(
        accessToken: widget.accessToken,
        kind: _kind,
        consentVersion: _consentVersion,
        idempotencyKey: key,
        isCancelled: () => !mounted,
      );
    } on InvalidSessionException {
      _expireSession();
      rethrow;
    } on EligibilityAssessmentStale {
      if (mounted) _resetForRecheck(stale: true);
      rethrow;
    } catch (error) {
      if (error is EligibilityUnavailable ||
          error is EligibilityRequestRejected) {
        _requestKey = null;
      }
      rethrow;
    } finally {
      _requestPending = false;
    }
  }

  void _expireSession() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ModalRoute.isCurrentOf(context) == true) {
        widget.onSessionExpired();
      }
    });
  }

  void _startCheck() {
    if (!_consented || _requestPending || _checkingOffer || _editing) return;
    setState(() {
      _offerError = null;
      _staleAssessment = false;
      _requestPending = true;
      final random = Random.secure();
      final key = _requestKey ??= List.generate(
        16,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      _assessment = _check(key);
    });
  }

  void _resetForRecheck({bool stale = false}) {
    setState(() {
      _kind = EligibilityCheckKind.recheck;
      _assessment = null;
      _requestKey = null;
      _offerError = null;
      _consented = false;
      _staleAssessment = stale;
    });
  }

  Future<void> _updateDetails() async {
    if (_editing || _checkingOffer || _requestPending) return;
    _editing = true;
    try {
      final result = await widget.openUpdateDetails();
      if (!mounted) return;
      if (result == BorrowerFlowResult.sessionExpired) {
        widget.onSessionExpired();
      } else if (result == BorrowerFlowResult.recheckEligibility) {
        _resetForRecheck();
      }
    } finally {
      _editing = false;
    }
  }

  Future<void> _openOffer(EligibilityAssessment assessment) async {
    final openSelection = widget.onLoanApplicationRequested;
    if (_checkingOffer || _editing || openSelection == null) return;
    setState(() => _checkingOffer = true);
    try {
      await widget.service.confirmOffer(
        accessToken: widget.accessToken,
        assessment: assessment,
      );
      if (mounted && ModalRoute.isCurrentOf(context) == true) {
        final stale = await openSelection(assessment);
        if (mounted && stale) _resetForRecheck(stale: true);
      }
    } on InvalidSessionException {
      _expireSession();
    } on EligibilityAssessmentStale {
      if (mounted) _resetForRecheck(stale: true);
    } catch (error) {
      if (!mounted) return;
      _offerError = error;
      _requestKey = null;
    } finally {
      if (mounted) setState(() => _checkingOffer = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_assessment == null) {
      return BorrowerPage(
        title: 'Check your eligibility',
        description:
            'Your permission is required for a credit eligibility assessment.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_staleAssessment) ...[
              const BorrowerNotice(
                'Your previous assessment is out of date. Check eligibility again using your latest saved details.',
                isError: true,
              ),
              const SizedBox(height: 12),
            ],
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'I consent to ETF Loans using my saved borrower details to assess my credit eligibility.',
              ),
              value: _consented,
              onChanged: (value) => setState(() => _consented = value == true),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              title: _staleAssessment
                  ? 'Check eligibility again'
                  : 'Check eligibility',
              enabled: _consented,
              onPressed: _startCheck,
            ),
            const SizedBox(height: 12),
            OutlineButton(title: 'Update details', onPressed: _updateDetails),
          ],
        ),
      );
    }

    return FutureBuilder<EligibilityAssessment>(
      future: _assessment,
      builder: (context, snapshot) {
        final assessment = snapshot.data;
        if (!_checkingOffer &&
            _offerError == null &&
            snapshot.connectionState == ConnectionState.done &&
            assessment != null) {
          return EligibilityResultScreen(
            assessment: assessment,
            borrowerName: widget.borrowerName,
            onUpdateDetails: _updateDetails,
            onLoanApplicationRequested:
                widget.onLoanApplicationRequested == null
                ? null
                : (_) => _openOffer(assessment),
          );
        }

        final error = _offerError ?? snapshot.error;
        final state =
            _checkingOffer ||
                snapshot.connectionState == ConnectionState.waiting
            ? EligibilityCheckState.loading
            : error is EligibilityUnavailable
            ? EligibilityCheckState.unavailable
            : EligibilityCheckState.failed;
        return CheckingEligibilityScreen(
          state: state,
          errorMessage: error is EligibilityRequestRejected
              ? error.message
              : null,
          onUpdateDetails: _updateDetails,
          onRetry: _startCheck,
        );
      },
    );
  }
}
