package com.etfloans.backend.service;

import org.junit.jupiter.api.Test;
import org.springframework.mock.env.MockEnvironment;

import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class OtpRateLimiterTests {
    @Test
    void aFullLimiterRejectsNewNumbersWithoutEvictingActiveCounters() {
        var limiter = new OtpRateLimiter(2, 60, 1, 60, 1, new MockEnvironment());
        limiter.checkSend("fixture-one");
        assertThrows(RateLimitExceededException.class, () -> limiter.checkSend("fixture-two"));
        limiter.checkSend("fixture-one");
        assertThrows(RateLimitExceededException.class, () -> limiter.checkSend("fixture-one"));
        limiter.checkVerify("fixture-two");
        assertThrows(RateLimitExceededException.class, () -> limiter.checkVerify("fixture-two"));
    }

    @Test
    void shortWindowsRequireLocalMockProfile() {
        for (String[] profiles : new String[][]{{"local"}, {"prod"}, {"test"}, {"local", "production"}, {}}) {
            var environment = new MockEnvironment()
                    .withProperty("etf.otp.mock-enabled", "true")
                    .withProperty("etf.otp.local-cooldown-seconds", "11");
            environment.setActiveProfiles(profiles);
            assertWindows(environment, profiles.length == 1 && profiles[0].equals("local"));
        }
        var localWithoutMock = new MockEnvironment().withProperty("etf.otp.local-cooldown-seconds", "11");
        localWithoutMock.setActiveProfiles("local");
        assertWindows(localWithoutMock, false);
    }

    private void assertWindows(MockEnvironment environment, boolean shortWindow) {
        var limiter = new OtpRateLimiter(1, 900, 1, 900, 100, environment);
        limiter.checkSend("fixture");
        limiter.checkVerify("fixture");
        long send = assertThrows(RateLimitExceededException.class, () -> limiter.checkSend("fixture"))
                .getRetryAfterSeconds();
        long verify = assertThrows(RateLimitExceededException.class, () -> limiter.checkVerify("fixture"))
                .getRetryAfterSeconds();
        assertTrue(shortWindow ? send <= 11 : send > 11);
        assertTrue(shortWindow ? verify <= 11 : verify > 11);
    }
}
