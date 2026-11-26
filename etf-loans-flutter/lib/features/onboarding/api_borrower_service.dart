import 'package:etf_loans/core/errors/app_errors.dart';
import 'package:etf_loans/core/network/network_service.dart';
import 'package:etf_loans/features/onboarding/borrower_details.dart';
import 'package:etf_loans/features/onboarding/borrower_service.dart';

class ApiBorrowerService implements BorrowerService {
  const ApiBorrowerService(this._network);

  static const _endpoint = '/api/borrower/profile';
  final NetworkService _network;

  @override
  Future<BorrowerProfile?> loadProfile({required String accessToken}) async {
    final response = await _network.get(_endpoint, authToken: accessToken);
    if (response['statusCode'] == 404 &&
        response['error'] == 'Borrower profile not found.') {
      return null;
    }
    return _confirmedProfile(response, expectedStatus: 200);
  }

  @override
  Future<void> completeOnboarding({
    required String accessToken,
    required BorrowerDetails details,
    required String pan,
    required bool panConsent,
  }) async {
    final normalizedPan = BorrowerValidation.normalizePan(pan);
    try {
      final response = await _network.post(
        _endpoint,
        authToken: accessToken,
        body: {
          ..._financesJson(details.finances),
          'fullName': details.fullName.trim(),
          'dateOfBirth': _isoDate(details.dateOfBirth),
          'pan': normalizedPan,
          'panConsent': panConsent,
        },
      );
      _confirmedProfile(response, expectedStatus: 201);
    } on TimeoutException {
      final saved = await loadProfile(accessToken: accessToken);
      if (saved == null || !_matchesSubmission(saved, details, normalizedPan)) {
        throw BorrowerRequestException(
          'We couldn’t confirm your save. Please try again.',
        );
      }
    }
  }

  @override
  Future<void> updateFinances({
    required String accessToken,
    required BorrowerFinances finances,
  }) async {
    final response = await _network.patch(
      _endpoint,
      authToken: accessToken,
      body: _financesJson(finances),
    );
    _confirmedProfile(response, expectedStatus: 200);
  }

  static Map<String, String> _financesJson(BorrowerFinances finances) => {
    'employment': switch (finances.employment) {
      EmploymentType.salaried => 'SALARIED',
      EmploymentType.selfEmployed => 'SELF_EMPLOYED',
    },
    'monthlyIncome': finances.monthlyIncome,
    'externalEmi': finances.externalEmi,
  };

  static BorrowerProfile _confirmedProfile(
    Map<String, dynamic> response, {
    required int expectedStatus,
  }) {
    final status = response['statusCode'];
    if (status == 401) throw InvalidSessionException();
    if (status != expectedStatus) {
      throw BorrowerRequestException(switch (status) {
        400 => 'Check the details you entered and try again.',
        404 => 'Your borrower profile could not be found.',
        409 => 'Profile creation could not be confirmed. Go back and reopen your details.',
        422 => 'We couldn’t verify the PAN against your name and date of birth.',
        429 => 'Too many verification attempts. Please try again later.',
        503 => 'PAN verification is unavailable. Please try again later.',
        _ => 'The borrower profile request could not be completed.',
      });
    }

    final data = response['data'];
    if (data case {
      'fullName': final String name,
      'dateOfBirth': final String date,
      'employment': final String employment,
      'monthlyIncome': final String income,
      'externalEmi': final String emi,
      'maskedPan': final String maskedPan,
    }) {
      final dateOfBirth = DateTime.tryParse(date);
      final employmentType = switch (employment) {
        'SALARIED' => EmploymentType.salaried,
        'SELF_EMPLOYED' => EmploymentType.selfEmployed,
        _ => null,
      };
      if (dateOfBirth != null &&
          _isoDate(dateOfBirth) == date &&
          employmentType != null &&
          BorrowerValidation.rupees(income) == null &&
          BorrowerValidation.rupees(emi) == null &&
          RegExp(r'^\*{6}[0-9]{3}[A-Z]$').hasMatch(maskedPan)) {
        return BorrowerProfile(
          details: BorrowerDetails(
            fullName: name,
            dateOfBirth: dateOfBirth,
            finances: BorrowerFinances(
              employment: employmentType,
              monthlyIncome: income,
              externalEmi: emi,
            ),
          ),
          maskedPan: maskedPan,
        );
      }
    }
    throw BorrowerRequestException('The server returned an invalid profile.');
  }

  static String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static bool _matchesSubmission(
    BorrowerProfile saved,
    BorrowerDetails submitted,
    String pan,
  ) {
    final actual = saved.details;
    return BorrowerValidation.pan(pan) == null &&
        actual.fullName == submitted.fullName.trim() &&
        _isoDate(actual.dateOfBirth) == _isoDate(submitted.dateOfBirth) &&
        actual.finances.employment == submitted.finances.employment &&
        _paise(actual.finances.monthlyIncome) ==
            _paise(submitted.finances.monthlyIncome) &&
        _paise(actual.finances.externalEmi) ==
            _paise(submitted.finances.externalEmi) &&
        saved.maskedPan == '******${pan.substring(6)}';
  }

  static BigInt? _paise(String amount) {
    if (BorrowerValidation.rupees(amount) != null) return null;
    final parts = amount.trim().split('.');
    final decimal = parts.length == 2 ? parts.last.padRight(2, '0') : '00';
    return BigInt.parse('${parts.first}$decimal');
  }
}
