# Phase 02 authentication

The password flows are approved for local development. Real SMS delivery requires a provider and configuration approval. Keep shared and production databases outside this rollout.

## REST contract

All mobile numbers use 10 Indian national digits. OTP requests use six digits. Password and grant requests require HTTPS outside loopback development.

| POST path under `/api/auth` | Request | Success response |
|---|---|---|
| `/otp/send` | `mobileNumber` | Existing challenge response |
| `/otp/resend` | `mobileNumber`, `challengeId` | Replacement challenge response |
| `/otp/verify` | `mobileNumber`, `challengeId`, `otp` | Existing bearer-session response for passwordless accounts |
| `/password/{flow}/start` | `mobileNumber` and, for `login`, `password` | Challenge response |
| `/password/{flow}/resend` | `mobileNumber`, `challengeId` | Replacement challenge response |
| `/password/{flow}/verify` | `mobileNumber`, `challengeId`, `otp` | Bearer session for `login`, or `grantToken` for `registration` and `recovery` |
| `/password/{flow}/complete` | `grantToken`, `password` for `registration` or `recovery` | HTTP 204 with an empty body |
| `/logout` | Bearer header | Idempotent success and revocation of the supplied session |

`GET /api/auth/me` requires a valid bearer token for an active user. Challenge responses preserve the existing `success`, `message`, `challengeId`, `expirySeconds`, and `resendAfterSeconds` fields. The development code is restricted to mock-enabled local or test configuration. The local profile listens on loopback. Password sign-in returns HTTP 401 with the same error for an unknown account, invalid password or ineligible account. Rejected sign-ins create no challenge and send no code. Registration and recovery still return indistinguishable challenge responses and suppress delivery for ineligible accounts. Rate limits apply to start, resend and verify requests. Resend consumes the previous challenge. Password sign-in resends stay within the expiry window established by the password check.

Registration creates an active account after a verified grant and password setup. Existing active passwordless accounts can use registration to add a password after proving control of the mobile number. Registration and recovery both return the client to sign-in and revoke earlier sessions. Recovery requires an existing password account.

## Migration and storage

`V2__Add_password_authentication.sql` adds nullable `users.password_hash`, purpose and credential fingerprint to OTP challenges, and a table for password grants. Existing challenges default to `LEGACY_LOGIN`. Existing users, sessions and challenge rows are preserved. A password change makes older challenges and grants for that credential unusable.

BCrypt uses cost **12**. A new password requires at least **12 Unicode code points** and at most **72 UTF-8 bytes**. Blank passwords are rejected. The server rejects oversized input before hashing or matching, preserving the full input without truncation or normalization. Passwords are never persisted by Flutter.

Grants contain 256 bits of randomness, expire in **five minutes**, and are stored as SHA-256 hashes. Transactional row locks serialize challenge verification, resend and grant consumption. Expiry is evaluated after locking. A wrong-code response commits the attempt count in its transaction. Password updates, grant consumption and session revocation commit together.

## Local device testing

With the isolated local profile and mock OTP enabled, send and verify quotas use a 10-second window and resend uses a 10-second cooldown. Set `ETF_LOCAL_OTP_COOLDOWN_SECONDS` to a positive integer to change all three. Production retains the 900-second send and verify windows and 30-second resend cooldown.

Provision a separate loopback PostgreSQL database named `etf_loans_device` with synthetic accounts only. Apply the unchanged migrations as an approved, separate step. Set `ETF_DEVICE_DB_URL` to `jdbc:postgresql://127.0.0.1:<port>/etf_loans_device`. Supply its credentials through `ETF_DEVICE_DB_USERNAME` and `ETF_DEVICE_DB_PASSWORD`, and set a separate random `ETF_DEV_OTP_KEY` of at least 32 characters. Set `$otp` to a six-digit local mock code in your console. Run `.\start-local-dev.ps1 -SyntheticAccountsOnly -MockOtpCode $otp`. The launcher disables startup migrations and Hibernate validates the installed schema. It refuses to reuse a backend already listening on port 8080. Use USB ADB reverse for loopback development.

Keep local and test databases, keys and tokens separate from all shared and production environments. Older backend versions must never access the V2 authentication database. They do not enforce V2 password and OTP-purpose checks. Before deploying outside development, confirm the intern team's API and database contract, enforce HTTPS, configure a real SMS provider and verify that provider timing preserves account enumeration protections. A shared throttle is required before running multiple instances. The local limiter has bounded per-instance storage and its counters reset on restart.

## Reproduce verification

Run `.\verify-phase02-backend.ps1` on Windows with PostgreSQL 18, Java 17 and Maven's dependencies cached. It runs H2 first, then creates a temporary, authenticated loopback PostgreSQL cluster with separate suite and V1-to-V2 migration databases. The script copies sources to a temporary build directory and writes Maven and Surefire reports and the effective PostgreSQL database identity to `phase02-verification/`. The PostgreSQL-only tests wait for observed database lock contention. PostgreSQL data and credentials are disposable.

From `etf-loans-flutter`, run `cmd /c flutter analyze` and `cmd /c flutter test --no-pub --concurrency=1 --reporter compact`.
