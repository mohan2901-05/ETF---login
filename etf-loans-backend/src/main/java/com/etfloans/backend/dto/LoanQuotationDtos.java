package com.etfloans.backend.dto;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public final class LoanQuotationDtos {
    private LoanQuotationDtos() {}

    public record Options(List<AmountOption> options) {}
    public record AmountOption(long amountPaise, List<Plan> plans) {}
    public record Plan(int months, long emiPaise, String affordabilityNote) {}
    public record Charge(String label, long amountPaise) {}
    public record Installment(int number, LocalDate dueDate, long amountPaise,
                              long principalPaise, long interestPaise) {}
    public record Quote(UUID id, UUID offerReference, String pricingVersion, Instant expiresAt,
                        long principalPaise, int months, long totalRepaymentPaise, long interestPaise,
                        long netProceedsPaise, long regularEmiPaise, long finalEmiPaise,
                        int monthlyFlatRatePercent, LocalDate firstDueDate,
                        List<Charge> charges, List<Installment> schedule) {}
}
