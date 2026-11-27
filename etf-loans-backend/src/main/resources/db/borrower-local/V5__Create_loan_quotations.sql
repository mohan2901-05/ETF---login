CREATE TABLE loan_quotations (
    id UUID PRIMARY KEY,
    profile_id UUID NOT NULL,
    financial_revision BIGINT NOT NULL CHECK (financial_revision >= 0),
    assessment_id UUID NOT NULL,
    idempotency_key VARCHAR(128) NOT NULL,
    principal_paise BIGINT NOT NULL CHECK (principal_paise > 0),
    tenure_months SMALLINT NOT NULL CHECK (tenure_months > 0),
    pricing_version VARCHAR(64) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL CHECK (expires_at > created_at),
    quote_terms JSONB NOT NULL CHECK (jsonb_typeof(quote_terms) = 'object'),
    UNIQUE (profile_id, idempotency_key),
    FOREIGN KEY (profile_id, financial_revision, assessment_id)
        REFERENCES eligibility_assessments(profile_id, financial_revision, id)
);
