package com.etfloans.backend.service;

import com.etfloans.backend.dto.EligibilityDtos.*;
import com.etfloans.backend.model.BorrowerProfile;
import com.etfloans.backend.model.EligibilityAssessment;
import com.etfloans.backend.model.EligibilityAssessment.Failure;
import com.etfloans.backend.repository.BorrowerProfileRepository;
import com.etfloans.backend.repository.EligibilityAssessmentRepository;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.annotation.PreDestroy;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.web.server.ResponseStatusException;

import java.time.Duration;
import java.time.Instant;
import java.util.UUID;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicReference;

@Service
public class EligibilityService {
    private static final Duration PROVIDER_TIMEOUT = Duration.ofSeconds(5);
    private static final Duration PROCESSING_WINDOW = Duration.ofSeconds(20);
    private static final Duration RESULT_LIFETIME = Duration.ofHours(24);

    private final BorrowerProfileRepository profiles;
    private final EligibilityAssessmentRepository assessments;
    private final EligibilityProvider provider;
    private final ObjectMapper json;
    private final TransactionTemplate writes;
    private final ExecutorService workers = new ThreadPoolExecutor(2, 2, 0, TimeUnit.SECONDS,
            new SynchronousQueue<>(), Executors.defaultThreadFactory());
    private final ScheduledThreadPoolExecutor timeouts = new ScheduledThreadPoolExecutor(1);

    public EligibilityService(BorrowerProfileRepository profiles, EligibilityAssessmentRepository assessments,
                              ObjectProvider<EligibilityProvider> providers, ObjectMapper json,
                              PlatformTransactionManager transactions) {
        this.profiles = profiles;
        this.assessments = assessments;
        this.provider = providers.getIfAvailable();
        this.json = json;
        this.writes = new TransactionTemplate(transactions);
        timeouts.setRemoveOnCancelPolicy(true);
    }

    @PreDestroy
    void shutdown() {
        timeouts.shutdownNow();
        workers.shutdownNow();
    }

    private record Reservation(EligibilityAssessment assessment, EligibilityProvider.Input input, Instant observedAt) {}
    private record Outcome(EligibilityProvider.Result result, String scoreMetadata, Failure failure) {
        static Outcome failed(Failure failure) { return new Outcome(null, null, failure); }
    }

    @Transactional(propagation = Propagation.NEVER)
    public Assessment start(UUID owner, Request request, String key) {
        var reservation = writes.execute(status -> reserve(owner, request, key));
        var row = reservation.assessment();
        if (reservation.input() != null) {
            dispatch(owner, row, reservation.input());
        }
        return present(row, reservation.observedAt());
    }

    private Reservation reserve(UUID owner, Request request, String key) {
        var profile = profiles.lockByUserId(owner).filter(BorrowerProfile::isPanVerified)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.CONFLICT, "A verified borrower profile is required."));
        Instant now = Instant.now();
        long revision = profile.financialRevision();
        var existing = assessments.findByProfileIdAndIdempotencyKey(owner, key).orElse(null);
        if (existing != null) {
            if (existing.kind() != request.kind() || existing.consentVersion() != request.consentVersion()) {
                throw new ResponseStatusException(HttpStatus.CONFLICT, "This idempotency key belongs to another request.");
            }
            return new Reservation(current(owner, profile, existing, now), null, now);
        }
        if (provider == null) throw unavailable();

        var pending = assessments.findByProfileIdAndFinancialRevisionAndState(owner, revision, State.PENDING).orElse(null);
        if (pending != null && (!now.isBefore(pending.processingDeadline())
                || pending.synthetic() != provider.synthetic() || pending.consentVersion() != request.consentVersion())) {
            pending.abandon(State.EXPIRED, now);
            // Release the PostgreSQL partial unique index before reserving a replacement.
            assessments.flush();
            pending = null;
        }
        var reusable = pending != null ? pending : reusableResult(owner, revision, request, now);
        var row = new EligibilityAssessment(owner, revision, key, request, provider.synthetic(), now,
                reusable == null ? now.plus(PROCESSING_WINDOW) : reusable.processingDeadline(),
                reusable == null ? null : reusable.id());
        assessments.save(row);
        if (reusable != null) return new Reservation(reusable, null, now);

        var input = new EligibilityProvider.Input(profile.employment(), profile.monthlyIncome(),
                profile.externalEmi(), profile.panProviderReference());
        return new Reservation(row, input, now);
    }

    private EligibilityAssessment reusableResult(UUID owner, long revision, Request request, Instant now) {
        return assessments
                .findFirstByProfileIdAndFinancialRevisionAndStateAndSyntheticAndConsentVersionAndResultExpiresAtAfterOrderByResultExpiresAtDesc(
                        owner, revision, State.COMPLETED, provider.synthetic(), request.consentVersion(), now).orElse(null);
    }

    @Transactional(propagation = Propagation.NEVER)
    public Assessment get(UUID owner, UUID id) {
        var reservation = writes.execute(status -> {
            var profile = profiles.lockByUserId(owner).orElseThrow(EligibilityService::missing);
            var row = ownedAssessment(owner, id);
            Instant now = Instant.now();
            return new Reservation(current(owner, profile, row, now), null, now);
        });
        return present(reservation.assessment(), reservation.observedAt());
    }

    /** Server-side guard for a downstream consumer of a borrower offer. */
    @Transactional
    public Offer requireOffer(UUID owner, UUID reference) {
        return lockedOffer(owner, reference).offer();
    }

    record CurrentOffer(UUID assessmentId, long revision, Instant expiresAt, boolean synthetic, Offer offer) {}

    @Transactional
    CurrentOffer lockedOffer(UUID owner, UUID reference) {
        if (reference == null) throw missing();
        var profile = profiles.lockByUserId(owner).orElseThrow(EligibilityService::missing);
        var row = assessments.findByProfileIdAndOfferReference(owner, reference).orElseThrow(EligibilityService::missing);
        Instant now = Instant.now();
        var result = present(current(owner, profile, row, now), now);
        if (result.offer() == null) throw missing();
        return new CurrentOffer(result.id(), profile.financialRevision(), result.expiresAt(),
                result.synthetic(), result.offer());
    }

    private EligibilityAssessment current(UUID owner, BorrowerProfile profile, EligibilityAssessment row, Instant now) {
        var canonical = row.reusedAssessmentId() == null ? row : ownedAssessment(owner, row.reusedAssessmentId());
        if (!profile.isPanVerified() || canonical.financialRevision() != profile.financialRevision()
                || canonical.consentVersion() != Request.CURRENT_CONSENT
                || (canonical.state() == State.PENDING && !now.isBefore(canonical.processingDeadline()))) {
            if (canonical.state() == State.PENDING) canonical.abandon(State.EXPIRED, now);
            // Return a sentinel so expiry of an abandoned reservation is committed before sending HTTP 410.
            return null;
        }
        return canonical;
    }

    private Assessment present(EligibilityAssessment row, Instant now) {
        if (row == null || row.state() == State.EXPIRED
                || (row.state() == State.COMPLETED && !now.isBefore(row.resultExpiresAt()))) {
            throw new ResponseStatusException(HttpStatus.GONE, "This assessment expired or the borrower details changed.");
        }
        if (provider == null || row.synthetic() != provider.synthetic()) {
            throw unavailable();
        }
        if (row.state() == State.FAILED) {
            throw switch (row.failure()) {
                case PROVIDER -> new ResponseStatusException(HttpStatus.BAD_GATEWAY, "The eligibility provider could not complete the assessment.");
                case TIMEOUT -> new ResponseStatusException(HttpStatus.GATEWAY_TIMEOUT, "The eligibility assessment timed out.");
                case UNAVAILABLE -> unavailable();
            };
        }
        if (row.state() == State.PENDING) return Assessment.pending(row.id(), row.synthetic());
        try {
            var score = row.scoreMetadata() == null ? null : json.readValue(row.scoreMetadata(), CreditScore.class);
            var offer = row.decision() == Decision.ELIGIBLE
                    ? new Offer(row.approvedLimitPaise(), row.affordableMonthlyEmiPaise(), row.offerReference())
                    : null;
            return Assessment.completed(row.id(), row.synthetic(), row.decision(), score,
                    row.updatedAt(), row.resultExpiresAt(), offer);
        } catch (JsonProcessingException failure) {
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY, "The eligibility result could not be read.");
        }
    }

    private void dispatch(UUID owner, EligibilityAssessment row, EligibilityProvider.Input input) {
        Instant cutoff = Instant.now().plus(PROVIDER_TIMEOUT);
        var timer = new AtomicReference<ScheduledFuture<?>>();
        var task = new FutureTask<Void>(() -> {
            Outcome outcome = assess(input, cutoff);
            publish(owner, row.id(), outcome);
            return null;
        }) {
            @Override
            protected void done() {
                var timeout = timer.get();
                if (timeout != null) timeout.cancel(false);
            }
        };
        try {
            // A saturated pool rejects work immediately. A running adapter gets a hard interruption deadline.
            timer.set(timeouts.schedule(() -> {
                if (task.cancel(true)) publish(owner, row.id(), Outcome.failed(Failure.TIMEOUT));
            }, PROVIDER_TIMEOUT.toMillis(), TimeUnit.MILLISECONDS));
            workers.execute(task);
        } catch (RejectedExecutionException failure) {
            task.cancel(true);
            publish(owner, row.id(), Outcome.failed(Failure.UNAVAILABLE));
            throw unavailable();
        }
    }

    private Outcome assess(EligibilityProvider.Input input, Instant cutoff) {
        try {
            var remaining = Duration.between(Instant.now(), cutoff);
            if (remaining.isNegative() || remaining.isZero()) return Outcome.failed(Failure.TIMEOUT);
            var result = provider.assess(input, remaining);
            if (!Instant.now().isBefore(cutoff)) return Outcome.failed(Failure.TIMEOUT);
            if (!valid(result)) return Outcome.failed(Failure.PROVIDER);
            String score = result.creditScore() == null ? null : json.writeValueAsString(result.creditScore());
            return new Outcome(result, score, null);
        } catch (RuntimeException | JsonProcessingException failure) {
            // Provider exceptions may contain borrower details.
            return Outcome.failed(Instant.now().isBefore(cutoff) && !Thread.currentThread().isInterrupted()
                    ? Failure.PROVIDER : Failure.TIMEOUT);
        }
    }

    private void publish(UUID owner, UUID id, Outcome outcome) {
        writes.executeWithoutResult(status -> {
            var profile = profiles.lockByUserId(owner).orElse(null);
            if (profile == null) return;
            var row = ownedAssessment(owner, id);
            if (row.state() != State.PENDING) return;
            Instant now = Instant.now();
            if (current(owner, profile, row, now) == null) return;
            if (outcome.failure() != null) {
                row.fail(outcome.failure(), now);
            } else {
                var result = outcome.result();
                row.finish(result.decision(), outcome.scoreMetadata(), result.approvedLimitPaise(),
                        result.affordableMonthlyEmiPaise(), result.issueOffer(), now, now.plus(RESULT_LIFETIME));
            }
        });
    }

    private EligibilityAssessment ownedAssessment(UUID owner, UUID id) {
        return assessments.findByProfileIdAndId(owner, id).orElseThrow(EligibilityService::missing);
    }

    private static boolean valid(EligibilityProvider.Result result) {
        return result != null && result.decision() != null
                && (result.approvedLimitPaise() == null || result.approvedLimitPaise() >= 0)
                && (result.affordableMonthlyEmiPaise() == null || result.affordableMonthlyEmiPaise() >= 0)
                && (result.decision() == Decision.ELIGIBLE
                    || (!result.issueOffer() && result.approvedLimitPaise() == null && result.affordableMonthlyEmiPaise() == null));
    }

    private static ResponseStatusException unavailable() {
        return new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "Eligibility assessment is unavailable. Try again later.");
    }

    private static ResponseStatusException missing() {
        return new ResponseStatusException(HttpStatus.NOT_FOUND, "Assessment or offer not found.");
    }
}
