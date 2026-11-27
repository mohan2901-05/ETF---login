import 'dart:math';

import 'package:etf_loans/features/loan_application/loan_quote.dart';

String newLoanQuoteKey() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

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

abstract interface class PersistedLoanQuoteService implements LoanQuoteService {
  @override
  Future<LoanQuote> requestQuote({
    required String accessToken,
    required String offerReference,
    required int amountPaise,
    required int months,
    String? idempotencyKey,
  });

  Future<LoanQuote> getQuote({required String accessToken, required String id});
}

class LoanQuoteStale implements Exception {
  const LoanQuoteStale();
}

class LoanQuoteRejected implements Exception {
  const LoanQuoteRejected();
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
