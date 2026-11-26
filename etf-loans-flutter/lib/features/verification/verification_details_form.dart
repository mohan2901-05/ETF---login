import 'package:etf_loans/core/errors/app_errors.dart';
import 'package:etf_loans/features/onboarding/borrower_form_widgets.dart';
import 'package:etf_loans/features/verification/verification_service.dart';
import 'package:etf_loans/shared/widgets/brand_card.dart';
import 'package:etf_loans/shared/widgets/custom_widgets.dart';
import 'package:flutter/material.dart';

class VerificationDetailsForm extends StatefulWidget {
  const VerificationDetailsForm({
    required this.title,
    required this.description,
    required this.fields,
    required this.submitLabel,
    required this.onSubmit,
    required this.onSessionExpired,
    super.key,
  });

  final String title;
  final String description;
  final Widget Function(bool enabled) fields;
  final String submitLabel;
  final Future<void> Function()? onSubmit;
  final VoidCallback onSessionExpired;

  @override
  State<VerificationDetailsForm> createState() =>
      _VerificationDetailsFormState();
}

class _VerificationDetailsFormState extends State<VerificationDetailsForm> {
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;
  bool _received = false;
  bool _unavailable = false;
  String? _error;

  Future<void> _submit() async {
    final submit = widget.onSubmit;
    if (submit == null ||
        _busy ||
        _unavailable ||
        !_formKey.currentState!.validate())
      return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await submit();
      if (mounted) setState(() => _received = true);
    } on InvalidSessionException {
      if (mounted) widget.onSessionExpired();
    } on VerificationIssue catch (issue) {
      if (mounted)
        setState(() {
          _unavailable = issue == VerificationIssue.unavailable;
          if (!_unavailable)
            _error = 'We couldn’t submit your details. Please try again.';
        });
    } catch (_) {
      if (mounted)
        setState(
          () => _error = 'We couldn’t submit your details. Please try again.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unavailable = widget.onSubmit == null || _unavailable;
    final enabled = !unavailable && !_busy;
    return BorrowerPage(
      title: widget.title,
      description: widget.description,
      submitting: _busy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _received
            ? [
                const BorrowerNotice(
                  'Details received. Return to the checklist to see the latest verification status.',
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  title: 'Return to checklist',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ]
            : [
                if (unavailable) ...[
                  const BorrowerNotice(
                    'This verification service is currently unavailable.',
                  ),
                  const SizedBox(height: 16),
                ],
                BrandCard(
                  child: Form(key: _formKey, child: widget.fields(enabled)),
                ),
                if (_error case final error?) ...[
                  const SizedBox(height: 12),
                  BorrowerNotice(error, isError: true),
                ],
                const SizedBox(height: 16),
                PrimaryButton(
                  title: widget.submitLabel,
                  enabled: enabled,
                  isLoading: _busy,
                  onPressed: _submit,
                ),
              ],
      ),
    );
  }
}
