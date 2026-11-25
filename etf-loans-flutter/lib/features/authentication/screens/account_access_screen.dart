import 'dart:convert';

import 'package:etf_loans/core/constants/app_routes.dart';
import 'package:etf_loans/core/errors/app_errors.dart';
import 'package:etf_loans/features/authentication/models/auth_purpose.dart';
import 'package:etf_loans/features/authentication/screens/otp_verification_screen.dart';
import 'package:etf_loans/features/authentication/services/authentication_service.dart';
import 'package:etf_loans/shared/widgets/custom_widgets.dart';
import 'package:etf_loans/theme/theme_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum AccountAccess {
  create('Create account'),
  setPassword('Set password'),
  recover('Forgot password'),
  resetPassword('Set new password');

  const AccountAccess(this.title);

  final String title;

  bool get requiresPassword => this == setPassword || this == resetPassword;

  AuthPurpose get purpose => this == create || this == setPassword
      ? AuthPurpose.registration
      : AuthPurpose.recovery;
}

class AccountAccessScreen extends StatefulWidget {
  const AccountAccessScreen({required this.flow, this.grant, super.key});

  final AccountAccess flow;
  final String? grant;

  @override
  State<AccountAccessScreen> createState() => _AccountAccessScreenState();
}

class _AccountAccessScreenState extends State<AccountAccessScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _mobile = TextEditingController();
  final _auth = AuthenticationService();
  bool _showPassword = false;
  bool _showConfirmation = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _mobile.dispose();
    _auth.close();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final flow = widget.flow;
    try {
      if (flow.requiresPassword) {
        final grant = widget.grant;
        if (grant == null) {
          throw ServerException('Request a verification code to continue.');
        }
        await _auth.completePasswordFlow(
          purpose: flow.purpose,
          grant: grant,
          password: _password.text,
        );
        if (!mounted) return;
        _password.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password saved. Sign in to continue.')),
        );
        Navigator.popUntil(
          context,
          (route) => route.settings.name == AppRoutes.signIn || route.isFirst,
        );
      } else {
        final mobile = _mobile.text;
        final response = await _auth.startPasswordFlow(
          purpose: flow.purpose,
          mobileNumber: mobile,
        );
        if (!mounted) return;
        final challengeId = response.challengeId;
        if (!response.success || challengeId == null || challengeId.isEmpty) {
          throw ServerException('Could not request a verification code.');
        }
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => OtpVerificationScreen(
              mobileNumber: mobile,
              challengeId: challengeId,
              expiresInSeconds: response.expirySeconds,
              resendAfterSeconds: response.resendAfterSeconds,
              developmentOtp: response.developmentOtp,
              purpose: flow.purpose,
              passwordScreen: (grant) => AccountAccessScreen(
                flow: flow == AccountAccess.create
                    ? AccountAccess.setPassword
                    : AccountAccess.resetPassword,
                grant: grant,
              ),
            ),
          ),
        );
      }
    } on AppError catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final flow = widget.flow;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AutofillGroup(
                onDisposeAction: AutofillContextAction.cancel,
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Image.asset(
                          'assets/logos/logo.png',
                          width: 32,
                          height: 32,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(flow.title, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text(
                        flow.requiresPassword
                            ? 'Enter and confirm your new password.'
                            : 'Enter the mobile number for your account.',
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 24),
                      if (flow.requiresPassword) ...[
                        _passwordField(confirmation: false),
                        const SizedBox(height: 16),
                        _passwordField(confirmation: true),
                      ] else
                        TextFormField(
                          controller: _mobile,
                          enabled: !_busy,
                          decoration: const InputDecoration(
                            labelText: 'Mobile number',
                            prefixText: '+91 ',
                          ),
                          keyboardType: TextInputType.phone,
                          autofillHints: const [
                            AutofillHints.telephoneNumberNational,
                          ],
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          validator: (value) =>
                              RegExp(r'^[6-9]\d{9}$').hasMatch(value ?? '')
                              ? null
                              : 'Enter a valid 10-digit mobile number',
                          onFieldSubmitted: (_) => _submit(),
                        ),
                      const SizedBox(height: 20),
                      PrimaryButton(
                        title: flow.requiresPassword
                            ? 'Save password'
                            : 'Send code',
                        onPressed: _submit,
                        isLoading: _busy,
                      ),
                      if (_error != null)
                        Semantics(
                          liveRegion: true,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              _error!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: ThemeConfig.errorRed,
                              ),
                            ),
                          ),
                        ),
                      if (flow == AccountAccess.create)
                        const AuthenticationLegalLinks(),
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

  Widget _passwordField({required bool confirmation}) {
    final visible = confirmation ? _showConfirmation : _showPassword;
    return TextFormField(
      controller: confirmation ? null : _password,
      enabled: !_busy,
      obscureText: !visible,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: confirmation
          ? TextInputAction.done
          : TextInputAction.next,
      decoration: InputDecoration(
        labelText: confirmation ? 'Confirm password' : 'New password',
        suffixIcon: IconButton(
          tooltip: visible ? 'Hide password' : 'Show password',
          onPressed: _busy
              ? null
              : () => setState(() {
                  if (confirmation) {
                    _showConfirmation = !_showConfirmation;
                  } else {
                    _showPassword = !_showPassword;
                  }
                }),
          icon: Icon(
            visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          ),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Enter your password';
        if (confirmation && value != _password.text)
          return 'Passwords do not match';
        if (!confirmation &&
            (value.trim().isEmpty ||
                value.runes.length < 12 ||
                utf8.encode(value).length > 72)) {
          return 'Use at least 12 characters and at most 72 UTF-8 bytes.';
        }
        return null;
      },
      onFieldSubmitted: confirmation ? (_) => _submit() : null,
    );
  }
}

class AuthenticationLegalLinks extends StatelessWidget {
  const AuthenticationLegalLinks({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        TextButton(
          onPressed: () => Navigator.pushNamed(context, AppRoutes.terms),
          child: const Text('Terms of Service'),
        ),
        TextButton(
          onPressed: () => Navigator.pushNamed(context, AppRoutes.privacy),
          child: const Text('Privacy Policy'),
        ),
      ],
    );
  }
}
