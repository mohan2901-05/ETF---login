import 'package:etf_loans/core/errors/app_errors.dart';
import 'package:etf_loans/features/onboarding/borrower_form_widgets.dart';
import 'package:etf_loans/features/verification/additional_verification_models.dart';
import 'package:etf_loans/features/verification/verification_models.dart';
import 'package:etf_loans/features/verification/verification_service.dart';
import 'package:etf_loans/shared/widgets/custom_widgets.dart';
import 'package:flutter/material.dart';

class AadhaarVerificationScreen extends StatefulWidget {
  const AadhaarVerificationScreen({
    this.start,
    this.checkStatus,
    required this.onSessionExpired,
    super.key,
  });

  final Future<AadhaarResult> Function(bool consent)? start;
  final Future<AadhaarResult> Function()? checkStatus;
  final VoidCallback onSessionExpired;

  @override
  State<AadhaarVerificationScreen> createState() =>
      _AadhaarVerificationScreenState();
}

class _AadhaarVerificationScreenState extends State<AadhaarVerificationScreen> {
  bool _consent = false;
  bool _busy = false;
  bool _unavailable = false;
  String? _error;
  AadhaarResult? _result;

  Future<void> _request(Future<AadhaarResult> Function() operation) async {
    if (_busy || _unavailable) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await operation();
      if (mounted) setState(() => _result = result);
    } on InvalidSessionException {
      if (mounted) widget.onSessionExpired();
    } on VerificationIssue catch (issue) {
      if (mounted) {
        setState(() {
          _unavailable = issue == VerificationIssue.unavailable;
          if (!_unavailable) {
            _error = 'We couldn’t check your Aadhaar status. Please try again.';
          }
        });
      }
    } catch (_) {
      if (mounted)
        setState(
          () => _error =
              'We couldn’t check your Aadhaar status. Please try again.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final start = widget.start;
    final checkStatus = widget.checkStatus;
    final unavailable = start == null || _unavailable;
    final notice = unavailable
        ? 'Aadhaar verification is currently unavailable.'
        : _error;
    if (result != null) {
      return AadhaarVerificationResultScreen(
        result: result,
        busy: _busy,
        notice: notice,
        onCheckStatus: checkStatus != null && !unavailable
            ? () => _request(checkStatus)
            : null,
      );
    }

    return BorrowerPage(
      title: 'Verify Aadhaar',
      description: 'Continue to DigiLocker to authorize sharing for this identity check.',
      submitting: _busy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (notice != null) BorrowerNotice(notice, isError: _error != null),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              'I agree to share Aadhaar information through DigiLocker for this check.',
            ),
            value: _consent,
            onChanged: unavailable || _busy
                ? null
                : (value) => setState(() => _consent = value ?? false),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            title: 'Continue to DigiLocker',
            enabled: _consent && !unavailable,
            isLoading: _busy,
            onPressed: () {
              if (start != null && _consent) _request(() => start(_consent));
            },
          ),
        ],
      ),
    );
  }
}

class AadhaarVerificationResultScreen extends StatelessWidget {
  const AadhaarVerificationResultScreen({
    required this.result,
    this.busy = false,
    this.notice,
    this.onCheckStatus,
    super.key,
  });

  final AadhaarResult result;
  final bool busy;
  final String? notice;
  final VoidCallback? onCheckStatus;

  @override
  Widget build(BuildContext context) {
    final refresh = onCheckStatus;
    final description = switch (result.status) {
      VerificationStatus.completed =>
        'The verification provider confirmed your identity check.',
      VerificationStatus.pending =>
        'The verification provider is still reviewing your check.',
      VerificationStatus.failed =>
        'The verification provider could not verify your identity check.',
      VerificationStatus.unavailable =>
        'The verification provider could not return a result.',
    };
    return BorrowerPage(
      title: 'Aadhaar verification result',
      description: description,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BorrowerNotice(
            result.status.label,
            isError: result.status == VerificationStatus.failed,
          ),
          if (result.maskedAadhaar case final masked?) ...[
            const SizedBox(height: 16),
            Text(
              'Masked Aadhaar',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(masked, style: Theme.of(context).textTheme.titleLarge),
          ],
          if (notice case final message?) ...[
            const SizedBox(height: 12),
            BorrowerNotice(message),
          ],
          const SizedBox(height: 16),
          if (result.status == VerificationStatus.pending &&
              refresh != null) ...[
            PrimaryButton(
              title: 'Check status',
              isLoading: busy,
              onPressed: refresh,
            ),
            const SizedBox(height: 12),
          ],
          OutlineButton(
            title: 'Return to checklist',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
