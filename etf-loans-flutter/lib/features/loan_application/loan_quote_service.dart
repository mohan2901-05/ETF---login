import 'package:etf_loans/features/loan_application/loan_quote.dart';

/// In-app boundary, independent of any future wire format. The server must
/// validate session, eligibility, offer ownership, and offer validity.
abstract interface class LoanQuoteService {
  Future<List<LoanAmountOption>> loadOptions({
    required String accessToken,
    required String offerReference,
  });

  Future<LoanQuote> requestQuote({
    required String accessToken,
    required String offerReference,
    required int amountPaise,
    required int months,
  });
}

class LoanQuoteUnavailable implements Exception {
  const LoanQuoteUnavailable();
}

class UnavailableLoanQuoteService implements LoanQuoteService {
  const UnavailableLoanQuoteService();

  @override
  Future<List<LoanAmountOption>> loadOptions({
    required String accessToken,
    required String offerReference,
  }) async {
    throw const LoanQuoteUnavailable();
  }

  @override
  Future<LoanQuote> requestQuote({
    required String accessToken,
    required String offerReference,
    required int amountPaise,
    required int months,
  }) async {
    throw const LoanQuoteUnavailable();
  }
}
