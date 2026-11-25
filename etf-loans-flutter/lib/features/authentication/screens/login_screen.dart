import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:etf_loans/features/authentication/screens/account_access_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:etf_loans/core/errors/app_errors.dart';
import 'package:etf_loans/features/authentication/models/auth_purpose.dart';
import 'package:etf_loans/features/authentication/screens/otp_verification_screen.dart';
import 'package:etf_loans/features/authentication/services/authentication_service.dart';
import 'package:etf_loans/features/authentication/services/mock_authentication_service.dart';
import 'package:etf_loans/core/network/network_service.dart';
import 'package:etf_loans/theme/theme_config.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.authenticationService});

  final AuthenticationService? authenticationService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _withPassword = true;
  bool _showPassword = false;
  bool _isLoading = false;
  String? _errorMessage;

  late final AuthenticationService _authService;

  late final AnimationController _screenController;
  late final AnimationController _illustrationController;
  late final Animation<double> _screenFade;
  late final Animation<Offset> _screenSlide;

  @override
  void initState() {
    super.initState();
    _authService = widget.authenticationService ??
        (kDebugMode && const bool.fromEnvironment('USE_MOCK_AUTH')
            ? MockAuthenticationService()
            : AuthenticationService(networkService: NetworkService()));

    _screenController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _illustrationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _screenFade = CurvedAnimation(parent: _screenController, curve: Curves.easeOut);
    _screenSlide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _screenController, curve: Curves.easeOut));

    _screenController.forward();
    _illustrationController.forward();

    _mobileController.addListener(_formatMobileNumber);
  }

  @override
  void dispose() {
    _mobileController.removeListener(_formatMobileNumber);
    _mobileController.dispose();
    _passwordController.dispose();
    _screenController.dispose();
    _illustrationController.dispose();
    if (widget.authenticationService == null) _authService.close();
    super.dispose();
  }

  void _formatMobileNumber() {
    final text = _mobileController.text;
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 10) return;
    final formatted = digits.length > 5
        ? '${digits.substring(0, 5)} ${digits.substring(5)}'
        : digits;
    if (formatted != text) {
      _mobileController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  String _getRawMobileNumber() {
    return _mobileController.text.replaceAll(RegExp(r'\D'), '');
  }

  Future<void> _validateAndSendOtp() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final mobileNumber = _getRawMobileNumber();
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(mobileNumber)) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Enter a valid 10-digit mobile number';
      });
      return;
    }

    try {
      final purpose = _withPassword ? AuthPurpose.passwordLogin : AuthPurpose.legacyLogin;
      final response = _withPassword
          ? await _authService.startPasswordFlow(
              purpose: purpose,
              mobileNumber: mobileNumber,
              password: _passwordController.text,
            )
          : await _authService.sendOtp(mobileNumber);
      if (!mounted) return;

      setState(() => _isLoading = false);

      if (response.success) {
        _passwordController.clear();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(
              mobileNumber: mobileNumber,
              challengeId: response.challengeId,
              expiresInSeconds: response.expirySeconds,
              resendAfterSeconds: response.resendAfterSeconds,
              developmentOtp: response.developmentOtp,
              purpose: purpose,
            ),
          ),
        );
      } else {
        _showError(response.message ?? 'Failed to send OTP');
      }
    } on AppError catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Something went wrong. Please try again.');
    }
  }

  void _showError(String message) {
    setState(() => _errorMessage = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ThemeConfig.errorRed,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () => setState(() => _errorMessage = null),
        ),
      ),
    );
  }

  Future<void> _handleDemoSkip() async {
    setState(() => _isLoading = true);
    try {
      final response = await _authService.sendOtp('9999999999');
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (response.success) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(
              mobileNumber: '9999999999',
              challengeId: response.challengeId,
              expiresInSeconds: response.expirySeconds,
              resendAfterSeconds: response.resendAfterSeconds,
              developmentOtp: response.developmentOtp,
            ),
          ),
        );
      } else {
        _showError(response.message ?? 'Demo login failed');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Demo login failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeConfig.paperBg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _screenFade,
          child: SlideTransition(
            position: _screenSlide,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    _buildTopBar().animate().fadeIn(duration: 300.ms, delay: 100.ms).slideY(begin: -0.1, end: 0, duration: 300.ms),
                    const SizedBox(height: 24),
                    _buildIllustration().animate().fadeIn(duration: 500.ms, delay: 200.ms).scale(begin: const Offset(0.9, 0.9), end: const Offset(1.0, 1.0), duration: 500.ms, curve: Curves.easeOutBack),
                    const SizedBox(height: 28),
                    _buildHeadSection().animate().fadeIn(duration: 300.ms, delay: 400.ms).slideY(begin: 0.1, end: 0, duration: 300.ms),
                    const SizedBox(height: 12),
                    _buildForm().animate().fadeIn(duration: 300.ms, delay: 500.ms).slideY(begin: 0.1, end: 0, duration: 300.ms),
                    const SizedBox(height: 24),
                    _buildPrimaryButton().animate().fadeIn(duration: 300.ms, delay: 600.ms).slideY(begin: 0.1, end: 0, duration: 300.ms),
                    const SizedBox(height: 16),
                    _buildLegalText().animate().fadeIn(duration: 300.ms, delay: 700.ms),
                    Wrap(
                      alignment: WrapAlignment.center,
                      children: [
                        for (final flow in [AccountAccess.create, AccountAccess.recover])
                          TextButton(
                            onPressed: _isLoading ? null : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(builder: (_) => AccountAccessScreen(flow: flow)),
                            ),
                            child: Text(flow.title),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildDemoSkipButton().animate().fadeIn(duration: 300.ms, delay: 800.ms),
                    SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          style: IconButton.styleFrom(
            foregroundColor: ThemeConfig.ink,
            backgroundColor: Colors.transparent,
          ),
        ),
        const SizedBox(width: 12),
        Image.asset(
          'assets/logos/logo.png',
          height: 30,
          width: 30,
          fit: BoxFit.contain,
        ),
      ],
    );
  }

  Widget _buildIllustration() {
    return Center(
      child: SvgPicture.asset(
        'assets/illustrations/login_art.svg',
        width: 132,
        height: 132 * 108 / 160,
        fit: BoxFit.contain,
        colorFilter: ColorFilter.mode(
          ThemeConfig.ink,
          BlendMode.srcIn,
        ),
      ),
    );
  }

  Widget _buildHeadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Sign in with your mobile',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _withPassword
              ? 'Enter your mobile number and password to request a verification code.'
              : 'If you haven’t set a password, sign in with a verification code.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: ThemeConfig.mutedText,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMobileField(),
          if (_withPassword) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              enabled: !_isLoading,
              obscureText: !_showPassword,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  tooltip: _showPassword ? 'Hide password' : 'Show password',
                  onPressed: _isLoading ? null : () => setState(() => _showPassword = !_showPassword),
                  icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                ),
              ),
              validator: (value) => value == null || value.isEmpty ? 'Enter your password' : null,
              onFieldSubmitted: (_) => _validateAndSendOtp(),
            ),
          ],
          TextButton(
            onPressed: _isLoading ? null : () {
              _passwordController.clear();
              setState(() {
                _withPassword = !_withPassword;
                _showPassword = false;
                _errorMessage = null;
              });
            },
            child: Text(_withPassword ? 'Sign in without a password' : 'Sign in with a password'),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ThemeConfig.errorRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(ThemeConfig.radiusBase),
                border: Border.all(color: ThemeConfig.errorRed, width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: ThemeConfig.errorRed, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: ThemeConfig.errorRed,
                        fontFamily: ThemeConfig.bodyFontFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMobileField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Mobile number',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _mobileController,
          enabled: !_isLoading,
          keyboardType: TextInputType.phone,
          maxLength: 11,
          decoration: InputDecoration(
            prefixText: '+91 ',
            prefixStyle: TextStyle(
              fontFamily: ThemeConfig.bodyFontFamily,
              fontSize: ThemeConfig.inputFontSize,
              fontWeight: FontWeight.w500,
              color: ThemeConfig.mutedText,
            ),
            hintText: '98765 43210',
            counterText: '',
          ),
          validator: (value) {
            final digits = value?.replaceAll(RegExp(r'\D'), '') ?? '';
            if (digits.isEmpty) return 'Mobile number is required';
            if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
              return 'Enter a valid 10-digit mobile number';
            }
            return null;
          },
          textInputAction: _withPassword ? TextInputAction.next : TextInputAction.done,
          onFieldSubmitted: _withPassword ? null : (_) => _validateAndSendOtp(),
        ),
        const SizedBox(height: 6),
        Text(
          'One number, one account. We use it for your loan and payment reminders only.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: 13,
            color: ThemeConfig.mutedText,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _isLoading
          ? SizedBox(
              key: const ValueKey('loading'),
              height: ThemeConfig.buttonHeight,
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(ThemeConfig.onDeep),
                  ),
                ),
              ),
            )
          : ElevatedButton(
              key: const ValueKey('button'),
              onPressed: _validateAndSendOtp,
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
              ),
              child: Text(
                'Send code',
                style: TextStyle(
                  fontFamily: ThemeConfig.headingFontFamily,
                  fontSize: ThemeConfig.buttonFontSize,
                  fontWeight: ThemeConfig.buttonFontWeight,
                  letterSpacing: -0.16,
                ),
              ),
            ),
    );
  }

  Widget _buildLegalText() {
    return Column(
      children: [
        Text('By continuing you agree to our', style: Theme.of(context).textTheme.labelSmall),
        const AuthenticationLegalLinks(),
      ],
    );
  }

  Widget _buildDemoSkipButton() {
    if (kDebugMode && const bool.fromEnvironment('USE_MOCK_AUTH')) {
      return TextButton(
        onPressed: _isLoading ? null : _handleDemoSkip,
        style: TextButton.styleFrom(
          foregroundColor: ThemeConfig.mutedText,
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
        child: Text(
          'Skip sign-in (demo)',
          style: TextStyle(
            fontFamily: ThemeConfig.bodyFontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            decoration: TextDecoration.underline,
            decorationColor: ThemeConfig.mutedText,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
