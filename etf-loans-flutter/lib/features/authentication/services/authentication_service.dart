import 'package:etf_loans/core/constants/api_constants.dart';
import 'package:etf_loans/core/errors/app_errors.dart';
import 'package:etf_loans/core/network/network_service.dart';
import 'package:etf_loans/features/authentication/models/auth_models.dart';
import 'package:etf_loans/features/authentication/models/auth_purpose.dart';

class AuthenticationService {
  final NetworkService _networkService;

  AuthenticationService({NetworkService? networkService})
    : _networkService = networkService ?? NetworkService();

  Future<OtpSendResponse> startPasswordFlow({
    required AuthPurpose purpose,
    required String mobileNumber,
    String? password,
  }) async {
    final data = await _post(purpose.endpoint('start'), {
      'mobileNumber': mobileNumber,
      if (password != null) 'password': password,
    });
    return OtpSendResponse.fromJson(data as Map<String, dynamic>);
  }

  Future<OtpSendResponse> resendChallenge({
    required AuthPurpose purpose,
    required String mobileNumber,
    required String challengeId,
  }) async {
    final endpoint = purpose == AuthPurpose.legacyLogin
        ? Constants.otpResend
        : purpose.endpoint('resend');
    final data = await _post(endpoint, {
      'mobileNumber': mobileNumber,
      'challengeId': challengeId,
    });
    return OtpSendResponse.fromJson(data as Map<String, dynamic>);
  }

  Future<String> verifyPasswordGrant({
    required AuthPurpose purpose,
    required String mobileNumber,
    required String challengeId,
    required String otp,
  }) async {
    final data = await _post(purpose.endpoint('verify'), {
      'mobileNumber': mobileNumber,
      'challengeId': challengeId,
      'otp': otp,
    }) as Map<String, dynamic>;
    final grant = data['grantToken'];
    if (grant is! String || grant.isEmpty) {
      throw ServerException('Verification could not be completed.');
    }
    return grant;
  }

  Future<void> completePasswordFlow({
    required AuthPurpose purpose,
    required String grant,
    required String password,
  }) async {
    await _post(purpose.endpoint('complete'), {
      'grantToken': grant,
      'password': password,
    });
  }

  Future<dynamic> _post(String endpoint, Map<String, dynamic> body) async {
    final response = await _networkService.post(endpoint, body: body);
    final status = response['statusCode'] as int;
    if (status >= 200 && status < 300) return response['data'];
    throw ServerException(
      response['error']?.toString() ?? 'Authentication failed.',
    );
  }

  Future<OtpSendResponse> sendOtp(String mobileNumber) async {
    try {
      final response = await _networkService.post(
        Constants.otpSend,
        body: {'mobileNumber': mobileNumber},
      );

      if (response['statusCode'] >= 200 && response['statusCode'] < 300) {
        return OtpSendResponse.fromJson(
          response['data'] as Map<String, dynamic>,
        );
      }

      throw ServerException(response['error'] ?? 'Failed to send OTP');
    } on ServerException {
      rethrow;
    } on AppError {
      rethrow;
    } catch (e) {
      throw FetchDataError(e.toString());
    }
  }

  Future<OtpVerifyResponse> verifyOtp({
    required String challengeId,
    required String mobileNumber,
    required String otp,
    AuthPurpose purpose = AuthPurpose.legacyLogin,
  }) async {
    try {
      final response = await _networkService.post(
        purpose == AuthPurpose.legacyLogin
            ? Constants.otpVerify
            : purpose.endpoint('verify'),
        body: {
          'challengeId': challengeId,
          'mobileNumber': mobileNumber,
          'otp': otp,
        },
      );

      if (response['statusCode'] >= 200 && response['statusCode'] < 300) {
        return OtpVerifyResponse.fromJson(
          response['data'] as Map<String, dynamic>,
        );
      }

      throw ServerException(response['error'] ?? 'Failed to verify OTP');
    } on ServerException {
      rethrow;
    } on AppError {
      rethrow;
    } catch (e) {
      throw FetchDataError(e.toString());
    }
  }

  Future<UserProfile> getUserProfile({required String accessToken}) async {
    try {
      final response = await _networkService.get(
        Constants.me,
        authToken: accessToken,
      );

      if (response['statusCode'] >= 200 && response['statusCode'] < 300) {
        final userData = response['data'] as Map<String, dynamic>;
        return UserProfile.fromJson(userData);
      }

      // Handle authentication failures specifically
      if (response['statusCode'] == 401 || response['statusCode'] == 403) {
        throw InvalidSessionException();
      }

      throw ServerException(response['error'] ?? 'Failed to load user profile');
    } on ServerException {
      rethrow;
    } on AppError {
      rethrow;
    } catch (e) {
      throw FetchDataError(e.toString());
    }
  }

  Future<void> logout({required String accessToken}) async {
    final response = await _networkService.post(
      Constants.logout,
      authToken: accessToken,
    );
    final status = response['statusCode'] as int;
    if (status < 200 || status >= 300) {
      throw ServerException('Could not sign out. Please try again.');
    }
  }

  void close() {
    _networkService.close();
  }
}
