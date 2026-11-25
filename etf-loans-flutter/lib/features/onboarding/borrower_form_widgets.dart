import 'package:flutter/material.dart';
import 'package:etf_loans/features/onboarding/borrower_details.dart';
import 'package:etf_loans/theme/theme_config.dart';

class BorrowerPage extends StatelessWidget {
  const BorrowerPage({
    required this.title,
    required this.description,
    required this.child,
    this.submitting = false,
    super.key,
  });

  final String title;
  final String description;
  final Widget child;
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    final typography = Theme.of(context).textTheme;
    return PopScope(
      canPop: !submitting,
      child: Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
          title: Image.asset(
            'assets/logos/logo.png',
            height: 30,
            semanticLabel: 'ETF Loans',
          ),
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(title, style: typography.titleLarge),
                      ),
                      const SizedBox(height: 8),
                      Text(description, style: typography.bodyMedium),
                      const SizedBox(height: 24),
                      child,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BorrowerNotice extends StatelessWidget {
  const BorrowerNotice(this.message, {this.isError = false, super.key});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isError ? ThemeConfig.cardBg : ThemeConfig.tintGreen,
          border: Border.all(
            color: isError ? ThemeConfig.errorRed : ThemeConfig.ruleLight,
          ),
          borderRadius: BorderRadius.circular(ThemeConfig.radiusBase),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.info_outline,
                color: isError
                    ? ThemeConfig.errorRed
                    : ThemeConfig.primaryGreen,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BorrowerInput extends StatelessWidget {
  const BorrowerInput({
    required this.label,
    required this.controller,
    required this.validator,
    this.enabled = true,
    this.hint,
    this.helper,
    this.prefix,
    this.keyboardType,
    this.capitalization = TextCapitalization.none,
    this.onChanged,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final FormFieldValidator<String> validator;
  final bool enabled;
  final String? hint;
  final String? helper;
  final String? prefix;
  final TextInputType? keyboardType;
  final TextCapitalization capitalization;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      enabled: enabled,
      keyboardType: keyboardType,
      textCapitalization: capitalization,
      textInputAction: TextInputAction.next,
      onChanged: onChanged,
      autocorrect: false,
      enableSuggestions: false,
      autovalidateMode: AutovalidateMode.onUnfocus,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        prefixText: prefix,
        constraints: const BoxConstraints(minHeight: ThemeConfig.inputHeight),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        errorMaxLines: 4,
        helperMaxLines: 3,
      ),
    );
  }
}

class FinanceFields extends StatefulWidget {
  const FinanceFields({this.initial, this.enabled = true, super.key});

  final BorrowerFinances? initial;
  final bool enabled;

  @override
  State<FinanceFields> createState() => FinanceFieldsState();
}

class FinanceFieldsState extends State<FinanceFields> {
  late final _monthlyIncome = TextEditingController(
    text: widget.initial?.monthlyIncome,
  );
  late final _externalEmi = TextEditingController(
    text: widget.initial?.externalEmi,
  );
  late EmploymentType? _employment = widget.initial?.employment;

  BorrowerFinances get value => BorrowerFinances(
    employment: _employment!,
    monthlyIncome: _monthlyIncome.text.trim(),
    externalEmi: _externalEmi.text.trim(),
  );

  @override
  Widget build(BuildContext context) {
    const amountKeyboard = TextInputType.numberWithOptions(decimal: true);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<EmploymentType>(
          initialValue: _employment,
          isExpanded: true,
          itemHeight: null,
          decoration: const InputDecoration(
            labelText: 'Employment type',
            constraints: BoxConstraints(minHeight: ThemeConfig.inputHeight),
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          items: [
            for (final type in EmploymentType.values)
              DropdownMenuItem(
                value: type,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(type.label),
                ),
              ),
          ],
          onChanged: widget.enabled ? (value) => _employment = value : null,
          validator: (value) =>
              value == null ? 'Choose your employment type.' : null,
        ),
        const SizedBox(height: 18),
        BorrowerInput(
          label: 'Monthly take-home income',
          controller: _monthlyIncome,
          keyboardType: amountKeyboard,
          prefix: '₹ ',
          validator: BorrowerValidation.rupees,
          enabled: widget.enabled,
        ),
        const SizedBox(height: 18),
        BorrowerInput(
          label: 'Other monthly EMIs',
          controller: _externalEmi,
          keyboardType: amountKeyboard,
          prefix: '₹ ',
          helper: 'Enter 0 if you have no EMIs with other lenders.',
          validator: BorrowerValidation.rupees,
          enabled: widget.enabled,
        ),
      ],
    );
  }

  @override
  void dispose() {
    _monthlyIncome.dispose();
    _externalEmi.dispose();
    super.dispose();
  }
}
