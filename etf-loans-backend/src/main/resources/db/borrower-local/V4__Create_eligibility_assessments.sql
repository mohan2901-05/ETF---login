ALTER TABLE borrower_profiles
    ADD COLUMN financial_revision BIGINT NOT NULL DEFAULT 0 CHECK (financial_revision >= 0);

CREATE TABLE eligibility_assessments (
    id UUID PRIMARY KEY,
    profile_id UUID NOT NULL REFERENCES borrower_profiles(user_id),
    financial_revision BIGINT NOT NULL CHECK (financial_revision >= 0),
    idempotency_key VARCHAR(128) NOT NULL,
    kind VARCHAR(8) NOT NULL CHECK (kind IN ('INITIAL', 'RECHECK')),
    state VARCHAR(12) NOT NULL CHECK (state IN ('PENDING', 'COMPLETED', 'FAILED', 'EXPIRED', 'REUSED')),
    consent_version SMALLINT NOT NULL CHECK (consent_version > 0),
    consented_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    processing_deadline TIMESTAMPTZ NOT NULL,
    result_expires_at TIMESTAMPTZ,
    decision VARCHAR(10) CHECK (decision IN ('ELIGIBLE', 'INELIGIBLE')),
    score_metadata TEXT,
    approved_limit_paise BIGINT CHECK (approved_limit_paise >= 0),
    affordable_monthly_emi_paise BIGINT CHECK (affordable_monthly_emi_paise >= 0),
    offer_reference UUID UNIQUE,
    synthetic BOOLEAN NOT NULL,
    reused_assessment_id UUID,
    UNIQUE (profile_id, idempotency_key),
    UNIQUE (profile_id, financial_revision, id),
    FOREIGN KEY (profile_id, financial_revision, reused_assessment_id)
        REFERENCES eligibility_assessments(profile_id, financial_revision, id),
    CHECK ((state = 'REUSED') = (reused_assessment_id IS NOT NULL)),
    CHECK (reused_assessment_id IS NULL OR reused_assessment_id <> id),
    CHECK ((state = 'COMPLETED') = (decision IS NOT NULL AND result_expires_at IS NOT NULL)),
    CHECK (decision IS NOT DISTINCT FROM 'ELIGIBLE' OR
        (offer_reference IS NULL AND approved_limit_paise IS NULL AND affordable_monthly_emi_paise IS NULL))
);

CREATE UNIQUE INDEX eligibility_one_pending_per_revision
    ON eligibility_assessments(profile_id, financial_revision) WHERE state = 'PENDING';

CREATE INDEX eligibility_reusable_result
    ON eligibility_assessments(profile_id, financial_revision, synthetic, consent_version, result_expires_at)
    WHERE state = 'COMPLETED';
