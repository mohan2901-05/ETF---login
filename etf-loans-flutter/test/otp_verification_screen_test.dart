import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:etf_loans/features/authentication/screens/otp_verification_screen.dart';

class _FakeSecureStorage implements SecureStorage {
  final Map<String, String> _data = {};
  @override
  Future<void> write({required String key, required String value}) async {
    _data[key] = value;
  }
}

void main() {
  group('OtpVerificationScreen', () {
    testWidgets('renders OTP verification title', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: OtpVerificationScreen(
          mobileNumber: '+91 98765 12345',
          secureStorage: _FakeSecureStorage(),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Enter the code'), findsOneWidget);
    });

    testWidgets('renders mobile number display', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: OtpVerificationScreen(
          mobileNumber: '+91 98765 12345',
          secureStorage: _FakeSecureStorage(),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('+91 98765 12345'), findsOneWidget);
    });
  });
}