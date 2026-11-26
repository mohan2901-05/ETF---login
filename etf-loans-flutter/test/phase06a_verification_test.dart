import 'dart:async';

import 'package:etf_loans/features/verification/verification_checklist_screen.dart';
import 'package:etf_loans/features/verification/verification_models.dart';
import 'package:etf_loans/features/verification/verification_service.dart';
import 'package:etf_loans/theme/theme_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('unconfigured checklist reports unavailable for every check', (
    tester,
  ) async {
    await _open(tester, const UnavailableLoanVerificationService());
    expect(
      find.text('Verification services are currently unavailable.'),
      findsOneWidget,
    );
    expect(find.text('Unavailable'), findsNWidgets(5));
    expect(find.text('Completed'), findsNothing);
  });

  testWidgets(
    'checklist renders provider statuses and hands Aadhaar to its route handler',
    (tester) async {
      final service = _SyntheticVerificationService();
      VerificationKind? opened;
      await _open(
        tester,
        service,
        onOpenOtherCheck: (kind) async => opened = kind,
      );
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Pending'), findsNWidgets(2));
      expect(find.text('Failed'), findsOneWidget);
      expect(find.text('Unavailable'), findsOneWidget);
      await _tap(tester, 'Aadhaar');
      expect(opened, VerificationKind.aadhaar);
      expect(service.checklistLoads, 2);
    },
  );

  testWidgets(
    'consent gates camera, permission can retry, and result waits for provider',
    (tester) async {
      final service = _SyntheticVerificationService();
      await _open(tester, service);
      await _tap(tester, 'Face verification');
      final start = find.ancestor(
        of: find.text('Start face check'),
        matching: find.byType(ElevatedButton),
      );
      expect(tester.widget<ElevatedButton>(start).onPressed, isNull);
      expect(service.sessionsOpened, 0);
      await _tap(tester, 'I agree to use my camera for this identity check.');
      await _tap(tester, 'Start face check');
      expect(find.textContaining('Camera access was denied'), findsOneWidget);
      await _tap(tester, 'Try again');
      expect(find.text('Position your face inside the oval.'), findsOneWidget);
      await tester.tap(find.text('Capture'));
      await tester.pump();
      expect(
        find.text('Waiting for the verification provider'),
        findsOneWidget,
      );
      expect(find.text('Face verification result'), findsNothing);
      service.session.result.complete(
        const FaceVerificationResult(
          status: VerificationStatus.failed,
          canRetry: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Face verification result'), findsOneWidget);
      expect(find.text('Failed'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(service.session.closed, isTrue);
    },
  );
}

// Isolated test adapter. All states are synthetic and no camera is opened.
class _SyntheticVerificationService implements LoanVerificationService {
  final session = _SyntheticFaceSession();
  int sessionsOpened = 0;
  int checklistLoads = 0;

  @override
  Future<Map<VerificationKind, VerificationCheck>> loadChecklist({
    required String accessToken,
    required String offerReference,
  }) async {
    expect(accessToken, 'synthetic-session');
    expect(offerReference, 'synthetic-offer');
    checklistLoads++;
    return const {
      VerificationKind.pan: VerificationCheck(VerificationStatus.completed),
      VerificationKind.face: VerificationCheck(
        VerificationStatus.pending,
        canStart: true,
      ),
      VerificationKind.aadhaar: VerificationCheck(
        VerificationStatus.pending,
        canStart: true,
      ),
      VerificationKind.address: VerificationCheck(VerificationStatus.failed),
    };
  }

  @override
  Future<FaceVerificationSession> openFaceSession({
    required String accessToken,
    required String offerReference,
    required bool consent,
  }) async {
    expect(consent, isTrue);
    if (++sessionsOpened == 1) throw VerificationIssue.permissionDenied;
    return session;
  }
}

class _SyntheticFaceSession implements FaceVerificationSession {
  final result = Completer<FaceVerificationResult>();
  bool closed = false;

  @override
  int? get textureId => null;

  @override
  Future<FaceVerificationResult> captureAndVerify() => result.future;

  @override
  void close() => closed = true;
}

Future<void> _open(
  WidgetTester tester,
  LoanVerificationService service, {
  Future<void> Function(VerificationKind)? onOpenOtherCheck,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeConfig.lightTheme,
      home: VerificationChecklistScreen(
        accessToken: 'synthetic-session',
        offerReference: 'synthetic-offer',
        service: service,
        onSessionExpired: () {},
        onOpenOtherCheck: onOpenOtherCheck,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
