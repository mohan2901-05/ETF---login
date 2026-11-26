import 'package:etf_loans/features/onboarding/borrower_form_widgets.dart';
import 'package:etf_loans/features/verification/additional_verification_models.dart';
import 'package:etf_loans/features/verification/verification_details_form.dart';
import 'package:etf_loans/features/verification/verification_service.dart';
import 'package:flutter/material.dart';

class BankVerificationScreen extends StatefulWidget {
  const BankVerificationScreen({
    this.submit,
    required this.onSessionExpired,
    super.key,
  });

  final Future<void> Function(BankAccountDetails)? submit;
  final VoidCallback onSessionExpired;

  @override
  State<BankVerificationScreen> createState() => _BankVerificationScreenState();
}

class _BankVerificationScreenState extends State<BankVerificationScreen> {
  final _holder = TextEditingController();
  final _number = TextEditingController();
  final _confirmation = TextEditingController();
  final _ifsc = TextEditingController();

  String? _validateConfirmation(String? value) =>
      VerificationInputValidation.accountNumber(value) ??
      (value!.trim() == _number.text.trim()
          ? null
          : 'The account numbers must match.');

  void _clear() {
    for (final controller in [_holder, _number, _confirmation, _ifsc]) {
      controller.clear();
    }
  }

  @override
  void dispose() {
    for (final controller in [_holder, _number, _confirmation, _ifsc]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final submit = widget.submit;
    return VerificationDetailsForm(
      title: 'Verify bank account',
      description: 'Confirm the account you want checked for this loan.',
      submitLabel: 'Verify account',
      onSessionExpired: widget.onSessionExpired,
      onSubmit: submit == null
          ? null
          : () async {
              try {
                await submit(
                  BankAccountDetails(
                    holder: _holder.text.trim(),
                    number: _number.text.trim(),
                    ifsc: _ifsc.text.trim().toUpperCase(),
                  ),
                );
              } on VerificationIssue catch (issue) {
                if (mounted && issue == VerificationIssue.unavailable) _clear();
                rethrow;
              }
              if (mounted) _clear();
            },
      fields: (enabled) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BorrowerInput(
            label: 'Account holder name',
            controller: _holder,
            enabled: enabled,
            validator: VerificationInputValidation.requiredText,
          ),
          const SizedBox(height: 18),
          BorrowerInput(
            label: 'Account number',
            controller: _number,
            enabled: enabled,
            obscureText: true,
            keyboardType: TextInputType.number,
            validator: VerificationInputValidation.accountNumber,
          ),
          const SizedBox(height: 18),
          BorrowerInput(
            label: 'Confirm account number',
            controller: _confirmation,
            enabled: enabled,
            obscureText: true,
            keyboardType: TextInputType.number,
            validator: _validateConfirmation,
          ),
          const SizedBox(height: 18),
          BorrowerInput(
            label: 'IFSC',
            controller: _ifsc,
            enabled: enabled,
            capitalization: TextCapitalization.characters,
            validator: VerificationInputValidation.ifsc,
          ),
        ],
      ),
    );
  }
}
