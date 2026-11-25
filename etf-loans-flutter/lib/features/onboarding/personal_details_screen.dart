import 'package:flutter/material.dart';
import 'package:etf_loans/features/onboarding/borrower_details.dart';
import 'package:etf_loans/features/onboarding/borrower_form_widgets.dart';
import 'package:etf_loans/features/onboarding/borrower_service.dart';
import 'package:etf_loans/features/onboarding/pan_verification_screen.dart';
import 'package:etf_loans/shared/widgets/brand_card.dart';
import 'package:etf_loans/shared/widgets/custom_widgets.dart';

class PersonalDetailsScreen extends StatefulWidget {
  const PersonalDetailsScreen({
    required this.service,
    required this.accessToken,
    this.accountName,
    this.profileUnavailable = false,
    super.key,
  });

  final BorrowerService service;
  final String accessToken;
  final String? accountName;
  final bool profileUnavailable;

  @override
  State<PersonalDetailsScreen> createState() => _PersonalDetailsScreenState();
}

class _PersonalDetailsScreenState extends State<PersonalDetailsScreen> {
  final _form = GlobalKey<FormState>();
  final _finances = GlobalKey<FinanceFieldsState>();
  late final _name = TextEditingController(text: widget.accountName);
  final _birthDate = TextEditingController();
  final _pan = TextEditingController();
  bool _panConsent = false;
  bool _openingPan = false;

  Future<void> _continueToPan() async {
    if (_openingPan || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    _openingPan = true;
    final details = BorrowerDetails(
      fullName: _name.text.trim(),
      dateOfBirth: BorrowerValidation.parseBirthDate(_birthDate.text)!,
      finances: _finances.currentState!.value,
    );
    final result = await Navigator.of(context).push<BorrowerFlowResult>(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/pan-verification'),
        builder: (_) => PanVerificationScreen(
          service: widget.service,
          accessToken: widget.accessToken,
          details: details,
          panController: _pan,
          initialConsent: _panConsent,
          onConsentChanged: (consent) => _panConsent = consent,
          profileUnavailable: widget.profileUnavailable,
        ),
      ),
    );
    _openingPan = false;
    if (mounted && result != null) Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return BorrowerPage(
      title: 'Your details',
      description: 'Tell us about yourself and your monthly finances.',
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.profileUnavailable) ...[
              const BorrowerNotice(
                'You can enter a draft. Saving your details is currently unavailable.',
              ),
              const SizedBox(height: 16),
            ],
            BrandCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  BorrowerInput(
                    label: 'Full name',
                    controller: _name,
                    capitalization: TextCapitalization.words,
                    validator: BorrowerValidation.fullName,
                  ),
                  const SizedBox(height: 18),
                  BorrowerInput(
                    label: 'Date of birth',
                    controller: _birthDate,
                    hint: 'DD/MM/YYYY',
                    keyboardType: TextInputType.datetime,
                    validator: BorrowerValidation.birthDate,
                  ),
                  const SizedBox(height: 18),
                  FinanceFields(key: _finances),
                ],
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              title: 'Continue to PAN verification',
              onPressed: _continueToPan,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _birthDate.dispose();
    _pan.dispose();
    super.dispose();
  }
}
