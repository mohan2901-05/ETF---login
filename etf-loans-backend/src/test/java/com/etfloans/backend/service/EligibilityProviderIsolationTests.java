package com.etfloans.backend.service;

import com.etfloans.backend.dto.EligibilityDtos.Decision;
import com.etfloans.backend.model.BorrowerProfile.Employment;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;

import java.math.BigDecimal;
import java.time.Duration;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.*;

class EligibilityProviderIsolationTests {
    private final ApplicationContextRunner contexts = new ApplicationContextRunner()
            .withUserConfiguration(SyntheticEligibilityProvider.class);

    @Test
    void syntheticRequiresExplicitOptInAndAnIsolatedProfile() {
        for (String profile : new String[]{"local", "test"}) {
            var isolated = contexts.withPropertyValues("spring.profiles.active=" + profile);
            isolated.run(context -> assertThat(context).doesNotHaveBean(EligibilityProvider.class));
            isolated.withPropertyValues("etf.eligibility.synthetic-enabled=true")
                    .run(context -> assertThat(context).hasSingleBean(EligibilityProvider.class));
        }
        for (String profile : new String[]{"default", "prod", "production", "local,prod", "test,production", "local,test"}) {
            contexts.withPropertyValues("spring.profiles.active=" + profile, "etf.eligibility.synthetic-enabled=true")
                    .run(context -> assertThat(context).doesNotHaveBean(EligibilityProvider.class));
        }
    }

    @Test
    void scenariosAreIndependentOfBorrowerFinances() {
        var timeout = Duration.ofSeconds(1);
        assertTrue(new SyntheticEligibilityProvider("eligible").assess(null, timeout).issueOffer());
        var ineligible = new SyntheticEligibilityProvider("ineligible").assess(null, timeout);
        assertEquals(Decision.INELIGIBLE, ineligible.decision());
        assertFalse(ineligible.issueOffer());
        assertThrows(IllegalStateException.class, () -> new SyntheticEligibilityProvider("failure").assess(null, timeout));
    }

    @Test
    void financialFixtureExercisesIncomeAndEmiIndependently() {
        var provider = new SyntheticEligibilityProvider("financial-fixture");
        var timeout = Duration.ofSeconds(1);
        var baseline = provider.assess(input("42000.00", "1000.00"), timeout);
        var incomeChanged = provider.assess(input("48000", "1000"), timeout);
        var emiChanged = provider.assess(input("48000", "5000"), timeout);
        assertEquals(10_000_000L, baseline.approvedLimitPaise());
        assertEquals(12_000_000L, incomeChanged.approvedLimitPaise());
        assertEquals(8_000_000L, emiChanged.approvedLimitPaise());
        assertEquals(700_000L, emiChanged.affordableMonthlyEmiPaise());
        assertTrue(emiChanged.issueOffer());
        assertEquals(Decision.INELIGIBLE, provider.assess(input("48000", "12000"), timeout).decision());
    }

    @Test
    void financialFixtureCalculatesUnlistedAndBoundaryAmountsInPaise() {
        var provider = new SyntheticEligibilityProvider("financial-fixture");
        var timeout = Duration.ofSeconds(1);
        assertEquals(7_000_000L, provider.assess(input("60000", "10000"), timeout).approvedLimitPaise());
        assertEquals(600_033L, provider.assess(input("60001.02", "10000.01"), timeout).affordableMonthlyEmiPaise());
        assertEquals(1L, provider.assess(input("12000.03", "0"), timeout).affordableMonthlyEmiPaise());
        assertEquals(Decision.INELIGIBLE, provider.assess(input("12000.02", "0"), timeout).decision());
        assertEquals(Decision.INELIGIBLE, provider.assess(input("0", "0"), timeout).decision());
        assertEquals(Decision.INELIGIBLE, provider.assess(input("48000", "999999999999.99"), timeout).decision());
        var largest = provider.assess(input("999999999999.99", "0"), timeout);
        assertEquals(33_333_332_933_333L, largest.affordableMonthlyEmiPaise());
        assertEquals(333_333_330_333_330L, largest.approvedLimitPaise());
    }

    private static EligibilityProvider.Input input(String income, String emi) {
        return new EligibilityProvider.Input(Employment.SALARIED,
                new BigDecimal(income), new BigDecimal(emi), "fixture");
    }
}
