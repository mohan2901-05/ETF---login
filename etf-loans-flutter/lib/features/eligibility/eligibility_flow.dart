import 'package:etf_loans/core/errors/app_errors.dart';
import 'package:etf_loans/features/eligibility/checking_eligibility_screen.dart';
import 'package:etf_loans/features/eligibility/eligibility_models.dart';
import 'package:etf_loans/features/eligibility/eligibility_result_screen.dart';
import 'package:etf_loans/features/eligibility/eligibility_service.dart';
import 'package:etf_loans/features/onboarding/borrower_details.dart';
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
  final ValueChanged<String>? onLoanApplicationRequested;

  @override
  State<EligibilityFlow> createState() => _EligibilityFlowState();
}

class _EligibilityFlowState extends State<EligibilityFlow> {
  late EligibilityCheckKind _kind = widget.initialKind;
  late Future<EligibilityAssessment> _assessment = _check();
  bool _requestPending = false;
  bool _editing = false;

  Future<EligibilityAssessment> _check() async {
    _requestPending = true;
    try {
      return await widget.service.check(
        accessToken: widget.accessToken,
        kind: _kind,
      );
    } on InvalidSessionException {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ModalRoute.isCurrentOf(context) == true) {
          widget.onSessionExpired();
        }
      });
      rethrow;
    } finally {
      _requestPending = false;
    }
  }

  void _startCheck(EligibilityCheckKind kind) {
    if (_requestPending) return;
    setState(() {
      _kind = kind;
      _assessment = _check();
    });
  }

  Future<void> _updateDetails() async {
    if (_editing) return;
    _editing = true;
    try {
      final result = await widget.openUpdateDetails();
      if (!mounted) return;
      if (result == BorrowerFlowResult.sessionExpired) {
        widget.onSessionExpired();
      } else if (result == BorrowerFlowResult.recheckEligibility) {
        _startCheck(EligibilityCheckKind.recheck);
      }
    } finally {
      _editing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EligibilityAssessment>(
      future: _assessment,
      builder: (context, snapshot) {
        final assessment = snapshot.data;
        if (snapshot.connectionState == ConnectionState.done &&
            assessment != null) {
          return EligibilityResultScreen(
            assessment: assessment,
            borrowerName: widget.borrowerName,
            onUpdateDetails: _updateDetails,
            onLoanApplicationRequested: widget.onLoanApplicationRequested,
          );
        }

        final state = switch (snapshot) {
          AsyncSnapshot(connectionState: ConnectionState.waiting) =>
            EligibilityCheckState.loading,
          AsyncSnapshot(error: EligibilityUnavailable()) =>
            EligibilityCheckState.unavailable,
          _ => EligibilityCheckState.failed,
        };
        return CheckingEligibilityScreen(
          state: state,
          onUpdateDetails: _updateDetails,
          onRetry: () => _startCheck(_kind),
        );
      },
    );
  }
}
