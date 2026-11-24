import 'package:etf_loans/features/authentication/models/auth_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MobileNumberRequest', () {
    final model = MobileNumberRequest(mobileNumber: '+919876512345');
    test('has correct mobileNumber', () {
      expect(model.mobileNumber, '+919876512345');
    });

    test('fromJson/toJson roundtrip', () {
      final json = model.toJson();
      final decoded = MobileNumberRequest.fromJson(json);
      expect(decoded.mobileNumber, model.mobileNumber);
    });
  });

  group('OtpVerificationRequest', () {
    final model = OtpVerificationRequest(challengeId: 'ch_123', mobileNumber: '+919876512345', otp: '123456');
    test('has correct fields', () {
      expect(model.challengeId, 'ch_123');
      expect(model.mobileNumber, '+919876512345');
      expect(model.otp, '123456');
    });

    test('fromJson/toJson roundtrip', () {
      final json = model.toJson();
      final decoded = OtpVerificationRequest.fromJson(json);
      expect(decoded.mobileNumber, model.mobileNumber);
      expect(decoded.otp, model.otp);
    });
  });

  group('OtpSendResponse', () {
    final model = OtpSendResponse(success: true, message: 'OTP sent', expirySeconds: 300);
    test('has correct fields', () {
      expect(model.success, true);
      expect(model.message, 'OTP sent');
      expect(model.expirySeconds, 300);
    });

    test('fromJson/toJson roundtrip with message', () {
      final json = model.toJson();
      final decoded = OtpSendResponse.fromJson(json);
      expect(decoded.success, model.success);
      expect(decoded.message, model.message);
      expect(decoded.expirySeconds, model.expirySeconds);
    });

    test('fromJson/toJson roundtrip without message', () {
      final noMsg = OtpSendResponse(success: false, expirySeconds: 180);
      final json = noMsg.toJson();
      final decoded = OtpSendResponse.fromJson(json);
      expect(decoded.success, noMsg.success);
      expect(decoded.message, null);
      expect(decoded.expirySeconds, noMsg.expirySeconds);
    });
  });

  group('OtpVerifyResponse', () {
    final model = OtpVerifyResponse(success: true, accessToken: 'abc123', message: 'Login successful', user: VerifyUser(id: '1', mobileNumber: '+919876542345', isNewUser: false));
    test('has correct fields', () {
      expect(model.success, true);
      expect(model.accessToken, 'abc123');
      expect(model.message, 'Login successful');
      expect(model.user!.isNewUser, false);
    });

    test('fromJson/toJson roundtrip', () {
      final json = model.toJson();
      final decoded = OtpVerifyResponse.fromJson(json);
      expect(decoded.success, model.success);
      expect(decoded.accessToken, model.accessToken);
      expect(decoded.message, model.message);
      expect(decoded.user!.isNewUser, model.user!.isNewUser);
    });
  });

  group('UserProfile', () {
    final model = UserProfile(
      id: '1',
      mobileNumber: '+919876512345',
      name: 'Test User',
      email: 'test@example.com',
      createdAt: '2024-01-01',
    );
    test('has correct fields', () {
      expect(model.id, '1');
      expect(model.mobileNumber, '+919876512345');
      expect(model.name, 'Test User');
      expect(model.email, 'test@example.com');
      expect(model.createdAt, '2024-01-01');
    });

    test('fromJson/toJson roundtrip', () {
      final json = model.toJson();
      final decoded = UserProfile.fromJson(json);
      expect(decoded.id, model.id);
      expect(decoded.mobileNumber, model.mobileNumber);
      expect(decoded.name, model.name);
      expect(decoded.email, model.email);
      expect(decoded.createdAt, model.createdAt);
    });

    test('fromJson/toJson roundtrip - optional fields null', () {
      final minimal = UserProfile(
        id: '2',
        mobileNumber: '+919876512346',
        name: 'Minimal User',
      );
      final json = minimal.toJson();
      final decoded = UserProfile.fromJson(json);
      expect(decoded.id, minimal.id);
      expect(decoded.mobileNumber, minimal.mobileNumber);
      expect(decoded.name, minimal.name);
      expect(decoded.email, null);
      expect(decoded.createdAt, null);
    });

    test('fromJson with null name', () {
      final json = {
        'id': '3',
        'mobileNumber': '+919876512347',
        'name': null,
        'email': 'nullname@example.com',
        'createdAt': '2024-01-02',
      };
      final decoded = UserProfile.fromJson(json);
      expect(decoded.id, '3');
      expect(decoded.mobileNumber, '+919876512347');
      expect(decoded.name, null);
      expect(decoded.email, 'nullname@example.com');
      expect(decoded.createdAt, '2024-01-02');
    });

    test('fromJson with missing name field', () {
      final json = {
        'id': '4',
        'mobileNumber': '+919876512348',
        'email': 'noname@example.com',
      };
      final decoded = UserProfile.fromJson(json);
      expect(decoded.id, '4');
      expect(decoded.mobileNumber, '+919876512348');
      expect(decoded.name, null);
      expect(decoded.email, 'noname@example.com');
      expect(decoded.createdAt, null);
    });

    test('toJson with null name', () {
      final model = UserProfile(
        id: '5',
        mobileNumber: '+919876512349',
        name: null,
        email: 'noname2@example.com',
      );
      final json = model.toJson();
      expect(json['id'], '5');
      expect(json['mobileNumber'], '+919876512349');
      expect(json['name'], null);
      expect(json['email'], 'noname2@example.com');
      expect(json['createdAt'], null);
    });
  });
}