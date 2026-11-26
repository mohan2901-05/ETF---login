package com.etfloans.backend.service;

import com.etfloans.backend.dto.BorrowerProfileDtos.Create;
import com.etfloans.backend.dto.BorrowerProfileDtos.Finances;
import com.etfloans.backend.dto.BorrowerProfileDtos.Profile;
import com.etfloans.backend.model.BorrowerProfile;
import com.etfloans.backend.repository.BorrowerProfileRepository;
import com.etfloans.backend.repository.UsersRepository;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;
import java.util.Locale;
import java.util.Optional;
import java.util.UUID;

@Service
public class BorrowerProfileService {
    private static final short CONSENT_VERSION = 1;
    private final BorrowerProfileRepository profiles;
    private final UsersRepository users;
    private final PanVerificationProvider panProvider;
    private final PanAttemptLimiter attempts;
    private final TransactionTemplate writes;

    public BorrowerProfileService(BorrowerProfileRepository profiles, UsersRepository users,
                                  ObjectProvider<PanVerificationProvider> panProviders, PanAttemptLimiter attempts,
                                  PlatformTransactionManager transactions) {
        this.profiles = profiles;
        this.users = users;
        this.panProvider = panProviders.getIfAvailable();
        this.attempts = attempts;
        this.writes = new TransactionTemplate(transactions);
    }

    @Transactional(propagation = Propagation.NEVER)
    public Profile create(UUID userId, Create request) {
        ensureMissing(userId);
        if (panProvider == null) {
            throw providerUnavailable();
        }
        attempts.start(userId);
        try {
            ensureMissing(userId);
            Instant consentedAt = Instant.now();
            String reference = verifyPan(request);
            Instant verifiedAt = Instant.now();
            String maskedPan = "******" + request.pan().substring(6);

            return writes.execute(status -> {
                var user = users.lockById(userId).filter(account -> account.isActive())
                        .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED,
                                "Authentication required."));
                ensureMissing(userId);
                user.setFullName(request.fullName());
                var profile = new BorrowerProfile(user, request.dateOfBirth(), maskedPan, reference,
                        CONSENT_VERSION, consentedAt, verifiedAt);
                applyFinances(profile, request.finances());
                return Profile.from(profiles.save(profile));
            });
        } finally {
            attempts.finish(userId);
        }
    }

    @Transactional(readOnly = true)
    public Profile retrieve(UUID userId) {
        return profiles.findById(userId).map(Profile::from).orElseThrow(BorrowerProfileService::missingProfile);
    }

    @Transactional
    public Profile update(UUID userId, Finances finances) {
        var profile = profiles.lockByUserId(userId).orElseThrow(BorrowerProfileService::missingProfile);
        applyFinances(profile, finances);
        return Profile.from(profile);
    }

    private String verifyPan(Create request) {
        Optional<String> result;
        try {
            result = panProvider.verify(request.pan(), request.fullName(), request.dateOfBirth());
        } catch (RuntimeException failure) {
            // Provider exceptions can contain request data. Return a fixed message without a cause.
            throw providerUnavailable();
        }
        if (result == null) {
            throw providerUnavailable();
        }
        String reference = result.orElseThrow(() -> new ResponseStatusException(
                HttpStatus.UNPROCESSABLE_ENTITY, "PAN and identity details could not be verified."));
        if (reference.isBlank() || reference.length() > 128
                || reference.codePoints().anyMatch(Character::isISOControl)
                || reference.toUpperCase(Locale.ROOT).contains(request.pan())) {
            throw providerUnavailable();
        }
        return reference;
    }

    private void ensureMissing(UUID userId) {
        if (profiles.existsById(userId)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "A borrower profile already exists.");
        }
    }

    private static void applyFinances(BorrowerProfile profile, Finances finances) {
        profile.updateFinances(finances.employment(), finances.monthlyIncome(), finances.externalEmi(), Instant.now());
    }

    private static ResponseStatusException missingProfile() {
        return new ResponseStatusException(HttpStatus.NOT_FOUND, "Borrower profile not found.");
    }

    private static ResponseStatusException providerUnavailable() {
        return new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "PAN verification is unavailable. Try again later.");
    }
}
