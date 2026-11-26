import 'package:etf_loans/features/verification/verification_models.dart';

class AadhaarResult {
  const AadhaarResult(this.status, {this.lastFourDigits});

  final VerificationStatus status;
  final String? lastFourDigits;

  String? get maskedAadhaar {
    final suffix = lastFourDigits;
    if (status != VerificationStatus.completed ||
        suffix == null ||
        !RegExp(r'^[0-9]{4}$').hasMatch(suffix))
      return null;
    return '•••• •••• $suffix';
  }
}

enum AddressField {
  street('House, street and area'),
  city('City'),
  state('State'),
  pin('PIN code'),
  employer('Employer or business name'),
  role('Role (optional)');

  const AddressField(this.label);
  final String label;
}

enum HousingType {
  owned('Owned'),
  rented('Rented'),
  family('Family'),
  company('Company');

  const HousingType(this.label);
  final String label;
}

/// Editable only in memory, scoped to the open offer checklist.
class AddressDraft {
  final fields = <AddressField, String>{};
  HousingType? housing;

  void clear() {
    fields.clear();
    housing = null;
  }
}

class AddressDetails {
  AddressDetails({
    required Map<AddressField, String> fields,
    required this.housing,
  }) : fields = Map.unmodifiable(fields);

  final Map<AddressField, String> fields;
  final HousingType housing;
}

class BankAccountDetails {
  const BankAccountDetails({
    required this.holder,
    required this.number,
    required this.ifsc,
  });

  final String holder;
  final String number;
  final String ifsc;
}

abstract final class VerificationInputValidation {
  static String? requiredText(String? value) =>
      (value ?? '').trim().isEmpty ? 'Enter a value.' : null;

  static String? pin(String? value) =>
      RegExp(r'^[0-9]{6}$').hasMatch((value ?? '').trim())
      ? null
      : 'Enter a six-digit PIN code.';

  static String? accountNumber(String? value) =>
      RegExp(r'^[0-9]+$').hasMatch((value ?? '').trim())
      ? null
      : 'Enter the account number using digits only.';

  static String? ifsc(String? value) =>
      RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$')
          .hasMatch((value ?? '').trim().toUpperCase())
      ? null
      : 'Enter a valid 11-character IFSC.';
}
