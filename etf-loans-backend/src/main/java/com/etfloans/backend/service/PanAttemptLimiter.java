package com.etfloans.backend.service;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ResponseStatusException;

import java.time.Duration;
import java.time.Instant;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

/** Keeps simultaneous calls and repeated attempts bounded within a single backend instance. */
@Component
class PanAttemptLimiter {
    private static final int MAX_ATTEMPTS = 5;
    private static final int MAX_ACCOUNTS = 10_000;
    private static final Duration WINDOW = Duration.ofMinutes(5);
    private final Map<UUID, Attempts> attempts = new HashMap<>();

    synchronized void start(UUID userId) {
        Instant now = Instant.now();
        attempts.values().removeIf(state -> !state.inProgress && !state.expiresAt.isAfter(now));
        Attempts state = attempts.get(userId);
        if (state == null) {
            if (attempts.size() >= MAX_ACCOUNTS) {
                throw new RateLimitExceededException(WINDOW.toSeconds());
            }
            state = new Attempts(now.plus(WINDOW));
            attempts.put(userId, state);
        }
        if (state.inProgress) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Profile creation is already in progress.");
        }
        if (state.count >= MAX_ATTEMPTS) {
            throw new RateLimitExceededException(Duration.between(now, state.expiresAt).toSeconds() + 1);
        }
        state.count++;
        state.inProgress = true;
    }

    synchronized void finish(UUID userId) {
        attempts.get(userId).inProgress = false;
    }

    private static final class Attempts {
        private final Instant expiresAt;
        private int count;
        private boolean inProgress;

        private Attempts(Instant expiresAt) {
            this.expiresAt = expiresAt;
        }
    }
}
