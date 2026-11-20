import 'package:flutter/material.dart';

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
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF15703B),
        ),
      ),
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