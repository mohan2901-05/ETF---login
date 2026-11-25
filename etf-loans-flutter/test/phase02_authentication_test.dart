import 'dart:convert';

import 'package:etf_loans/core/network/network_service.dart';
import 'package:etf_loans/features/authentication/models/auth_models.dart';
import 'package:etf_loans/features/authentication/models/auth_purpose.dart';
import 'package:etf_loans/features/authentication/screens/account_access_screen.dart';
import 'package:etf_loans/features/authentication/screens/login_screen.dart';
import 'package:etf_loans/features/authentication/screens/home_screen.dart';
import 'package:etf_loans/features/authentication/screens/otp_verification_screen.dart';
import 'package:etf_loans/features/authentication/services/authentication_service.dart';
import 'package:etf_loans/theme/theme_config.dart';
import 'package:etf_loans/main.dart';
import 'package:etf_loans/features/welcome/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _OtpService extends AuthenticationService {
  final challengeIds = <String>[];

  @override
  Future<OtpSendResponse> resendChallenge({
    required AuthPurpose purpose,
    required String mobileNumber,
    required String challengeId,
  }) async {
    expect(challengeId, 'initial');
    return OtpSendResponse(success: true, challengeId: 'replacement');
  }

  @override
  Future<String> verifyPasswordGrant({
    required AuthPurpose purpose,
    required String mobileNumber,
    required String challengeId,
    required String otp,
  }) async {
    expect(purpose, AuthPurpose.recovery);
    challengeIds.add(challengeId);
    return 'fixture-grant';
  }
}

class _NoSessionStorage implements SecureStorage {
  @override
  Future<void> write({required String key, required String value}) async {
    fail('Recovery must never write a bearer token.');
  }
}

void main() {
  test('HTTP 429 uses Retry-After seconds for the authentication error', () async {
    final client = MockClient((_) async => http.Response(
      '{"message":"Generic server error"}',
      429,
      headers: {'Retry-After': '10'},
    ));
    final network = NetworkService(client: client);
    addTearDown(network.close);
    final response = await network.post('/api/auth/password/login/start');
    expect(response['error'], 'Too many requests. Try again in 10 seconds.');
  });

  for (final valid in [false, true]) {
    testWidgets(
      valid
          ? 'valid password opens OTP verification'
          : 'invalid password stays on sign-in',
      (tester) async {
        const error = 'Invalid mobile number or password. Please try again.';
        var requests = 0;
        final client = MockClient((request) async {
          requests++;
          expect(request.url.path, '/api/auth/password/login/start');
          expect(jsonDecode(request.body), {
            'mobileNumber': '9100000020',
            'password': 'fixture-password',
          });
          return http.Response(
            jsonEncode(
              valid
                  ? {
                      'success': true,
                      'challengeId': 'fixture-challenge',
                      'expirySeconds': 300,
                      'resendAfterSeconds': 30,
                    }
                  : {'success': false, 'message': error},
            ),
            valid ? 200 : 401,
          );
        });
        final service = AuthenticationService(
          networkService: NetworkService(client: client),
        );
        addTearDown(service.close);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeConfig.lightTheme,
            home: LoginScreen(authenticationService: service),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        final fields = find.byType(TextFormField);
        await tester.enterText(fields.first, '9100000020');
        await tester.enterText(fields.last, 'fixture-password');
        final submit = find.text('Send code');
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(requests, 1);
        if (valid) {
          final otpScreen = tester.widget<OtpVerificationScreen>(
            find.byType(OtpVerificationScreen),
          );
          expect(otpScreen.challengeId, 'fixture-challenge');
          expect(otpScreen.purpose, AuthPurpose.passwordLogin);
        } else {
          expect(find.byType(LoginScreen), findsOneWidget);
          expect(find.text(error), findsWidgets);
          expect(find.byType(OtpVerificationScreen), findsNothing);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final valid in [true, false]) {
    testWidgets(
      valid
          ? 'restores a validated session'
          : 'clears an expired stored session',
      (tester) async {
        FlutterSecureStorage.setMockInitialValues({
          'accessToken': 'stored-fixture-token',
        });
        addTearDown(() => FlutterSecureStorage.setMockInitialValues({}));
        final auth = AuthenticationService(
          networkService: NetworkService(
            client: MockClient((request) async {
              expect(request.url.path, '/api/auth/me');
              expect(
                request.headers['authorization'],
                'Bearer stored-fixture-token',
              );
              return valid
                  ? http.Response(
                      '{"id":"fixture","mobileNumber":"9590000000","fullName":"Test User"}',
                      200,
                    )
                  : http.Response(
                      '{"message":"Invalid or expired token"}',
                      401,
                    );
            }),
          ),
        );
        addTearDown(auth.close);
        await tester.pumpWidget(ETFLoansApp(authenticationService: auth));
        await tester.pumpAndSettle();
        const storage = FlutterSecureStorage();
        if (valid) {
          expect(find.byType(HomeScreen), findsOneWidget);
          expect(
            await storage.read(key: 'accessToken'),
            'stored-fixture-token',
          );
        } else {
          expect(find.byType(WelcomeScreen), findsOneWidget);
          expect(await storage.read(key: 'accessToken'), isNull);
        }
      },
    );
  }

  testWidgets('sign-in keeps legacy OTP available and opens recovery', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: ThemeConfig.lightTheme, home: const LoginScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
    final legacy = find.text('Sign in without a password');
    await tester.ensureVisible(legacy);
    await tester.tap(legacy);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Password'), findsNothing);
    final recover = find.text('Forgot password');
    await tester.ensureVisible(recover);
    await tester.tap(recover);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid 10-digit mobile number'), findsOneWidget);
  });

  for (final width in [360.0, 390.0, 412.0]) {
    testWidgets(
      'password form at ${width.toInt()} px with large text and keyboard',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 820);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeConfig.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: const AccountAccessScreen(flow: AccountAccess.resetPassword),
          ),
        );
        final fields = find.byType(TextFormField);
        await tester.ensureVisible(fields.first);
        await tester.enterText(fields.first, 'fixture-password');
        await tester.tap(find.byTooltip('Show password').first);
        await tester.pump();
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText).first)
              .obscureText,
          isFalse,
        );
        await tester.ensureVisible(fields.last);
        await tester.enterText(fields.last, 'different-password');
        final save = find.text('Save password');
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(find.text('Passwords do not match'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'recovery OTP verifies the replacement challenge and issues no session',
    (tester) async {
      final service = _OtpService();
      addTearDown(service.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeConfig.lightTheme,
          home: OtpVerificationScreen(
            mobileNumber: '9590000000',
            challengeId: 'initial',
            resendAfterSeconds: 0,
            purpose: AuthPurpose.recovery,
            authenticationService: service,
            secureStorage: _NoSessionStorage(),
            passwordScreen: (grant) => Scaffold(body: Text(grant)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 700));
      final resend = find.text('Resend code');
      await tester.ensureVisible(resend);
      await tester.tap(resend);
      await tester.pump();
      await tester.enterText(find.byType(TextField), '654321');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('fixture-grant'), findsOneWidget);
      expect(service.challengeIds, ['replacement']);
    },
  );
}
