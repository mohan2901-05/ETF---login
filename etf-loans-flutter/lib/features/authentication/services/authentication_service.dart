import 'package:etf_loans/core/constants/api_constants.dart';
import 'package:etf_loans/core/errors/app_errors.dart';
import 'package:etf_loans/core/network/network_service.dart';
import 'package:etf_loans/features/authentication/models/auth_models.dart';

class AuthenticationService {
  final NetworkService _networkService;

  AuthenticationService({NetworkService? networkService})
      : _networkService = networkService ?? NetworkService();

  Future<OtpSendResponse> sendOtp(String mobileNumber) async {
    try {
      final response = await _networkService.post(
        Constants.otpSend,
        body: {'mobileNumber': mobileNumber},
      );

      if (response['statusCode'] >= 200 && response['statusCode'] < 300) {
        return OtpSendResponse.fromJson(response['data'] as Map<String, dynamic>);
      }

      throw ServerException(
          response['error'] ?? 'Failed to send OTP');
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
  }) async {
    try {
      final response = await _networkService.post(
        Constants.otpVerify,
        body: {
          'challengeId': challengeId,
          'mobileNumber': mobileNumber,
          'otp': otp,
        },
      );

      if (response['statusCode'] >= 200 && response['statusCode'] < 300) {
        return OtpVerifyResponse.fromJson(response['data'] as Map<String, dynamic>);
      }

      throw ServerException(
          response['error'] ?? 'Failed to verify OTP');
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
      final response = await _networkService.get(Constants.me, authToken: accessToken);

      if (response['statusCode'] >= 200 && response['statusCode'] < 300) {
        final userData = response['data'] as Map<String, dynamic>;
        return UserProfile.fromJson(userData);
      }

      // Handle authentication failures specifically
      if (response['statusCode'] == 401) {
        throw ServerException('Session expired. Please log in again.');
      }
      if (response['statusCode'] == 403) {
        throw ServerException('Access denied. Invalid session.');
      }

      throw ServerException(
          response['error'] ?? 'Failed to load user profile');
    } on ServerException {
      rethrow;
    } on AppError {
      rethrow;
    } catch (e) {
      throw FetchDataError(e.toString());
    }
  }

  Future<void> logout() async {
    try {
      await _networkService.post(Constants.logout);
    } catch (e) {
      // Logout failure should not block the session end
      throw FetchDataError(e.toString());
    }
  }

  void close() {
    _networkService.close();
  }
}