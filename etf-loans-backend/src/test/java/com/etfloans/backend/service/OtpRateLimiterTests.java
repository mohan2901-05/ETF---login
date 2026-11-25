package com.etfloans.backend.service;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertThrows;

class OtpRateLimiterTests {
    @Test
    void aFullLimiterRejectsNewNumbersWithoutEvictingActiveCounters() {
        var limiter = new OtpRateLimiter(2, 60, 1, 60, 1);
        limiter.checkSend("fixture-one");
        assertThrows(RateLimitExceededException.class, () -> limiter.checkSend("fixture-two"));
        limiter.checkSend("fixture-one");
        assertThrows(RateLimitExceededException.class, () -> limiter.checkSend("fixture-one"));
        limiter.checkVerify("fixture-two");
        assertThrows(RateLimitExceededException.class, () -> limiter.checkVerify("fixture-two"));
    }
}
