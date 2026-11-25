package com.etfloans.backend.service;

import com.etfloans.backend.config.AuthenticationEnvironment;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Component;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Bounded, single-instance sliding windows keyed by mobile number.
 */
@Component
public class OtpRateLimiter {

    private final int sendLimit;
    private final long sendWindowSeconds;
    private final int verifyLimit;
    private final long verifyWindowSeconds;
    private final int maxBuckets;

    private final Map<String, Deque<Instant>> sendBuckets = new LinkedHashMap<>();
    private final Map<String, Deque<Instant>> verifyBuckets = new LinkedHashMap<>();

    public OtpRateLimiter(
            @Value("${etf.otp.send-limit:3}") int sendLimit,
            @Value("${etf.otp.send-window-seconds:900}") long sendWindowSeconds,
            @Value("${etf.otp.verify-limit:10}") int verifyLimit,
            @Value("${etf.otp.verify-window-seconds:900}") long verifyWindowSeconds,
            @Value("${etf.otp.max-buckets:10000}") int maxBuckets,
            Environment environment) {
        if (sendLimit < 1 || sendWindowSeconds < 1 || verifyLimit < 1 || verifyWindowSeconds < 1 || maxBuckets < 1) {
            throw new IllegalArgumentException("Authentication rate limits must be positive");
        }
        this.sendLimit = sendLimit;
        this.sendWindowSeconds = AuthenticationEnvironment.otpCooldownSeconds(environment, sendWindowSeconds);
        this.verifyLimit = verifyLimit;
        this.verifyWindowSeconds = AuthenticationEnvironment.otpCooldownSeconds(environment, verifyWindowSeconds);
        this.maxBuckets = maxBuckets;
    }

    public void checkSend(String mobileNumber) {
        check(sendBuckets, mobileNumber, sendLimit, sendWindowSeconds);
    }

    public void checkVerify(String mobileNumber) {
        check(verifyBuckets, mobileNumber, verifyLimit, verifyWindowSeconds);
    }

    private void check(Map<String, Deque<Instant>> buckets, String key,
                       int limit, long windowSeconds) {
        synchronized (buckets) {
            Instant now = Instant.now();
            Instant cutoff = now.minusSeconds(windowSeconds);
            // Buckets are ordered by their most recent accepted request.
            var entries = buckets.values().iterator();
            while (entries.hasNext() && !entries.next().peekLast().isAfter(cutoff)) {
                entries.remove();
            }
            Deque<Instant> bucket = buckets.get(key);
            if (bucket == null) {
                if (buckets.size() >= maxBuckets) {
                    var oldest = buckets.values().iterator().next().peekLast();
                    throw new RateLimitExceededException(retryAfter(oldest, now, windowSeconds));
                }
                bucket = new ArrayDeque<>();
            }
            while (!bucket.isEmpty() && !bucket.peekFirst().isAfter(cutoff)) {
                bucket.pollFirst();
            }
            if (bucket.size() >= limit) {
                throw new RateLimitExceededException(retryAfter(bucket.peekFirst(), now, windowSeconds));
            }
            bucket.addLast(now);
            buckets.remove(key);
            buckets.put(key, bucket);
        }
    }

    private long retryAfter(Instant recorded, Instant now, long windowSeconds) {
        return Math.max(1, windowSeconds - Duration.between(recorded, now).getSeconds());
    }
}
