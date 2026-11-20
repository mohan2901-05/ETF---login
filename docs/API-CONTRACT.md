# API CONTRACT - PROPOSED
# =======================

**STATUS: PROPOSED — NOT IMPLEMENTED OR VERIFIED**

This document describes the proposed API contract for the ETF Loans backend.
Endpoints are proposed for the new Spring Boot backend, not verified endpoints
from the existing website.

---

## Base URL

`http://localhost:8080/api`

---

## Authentication Endpoints

### POST /api/auth/otp/send

**Description:** Send OTP to borrower's mobile number

**Authentication:** Public (no auth required)

**Request:**

```json
{
  "mobileNumber": "+919876543210"
}
```

**Request Fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `mobileNumber` | string | yes | Borrower's mobile number in E.164 format (e.g., "+919876543210") |

**Validation Rules:**

- Must be in E.164 format (prefixed with "+" and country code)
- Must contain 10-15 digits after the "+" prefix
- First digit after "+" must be 6-9 (valid Indian mobile numbering scheme)

**Successful Response (200):**

```json
{
  "success": true,
  "message": "Verification code requested.",
  "challengeId": "uuid",
  "expiresInSeconds": 300,
  "resendAfterSeconds": 30
}
```

**Response Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `success` | boolean | Indicates if the request was processed successfully |
| `message` | string | Human-readable confirmation message |
| `challengeId` | UUID | Unique identifier for this OTP challenge, used in verify request |
| `expiresInSeconds` | integer | Time-to-live for the OTP (5 minutes = 300 seconds) |
| `resendAfterSeconds` | integer | Minimum wait time before the OTP can be resent (30 seconds) |

**Error Responses:**

| Status | Code | Body Format | Description |
|--------|------|-------------|-------------|
| 400 | VALIDATION_ERROR | `{"message": "Specific validation error"}` | Invalid mobile number format |
| 429 | OTP_RATE_LIMITED | `{"message": "Too many requests. Try again in X seconds."}` | Rate limit exceeded per IP or per mobile number |
| 500 | INTERNAL_ERROR | `{"message": "Internal server error"}` | Unexpected error |

**Security Considerations:**

- Mobile number validation prevents malformed input
- Rate limiting protects against brute-force OTP attempts
- No OTP value returned in response
- challengeId is single-use and consumable after verification

**Expected Flutter Behavior:**

- Display success message on screen
- Store `challengeId` for use in OTP verification request
- Show countdown timer based on `expiresInSeconds`
- Allow OTP resend after `resendAfterSeconds` elapsed

---

### POST /api/auth/otp/verify

**Description:** Verify OTP and authenticate borrower

**Authentication:** Public (no auth required)

**Request:**

```json
{
  "challengeId": "uuid",
  "mobileNumber": "+919876543210",
  "otp": "123456"
}
```

**Request Fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `challengeId` | string (UUID) | yes | Challenge ID received from OTP send response |
| `mobileNumber` | string | yes | Borrower's mobile number in E.164 format |
| `otp` | string | yes | 6-digit numeric OTP code entered by user |

**Validation Rules:**

- `challengeId` must match an active, unconsumed OTP challenge
- `mobileNumber` must match the mobile number associated with the challenge
- `otp` must be exactly 6 digits
- OTP must not be expired (current time < created_at + expiresInSeconds)
- Maximum 5 verification attempts per challenge

**Successful Response (200):**

```json
{
  "success": true,
  "message": "Authentication successful.",
  "accessToken": "opaque-random-session-token",
  "tokenType": "Bearer",
  "expiresInSeconds": 2592000,
  "user": {
    "id": "uuid",
    "mobileNumber": "+919876543210",
    "name": null,
    "isNewUser": true
  }
}
```

**Response Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `success` | boolean | Indicates authentication succeeded |
| `message` | string | Human-readable authentication confirmation |
| `accessToken` | string | Opaque session token identifier (Bearer scheme) |
| `tokenType` | string | Authentication scheme prefix ("Bearer") |
| `expiresInSeconds` | integer | Session lifetime (30 days = 2592000 seconds) |
| `user.id` | UUID | Unique identifier for the user account |
| `user.mobileNumber` | string | Borrower's mobile number in E.164 format |
| `user.name` | string|null | Borrower's full name (null for new/first-time users) |
| `user.isNewUser` | boolean | True if this is the user's first login |

**Error Responses:**

| Status | Code | Body Format | Description |
|--------|------|-------------|-------------|
| 400 | OTP_INVALID | `{"message": "Invalid OTP"}` | OTP is not 6 digits or does not match challenge |
| 400 | OTP_EXPIRED | `{"message": "OTP has expired. Request a new one."}` | OTP validity period has passed |
| 400 | OTP_ATTEMPTS_EXCEEDED | `{"message": "Maximum verification attempts exceeded. Try again later."}` | 5 failed attempts for this challenge |
| 429 | OTP_RATE_LIMITED | `{"message": "Too many verification attempts. Try again in X seconds."}` | Rate limit for verify requests |
| 401 | UNAUTHORIZED | `{"message": "Unauthorized"}` | Missing or invalid context |
| 500 | INTERNAL_ERROR | `{"message": "Internal server error"}` | Unexpected error |

**Security Considerations:**

- OTP is consumed (one-time use) after successful verification
- Failed attempts are tracked per challenge
- Rate limiting prevents brute-force attacks
- OTP plaintext is never returned in any response
- challengeId is invalidated after verification (consumed)
- Session created only after successful verification

**Expected Flutter Behavior:**

- Show error message on invalid/expired OTP
- Navigate to main application screen on successful authentication
- Store `accessToken` securely using Flutter secure storage
- Refresh session before `expiresInSeconds` elapses
- Show resend OTP button after `resendAfterSeconds` cooldown

---

### POST /api/auth/logout

**Description:** Log out the authenticated user

**Authentication:** Requires valid Bearer `accessToken`

**Request:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| Authorization | string (Bearer token) | yes | Access token received from verify response |

**Header:**

```
Authorization: Bearer <accessToken>
```

**Successful Response (200):**

```json
{
  "success": true,
  "message": "Logged out successfully"
}
```

**Error Responses:**

| Status | Code | Body Format | Description |
|--------|------|-------------|-------------|
| 401 | UNAUTHORIZED | `{"message": "Invalid or expired token"}` | Token is missing, malformed, or expired |
| 401 | UNAUTHORIZED | `{"message": "Session already revoked"}` | Session no longer active |
| 500 | INTERNAL_ERROR | `{"message": "Internal server error"}` | Unexpected error |

**Security Considerations:**

- Token is invalidated on server side
- Session revocation timestamp recorded
- Concurrent session control enforced
- Client should clear stored token after successful logout

**Expected Flutter Behavior:**

- Clear stored `accessToken` from secure storage
- Navigate back to login screen
- Show success message on logout

---

### GET /api/auth/me

**Description:** Get current authenticated user profile

**Authentication:** Requires valid Bearer `accessToken`

**Request:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| Authorization | string (Bearer token) | yes | Access token received from verify response |

**Header:**

```
Authorization: Bearer <accessToken>
```

**Successful Response (200):**

```json
{
  "id": "uuid",
  "mobileNumber": "+919876543210",
  "name": null,
  "isNewUser": true
}
```

**Response Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `id` | UUID | User's unique identifier |
| `mobileNumber` | string | Borrower's mobile number in E.164 format |
| `name` | string|null | Borrower's full name (null if not yet provided) |
| `isNewUser` | boolean | True if this is the user's first login after OTP verification |

**Error Responses:**

| Status | Code | Body Format | Description |
|--------|------|-------------|-------------|
| 401 | UNAUTHORIZED | `{"message": "Invalid or expired token"}` | Token is missing, malformed, or expired |
| 404 | — | `{"message": "User not found"}` | Token valid but user record not found (rare) |
| 500 | INTERNAL_ERROR | `{"message": "Internal server error"}` | Unexpected error |

**Security Considerations:**

- Token validation on server side
- Returns only authorized user's data
- No sensitive information (passwords, raw OTPs) in response
- Session expiry enforced via `expiresInSeconds`

**Expected Flutter Behavior:**

- Display user profile information
- Enable profile editing features (name, etc.)
- Token refresh if near expiry
- Redirect to login if token invalid/expired

---

## Error Handling

All error responses follow a consistent structure:

```json
{
  "timestamp": "2024-01-15T10:30:00Z",
  "status": 400,
  "error": "Bad Request",
  "message": "Specific error message",
  "path": "/api/auth/otp/verify"
}
```

**HTTP Status Codes:**

| Code | Meaning | Usage |
|------|---------|-------|
| 400 | Bad Request | Invalid input validation |
| 401 | Unauthorized | Missing or invalid token / OTP invalid/expired |
| 403 | Forbidden | Token does not have required roles |
| 422 | Unprocessable Entity | Business logic validation failed |
| 429 | Too Many Requests | Rate limit exceeded |
| 500 | Internal Server Error | Unexpected error |

---

## OTP Policy

| Parameter | Value | Description |
|-----------|-------|-------------|
| OTP Length | 6 digits | Numeric only |
| OTP Expiry | 5 minutes | 300 seconds from creation |
| Max Attempts | 5 per challenge | Verification attempts per challenge_id |
| Resend Cooldown | 30 seconds | Minimum wait between OTP resends |
| OTP Requests per MP per 15 min | 3 | Maximum OTP send requests per mobile number in 15 minutes |
| OTP Requests per MP per 24 hr | 10 | Maximum OTP send requests per mobile number in 24 hours |
| OTP Requests per IP per hr | 20 | Maximum OTP send requests per source IP in 1 hour |
| Delivery Provider | HMAC-SHA-256 | Secure OTP generation and hash storage |
| Plaintext OTP | Never stored | OTP value never persisted in database or logs |
| Hash Storage | HMAC-SHA-256 | OTP hash (not plaintext) stored in challenge record |
| Consumption | Atomic | challengeId consumed on successful verification |

**Development-Only Mock OTP:**

- When no production OTP provider is configured, a mock provider may be used in local/development mode only
- OTP mock code supplied via environment variable: `ETF_OTP_MOCK_CODE`
- Mock provider **disabled** in production/professional deployment
- Missing mock configuration must fail clearly (error, not silent fallback)
- Mock OTP value is 6 digits; actual SMS delivery via Twilio will implement the same `OtpDeliveryProvider` interface
- Development profile: `spring.profiles.active=local` enables mock provider

**Mock OTP Workflow:**

1. Flutter sends OTP send request to `/api/auth/otp/send`
2. Backend generates challengeId, stores HMAC-SHA-256 hash of mock OTP
3. Backend returns `challengeId` to Flutter
4. Flutter displays OTP entry field (mock code from `ETF_OTP_MOCK_CODE` env var)
5. Flutter sends verify request with `challengeId`, `mobileNumber`, and entered OTP
6. Backend compares entered OTP hash against stored hash
7. On match, challenge consumed, session created, user authenticated

**Error Handling for Mock:**

- If `ETF_OTP_MOCK_CODE` not set and profile is `local`, backend returns 500 with clear message
- If `ETF_OTP_MOCK_CODE` set, mock OTP comparison proceeds normally
- Production profile (`spring.profiles.active=production` or `!local`) disables mock provider entirely

---

## Session Management

| Aspect | Details |
|--------|---------|
| Token Type | Opaque random session token (not JWT by default) |
| Token Scheme | Bearer |
| Token Lifetime | 30 days (2592000 seconds) |
| Token Storage Client | Flutter Secure Storage (`flutter_secure_storage`) |
| Server-Side Storage | None (token is opaque; only hash tracked) |
| Concurrent Sessions | 1 per user (subsequent logins replace previous) |
| Logout Behavior | Token invalidated; subsequent use returns 401 |
| Token Refresh | Not supported; re-authenticate via OTP flow |
| Session Revocation | Server-side on logout; client clears stored token |

---

## Data Validation (Jakarta Bean Validation)

- `@NotNull`: Field must not be null
- `@Size(min=6, max=15)`: Mobile number length after E.164 prefix
- `@Pattern(regexp="^\\+[6-9]\\d{9,14}$")`: Mobile number pattern (E.164)
- `@NotEmpty`: Field must not be empty string

---

## Error Response Structure (Consistent Across All Endpoints)

```json
{
  "timestamp": "2024-01-15T10:30:00Z",
  "status": 400,
  "error": "Bad Request",
  "message": "Specific error message",
  "path": "/api/auth/otp/verify"
}
```

**Mark all contract decisions as PROPOSED / AWAITING APPROVAL.**

---

## Flutter Model Compatibility

| Flutter Model | Endpoint Field Mapping | Status |
|---------------|----------------------|--------|
| `MobileNumberRequest` | `OTP send` request `mobileNumber` | ✅ Compatible |
| `OtpVerificationRequest` | `OTP verify` request `challengeId`, `mobileNumber`, `otp` | ⚠️ Fields will need extension (currently has mobileNumber + otp only) |
| `OtpSendResponse` | `OTP send` response `success`, `message`, but lacks `challengeId`, `expiresInSeconds`, `resendAfterSeconds` | ⚠️ Model will need extension |
| `OtpVerifyResponse` | `OTP verify` response `success`, `message`, lacks `accessToken`, `tokenType`, `expiresInSeconds`, `user` | ⚠️ Model will need extension |
| `UserProfile` | `GET /me` response `id`, `mobileNumber`, but lacks `isNewUser` | ⚠️ Model will need extension |

**Note:** Flutter models documented in `auth_models.dart` will require extension to fully match the proposed contract. Do not modify Flutter code per task scope; document field gaps for future alignment.

---

# END OF DOCUMENT

*Mark all contract decisions as PROPOSED / AWAITING APPROVAL.*