# Deployment Guide (prepared — not executed)

No deployment, cloud resource creation, database migration, or secret entry was
performed. This document describes the approved, repeatable steps.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         RESTRICTED DEMO ARCHITECTURE                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   ┌──────────────┐       HTTPS        ┌──────────────┐                 │
│   │  Flutter Web │ ─────────────────► │  Vercel      │                 │
│   │  (Static)    │                    │  Serverless  │                 │
│   └──────────────┘                    │  Function    │                 │
│        │                              │  (API Key)   │                 │
│        │                              └──────┬───────┘                 │
│        │                                     │                        │
│        │                              HTTPS  ▼                        │
│        │                    ┌──────────────────────────┐              │
│        │                    │  Render Web Service      │              │
│        └───────────────────►│  (Spring Boot API)       │              │
│                             │  Validates X-API-Key     │              │
│                             └───────────┬──────────────┘              │
│                                         │                             │
│                                         ▼                             │
│                              ┌─────────────────────┐                  │
│                              │  PostgreSQL (Flyway)│                  │
│                              └─────────────────────┘                  │
│                                                                       │
│   ┌──────────────┐         HTTPS + X-API-Key     ┌──────────────┐    │
│   │  Flutter     │ ─────────────────────────────► │  Render      │    │
│   │  Android APK │                                 │  Web Service │    │
│   └──────────────┘                                 └──────────────┘    │
│                                                                       │
└─────────────────────────────────────────────────────────────────────────┘
```

Spring Boot is **not** deployed to Vercel: Vercel serverless functions cannot run a
conventional long-lived Spring Boot/JVM process. Host the API on Render and the Flutter
Web build on Vercel.

## 1. Backend — Render (Docker)

Files: `etf-loans-backend/Dockerfile`, `render.yaml` (repo root).

1. Create a Render **Postgres** instance and note its connection details.
2. Create a Render **Web Service** from the repo using the blueprint (`render.yaml`)
   or manually with `rootDir=etf-loans-backend`, Dockerfile `./Dockerfile`.
3. Set environment variables in the Render dashboard:

| Variable | Required | Purpose |
|---|---|---|
| `DB_URL` | Yes | `jdbc:postgresql://<host>:<port>/<db>` |
| `DB_USERNAME` | Yes | DB user |
| `DB_PASSWORD` | Yes | DB password (secret) |
| `ETF_OTP_KEY` | Yes | Strong random HMAC key (≥32 chars) for OTP hashing |
| `CORS_ALLOWED_ORIGINS` | Yes | Comma-separated Vercel origin(s), e.g. `https://etf-loans.vercel.app` |
| `ETF_OTP_MOCK_ENABLED` | Demo only | `true` **only** for the demo; `false` for real deployment |
| `ETF_OTP_MOCK_CODE` | Demo only | Demo OTP (e.g. `123456`); unset for real deployment |
| `ETF_DEMO_ENABLED` | Demo only | `true` to enable demo mode (requires API keys) |
| `ETF_DEMO_API_KEY` | Demo only | Shared secret for Vercel serverless function → Render |
| `ETF_DEMO_ANDROID_API_KEY` | Demo only | Shared secret for Android APK → Render |

4. First boot: `spring.flyway.enabled=true` and `ddl-auto=validate`, so Flyway applies
   `V1__Create_auth_tables.sql` to the Render database. This creates the auth tables on
   that managed DB (not your local DB). Start the service only after approval.
5. Health check: `GET /api/health`.

## 2. Flutter Web — Vercel (static) + Serverless Function

**No secrets in Flutter Web build.** The Flutter static build calls a Vercel serverless
function (not Render directly). The serverless function holds the API key and forwards
requests to Render.

### 2a. Vercel Serverless Function (`api/otp-proxy.js`)

Create a serverless function that:
- Receives requests from Flutter Web
- Adds `X-API-Key: <ETF_DEMO_API_KEY>` header
- Forwards to Render backend
- Returns response to Flutter Web

```javascript
// api/otp-proxy.js
export default async function handler(req, res) {
  const apiKey = process.env.ETF_DEMO_API_KEY;
  const renderUrl = process.env.RENDER_API_URL; // e.g. https://etf-loans-backend.onrender.com

  if (!apiKey || !renderUrl) {
    return res.status(500).json({ error: 'Server configuration missing' });
  }

  try {
    const response = await fetch(`${renderUrl}${req.url}`, {
      method: req.method,
      headers: {
        'Content-Type': 'application/json',
        'X-API-Key': apiKey,
        // Forward relevant headers (Origin, etc.)
        ...(req.headers.origin && { 'Origin': req.headers.origin }),
      },
      body: ['GET', 'HEAD'].includes(req.method) ? undefined : JSON.stringify(req.body),
    });

    const data = await response.json();
    return res.status(response.status).json(data);
  } catch (err) {
    return res.status(502).json({ error: 'Upstream error', detail: err.message });
  }
}
```

### 2b. Flutter Web Configuration

Build Flutter Web pointing to the **Vercel proxy**, not Render directly:

```powershell
cd "D:\projects\ETF - login\etf-loans-flutter"
& "C:\Users\mohan\develop\flutter\bin\cache\dart-sdk\bin\dart.exe" `
  "C:\Users\mohan\develop\flutter\bin\cache\flutter_tools.snapshot" `
  build web --release --dart-define=API_BASE_URL=https://<your-vercel-app>.vercel.app/api
```

Deploy the `build/web` directory as a static site (e.g. `vercel deploy build/web --prod`,
or drag-and-drop in the Vercel dashboard).

Set `CORS_ALLOWED_ORIGINS` on Render to the Vercel origin(s).

### 2c. Vercel Environment Variables

| Variable | Required | Purpose |
|---|---|---|
| `ETF_DEMO_API_KEY` | Yes | Shared secret for proxy → Render |
| `RENDER_API_URL` | Yes | Render backend URL (e.g. `https://etf-loans-backend.onrender.com`) |

## 3. Android APK

The Android APK calls Render **directly** with its own API key (not through Vercel).

Build with the deployed API URL and API key pinned at compile time (or use secure storage):

```powershell
& "C:\Users\mohan\develop\flutter\bin\cache\dart-sdk\bin\dart.exe" `
  "C:\Users\mohan\develop\flutter\bin\cache\flutter_tools.snapshot" `
  build apk --debug --dart-define=API_BASE_URL=https://<your-render-service>.onrender.com
```

At runtime, the Android app reads `ETF_DEMO_ANDROID_API_KEY` from secure storage
(Android Keystore / `flutter_secure_storage`) and adds `X-API-Key` header to requests.
The backend validates this key separately from the Vercel proxy key.

**Authentication distinction:**
- **Browser demo**: Flutter Web → Vercel Proxy (adds `X-API-Key: ETF_DEMO_API_KEY`) → Render
- **Android APK**: Flutter Android → Render directly (adds `X-API-Key: ETF_DEMO_ANDROID_API_KEY`)

Both keys are validated by the same `DemoAccessFilter`. Compromise of one does not affect the other.

## 4. OTP modes

- **Demo (both paths supported):** run the backend with mock enabled
  (`ETF_OTP_MOCK_ENABLED=true`, `ETF_OTP_MOCK_CODE=123456`, `ETF_DEMO_ENABLED=true`,
  both API keys configured). The send response includes `developmentOtp`,
  and the OTP screen displays "Development code: …". No SMS is sent.
- **Real SMS (later):** implement `OtpDeliveryProvider` with a provider such as Twilio
  (adds a provider dependency, pending approval) and set `ETF_OTP_MOCK_ENABLED=false`.
  Raw OTPs are never logged or returned in production mode.

## 5. Flyway migration on fresh PostgreSQL

- `flyway.baseline-on-migrate=true` + `flyway.enabled=true`
- On a **fresh, empty database**: Flyway creates the schema history table and applies
  `V1__Create_auth_tables.sql` (creates `users`, `otp_challenges`, `user_sessions`).
- On an **existing database with tables but no Flyway history**: Flyway baselines the
  current schema (marks as version 1) and applies pending migrations.
- `spring.jpa.hibernate.ddl-auto=validate` ensures the schema matches JPA entities.
- **No manual migration execution required** — runs automatically on first backend startup.

## 6. Security notes

- The Flutter app never connects to PostgreSQL and contains no DB credentials.
- Secrets live only in server-side environments (Render, Vercel serverless, Android Keystore).
- Mock OTP must be disabled outside the demonstration (`ETF_OTP_MOCK_ENABLED=false`).
- Startup validation rejects unsafe configurations:
  - `ETF_OTP_KEY` must be ≥32 chars and not a known default value
  - Demo mode requires at least one API key: `etf.demo.api-key` (Vercel proxy) or `etf.demo.android-api-key` (Android APK)
  - `CORS_ALLOWED_ORIGINS` must be explicitly set (no `*` default)
- Direct access to Render OTP endpoints without valid `X-API-Key` returns 403.
- The in-memory rate limiter is single-instance; use Redis before scaling to multiple
  backend instances.