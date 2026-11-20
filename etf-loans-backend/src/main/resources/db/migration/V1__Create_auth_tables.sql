-- Flyway migration V1: Create authentication tables
-- Creates users, otp_challenges, and user_sessions tables
-- Compatible with PostgreSQL 18

-- =====================================================================
-- USERS TABLE
-- =====================================================================
CREATE TABLE users (
    id              UUID PRIMARY KEY,
    mobile_number   VARCHAR(20) NOT NULL UNIQUE,
    full_name       VARCHAR(100),
    is_active       BOOLEAN NOT NULL DEFAULT true,
    created_at      TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    updated_at      TIMESTAMP WITHOUT TIME ZONE NOT NULL
);

CREATE INDEX idx_users_mobile_number ON users(mobile_number);

-- =====================================================================
-- OTP_CHALLENGES TABLE
-- =====================================================================
CREATE TABLE otp_challenges (
    challenge_id      UUID PRIMARY KEY,
    mobile_number     VARCHAR(20) NOT NULL,
    otp_hash          VARCHAR(128) NOT NULL,
    expires_at        TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    attempt_count     INTEGER NOT NULL DEFAULT 0,
    max_attempts      INTEGER NOT NULL DEFAULT 5,
    created_at        TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    consumed_at       TIMESTAMP WITHOUT TIME ZONE,
    request_ip        VARCHAR(45),
    delivery_provider VARCHAR(50)
);

CREATE INDEX idx_otp_challenges_mobile ON otp_challenges(mobile_number);
CREATE INDEX idx_otp_challenges_expires ON otp_challenges(expires_at);

-- =====================================================================
-- USER_SESSIONS TABLE
-- =====================================================================
CREATE TABLE user_sessions (
    session_id  UUID PRIMARY KEY,
    user_id     UUID NOT NULL,
    token_hash  VARCHAR(128) NOT NULL UNIQUE,
    device_info VARCHAR(255),
    ip_address  VARCHAR(45),
    created_at  TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    last_used_at TIMESTAMP WITHOUT TIME ZONE,
    expires_at  TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    revoked_at  TIMESTAMP WITHOUT TIME ZONE
);

CREATE INDEX idx_user_sessions_user ON user_sessions(user_id);
CREATE INDEX idx_user_sessions_token_hash ON user_sessions(token_hash);
CREATE INDEX idx_user_sessions_expires ON user_sessions(expires_at);
CREATE INDEX idx_user_sessions_revoked ON user_sessions(revoked_at);