package com.etfloans.backend.service;

import com.etfloans.backend.dto.LoanQuotationDtos.Installment;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

@Component
@Profile({"local & !test & !prod & !production", "test & !local & !prod & !production"})
@ConditionalOnProperty(name = "etf.loan-pricing.synthetic-enabled", havingValue = "true")
final class SyntheticLoanPricing {
    static final String VERSION = "synthetic-flat-v1";
    static final long STEP_PAISE = 1_000_000;
    static final long MAX_PAISE = 50_000_000;
    static final List<Integer> TENURES = List.of(3, 6, 9, 12, 18, 24);

    record Terms(int ratePercent, long interest, long total, long regular, long last) {
        boolean affordable(long cap) {
            return Math.max(regular, last) <= cap;
        }

        List<Installment> schedule(long principal, int months, LocalDate issueDate) {
            var installments = new ArrayList<Installment>(months);
            long allocatedPrincipal = 0;
            for (int number = 1; number <= months; number++) {
                long payment = number == months ? last : regular;
                // Allocate principal by cumulative cash paid, rounding down to a paise.
                long paid = regular * (number - 1) + payment;
                long cumulativePrincipal = paid * principal / total;
                long portion = cumulativePrincipal - allocatedPrincipal;
                installments.add(new Installment(number, issueDate.plusMonths(number), payment,
                        portion, payment - portion));
                allocatedPrincipal = cumulativePrincipal;
            }
            return List.copyOf(installments);
        }
    }

    Terms calculate(long principal, int months) {
        int rate = months <= 6 ? 2 : 3;
        long interest = BigDecimal.valueOf(principal).multiply(BigDecimal.valueOf((long) rate * months))
                .movePointLeft(2).setScale(0, RoundingMode.HALF_UP).longValueExact();
        long total = principal + interest;
        long regular = total / months / 100 * 100;
        return new Terms(rate, interest, total, regular, total - regular * (months - 1));
    }
}
