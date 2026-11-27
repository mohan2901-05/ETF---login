package com.etfloans.backend.service;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;

import java.time.LocalDate;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.*;

class SyntheticLoanPricingTests {
    @Test
    void requiresOptInAndAnIsolatedProfile() {
        var contexts = new ApplicationContextRunner().withUserConfiguration(SyntheticLoanPricing.class);
        for (String profile : new String[]{"local", "test"}) {
            var isolated = contexts.withPropertyValues("spring.profiles.active=" + profile);
            isolated.run(context -> assertThat(context).doesNotHaveBean(SyntheticLoanPricing.class));
            isolated.withPropertyValues("etf.loan-pricing.synthetic-enabled=true")
                    .run(context -> assertThat(context).hasSingleBean(SyntheticLoanPricing.class));
        }
        for (String profile : new String[]{"default", "prod", "production", "local,prod", "test,production", "local,test"}) {
            contexts.withPropertyValues("spring.profiles.active=" + profile, "etf.loan-pricing.synthetic-enabled=true")
                    .run(context -> assertThat(context).doesNotHaveBean(SyntheticLoanPricing.class));
        }
    }

    @Test
    void roundsInterestHalfUpAndChecksFinalPaymentAgainstAffordability() {
        long principal = 1_000_025;
        var terms = new SyntheticLoanPricing().calculate(principal, 3);
        assertEquals(60_002, terms.interest());
        assertEquals(353_300, terms.regular());
        assertEquals(353_427, terms.last());
        assertFalse(terms.affordable(terms.last() - 1));
        assertTrue(terms.affordable(terms.last()));
        var schedule = terms.schedule(principal, 3, LocalDate.of(2028, 1, 31));
        assertEquals(LocalDate.of(2028, 2, 29), schedule.get(0).dueDate());
        assertEquals(LocalDate.of(2028, 3, 31), schedule.get(1).dueDate());
        for (var installment : schedule) {
            assertEquals(installment.amountPaise(), installment.principalPaise() + installment.interestPaise());
        }
        assertEquals(principal, schedule.stream().mapToLong(row -> row.principalPaise()).sum());
        assertEquals(terms.interest(), schedule.stream().mapToLong(row -> row.interestPaise()).sum());
        assertEquals(terms.total(), schedule.stream().mapToLong(row -> row.amountPaise()).sum());
    }
}
