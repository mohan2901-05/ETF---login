import 'package:etf_loans/core/errors/app_errors.dart';
import 'package:etf_loans/features/onboarding/borrower_form_widgets.dart';
import 'package:etf_loans/features/verification/aadhaar_verification_screen.dart';
import 'package:etf_loans/features/verification/additional_verification_models.dart';
import 'package:etf_loans/features/verification/additional_verification_service.dart';
import 'package:etf_loans/features/verification/address_verification_screen.dart';
import 'package:etf_loans/features/verification/bank_verification_screen.dart';
import 'package:etf_loans/features/verification/face_verification_screen.dart';
import 'package:etf_loans/features/verification/verification_service.dart';
import 'package:etf_loans/features/verification/verification_models.dart';
import 'package:etf_loans/shared/widgets/brand_card.dart';
import 'package:etf_loans/shared/widgets/custom_widgets.dart';
import 'package:etf_loans/theme/theme_config.dart';
import 'package:flutter/material.dart';

class VerificationChecklistScreen extends StatefulWidget {
  const VerificationChecklistScreen({
    required this.accessToken,
    required this.offerReference,
    required this.onSessionExpired,
    this.service = const UnavailableLoanVerificationService(),
    this.additionalService,
    this.onOpenOtherCheck,
    super.key,
  });

  final String accessToken;
  final String offerReference;
  final VoidCallback onSessionExpired;
  final LoanVerificationService service;
  final AdditionalVerificationService? additionalService;

  /// Optional navigation override for the additional checks.
  final Future<void> Function(VerificationKind kind)? onOpenOtherCheck;

  @override
  State<VerificationChecklistScreen> createState() =>
      _VerificationChecklistScreenState();
}

class _VerificationChecklistScreenState
    extends State<VerificationChecklistScreen> {
  late Future<Map<VerificationKind, VerificationCheck>> _checklist = _load();
  bool _checkOpen = false;
  final _addressDraft = AddressDraft();

  Future<Map<VerificationKind, VerificationCheck>> _load() async {
    if (widget.accessToken.trim().isEmpty ||
        widget.offerReference.trim().isEmpty) {
      throw VerificationIssue.unavailable;
    }
    try {
      return await widget.service.loadChecklist(
        accessToken: widget.accessToken,
        offerReference: widget.offerReference,
      );
    } on InvalidSessionException {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ModalRoute.isCurrentOf(context) == true)
          widget.onSessionExpired();
      });
      rethrow;
    }
  }

  void _refresh() => setState(() => _checklist = _load());

  Future<void> _open(VerificationKind kind) async {
    if (_checkOpen) return;
    _checkOpen = true;
    try {
      if (kind == VerificationKind.face) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => FaceVerificationInstructions(
              onSessionExpired: widget.onSessionExpired,
              openSession: (consent) => widget.service.openFaceSession(
                accessToken: widget.accessToken,
                offerReference: widget.offerReference,
                consent: consent,
              ),
            ),
          ),
        );
      } else {
        final openOther = widget.onOpenOtherCheck;
        if (openOther != null) {
          await openOther(kind);
        } else {
          final page = _additionalCheck(kind);
          if (page != null) {
            await Navigator.of(context)
                .push<void>(MaterialPageRoute(builder: (_) => page));
          }
        }
      }
    } on InvalidSessionException {
      if (mounted) widget.onSessionExpired();
      return;
    } finally {
      _checkOpen = false;
    }
    if (mounted) _refresh();
  }

  Widget? _additionalCheck(VerificationKind kind) {
    final service = widget.additionalService;
    final token = widget.accessToken;
    final offer = widget.offerReference;
    final expired = widget.onSessionExpired;
    return switch (kind) {
      VerificationKind.aadhaar => AadhaarVerificationScreen(
        onSessionExpired: expired,
        start: service == null
            ? null
            : (consent) => service.startAadhaar(
                accessToken: token,
                offerReference: offer,
                consent: consent,
              ),
        checkStatus: service == null
            ? null
            : () => service.readAadhaarResult(
                accessToken: token,
                offerReference: offer,
              ),
      ),
      VerificationKind.address => AddressVerificationScreen(
        onSessionExpired: expired,
        draft: _addressDraft,
        submit: service == null
            ? null
            : (details) => service.submitAddress(
                accessToken: token,
                offerReference: offer,
                details: details,
              ),
      ),
      VerificationKind.bank => BankVerificationScreen(
        onSessionExpired: expired,
        submit: service == null
            ? null
            : (details) => service.submitBankAccount(
                accessToken: token,
                offerReference: offer,
                details: details,
              ),
      ),
      VerificationKind.pan || VerificationKind.face => null,
    };
  }

  @override
  Widget build(BuildContext context) => BorrowerPage(
    title: 'Loan verification checklist',
    description: 'Review the identity and account checks for this offer.',
    child: FutureBuilder<Map<VerificationKind, VerificationCheck>>(
      future: _checklist,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const BorrowerNotice('Loading verification checks');
        }
        if (snapshot.error is InvalidSessionException)
          return const BorrowerNotice('Your session has expired.');
        final statuses =
            snapshot.data ?? const <VerificationKind, VerificationCheck>{};
        final unavailable = snapshot.error == VerificationIssue.unavailable;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (snapshot.hasError) ...[
              BorrowerNotice(
                unavailable
                    ? 'Verification services are currently unavailable.'
                    : 'We couldn’t load your verification checks.',
                isError: !unavailable,
              ),
              if (!unavailable)
                PrimaryButton(title: 'Retry checklist', onPressed: _refresh),
              const SizedBox(height: 16),
            ],
            BrandCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(
                children: [
                  for (final kind in VerificationKind.values)
                    _checkRow(kind, statuses[kind]),
                ],
              ),
            ),
            const SizedBox(height: 18),
            OutlineButton(
              title: 'Return to loan review',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    ),
  );

  Widget _checkRow(VerificationKind kind, VerificationCheck? check) {
    final status = check?.status ?? VerificationStatus.unavailable;
    final canOpen =
        check?.canStart == true &&
        (status == VerificationStatus.pending ||
            status == VerificationStatus.failed);
    final enabled = canOpen && kind != VerificationKind.pan;
    final (icon, color) = switch (status) {
      VerificationStatus.pending => (Icons.schedule, ThemeConfig.mutedText),
      VerificationStatus.completed => (
        Icons.check_circle_outline,
        ThemeConfig.primaryGreen,
      ),
      VerificationStatus.failed => (Icons.error_outline, ThemeConfig.errorRed),
      VerificationStatus.unavailable => (
        Icons.remove_circle_outline,
        ThemeConfig.mutedText,
      ),
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(kind.label),
      subtitle: Text(status.label),
      trailing: enabled ? const Icon(Icons.chevron_right) : null,
      onTap: enabled ? () => _open(kind) : null,
    );
  }
}
