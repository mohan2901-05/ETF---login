package com.etfloans.backend.service;

import com.etfloans.backend.dto.EligibilityDtos.CreditScore;
import com.etfloans.backend.dto.EligibilityDtos.Decision;
import com.etfloans.backend.dto.EligibilityDtos.Factor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

import java.time.Duration;
import java.util.List;
import java.util.Locale;

@Component
@Profile({"local & !test & !prod & !production", "test & !local & !prod & !production"})
@ConditionalOnProperty(name = "etf.eligibility.synthetic-enabled", havingValue = "true")
class SyntheticEligibilityProvider implements EligibilityProvider {
    private enum Scenario { ELIGIBLE, INELIGIBLE, FAILURE, FINANCIAL_FIXTURE }
    private final Scenario scenario;

    SyntheticEligibilityProvider(@Value("${etf.eligibility.synthetic-scenario:failure}") String scenario) {
        this.scenario = Scenario.valueOf(scenario.toUpperCase(Locale.ROOT).replace('-', '_'));
    }

    @Override
    public Result assess(Input input, Duration timeout) {
        return switch (scenario) {
            case ELIGIBLE -> approved(14_100_025L, 1_600_000L,
                    "This fixed fixture returns the same sample amounts after financial updates.");
            case INELIGIBLE -> new Result(Decision.INELIGIBLE, null, null, null, false);
            case FAILURE -> throw new IllegalStateException("Synthetic provider failure.");
            case FINANCIAL_FIXTURE -> financialFixture(input);
        };
    }

    private static Result financialFixture(Input input) {
        // Integer paise keeps decimal inputs exact. This formula is for development only.
        long income = input.monthlyIncome().movePointRight(2).longValueExact();
        long externalEmi = input.externalEmi().movePointRight(2).longValueExact();
        long grossCapacity = Math.max(0, income - 1_200_000L) / 3;
        long affordableEmi = grossCapacity - externalEmi;
        if (affordableEmi <= 0) {
            return new Result(Decision.INELIGIBLE, null, null, null, false);
        }
        return approved(10 * affordableEmi + 1_000_000L, affordableEmi,
                "Sample amounts are calculated from the saved income and EMI in this development fixture.");
    }

    private static Result approved(long limit, long emi, String description) {
        return new Result(Decision.ELIGIBLE, new CreditScore(699, null, "Synthetic development data",
                List.of(new Factor("Synthetic fixture", description))), limit, emi, true);
    }

    @Override
    public boolean synthetic() { return true; }
}
