import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:etf_loans/core/errors/app_errors.dart';
import 'package:etf_loans/features/authentication/services/authentication_service.dart';
import 'package:etf_loans/features/authentication/services/mock_authentication_service.dart';
import 'package:etf_loans/core/network/network_service.dart';
import 'package:etf_loans/theme/theme_config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:etf_loans/features/authentication/models/auth_models.dart';
import 'package:etf_loans/features/authentication/screens/home_screen.dart';

/// Interface for secure storage to allow test mocking.
abstract class SecureStorage {
  Future<void> write({required String key, required String value});
}

class _FlutterSecureStorageAdapter implements SecureStorage {
  final FlutterSecureStorage _storage;
  _FlutterSecureStorageAdapter(this._storage);

  @override
  Future<void> write({required String key, required String value}) =>
      _storage.write(key: key, value: value);
}

class OtpVerificationScreen extends StatefulWidget {
  final String mobileNumber;
  final String? challengeId;
  final int? expiresInSeconds;
  final int? resendAfterSeconds;
  final String? developmentOtp;
  final SecureStorage? secureStorage;

  const OtpVerificationScreen({
    required this.mobileNumber,
    this.challengeId,
    this.expiresInSeconds,
    this.resendAfterSeconds,
    this.developmentOtp,
    this.secureStorage,
    super.key,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen>
    with TickerProviderStateMixin {
  late final TextEditingController _hiddenController;
  late final FocusNode _hiddenFocusNode;
  late final AuthenticationService _authService;
  late final SecureStorage _secureStorage;

  String _otp = '';
  OtpState _state = OtpState.empty;
  String? _errorMessage;
  String? _statusMessage;
  int _resendCountdown = 0;
  bool _isResending = false;
  bool _verificationInProgress = false;

  late final AnimationController _caretController;
  late final AnimationController _checkController;
  late final AnimationController _errorController;
  late final AnimationController _successController;
  late final AnimationController _countdownController;

  late final Animation<double> _caretAnimation;
  late final Animation<double> _checkAnimation;
  late final Animation<double> _errorShakeAnimation;
  late final List<Animation<double>> _successTileAnimations;
  late final Animation<int> _countdownAnimation;

  @override
  void initState() {
    super.initState();
    _hiddenController = TextEditingController();
    _hiddenFocusNode = FocusNode();
    _authService = const bool.fromEnvironment('USE_MOCK_AUTH', defaultValue: false)
        ? MockAuthenticationService()
        : AuthenticationService(networkService: NetworkService());
    _secureStorage = widget.secureStorage ??
        _FlutterSecureStorageAdapter(const FlutterSecureStorage());

    _resendCountdown = widget.resendAfterSeconds ?? 30;

    _caretController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    _checkController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    _errorController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _successController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _countdownController = AnimationController(
      duration: Duration(seconds: _resendCountdown),
      vsync: this,
    );

    _caretAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _caretController, curve: Curves.easeInOut),
    );

    _checkAnimation = CurvedAnimation(
      parent: _checkController,
      curve: Curves.easeInOut,
    );

    _errorShakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _errorController, curve: Curves.elasticIn),
    );

    _successTileAnimations = List.generate(6, (index) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _successController,
          curve: Interval(
            index * 0.08,
            (index * 0.08) + 0.3,
            curve: Curves.easeOutBack,
          ),
        ),
      );
    });

    _countdownAnimation = IntTween(
      begin: _resendCountdown,
      end: 0,
    ).animate(_countdownController);

    _hiddenController.addListener(_onHiddenInputChanged);
    _countdownController.addListener(_onCountdownTick);
    _countdownController.forward();

    // Focus the hidden input for autofill
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hiddenFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _hiddenController.removeListener(_onHiddenInputChanged);
    _hiddenController.dispose();
    _hiddenFocusNode.dispose();
    _caretController.dispose();
    _checkController.dispose();
    _errorController.dispose();
    _successController.dispose();
    _countdownController.dispose();
    _authService.close();
    super.dispose();
  }

  void _onHiddenInputChanged() {
    final input = _hiddenController.text.replaceAll(RegExp(r'\D'), '');
    final newOtp = input.length > 6 ? input.substring(0, 6) : input;

    if (newOtp != _otp) {
      setState(() {
        _otp = newOtp;
        if (_state == OtpState.error) {
          _state = OtpState.typing;
          _errorMessage = null;
        }
      });

      // Trigger verification only when OTP is complete and not already verifying
      if (_otp.length == 6 && 
          _state != OtpState.checking && 
          _state != OtpState.success && 
          !_verificationInProgress) {
        _verifyOtp();
      }
    }
  }

  void _onCountdownTick() {
    if (!_countdownController.isAnimating) return;
    setState(() {
      _resendCountdown = _countdownAnimation.value;
    });
  }

  Future<void> _verifyOtp() async {
    if (_verificationInProgress || _state == OtpState.success) return;
    if (widget.challengeId == null) {
      _showError('Invalid session. Please request a new code.');
      return;
    }

    setState(() {
      _verificationInProgress = true;
      _state = OtpState.checking;
    });
    _checkController.forward(from: 0);

    try {
      final response = await _authService.verifyOtp(
        challengeId: widget.challengeId!,
        mobileNumber: widget.mobileNumber,
        otp: _otp,
      );

      if (!mounted) return;

      _checkController.stop();

      if (response.success) {
        _state = OtpState.success;
        _statusMessage = 'Verified';
        _successController.forward(from: 0);
        _accessToken = response.accessToken;
        await _secureStorage.write(
          key: 'accessToken',
          value: response.accessToken ?? '',
        );

        // Navigate after success animation
        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;
        _navigateToSuccess();
      } else {
        _state = OtpState.error;
        _errorMessage = response.message ?? 'Invalid OTP';
        _errorController.forward(from: 0);
        _countdownController
            .reset(); // Reset countdown on error per spec
        _resendCountdown = widget.resendAfterSeconds ?? 30;
        _countdownController.forward(from: 0);
      }
    } on AppError catch (e) {
      if (!mounted) return;
      _checkController.stop();
      _state = OtpState.error;
      _errorMessage = e.message;
      _errorController.forward(from: 0);
      _countdownController.reset();
      _resendCountdown = widget.resendAfterSeconds ?? 30;
      _countdownController.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      _checkController.stop();
      _state = OtpState.error;
      _errorMessage = 'Something went wrong. Please try again.';
      _errorController.forward(from: 0);
      _countdownController.reset();
      _resendCountdown = widget.resendAfterSeconds ?? 30;
      _countdownController.forward(from: 0);
    } finally {
      if (mounted) {
        setState(() {
          _verificationInProgress = false;
        });
      }
    }
  }

  Future<void> _resendOtp() async {
    if (_isResending || _resendCountdown > 0) return;

    setState(() => _isResending = true);

    try {
      final response = await _authService.sendOtp(widget.mobileNumber);
      if (!mounted) return;

      setState(() => _isResending = false);

      if (response.success) {
        // Update challenge ID and reset countdown
        _resendCountdown = response.resendAfterSeconds ?? 30;
        _countdownController
          ..reset()
          ..forward();
        _showStatus('New code sent', isSuccess: true);
      } else {
        _showError(response.message ?? 'Failed to resend code');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isResending = false);
      _showError('Failed to resend code. Please try again.');
    }
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
      _statusMessage = null;
    });
  }

  void _showStatus(String message, {bool isSuccess = false}) {
    setState(() {
      _statusMessage = message;
      _errorMessage = null;
    });
  }

  void _navigateToSuccess() {
    if (!mounted) return;
    
    // Create a minimal UserProfile from the verification response data
    // We have the mobile number, and the token. We'll fetch the full profile in HomeScreen.
    final userProfile = UserProfile(
      id: '', // Will be fetched in HomeScreen
      mobileNumber: widget.mobileNumber,
      name: '',
      email: null,
      createdAt: null,
    );
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          initialUser: userProfile,
          initialToken: _accessToken,
        ),
      ),
    );
  }

  String? _accessToken;

  void _goBackToLogin() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 360;
    final tileSize = isNarrow ? 54.0 : 62.0;
    final tileGap = isNarrow ? 7.0 : 10.0;
    final digitFontSize = isNarrow ? 24.0 : 28.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F9F6), // OTP page background
      body: Stack(
        children: [
          // Iridescent background
          const _IridescentBackground(),
          // Main content
          SafeArea(
            child: Column(
              children: [
                // Topbar
                _buildTopBar(),
                // OTP Body
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 24),
                          _buildHeading(),
                          const SizedBox(height: 36),
                          _buildOtpTiles(tileSize, tileGap, digitFontSize),
                          const SizedBox(height: 18),
                          _buildStatus(),
                          const SizedBox(height: 18),
                          _buildResendFooter(),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Hidden input for autofill
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: _hiddenController,
                focusNode: _hiddenFocusNode,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                autofillHints: const [AutofillHints.oneTimeCode],
                maxLength: 6,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  counterText: '',
                ),
                style: const TextStyle(
                  color: Colors.transparent,
                  fontSize: 16,
                ),
                cursorColor: Colors.transparent,
                enableSuggestions: false,
                autocorrect: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: _goBackToLogin,
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
      ),
    );
  }

  Widget _buildHeading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Enter the code',
          style: TextStyle(
            fontFamily: ThemeConfig.headingFontFamily,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: ThemeConfig.ink,
            letterSpacing: -0.02,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Sent to ',
              style: TextStyle(
                fontFamily: ThemeConfig.bodyFontFamily,
                fontSize: 15,
                color: const Color(0xFF34503F),
                height: 1.4,
              ),
            ),
            Text(
              _formatMobileNumber(widget.mobileNumber),
              style: TextStyle(
                fontFamily: ThemeConfig.bodyFontFamily,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: ThemeConfig.ink,
                height: 1.4,
              ),
            ),
            const SizedBox(width: 8),
            _buildEditButton(),
          ],
        ),
        if (widget.developmentOtp != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: ThemeConfig.primaryGreen.withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              'Development code: ${widget.developmentOtp}',
              style: TextStyle(
                fontFamily: ThemeConfig.bodyFontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ThemeConfig.primaryGreen,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEditButton() {
    return TextButton(
      onPressed: _goBackToLogin,
      style: TextButton.styleFrom(
        foregroundColor: ThemeConfig.primaryGreen,
        backgroundColor: Colors.white.withValues(alpha: 0.7),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(
            color: ThemeConfig.primaryGreen.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
      ),
      child: Text(
        'Edit',
        style: TextStyle(
          fontFamily: ThemeConfig.bodyFontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildOtpTiles(double tileSize, double tileGap, double digitFontSize) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        
        // Calculate responsive tile size based on available width
        // 6 tiles + 5 gaps = total width
        // tileSize * 6 + tileGap * 5 <= maxWidth
        // tileSize = (maxWidth - tileGap * 5) / 6
        const tileCount = 6;
        const gapCount = tileCount - 1;
        const minTileSize = 44.0;
        const minGap = 6.0;
        
        double calculatedTileSize = tileSize;
        double calculatedGap = tileGap;
        double calculatedFontSize = digitFontSize;
        
        // If fixed size doesn't fit, calculate responsive size
        final fixedWidth = tileSize * tileCount + tileGap * gapCount;
        if (fixedWidth > maxWidth) {
          calculatedGap = minGap;
          calculatedTileSize = ((maxWidth - calculatedGap * gapCount) / tileCount).clamp(minTileSize, tileSize);
          // Scale font size proportionally
          calculatedFontSize = (digitFontSize * (calculatedTileSize / tileSize)).clamp(20.0, digitFontSize);
        }
        
        return SizedBox(
          width: maxWidth,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (index) {
              final digit = index < _otp.length ? _otp[index] : '';
              final isActive = _state == OtpState.typing && index == _otp.length && _otp.length < 6;
              final isFilled = index < _otp.length;
              final isError = _state == OtpState.error;
              final isSuccess = _state == OtpState.success;
              final isChecking = _state == OtpState.checking;

              return AnimatedBuilder(
                animation: Listenable.merge([
                  _caretController,
                  _checkController,
                  _errorController,
                  _successController,
                ]),
                builder: (context, child) {
                  return _OtpTile(
                    index: index,
                    digit: digit,
                    isActive: isActive,
                    isFilled: isFilled,
                    isError: isError,
                    isSuccess: isSuccess,
                    isChecking: isChecking,
                    caretAnimation: _caretAnimation,
                    checkAnimation: _checkAnimation,
                    errorAnimation: _errorShakeAnimation,
                    successAnimation: _successTileAnimations[index],
                    caretController: _caretController,
                    checkController: _checkController,
                    tileSize: calculatedTileSize,
                    digitFontSize: calculatedFontSize,
                    tileGap: calculatedGap,
                  );
                },
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildStatus() {
    if (_state == OtpState.success) {
      return AnimatedBuilder(
        animation: _successController,
        builder: (context, child) {
          return Opacity(
            opacity: _successController.value,
            child: Transform.translate(
              offset: Offset(0, (1 - _successController.value) * 4),
              child: _StatusIndicator.success(),
            ),
          );
        },
      );
    }

    if (_state == OtpState.error) {
      return AnimatedBuilder(
        animation: _errorController,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(_errorShakeAnimation.value * 6, 0),
            child: _StatusIndicator.error(_errorMessage ?? 'Invalid OTP'),
          );
        },
      );
    }

    if (_state == OtpState.checking) {
      return _StatusIndicator.checking();
    }

    if (_statusMessage != null) {
      return _StatusIndicator.info(_statusMessage!);
    }

    return const SizedBox(height: 26);
  }

  Widget _buildResendFooter() {
    if (_resendCountdown > 0) {
      return Text(
        'Resend in 0:${_resendCountdown.toString().padLeft(2, '0')}',
        style: TextStyle(
          fontFamily: ThemeConfig.bodyFontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF4D6858),
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
    }

    return ElevatedButton(
      onPressed: _isResending ? null : _resendOtp,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.75),
        foregroundColor: ThemeConfig.primaryGreen,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(
            color: ThemeConfig.primaryGreen.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
      ),
      child: _isResending
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(ThemeConfig.primaryGreen),
              ),
            )
          : Text(
              'Resend code',
              style: TextStyle(
                fontFamily: ThemeConfig.bodyFontFamily,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }

  String _formatMobileNumber(String mobile) {
    final digits = mobile.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
    }
    return mobile;
  }
}

enum OtpState { empty, typing, checking, error, success }

class _IridescentBackground extends StatelessWidget {
  const _IridescentBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base background
        Container(color: const Color(0xFFF5F9F6)),
        // Conic gradient layer
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _IriConicPainter(),
            ),
          ),
        ),
        // Sheen layer
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _IriSheenPainter(),
            ),
          ),
        ),
        // Radial highlight
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.4),
                  radius: 1.2,
                  colors: [
                    const Color(0xFFF7FDFB).withValues(alpha: 0.55),
                    const Color(0xFFF7FDFB).withValues(alpha: 0.1),
                  ],
                  stops: const [0.0, 0.7],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _IriConicPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.9;

    final rect = Rect.fromCircle(center: center, radius: radius);

    final gradient = SweepGradient(
      startAngle: 0,
      endAngle: 2 * 3.14159,
      colors: const [
        Color(0xFFBDF0D6),
        Color(0xFFD9F7B5),
        Color(0xFFB9E8F5),
        Color(0xFFDCD6FB),
        Color(0xFFFDE0CF),
        Color(0xFFC8F3E0),
        Color(0xFFBDF0D6),
      ],
      stops: const [0.0, 0.16, 0.33, 0.5, 0.66, 0.83, 1.0],
    ).createShader(rect);

    final paint = Paint()
      ..shader = gradient
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 48);

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _IriSheenPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gradient = LinearGradient(
      begin: const Alignment(-1, -0.5),
      end: const Alignment(1, 0.5),
      colors: [
        Colors.transparent,
        Colors.white.withValues(alpha: 0.55),
        Colors.transparent,
        Colors.white.withValues(alpha: 0.35),
        Colors.transparent,
      ],
      stops: const [0.2, 0.32, 0.44, 0.58, 0.7],
      transform: const GradientRotation(-0.5),
    ).createShader(Offset.zero & size);

    final paint = Paint()
      ..shader = gradient
      ..blendMode = BlendMode.softLight;

    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OtpTile extends StatelessWidget {
  final int index;
  final String digit;
  final bool isActive;
  final bool isFilled;
  final bool isError;
  final bool isSuccess;
  final bool isChecking;
  final Animation<double> caretAnimation;
  final Animation<double> checkAnimation;
  final Animation<double> errorAnimation;
  final Animation<double> successAnimation;
  final AnimationController caretController;
  final AnimationController checkController;
  final double tileSize;
  final double digitFontSize;
  final double tileGap;

  const _OtpTile({
    required this.index,
    required this.digit,
    required this.isActive,
    required this.isFilled,
    required this.isError,
    required this.isSuccess,
    required this.isChecking,
    required this.caretAnimation,
    required this.checkAnimation,
    required this.errorAnimation,
    required this.successAnimation,
    required this.caretController,
    required this.checkController,
    required this.tileSize,
    required this.digitFontSize,
    required this.tileGap,
  });

  @override
  Widget build(BuildContext context) {
    final isFilledLocal = isFilled;

    Color borderColor;
    Color backgroundColor;
    Color digitColor;
    double borderWidth = 1.5;
    List<BoxShadow> shadows = [
      BoxShadow(
        color: const Color(0x0F0A2E1B),
        offset: const Offset(0, 1),
        blurRadius: 2,
      ),
      BoxShadow(
        color: const Color(0x590A2E1B),
        offset: const Offset(0, 10),
        blurRadius: 22,
        spreadRadius: -14,
      ),
    ];

    if (isSuccess) {
      borderColor = ThemeConfig.primaryGreen;
      backgroundColor = ThemeConfig.primaryGreen;
      digitColor = Colors.white;
      borderWidth = 1.5;
      shadows = [
        BoxShadow(
          color: const Color(0xB315803F),
          offset: const Offset(0, 10),
          blurRadius: 24,
          spreadRadius: -12,
        ),
      ];
    } else if (isError) {
      borderColor = ThemeConfig.errorRed;
      backgroundColor = const Color(0xFFFFF4F2);
      digitColor = ThemeConfig.errorRed;
      borderWidth = 2;
      shadows = [
        BoxShadow(
          color: const Color(0x1EC0392B),
          offset: const Offset(0, 0),
          blurRadius: 0,
          spreadRadius: 4,
        ),
        BoxShadow(
          color: const Color(0x590A2E1B),
          offset: const Offset(0, 10),
          blurRadius: 22,
          spreadRadius: -14,
        ),
      ];
    } else if (isChecking) {
      borderColor = ThemeConfig.primaryGreen;
      backgroundColor = Colors.white;
      digitColor = ThemeConfig.ink;
      borderWidth = 1.5;
      shadows = [
        BoxShadow(
          color: const Color(0x2315803F),
          offset: const Offset(0, 0),
          blurRadius: 0,
          spreadRadius: 4,
        ),
        BoxShadow(
          color: const Color(0x660A2E1B),
          offset: const Offset(0, 14),
          blurRadius: 22,
          spreadRadius: -14,
        ),
      ];
    } else if (isActive) {
      borderColor = ThemeConfig.primaryGreen;
      backgroundColor = Colors.white;
      digitColor = ThemeConfig.ink;
      borderWidth = 2;
      shadows = [
        BoxShadow(
          color: const Color(0x2915803F),
          offset: const Offset(0, 0),
          blurRadius: 0,
          spreadRadius: 4,
        ),
        BoxShadow(
          color: const Color(0x590A2E1B),
          offset: const Offset(0, 10),
          blurRadius: 22,
          spreadRadius: -14,
        ),
      ];
    } else if (isFilledLocal) {
      borderColor = const Color(0x800A2E1B);
      backgroundColor = Colors.white;
      digitColor = ThemeConfig.ink;
    } else {
      borderColor = const Color(0x380A2E1B);
      backgroundColor = Colors.white;
      digitColor = ThemeConfig.ink;
    }

    double transformY = 0;
    double scale = 1.0;

    if (isActive) {
      transformY = -2;
    } else if (isChecking) {
      final waveValue = math.sin((checkController.value * 2 * math.pi) - (index * 0.16));
      transformY = -6 * waveValue.clamp(-1.0, 0.0).abs();
    } else if (isSuccess) {
      scale = 1.0 + (0.08 * successAnimation.value);
    } else if (isError) {
      // Shake handled by parent
    }

    return Padding(
      padding: EdgeInsets.only(right: index == 5 ? 0 : tileGap),
      child: Transform.translate(
        offset: Offset(0, transformY),
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: tileSize,
            height: tileSize,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: borderWidth),
              boxShadow: shadows,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Digit
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    fontFamily: 'sans-serif', // System font fallback
                    fontSize: digitFontSize,
                    fontWeight: FontWeight.w800,
                    color: digitColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    letterSpacing: -0.02,
                  ),
                  child: Text(digit),
                ),
                // Caret
                if (isActive && !isFilledLocal)
                  AnimatedBuilder(
                    animation: caretAnimation,
                    builder: (context, child) {
                      return Opacity(
                        opacity: caretAnimation.value,
                        child: Container(
                          width: 2,
                          height: 26,
                          decoration: BoxDecoration(
                            color: ThemeConfig.primaryGreen,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    },
                  ),
                // Success checkmark (built into digit color change)
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final String? message;
  final bool isError;
  final bool isChecking;
  final bool isSuccess;

  const _StatusIndicator.success()
      : message = null,
        isError = false,
        isChecking = false,
        isSuccess = true;

  const _StatusIndicator.error(this.message)
      : isError = true,
        isChecking = false,
        isSuccess = false;

  const _StatusIndicator.checking()
      : message = null,
        isError = false,
        isChecking = true,
        isSuccess = false;

  const _StatusIndicator.info(this.message)
      : isError = false,
        isChecking = false,
        isSuccess = false;

  @override
  Widget build(BuildContext context) {
    if (isSuccess) {
      return _StatusContent(
        icon: Icons.check_circle,
        iconColor: ThemeConfig.primaryGreen,
        textColor: ThemeConfig.primaryGreen,
        child: const SizedBox.shrink(),
      );
    }

    if (isError) {
      return _StatusContent(
        iconColor: ThemeConfig.errorRed,
        textColor: ThemeConfig.errorRed,
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: ThemeConfig.errorRed,
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text(
              '!',
              style: TextStyle(
                fontFamily: 'sans-serif',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
        text: message,
      );
    }

    if (isChecking) {
      return _StatusContent(
        iconColor: ThemeConfig.primaryGreen,
        textColor: ThemeConfig.primaryGreen,
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(ThemeConfig.primaryGreen),
          ),
        ),
        text: 'Checking',
      );
    }

    if (message != null) {
      return _StatusContent(
        iconColor: ThemeConfig.primaryGreen,
        textColor: ThemeConfig.primaryGreen,
        child: const Icon(Icons.check_circle, size: 20),
        text: message,
      );
    }

    return const SizedBox(height: 26);
  }
}

class _StatusContent extends StatelessWidget {
  final Color iconColor;
  final Color textColor;
  final Widget child;
  final String? text;
  final IconData? icon;

  const _StatusContent({
    required this.iconColor,
    required this.textColor,
    required this.child,
    this.text,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 26,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null)
            Icon(icon, size: 20, color: iconColor)
          else
            child,
          if (text != null) ...[
            const SizedBox(width: 8),
            Text(
              text!,
              style: TextStyle(
                fontFamily: 'sans-serif',
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}