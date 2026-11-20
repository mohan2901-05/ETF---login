package com.etfloans.backend.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Minimal in-memory sliding-window rate limiter keyed by mobile number.
 * Single-instance only; a distributed store (Redis) is needed for multi-instance
 * deployments.
 */
@Component
public class OtpRateLimiter {

    private final int sendLimit;
    private final long sendWindowSeconds;
    private final int verifyLimit;
    private final long verifyWindowSeconds;

    private final Map<String, Deque<Instant>> sendBuckets = new ConcurrentHashMap<>();
    private final Map<String, Deque<Instant>> verifyBuckets = new ConcurrentHashMap<>();

    public OtpRateLimiter(
            @Value("${etf.otp.send-limit:3}") int sendLimit,
            @Value("${etf.otp.send-window-seconds:900}") long sendWindowSeconds,
            @Value("${etf.otp.verify-limit:10}") int verifyLimit,
            @Value("${etf.otp.verify-window-seconds:900}") long verifyWindowSeconds) {
        this.sendLimit = sendLimit;
        this.sendWindowSeconds = sendWindowSeconds;
        this.verifyLimit = verifyLimit;
        this.verifyWindowSeconds = verifyWindowSeconds;
    }

    public void checkSend(String mobileNumber) {
        check(sendBuckets, mobileNumber, sendLimit, sendWindowSeconds);
    }

    public void checkVerify(String mobileNumber) {
        check(verifyBuckets, mobileNumber, verifyLimit, verifyWindowSeconds);
    }

    private void check(Map<String, Deque<Instant>> buckets, String key,
                       int limit, long windowSeconds) {
        Instant now = Instant.now();
        Instant cutoff = now.minusSeconds(windowSeconds);
        Deque<Instant> bucket = buckets.computeIfAbsent(key, ignored -> new ArrayDeque<>());
        synchronized (bucket) {
            while (!bucket.isEmpty() && bucket.peekFirst().isBefore(cutoff)) {
                bucket.pollFirst();
            }
            if (bucket.size() >= limit) {
                long elapsed = Duration.between(bucket.peekFirst(), now).getSeconds();
                long retryAfter = Math.max(1, windowSeconds - elapsed);
                throw new RateLimitExceededException(retryAfter);
            }
            bucket.addLast(now);
        }
    }
}
