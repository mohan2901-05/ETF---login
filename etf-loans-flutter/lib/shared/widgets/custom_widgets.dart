import 'package:flutter/material.dart';

import 'package:etf_loans/theme/theme_config.dart';

class PrimaryButton extends StatelessWidget {
  final String title;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool? enabled;

  const PrimaryButton({
    required this.title,
    required this.onPressed,
    this.isLoading = false,
    this.enabled,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: enabled != false && !isLoading ? onPressed : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: ThemeConfig.primaryGreen,
        foregroundColor: ThemeConfig.onDeep,
        elevation: 0,
        shadowColor: ThemeConfig.shadowButtonPrimary.first.color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ThemeConfig.radiusButton),
        ),
        minimumSize: Size(double.infinity, ThemeConfig.buttonHeight),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        textStyle: TextStyle(
          fontFamily: ThemeConfig.headingFontFamily,
          fontSize: ThemeConfig.buttonFontSize,
          fontWeight: ThemeConfig.buttonFontWeight,
          fontVariations: [FontVariation.weight(700)],
          letterSpacing: -0.16,
        ),
      ),
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(ThemeConfig.onDeep),
              ),
            )
          : Text(title),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  final String title;
  final VoidCallback onPressed;
  final bool? enabled;

  const SecondaryButton({
    required this.title,
    required this.onPressed,
    this.enabled,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: enabled != false ? onPressed : null,
      style: TextButton.styleFrom(
        foregroundColor: ThemeConfig.primaryGreen,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: TextStyle(
          fontFamily: ThemeConfig.bodyFontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          decoration: TextDecoration.underline,
          decorationColor: ThemeConfig.primaryGreen,
          decorationThickness: 2,
        ),
      ),
      child: Text(title),
    );
  }
}

class OutlineButton extends StatelessWidget {
  final String title;
  final VoidCallback onPressed;
  final bool? enabled;

  const OutlineButton({
    required this.title,
    required this.onPressed,
    this.enabled,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: enabled != false ? onPressed : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: ThemeConfig.primaryGreen,
        side: BorderSide(color: ThemeConfig.ruleStrong, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ThemeConfig.radiusBase),
        ),
        minimumSize: Size(double.infinity, ThemeConfig.buttonHeight),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        textStyle: TextStyle(
          fontFamily: ThemeConfig.bodyFontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Text(title),
    );
  }
}

class AppTextField extends StatelessWidget {
  final String label;
  final String? hintText;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int? maxLines;
  final int? maxLength;
  final Widget? suffixIcon;
  final bool? obscureText;
  final String? errorText;

  const AppTextField({
    required this.label,
    this.hintText,
    this.controller,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
    this.suffixIcon,
    this.obscureText,
    this.errorText,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        errorText: errorText,
        suffixIcon: suffixIcon,
      ),
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      obscureText: obscureText ?? false,
    );
  }
}