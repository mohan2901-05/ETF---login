import 'package:etf_loans/features/verification/additional_verification_models.dart';

/// An in-app interface for an authorized adapter scoped to the current session
/// and offer. Writes acknowledge receipt; checklist status is loaded separately.
abstract interface class AdditionalVerificationService {
  /// Launches approved hosted authorization and reads the backend result after
  /// return. Flutter never receives an Aadhaar number or provider credentials.
  Future<AadhaarResult> startAadhaar({
    required String accessToken,
    required String offerReference,
    required bool consent,
  });

  Future<AadhaarResult> readAadhaarResult({
    required String accessToken,
    required String offerReference,
  });

  Future<void> submitAddress({
    required String accessToken,
    required String offerReference,
    required AddressDetails details,
  });

  Future<void> submitBankAccount({
    required String accessToken,
    required String offerReference,
    required BankAccountDetails details,
  });
}
