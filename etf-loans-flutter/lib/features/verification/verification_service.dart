import 'package:etf_loans/features/verification/verification_models.dart';

enum VerificationIssue implements Exception { unavailable, permissionDenied }

/// An approved adapter owns the camera and provider session. Flutter receives
/// a preview texture ID and an authoritative response, with no biometric payload.
abstract interface class FaceVerificationSession {
  int? get textureId;
  Future<FaceVerificationResult> captureAndVerify();

  /// Releases the preview and cancels in-flight work. Must be safe to repeat.
  void close();
}

/// In-app boundary. An adapter must authenticate the borrower and validate
/// ownership of the offer before accessing its checklist or starting a check.
abstract interface class LoanVerificationService {
  Future<Map<VerificationKind, VerificationCheck>> loadChecklist({
    required String accessToken,
    required String offerReference,
  });

  Future<FaceVerificationSession> openFaceSession({
    required String accessToken,
    required String offerReference,
    required bool consent,
  });
}

class UnavailableLoanVerificationService implements LoanVerificationService {
  const UnavailableLoanVerificationService();

  @override
  Future<Map<VerificationKind, VerificationCheck>> loadChecklist({
    required String accessToken,
    required String offerReference,
  }) async => throw VerificationIssue.unavailable;

  @override
  Future<FaceVerificationSession> openFaceSession({
    required String accessToken,
    required String offerReference,
    required bool consent,
  }) async => throw VerificationIssue.unavailable;
}
