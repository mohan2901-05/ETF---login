import 'package:etf_loans/core/errors/app_errors.dart';
import 'package:etf_loans/features/onboarding/borrower_details.dart';

/// In-app integration boundary. An adapter must use authenticated, approved
/// backend operations and complete writes only after server confirmation.
abstract interface class BorrowerService {
  /// Returns null only when the server confirms there is no borrower profile.
  Future<BorrowerProfile?> loadProfile({required String accessToken});

  /// Completes only after PAN verification and persistence both succeed.
  Future<void> completeOnboarding({
    required String accessToken,
    required BorrowerDetails details,
    required String pan,
    required bool panConsent,
  });

  Future<void> updateFinances({
    required String accessToken,
    required BorrowerFinances finances,
  });
}

class BorrowerServiceUnavailable extends AppError {
  BorrowerServiceUnavailable(super.message);
}

/// The current backend exposes account authentication only.
class UnavailableBorrowerService implements BorrowerService {
  const UnavailableBorrowerService();

  @override
  Future<BorrowerProfile?> loadProfile({required String accessToken}) async {
    throw BorrowerServiceUnavailable('Borrower profile access is unavailable.');
  }

  @override
  Future<void> completeOnboarding({
    required String accessToken,
    required BorrowerDetails details,
    required String pan,
    required bool panConsent,
  }) async {
    throw BorrowerServiceUnavailable(
      'PAN verification and saving your details are currently unavailable.',
    );
  }

  @override
  Future<void> updateFinances({
    required String accessToken,
    required BorrowerFinances finances,
  }) async {
    throw BorrowerServiceUnavailable('Saving borrower details is unavailable.');
  }
}
