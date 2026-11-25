/// Successful writes hand back a request to start Phase 04 eligibility.
enum BorrowerFlowResult { checkEligibility, recheckEligibility, sessionExpired }

enum EmploymentType {
  salaried('Salaried'),
  selfEmployed('Self-employed');

  const EmploymentType(this.label);

  final String label;
}

class BorrowerFinances {
  const BorrowerFinances({
    required this.employment,
    required this.monthlyIncome,
    required this.externalEmi,
  });

  final EmploymentType employment;
  // Decimal rupee amounts are kept as strings until a backend contract exists.
  final String monthlyIncome;
  final String externalEmi;
}

class BorrowerDetails {
  const BorrowerDetails({
    required this.fullName,
    required this.dateOfBirth,
    required this.finances,
  });

  final String fullName;
  final DateTime dateOfBirth;
  final BorrowerFinances finances;
}

class BorrowerProfile {
  const BorrowerProfile({required this.details, required this.maskedPan});

  final BorrowerDetails details;
  final String maskedPan;
}

abstract final class BorrowerValidation {
  static String? fullName(String? value) =>
      (value ?? '').trim().isEmpty ? 'Enter your full name.' : null;

  static DateTime? parseBirthDate(String value) {
    final parts = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(value.trim());
    if (parts == null) return null;
    final day = int.parse(parts[1]!);
    final month = int.parse(parts[2]!);
    final year = int.parse(parts[3]!);
    final date = DateTime(year, month, day);
    if (year == 0 || date.day != day || date.month != month) return null;
    return date;
  }

  static String? birthDate(String? value) {
    final date = parseBirthDate(value ?? '');
    if (date == null) return 'Enter a valid date in DD/MM/YYYY format.';
    if (date.isAfter(DateTime.now())) return 'Enter a date in the past.';
    return null;
  }

  static String? rupees(String? value) =>
      RegExp(r'^\d+(\.\d{1,2})?$').hasMatch((value ?? '').trim())
      ? null
      : 'Enter a rupee amount with up to two decimal places.';

  static String normalizePan(String value) => value.trim().toUpperCase();

  static String? pan(String? value) =>
      RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(normalizePan(value ?? ''))
      ? null
      : 'Enter a PAN in the format ABCDE1234F.';
}
