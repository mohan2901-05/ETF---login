package com.etfloans.backend.service;

import com.etfloans.backend.dto.EligibilityDtos.CreditScore;
import com.etfloans.backend.dto.EligibilityDtos.Decision;
import com.etfloans.backend.model.BorrowerProfile.Employment;

import java.math.BigDecimal;
import java.time.Duration;

public interface EligibilityProvider {
    record Input(Employment employment, BigDecimal monthlyIncome, BigDecimal externalEmi, String panVerificationReference) {}
    record Result(Decision decision, CreditScore creditScore, Long approvedLimitPaise,
                  Long affordableMonthlyEmiPaise, boolean issueOffer) {}

    /** Adapters must bound all provider I/O by the supplied timeout and honor interruption. */
    Result assess(Input input, Duration timeout);

    default boolean synthetic() { return false; }
}
