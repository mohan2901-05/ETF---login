package com.etfloans.backend.model;

import com.etfloans.backend.dto.EligibilityDtos.Decision;
import com.etfloans.backend.dto.EligibilityDtos.Kind;
import com.etfloans.backend.dto.EligibilityDtos.Request;
import com.etfloans.backend.dto.EligibilityDtos.State;
import jakarta.persistence.*;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "eligibility_assessments")
@org.hibernate.annotations.DynamicUpdate
public class EligibilityAssessment {
    @Id
    private UUID id;
    @Column(nullable = false, updatable = false)
    private UUID profileId;
    @Column(nullable = false, updatable = false)
    private long financialRevision;
    @Column(nullable = false, updatable = false, length = 128)
    private String idempotencyKey;
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, updatable = false, length = 8)
    private Kind kind;
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 12)
    private State state;
    @Column(nullable = false, updatable = false)
    private short consentVersion;
    @Column(nullable = false, updatable = false)
    private Instant consentedAt;
    @Column(nullable = false, updatable = false)
    private Instant createdAt;
    @Column(nullable = false)
    private Instant updatedAt;
    @Column(nullable = false, updatable = false)
    private Instant processingDeadline;
    private Instant resultExpiresAt;
    @Enumerated(EnumType.STRING)
    @Column(length = 10)
    private Decision decision;
    @Column(columnDefinition = "text")
    private String scoreMetadata;
    private Long approvedLimitPaise;
    private Long affordableMonthlyEmiPaise;
    private UUID offerReference;
    @Column(nullable = false, updatable = false)
    private boolean synthetic;
    @Column(updatable = false)
    private UUID reusedAssessmentId;

    protected EligibilityAssessment() {}

    public EligibilityAssessment(UUID profileId, long revision, String key, Request request, boolean synthetic,
                                 Instant now, Instant deadline, UUID reusedAssessmentId) {
        this.id = UUID.randomUUID();
        this.profileId = profileId;
        this.financialRevision = revision;
        this.idempotencyKey = key;
        this.kind = request.kind();
        this.state = reusedAssessmentId == null ? State.PENDING : State.REUSED;
        this.consentVersion = request.consentVersion();
        this.consentedAt = now;
        this.createdAt = now;
        this.updatedAt = now;
        this.processingDeadline = deadline;
        this.synthetic = synthetic;
        this.reusedAssessmentId = reusedAssessmentId;
    }

    public void finish(Decision decision, String scoreMetadata, Long limit, Long emi, boolean offer,
                       Instant now, Instant expiresAt) {
        this.state = State.COMPLETED;
        this.decision = decision;
        this.scoreMetadata = scoreMetadata;
        this.approvedLimitPaise = limit;
        this.affordableMonthlyEmiPaise = emi;
        this.offerReference = offer ? UUID.randomUUID() : null;
        this.updatedAt = now;
        this.resultExpiresAt = expiresAt;
    }

    public void abandon(State state, Instant now) {
        this.state = state;
        this.updatedAt = now;
    }

    public enum Failure { PROVIDER, TIMEOUT, UNAVAILABLE }

    public void fail(Failure failure, Instant now) {
        abandon(State.FAILED, now);
        // Completed rows hold score JSON here. Failed rows hold only a safe outcome code.
        this.scoreMetadata = failure.name();
    }

    public Failure failure() {
        if (state != State.FAILED || scoreMetadata == null) return Failure.UNAVAILABLE;
        return Failure.valueOf(scoreMetadata);
    }

    public UUID id() { return id; }
    public long financialRevision() { return financialRevision; }
    public Kind kind() { return kind; }
    public State state() { return state; }
    public short consentVersion() { return consentVersion; }
    public Instant updatedAt() { return updatedAt; }
    public Instant processingDeadline() { return processingDeadline; }
    public Instant resultExpiresAt() { return resultExpiresAt; }
    public Decision decision() { return decision; }
    public String scoreMetadata() { return scoreMetadata; }
    public Long approvedLimitPaise() { return approvedLimitPaise; }
    public Long affordableMonthlyEmiPaise() { return affordableMonthlyEmiPaise; }
    public UUID offerReference() { return offerReference; }
    public boolean synthetic() { return synthetic; }
    public UUID reusedAssessmentId() { return reusedAssessmentId; }
}
