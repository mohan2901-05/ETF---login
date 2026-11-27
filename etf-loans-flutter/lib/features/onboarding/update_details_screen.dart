import 'package:flutter/material.dart';
import 'package:etf_loans/core/errors/app_errors.dart';
import 'package:etf_loans/features/onboarding/borrower_details.dart';
import 'package:etf_loans/features/onboarding/borrower_form_widgets.dart';
import 'package:etf_loans/features/onboarding/borrower_service.dart';
import 'package:etf_loans/shared/widgets/brand_card.dart';
import 'package:etf_loans/shared/widgets/custom_widgets.dart';

class UpdateDetailsScreen extends StatefulWidget {
  const UpdateDetailsScreen({
    required this.service,
    required this.accessToken,
    required this.profile,
    this.profileUnavailable = false,
    super.key,
  });

  final BorrowerService service;
  final String accessToken;
  final BorrowerProfile? profile;
  final bool profileUnavailable;

  @override
  State<UpdateDetailsScreen> createState() => _UpdateDetailsScreenState();
}

class _UpdateDetailsScreenState extends State<UpdateDetailsScreen> {
  final _form = GlobalKey<FormState>();
  final _finances = GlobalKey<FinanceFieldsState>();
  bool _submitting = false;
  String? _error;

  Future<void> _save() async {
    if (_submitting || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    if (widget.profile == null) {
      setState(
        () => _error = widget.profileUnavailable
            ? 'Saving and rechecking are unavailable while your profile can’t be loaded.'
            : 'Complete your personal details and PAN verification before saving updates.',
      );
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.service.updateFinances(
        accessToken: widget.accessToken,
        finances: _finances.currentState!.value,
      );
      if (mounted)
        Navigator.of(context).pop(BorrowerFlowResult.recheckEligibility);
    } on InvalidSessionException {
      if (mounted) Navigator.of(context).pop(BorrowerFlowResult.sessionExpired);
    } on BorrowerRequestException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted)
        setState(
          () => _error = 'We couldn’t save your changes. Please try again.',
        );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final typography = Theme.of(context).textTheme;
    final profile = widget.profile;
    final details = profile?.details;
    final birthDate = details == null
        ? null
        : MaterialLocalizations.of(context).formatFullDate(details.dateOfBirth);

    return BorrowerPage(
      title: 'Update details',
      description: 'Update your income and other EMIs to recheck eligibility. Your current loans stay the same.',
      submitting: _submitting,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (profile == null) ...[
              BorrowerNotice(
                widget.profileUnavailable
                    ? 'Your borrower profile is currently unavailable.'
                    : 'Complete your personal details and PAN verification to create a borrower profile.',
              ),
              const SizedBox(height: 16),
            ],
            BrandCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'Identity details',
                      style: typography.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Name, PAN and date of birth are read-only.',
                    style: typography.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  for (final (label, value) in <(String, String?)>[
                    ('Full name', details?.fullName),
                    ('PAN', profile?.maskedPan),
                    ('Date of birth', birthDate),
                  ]) ...[
                    Text(label, style: typography.labelLarge),
                    Text(value ?? 'Unavailable', style: typography.bodyMedium),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            BrandCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'Income and expenses',
                      style: typography.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FinanceFields(
                    key: _finances,
                    initial: details?.finances,
                    enabled: !_submitting,
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
              title: 'Save and recheck eligibility',
              isLoading: _submitting,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
