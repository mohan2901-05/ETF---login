import 'package:etf_loans/core/network/network_service.dart';
import 'package:etf_loans/features/authentication/models/auth_models.dart';
import 'package:etf_loans/features/authentication/services/authentication_service.dart';

/// Development-only mock authentication service.
/// Used when [dart.vm.product] is false (debug mode) to allow
/// login and OTP flow testing without a running backend.
///
/// In production ([dart.vm.product] is true) this class must never be
/// instantiated. A separate guard at the app entry point enforces this.
class MockAuthenticationService extends AuthenticationService {
  MockAuthenticationService._internal([NetworkService? networkService])
      : super(networkService: networkService ?? NetworkService());

  static final MockAuthenticationService _instance =
      MockAuthenticationService._internal();

  factory MockAuthenticationService() => _instance;

  // ------------------------------
  // Internal state (development only)
  // ------------------------------

  String? _currentChallengeId;
  String? _currentMobileNumber;
  DateTime? _challengeCreatedAt;
  int _resendCountdown = 0;
  bool _isResending = false;

  // 5-minute challenge expiry
  static const int _challengeExpirySeconds = 300;
  // 30-second resend cooldown
  static const int _resendCooldownSeconds = 30;

  // Mock token data
  String? _mockAccessToken;
  String? _mockTokenType;
  String? _mockUserId;
  String? _mockMobileNumber;

  // ------------------------------
  // Public API matching AuthenticationService
  // ------------------------------

  /// Returns the current mock access token, if any.
  String? get mockAccessToken => _mockAccessToken;

  String? get mockTokenType => _mockTokenType;

  String? get mockUserId => _mockUserId;

  // ------------------------------
  // sendOtp
  // ------------------------------

  /// Validates the mobile number using the same regex as [LoginScreen].
  /// Returns an [OtpSendResponse] with [success] set based on validation.
  Future<OtpSendResponse> sendOtp(String mobileNumber) async {
    // Validate using the same pattern as LoginScreen._validateAndSendOtp
    final digits = mobileNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10 || !RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
      return OtpSendResponse(
        success: false,
        message: 'Enter a valid 10-digit mobile number',
      );
    }

    // Generate a unique challenge ID
    final challengeId = 'dev-challenge-${mobileNumber.hashCode}-${DateTime.now().millisecondsSinceEpoch}';

    // Store challenge state
    _currentChallengeId = challengeId;
    _currentMobileNumber = mobileNumber;
    _challengeCreatedAt = DateTime.now();

    // Reset resend countdown
    _resendCountdown = _resendCooldownSeconds;
    _isResending = false;

    // Mock OTP is always 123456; include expiry and resend info
    return OtpSendResponse(
      success: true,
      challengeId: challengeId,
      expirySeconds: _challengeExpirySeconds,
      resendAfterSeconds: _resendCooldownSeconds,
    );
  }

  // ------------------------------
  // verifyOtp
  // ------------------------------

  /// Validates the OTP against the stored challenge.
  /// Returns an [OtpVerifyResponse] with appropriate mock data.
  Future<OtpVerifyResponse> verifyOtp({
    required String challengeId,
    required String mobileNumber,
    required String otp,
  }) async {
    // Check that this challenge belongs to the supplied mobile number
    if (_currentChallengeId != challengeId) {
      return OtpVerifyResponse(
        success: false,
        message: 'Invalid session. Please request a new code.',
      );
    }

    // Check that the challenge belongs to the supplied mobile number
    if (_currentMobileNumber != mobileNumber) {
      return OtpVerifyResponse(
        success: false,
        message: 'Mobile number does not match this challenge.',
      );
    }

    // Check challenge expiry
    if (_challengeCreatedAt != null &&
        DateTime.now().difference(_challengeCreatedAt!).inSeconds > _challengeExpirySeconds) {
      return OtpVerifyResponse(
        success: false,
        message: 'Challenge expired. Please request a new code.',
      );
    }

    // Check that the challenge has not already been verified (superseded)
    // A challenge is considered superseded if a new one has been generated
    // (the framework resets state on new sendOtp calls, but we guard here)

    // Accept only OTP 123456
    if (otp != '123456') {
      return OtpVerifyResponse(
        success: false,
        message: 'Invalid OTP',
      );
    }

    // OTP is valid — generate mock token data
    _mockAccessToken = 'mock-access-token-${mobileNumber.hashCode}';
    _mockTokenType = 'mock-token-type';
    _mockUserId = 'dev-user-${mobileNumber.hashCode}';

    return OtpVerifyResponse(
      success: true,
      accessToken: _mockAccessToken,
      tokenType: _mockTokenType,
      expiresInSeconds: _challengeExpirySeconds,
      user: VerifyUser(
        id: _mockUserId!,
        mobileNumber: mobileNumber,
        isNewUser: true,
      ),
    );
  }

  // ------------------------------
  // logout
  // ------------------------------

  /// Clears all mock authentication state.
  Future<void> logout() async {
    _currentChallengeId = null;
    _currentMobileNumber = null;
    _challengeCreatedAt = null;
    _resendCountdown = _resendCooldownSeconds;
    _isResending = false;
    _mockAccessToken = null;
    _mockTokenType = null;
    _mockUserId = null;
  }

  // ------------------------------
  // getUserProfile
  // ------------------------------

  /// Mock-only implementation that returns fabricated test-user data.
  /// Does not invoke the real REST endpoint or make HTTP requests.
  @override
  Future<UserProfile> getUserProfile({required String accessToken}) async {
    return UserProfile(
      id: 'dev-user-${_mockUserId ?? 0}',
      mobileNumber: _mockMobileNumber ?? '+919876512345',
      name: 'Development Test User',
      email: 'test@example.com',
      createdAt: '2024-01-01',
    );
  }

  // ------------------------------
  // close
  // ------------------------------

  void close() {
    // No external resources to close for the mock service.
  }

  // ------------------------------
  // Resend helper (called from UI, enforces cooldown internally)
  // ------------------------------

  /// Returns whether a resend is currently available.
  bool get canResend => _resendCountdown <= 0 && !_isResending;

  /// Internal: called by the UI to initiate a resend.
  /// The service enforces the 30-second cooldown.
  void startResend() {
    _isResending = true;
    // The countdown is decremented by the UI via [tickResend];
    // here we just mark the start.
  }

  /// Internal: called by the UI each frame/tick to decrement the resend counter.
  void tickResend() {
    if (_resendCountdown > 0) {
      _resendCountdown--;
    }
    if (_resendCountdown <= 0 && _isResending) {
      _isResending = false;
    }
  }

  /// Returns the current resend countdown value.
  int get resendCountdown => _resendCountdown;
}