import 'package:flutter/material.dart';
import 'package:etf_loans/core/errors/app_errors.dart';
import 'package:etf_loans/features/onboarding/borrower_details.dart';
import 'package:etf_loans/features/onboarding/borrower_form_widgets.dart';
import 'package:etf_loans/features/onboarding/borrower_service.dart';
import 'package:etf_loans/shared/widgets/brand_card.dart';
import 'package:etf_loans/shared/widgets/custom_widgets.dart';
import 'package:etf_loans/theme/theme_config.dart';

class PanVerificationScreen extends StatefulWidget {
  const PanVerificationScreen({
    required this.service,
    required this.accessToken,
    required this.details,
    required this.panController,
    required this.initialConsent,
    required this.onConsentChanged,
    required this.profileUnavailable,
    super.key,
  });

  final BorrowerService service;
  final String accessToken;
  final BorrowerDetails details;
  final TextEditingController panController;
  final bool initialConsent;
  final ValueChanged<bool> onConsentChanged;
  final bool profileUnavailable;

  @override
  State<PanVerificationScreen> createState() => _PanVerificationScreenState();
}

class _PanVerificationScreenState extends State<PanVerificationScreen> {
  final _form = GlobalKey<FormState>();
  bool _submitting = false;
  String? _error;

  Future<void> _verify() async {
    if (_submitting || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.service.completeOnboarding(
        accessToken: widget.accessToken,
        details: widget.details,
        pan: BorrowerValidation.normalizePan(widget.panController.text),
        panConsent: true, // The required consent field passed validation.
      );
      if (mounted)
        Navigator.of(context).pop(BorrowerFlowResult.checkEligibility);
    } on InvalidSessionException {
      if (mounted) Navigator.of(context).pop(BorrowerFlowResult.sessionExpired);
    } on BorrowerServiceUnavailable catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'We couldn’t verify your PAN. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    return BorrowerPage(
      title: 'Verify your PAN',
      description: 'Enter the PAN shown on your PAN card.',
      submitting: _submitting,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.profileUnavailable && _error == null) ...[
              const BorrowerNotice(
                'PAN verification is currently unavailable.',
              ),
              const SizedBox(height: 16),
            ],
            BrandCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BorrowerInput(
                    label: 'PAN',
                    hint: 'ABCDE1234F',
                    controller: widget.panController,
                    capitalization: TextCapitalization.characters,
                    validator: BorrowerValidation.pan,
                    enabled: !_submitting,
                    onChanged: (_) => _clearError(),
                  ),
                  const SizedBox(height: 12),
                  FormField<bool>(
                    initialValue: widget.initialConsent,
                    validator: (value) => value == true
                        ? null
                        : 'Consent to PAN verification to continue.',
                    builder: (field) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text(
                            'I consent to verification of my PAN.',
                          ),
                          value: field.value ?? false,
                          onChanged: _submitting
                              ? null
                              : (value) {
                                  field.didChange(value);
                                  if (field.hasError) field.validate();
                                  widget.onConsentChanged(value ?? false);
                                  _clearError();
                                },
                        ),
                        if (field.errorText case final error?)
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              error,
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(color: ThemeConfig.errorRed),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_error case final error?) ...[
              const SizedBox(height: 16),
              BorrowerNotice(error, isError: true),
            ],
            const SizedBox(height: 24),
            PrimaryButton(
              title: 'Verify PAN',
              isLoading: _submitting,
              onPressed: _verify,
            ),
          ],
        ),
      ),
    );
  }
}
