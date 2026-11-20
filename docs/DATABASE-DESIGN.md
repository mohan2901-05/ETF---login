# DATABASE DESIGN - PROPOSED
# =========================

**STATUS: PROPOSED — AWAITING APPROVAL**

This document describes the proposed initial data model for the ETF Loans backend.
The design is awaiting explicit approval before any tables are created.

No tables have been created yet. The following design is proposed for the
initial authentication schema. Database DDL is documentation only —
do not execute SQL.

---

## Overview

The database uses PostgreSQL 18 with the `etf_loans_app` user connecting to
the `ETF-login(sap)` database. The schema uses the `public` namespace.

Existing configuration decisions must remain unchanged:
- `spring.jpa.hibernate.ddl-auto=validate` — Hibernate will NOT auto-create or modify tables
- `spring.flyway.enabled=false` — Flyway migrations must be explicitly run after approval
- Database credentials supplied through environment variables (DB_URL, DB_USERNAME, DB_PASSWORD)

---

## Proposed Tables

### 1. `users`

Stores borrower account information. Account creation occurs only after
successful OTP verification (first-time user flow). No password is stored
because this is an OTP-based authentication system, not credential-based.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PK, NOT NULL, DEFAULT `gen_random_uuid()` | Primary key |
| `mobile_number` | VARCHAR(15) | NOT NULL, UNIQUE, CHECK (mobile_number ~ '^[6-9]\d{9,14}$') | Borrower's mobile number in E.164 format (e.g., "+919876543210") |
| `full_name` | VARCHAR(100) | NULLable | Borrower's full name (optional; provided on first profile update) |
| `is_active` | BOOLEAN | NOT NULL, DEFAULT true | Account status — true if email/OTP verified |
| `created_at` | TIMESTAMP | NOT NULL, DEFAULT now() | Account creation time |
| `updated_at` | TIMESTAMP | NOT NULL, DEFAULT now() | Last update time (on profile change) |

**Indexes:**

- `idx_users_mobile_number` — ON users(mobile_number) — UNIQUE index for lookups and constraint enforcement
- `idx_users_active` — ON users(is_active) — Filter by active users

**Relationships:**

- No foreign keys (standalone entity; identity managed via OTP challenges)
- Unique constraint on `mobile_number` ensures one account per mobile number

---

### 2. `otp_challenges`

Stores OTP verification challenges. No foreign key to `users` because
OTP challenges are identified by mobile number alone — a user account
may not yet exist when the challenge is created (first-time login flow).
The challenge is consumed (one-time use) on successful verification.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `challenge_id` | UUID | PK, NOT NULL, DEFAULT `gen_random_uuid()` | Unique identifier for this OTP challenge |
| `mobile_number` | VARCHAR(15) | NOT NULL | Borrower's mobile number in E.164 format |
| `otp_hash` | VARCHAR(64) | NOT NULL, CHECK (length(otp_hash) = 64) | HMAC-SHA-256 hash of the OTP value (plaintext OTP never stored) |
| `expires_at` | TIMESTAMP | NOT NULL | Challenge expiry time; after this, challenge is automatically expired |
| `attempt_count` | INTEGER | NOT NULL, DEFAULT 0 | Number of failed verification attempts for this challenge |
| `max_attempts` | INTEGER | NOT NULL, DEFAULT 5 | Maximum allowed verification attempts per challenge |
| `created_at` | TIMESTAMP | NOT NULL, DEFAULT now() | Challenge creation time |
| `consumed_at` | TIMESTAMP | NULL | Timestamp when challenge was successfully verified (NULL = unconsumed) |
| `request_ip` | INET | NULL | Source IP address of the OTP send request (for rate limiting) |
| `delivery_provider` | VARCHAR(20) | NOT NULL, DEFAULT 'mock' | OTP delivery provider: 'mock', 'twilio', 'internal_sms' |

**Indexes:**

- `idx_otp_challenge_id` — ON otp_challenges(challenge_id) — PRIMARY KEY index
- `idx_otp_mobile_number` — ON otp_challenges(mobile_number) — Index for lookup by mobile number
- `idx_otp_expires` — ON otp_challenges(expires_at) — Index for automated cleanup of expired challenges
- `idx_otp_consumed` — ON otp_challenges(consumed_at) — Index for finding unconsumed challenges

**Design Rationale:**

- **No `user_id` foreign key:** OTP challenges are mobile-number-scoped, not user-scoped.
  A challenge may be created before a user account exists (first-time login). The
  mobile number uniquely identifies the challenge until consumption.
- **`otp_hash` instead of plaintext:** OTP value is never stored in plaintext.
  Only the HMAC-SHA-256 hash is persisted. This prevents credential leakage
  even if the database is compromised.
- **`consumed_at` tracks one-time use:** After successful verification,
  `consumed_at` is set, making the challenge ineligible for reuse.
- **`delivery_provider` enables provider swapping:** Starting with mock provider,
  Twilio or internal SMS gateway can be swapped per `spring.profiles.active`.

**Automated Cleanup (handled by scheduled job or PostgreSQL cron):**

- Challenges where `consumed_at` IS NOT NULL AND `expires_at` < now() — already consumed, remove
- Challenges where `expires_at` < now() AND `consumed_at` IS NULL — expired and unconsumed, remove
- Rate limiting data older than 24 hours can be purged

---

### 3. `user_sessions`

Stores active user sessions for logout and concurrent session control.
Only SHA-256 hash of the session token is stored; the plaintext token
resides only on the client device (Flutter Secure Storage).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `session_id` | UUID | PK, NOT NULL, DEFAULT `gen_random_uuid()` | Unique identifier for this session |
| `user_id` | UUID | NOT NULL, FK → users(id) | Associated user account |
| `token_hash` | VARCHAR(64) | NOT NULL, UNIQUE, CHECK (length(token_hash) = 64) | SHA-256 hash of the opaque session token |
| `device_info` | TEXT | NULLable | Device fingerprint (e.g., model, OS version) |
| `ip_address` | INET | NULL | Connection IP address at session creation |
| `created_at` | TIMESTAMP | NOT NULL, DEFAULT now() | Session creation time |
| `last_used_at` | TIMESTAMP | NOT NULL, DEFAULT now() | Timestamp of last request using this session |
| `expires_at` | TIMESTAMP | NOT NULL | Session expiry time (30 days from creation) |
| `revoked_at` | TIMESTAMP | NULL | Timestamp when session was revoked (logout) |

**Indexes:**

- `idx_sessions_session_id` — ON user_sessions(session_id) — PRIMARY KEY index
- `idx_sessions_user_id` — ON user_sessions(user_id) — Index by user (for logout/all sessions)
- `idx_sessions_token_hash` — ON user_sessions(token_hash) — UNIQUE index for token validation
- `idx_sessions_expires` — ON user_sessions(expires_at) — Index for automated session cleanup
- `idx_sessions_last_used` — ON user_sessions(last_used_at) — Index for session cleanup and timeout enforcement

**Design Rationale:**

- **Only SHA-256 hash stored:** The plaintext session token never touches the database.
  The token exists only on the client (Flutter Secure Storage). Server-side,
  only the hash is used for validation. Even if the database is compromised,
  attacker cannot reconstruct the session token.
- **`last_used_at` for timeout enforcement:** Session considered inactive if
  `current_timestamp - last_used_at > 24 hours` of inactivity, then auto-logout.
- **`revoked_at` for logout:** On logout, `revoked_at` is set and `expires_at` effectively
  becomes immediate; subsequent requests with this token return 401.
- **`ip_address` for anomaly detection:** Optional; can be used to flag
  sessions from unexpected IP addresses.

---

## Why Design Choices Exist

### Why OTP challenges do not require a `user_id` foreign key

OTP challenges are scoped by mobile number, not by user account. This is
intentional because:

1. A challenge may be created when no user account exists yet (first-time login).
2. The mobile number is the stable identifier across the authentication flow.
3. After successful verification, a new `users` row is created (or an existing one
   updated) linked to the mobile number.
4. Decoupling simplifies the schema and avoids orphaned records if account creation
   fails or is delayed.

### Why OTP plaintext is never stored

- Security principle: never store secrets in plaintext if hashing is feasible.
- HMAC-SHA-256 of the OTP value is stored instead; the original OTP is ephemeral.
- Even if the database is compromised, attacker only has hash values, not OTP codes.
- Prevents accidental exposure in logs, backups, or query tools.
- Consistent with industry best practices for OTP/totp systems.

### Why only session token hashes are stored

- Same security principle: the session token is a client-side credential.
- The Flutter app stores the opaque token in `flutter_secure_storage` (or equivalent).
- Server only needs to validate: `SHA256(client_token) == stored_token_hash`.
- Even with database compromise, no session tokens can be reconstructed.
- Enables session revocation without invalidating client tokens immediately
  (set `revoked_at`; existing tokens still match hash but are logically expired).

### How expired and consumed challenges are handled

- **Convened (successfully verified):** `consumed_at` IS NOT NULL. The challenge row
  remains in the table for audit purposes but is ineligible for reuse. A scheduled
  job can purge consumed challenges older than 24 hours.
- **Expired (time-to-live):** `consumed_at` IS NULL AND `expires_at` < now().
  The challenge is expired and unconsumed. A scheduled job can purge expired
  challenges older than 24 hours.
- **Rate limiting window:** Expired challenges contribute to the 15-minute/24-hour
  rate limit window during their lifetime. After expiry, they no longer count.

### How rate limiting can work without introducing Redis

Rate limiting is implemented using database-level counters within the existing
tables, no external Redis required:

- **Per mobile number per 15 minutes:** `SELECT COUNT(*) FROM otp_challenges
  WHERE mobile_number = ? AND created_at > now() - INTERVAL '15 minute'`
- **Per mobile number per 24 hours:** Same query with INTERVAL '24 hour'
- **Per IP per hour:** Query `api_requests` or track in `otp_challenges.request_ip`
  with `COUNT(*) WHERE request_ip = ? AND created_at > now() - INTERVAL '1 hour'`
- **Per challenge attempt count:** `attempt_count` in `otp_challenges` table;
  lockout when `attempt_count >= max_attempts` (5)

All counters are pure SQL; no separate cache required. For a development-scale
application on limited resources (8 GB RAM), this is a pragmatic approach.

### How a first-time user is created only after successful verification

The authentication flow is:

1. Flutter sends `POST /api/auth/otp/send` with `mobileNumber`
2. Backend creates `otp_challenges` row (challenge_id, mobile_number, otp_hash, etc.)
3. Flutter displays OTP entry screen; user enters 6-digit code
4. Flutter sends `POST /api/auth/otp/verify` with `challengeId`, `mobileNumber`, `otp`
5. Backend validates OTP hash against stored `otp_hash`
6. **On success:**
   - `otp_challenges.consumed_at` = now()
   - Check if a `users` row exists for this `mobile_number`
   - **If no existing user:** INSERT new row into `users` (`mobile_number`, `is_active` = true, `created_at`, `updated_at`)
   - **If existing user:** UPDATE `users` set `is_active` = true, `updated_at` = now()
   - Create `user_sessions` row (`user_id`, `token_hash`, `created_at`, `expires_at`, `last_used_at`)
   - Return `accessToken` in successful verify response
7. **On failure:** `attempt_count` incremented; if `attempt_count >= max_attempts`, return `OTP_ATTEMPTS_EXCEEDED`

This ensures a user account is created **only** after successful OTP verification,
never before. No account exists with a password or before OTP authentication.

---

## Proposed PostgreSQL DDL (Documentation Only)

Do not execute the following SQL. It is provided for review purposes only.

```sql
-- Table: users
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    mobile_number VARCHAR(15) NOT NULL UNIQUE
        CHECK (mobile_number ~ '^[6-9]\d{9,14}$'),
    full_name VARCHAR(100),
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    updated_at TIMESTAMP NOT NULL DEFAULT now()
);

-- Indexes for users
CREATE INDEX idx_users_mobile_number ON users(mobile_number);
CREATE INDEX idx_users_active ON users(is_active);

-- Table: otp_challenges
CREATE TABLE otp_challenges (
    challenge_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    mobile_number VARCHAR(15) NOT NULL,
    otp_hash VARCHAR(64) NOT NULL CHECK (length(otp_hash) = 64),
    expires_at TIMESTAMP NOT NULL,
    attempt_count INTEGER NOT NULL DEFAULT 0,
    max_attempts INTEGER NOT NULL DEFAULT 5,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    consumed_at TIMESTAMP,
    request_ip INET,
    delivery_provider VARCHAR(20) NOT NULL DEFAULT 'mock'
);

-- Indexes for otp_challenges
CREATE INDEX idx_otp_challenge_id ON otp_challenges(challenge_id);
CREATE INDEX idx_otp_mobile_number ON otp_challenges(mobile_number);
CREATE INDEX idx_otp_expires ON otp_challenges(expires_at);
CREATE INDEX idx_otp_consumed ON otp_challenges(consumed_at);

-- Table: user_sessions
CREATE TABLE user_sessions (
    session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    token_hash VARCHAR(64) NOT NULL UNIQUE CHECK (length(token_hash) = 64),
    device_info TEXT,
    ip_address INET,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    last_used_at TIMESTAMP NOT NULL DEFAULT now(),
    expires_at TIMESTAMP NOT NULL,
    revoked_at TIMESTAMP
);

-- Indexes for user_sessions
CREATE INDEX idx_sessions_user_id ON user_sessions(user_id);
CREATE INDEX idx_sessions_token_hash ON user_sessions(token_hash);
CREATE INDEX idx_sessions_expires ON user_sessions(expires_at);
CREATE INDEX idx_sessions_last_used ON user_sessions(last_used_at);
```

---

## Security Considerations

1. **Never store plaintext OTP** — Only HMAC-SHA-256 hash persisted; original OTP is ephemeral
2. **Never store plaintext session token** — Only SHA-256 hash persisted; token resides on client only
3. **HTTPS requirement outside local development** — All API traffic must use TLS; local HTTP allowed only with `spring.profiles.active=local`
4. **SecureRandom for OTP generation** — Use `java.security.SecureRandom` with `StrongRNG` algorithm
5. **OTP HMAC secret stored outside source control** — Secret key for HMAC-SHA-256 via environment variable or vault
6. **Session token generated using cryptographically secure randomness** — `SecureRandomUUID` or similar
7. **Only SHA-256 session token hashes stored in PostgreSQL** — Plaintext token never written to DB
8. **Rate limiting via database queries** — No Redis required; SQL counters sufficient for scale
9. **Atomic OTP verification** — Transaction: decrement/increment attempt_count, set consumed_at, create user/session all in one atomic operation
10. **Generic error responses** — Same format across all endpoints to reduce account enumeration attacks
11. **No credentials or secrets in Flutter** — Flutter contains no database credentials or OTP secrets
12. **Flutter secure storage for bearer tokens** — `flutter_secure_storage` or `encrypted_shared_preferences`
13. **Server-side session revocation** — On logout, `revoked_at` set; subsequent requests return 401
14. **Mock provider disabled in production** — `spring.profiles.active=production` or `!local` disables mock provider

---

## Pending Decisions

- [ ] OTP delivery mechanism (Twilio vs internal SMS gateway) — provider class implementation
- [ ] HMAC-SHA-256 secret management — environment variable name and vault integration
- [ ] Token lifetime (30 days proposed; adjust based on stakeholder input)
- [ ] Session timeout inactivity period (24 hours proposed; adjust based on UX input)
- [ ] Device fingerprinting detail level (full `user-agent` vs minimal)
- [ ] GDPR/data retention policy for OTP challenges (purge after 30/60/90 days)

---

## Flutter Model Compatibility

| Flutter Model | DB Table | Field Mapping | Status |
|---------------|----------|---------------|--------|
| `MobileNumberRequest` | `otp_challenges` | `mobileNumber` → `mobile_number` column | ✅ Compatible |
| `OtpVerificationRequest` | `otp_challenges` | `challengeId` → `challenge_id`, `mobileNumber` → `mobile_number`, `otp` → used for hash comparison only (not stored) | ✅ Compatible (otp not stored) |
| `OtpSendResponse` | — | `success`, `message`, `challengeId`, `expiresInSeconds`, `resendAfterSeconds` | ⚠️ Map to `otp_challenges` creation response |
| `OtpVerifyResponse` | `users` + `user_sessions` + `otp_challenges` | `success`, `message`, `accessToken`, `expiresInSeconds`, `user.id`, `user.mobileNumber`, `user.isNewUser` | ⚠️ Map to combined verification response |
| `UserProfile` | `users` | `id`, `mobileNumber`, `name` (optional) | ✅ Compatible after account creation |

**Note:** Flutter models in `auth_models.dart` will need field extensions to fully align with the proposed database schema. Do not modify Flutter code per task scope; document gaps for future alignment.

---

# END OF DOCUMENT

*Mark all design decisions as PROPOSED / AWAITING APPROVAL.*