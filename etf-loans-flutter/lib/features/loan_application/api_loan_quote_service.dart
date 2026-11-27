import 'package:etf_loans/core/errors/app_errors.dart';
import 'package:etf_loans/core/network/network_service.dart';
import 'package:etf_loans/features/loan_application/loan_quote.dart';
import 'package:etf_loans/features/loan_application/loan_quote_service.dart';

class ApiLoanQuoteService implements PersistedLoanQuoteService {
  const ApiLoanQuoteService(this._network);
  final NetworkService _network;
  static const _path = '/api/borrower/loans';
  static final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );

  @override
  Future<List<LoanAmountOption>> loadOptions({
    required String accessToken,
    required String offerReference,
  }) async {
    final data = _data(
      await _network.get(
        '$_path/offers/${_id(offerReference)}/options',
        authToken: accessToken,
        requireFresh: true,
      ),
    );
    return [
      for (final option in data['options'] as List)
        LoanAmountOption(
          amountPaise: option['amountPaise'] as int,
          plans: [
            for (final plan in option['plans'] as List)
              LoanPlan(
                months: plan['months'] as int,
                emiPaise: plan['emiPaise'] as int,
                affordabilityNote: plan['affordabilityNote'] as String?,
              ),
          ],
        ),
    ];
  }

  @override
  Future<LoanQuote> requestQuote({
    required String accessToken,
    required String offerReference,
    required int amountPaise,
    required int months,
    String? idempotencyKey,
  }) async {
    final data = _data(
      await _network.post(
        '$_path/offers/${_id(offerReference)}/quotes',
        authToken: accessToken,
        idempotencyKey: idempotencyKey ?? newLoanQuoteKey(),
        body: {'amountPaise': amountPaise, 'months': months},
      ),
    );
    if (data['offerReference'] != offerReference ||
        data['principalPaise'] != amountPaise ||
        data['months'] != months) {
      throw const FormatException('Unexpected loan quotation.');
    }
    return _quote(data);
  }

  @override
  Future<LoanQuote> getQuote({
    required String accessToken,
    required String id,
  }) async {
    final data = _data(
      await _network.get(
        '$_path/quotes/${_id(id)}',
        authToken: accessToken,
        requireFresh: true,
      ),
    );
    if (data['id'] != id)
      throw const FormatException('Unexpected loan quote ID.');
    return _quote(data);
  }

  static String _id(String id) {
    if (!_uuid.hasMatch(id)) throw const LoanQuoteStale();
    return id;
  }

  static Map<String, dynamic> _data(Map<String, dynamic> response) {
    switch (response['statusCode']) {
      case 200:
        return response['data'] as Map<String, dynamic>;
      case 401:
        throw InvalidSessionException();
      case 404:
      case 410:
        throw const LoanQuoteStale();
      case 422:
        throw const LoanQuoteRejected();
      case 503:
        throw const LoanQuoteUnavailable();
      default:
        throw const FormatException('Loan quotation request failed.');
    }
  }

  static LoanQuote _quote(Map<String, dynamic> data) => LoanQuote(
    id: _id(data['id'] as String),
    principalPaise: data['principalPaise'] as int,
    months: data['months'] as int,
    totalRepaymentPaise: data['totalRepaymentPaise'] as int,
    interestPaise: data['interestPaise'] as int,
    netProceedsPaise: data['netProceedsPaise'] as int,
    regularEmiPaise: data['regularEmiPaise'] as int,
    finalEmiPaise: data['finalEmiPaise'] as int,
    apr: 'Unavailable for synthetic pricing',
    interestRate: "${data['monthlyFlatRatePercent'] as int}% per month, flat",
    expiresAt: DateTime.parse(data['expiresAt'] as String),
    firstDueDate: DateTime.parse(data['firstDueDate'] as String),
    charges: [
      for (final charge in data['charges'] as List)
        (
          label: charge['label'] as String,
          amountPaise: charge['amountPaise'] as int,
        ),
    ],
    schedule: [
      for (final item in data['schedule'] as List)
        LoanInstallment(
          number: item['number'] as int,
          dueDate: DateTime.parse(item['dueDate'] as String),
          amountPaise: item['amountPaise'] as int,
          principalPaise: item['principalPaise'] as int,
          interestPaise: item['interestPaise'] as int,
        ),
    ],
  );
}
