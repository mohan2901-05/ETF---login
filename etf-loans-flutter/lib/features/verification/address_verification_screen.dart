import 'package:etf_loans/features/onboarding/borrower_form_widgets.dart';
import 'package:etf_loans/features/verification/additional_verification_models.dart';
import 'package:etf_loans/features/verification/verification_details_form.dart';
import 'package:flutter/material.dart';

class AddressVerificationScreen extends StatefulWidget {
  const AddressVerificationScreen({
    required this.draft,
    this.submit,
    required this.onSessionExpired,
    super.key,
  });

  final AddressDraft draft;
  final Future<void> Function(AddressDetails)? submit;
  final VoidCallback onSessionExpired;

  @override
  State<AddressVerificationScreen> createState() =>
      _AddressVerificationScreenState();
}

class _AddressVerificationScreenState extends State<AddressVerificationScreen> {
  late final _controllers = {
    for (final field in AddressField.values)
      field: TextEditingController(text: widget.draft.fields[field]),
  };

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final submit = widget.submit;
    return VerificationDetailsForm(
      title: 'Address and work',
      description:
          'Enter your current address and employment details for this offer.',
      submitLabel: 'Save details',
      onSessionExpired: widget.onSessionExpired,
      onSubmit: submit == null
          ? null
          : () async {
              await submit(
                AddressDetails(
                  fields: {
                    for (final entry in _controllers.entries)
                      entry.key: entry.value.text.trim(),
                  },
                  housing: widget.draft.housing!,
                ),
              );
              if (mounted) widget.draft.clear();
            },
      fields: (enabled) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final field in AddressField.values) ...[
            if (field == AddressField.employer) ...[
              DropdownButtonFormField<HousingType>(
                initialValue: widget.draft.housing,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Housing type'),
                items: [
                  for (final type in HousingType.values)
                    DropdownMenuItem(value: type, child: Text(type.label)),
                ],
                validator: (value) =>
                    value == null ? 'Choose your housing type.' : null,
                onChanged: enabled
                    ? (value) => widget.draft.housing = value
                    : null,
              ),
              const SizedBox(height: 18),
              Text(
                'Employment',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
            ],
            BorrowerInput(
              label: field.label,
              controller: _controllers[field]!,
              enabled: enabled,
              keyboardType: field == AddressField.pin
                  ? TextInputType.number
                  : TextInputType.text,
              validator: switch (field) {
                AddressField.pin => VerificationInputValidation.pin,
                AddressField.role => (_) => null,
                _ => VerificationInputValidation.requiredText,
              },
              onChanged: (value) => widget.draft.fields[field] = value,
            ),
            if (field != AddressField.role) const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }
}
