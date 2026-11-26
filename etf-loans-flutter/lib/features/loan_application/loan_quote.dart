class LoanAmountOption {
  const LoanAmountOption({required this.amountPaise, required this.plans});

  final int amountPaise;
  final List<LoanPlan> plans;
}

class LoanPlan {
  const LoanPlan({required this.months, this.emiPaise, this.affordabilityNote});

  final int months;
  final int? emiPaise;
  final String? affordabilityNote;
}

class LoanQuote {
  const LoanQuote({
    required this.principalPaise,
    required this.months,
    required this.totalRepaymentPaise,
    required this.interestPaise,
    required this.netProceedsPaise,
    required this.regularEmiPaise,
    required this.finalEmiPaise,
    required this.apr,
    this.interestRate,
    this.firstDueDate,
    this.expiresAt,
    this.charges = const [],
    this.schedule = const [],
    this.agreement,
    this.keyFacts,
  });

  final int principalPaise;
  final int months;
  final int totalRepaymentPaise;
  final int interestPaise;
  final int netProceedsPaise;
  final int regularEmiPaise;
  final int finalEmiPaise;
  final String apr;
  final String? interestRate;
  final DateTime? firstDueDate;
  final DateTime? expiresAt;
  final List<({String label, int amountPaise})> charges;
  final List<LoanInstallment> schedule;
  final LoanDisclosure? agreement;
  final LoanDisclosure? keyFacts;
}

class LoanInstallment {
  const LoanInstallment({
    required this.number,
    required this.dueDate,
    required this.amountPaise,
    this.principalPaise,
    this.interestPaise,
  });

  final int number;
  final DateTime dueDate;
  final int amountPaise;
  final int? principalPaise;
  final int? interestPaise;
}

class LoanDisclosure {
  const LoanDisclosure({required this.version, required this.text});

  final String version;
  final String text;

  bool get isAvailable => version.trim().isNotEmpty && text.trim().isNotEmpty;
}
