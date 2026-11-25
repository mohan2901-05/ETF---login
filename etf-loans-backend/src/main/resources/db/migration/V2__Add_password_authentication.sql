ALTER TABLE users ADD COLUMN password_hash VARCHAR(60);

ALTER TABLE otp_challenges
    ADD COLUMN purpose VARCHAR(16) NOT NULL DEFAULT 'LEGACY_LOGIN',
    ADD COLUMN credential_fingerprint VARCHAR(64),
    ADD CONSTRAINT otp_challenges_purpose_check
        CHECK (purpose IN ('LEGACY_LOGIN', 'PASSWORD_LOGIN', 'REGISTRATION', 'RECOVERY'));

CREATE TABLE password_grants (
    token_hash VARCHAR(64) PRIMARY KEY,
    mobile_number VARCHAR(20) NOT NULL,
    purpose VARCHAR(16) NOT NULL CHECK (purpose IN ('REGISTRATION', 'RECOVERY')),
    credential_fingerprint VARCHAR(64),
    expires_at TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    consumed_at TIMESTAMP WITHOUT TIME ZONE
);

CREATE INDEX idx_password_grants_expires ON password_grants(expires_at);
