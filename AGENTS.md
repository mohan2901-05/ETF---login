# AGENTS.md — ETF Loans Development

## 1. Project objective

Develop a professional Flutter borrower application matching the existing ETF Loans reference website, integrated with Spring Boot and PostgreSQL through secure REST APIs.

Repository root: `D:\projects\ETF - login`

Development branch: `feature/borrower-flutter-app`

Projects:
- `etf-loans-flutter/` — Flutter and Dart
- `etf-loans-backend/` — Spring Boot, Java 17 and PostgreSQL
- `docs/` — Requirements, design specifications and visual references

## 2. Source of truth

Consult relevant sections of:
- `docs/ETF_Loans_Master_Plan.md`
- `docs/WEBSITE-DESIGN-SPEC.md`
- `docs/references/`
- ETF Loans Site Map
- Existing source code and tests

Reference website: https://etf-loans.vercel.app/

Distinguish VERIFIED facts, ASSUMPTIONS and approved DECISIONS.

Never invent API contracts, database structures, business rules or verification outcomes.

## 3. UI and Hallmark requirements

Load Hallmark for reference-sensitive UI tasks when available.

Actually inspect reference screenshots before implementation. Screenshots are the primary authority for visual composition.

Preserve the accepted ETF Loans branding, local fonts and existing components.

Typography:
- Headings: Plus Jakarta Sans
- Body: DM Sans
- Technical labels: JetBrains Mono

Match reference spacing, hierarchy, typography, gradients, icons, proportions and navigation.

Avoid generic Material layouts when they conflict with references.

Render and compare implemented screens against references before claiming visual parity.

Support narrow screens, large text, accessibility, keyboard interaction and responsive layouts.

Do not redesign previously accepted screens without authorization.

## 4. Architecture

Keep UI, state, models, API services and configuration separate.

Reuse existing implementations before introducing new abstractions.

Flutter communicates with the backend exclusively through APIs.

Preserve existing authentication contracts and session handling unless an approved change requires modification.

Do not connect Flutter directly to PostgreSQL.

Avoid unnecessary dependencies or framework changes.

## 5. Security

Never expose credentials, API keys, passwords or session tokens.

Never store plaintext passwords.

Use approved password hashing and secure session storage.

OTP challenges must expire, be single-use, purpose-bound and rate-limited.

Prevent replay, enumeration, duplicate submissions and unauthorized access.

Distinguish login, registration and recovery authorization.

Password reset must not automatically grant unrestricted access.

Mock authentication and fixed OTP values must remain isolated to development or test environments.

Do not weaken authentication to make tests pass.

## 6. Database rules

Inspect existing PostgreSQL migrations, entities and repositories before proposing changes.

Do not alter schema, migrations, production data or database permissions without explicit user approval.

If functionality requires schema changes, report the exact proposed changes, rationale and compatibility implications.

Continue independent UI work where possible, but do not simulate successful production authentication.

## 7. Git and file safety

Inspect the active branch and relevant working-tree changes before editing.

Preserve all existing user and agent changes.

Do not perform destructive Git commands.

Never commit, push, merge or switch branches without permission.

Do not stage generated artifacts, local secrets, APKs or unrelated files.

Do not edit global SDK files or package-cache source files.

Obtain approval before changing Android ABI filters, Gradle versions or dependencies.

## 8. Windows development environment

Windows 11, 8 GB RAM, Antigravity IDE.

Physical Android device: POCO F4, ID `2786684b`.

Avoid Android emulators and unnecessary concurrent processes.

Prefer CMD-based Flutter commands because of intermittent Windows launcher failures.

Flutter verification:
- `cmd /c flutter analyze`
- `cmd /c flutter test --no-pub --concurrency=1 --reporter compact`

Android build:
- `cmd /c flutter build apk --debug --no-pub --dart-define=API_BASE_URL=http://127.0.0.1:8080`

Use the local backend URL only for local development.

Backend verification:
- Use the existing Maven configuration and isolated test profile.

Do not repeatedly clean caches or rebuild when valid artifacts already exist.

## 9. Testing and acceptance

Preserve existing test coverage.

Add focused tests for changed functionality.

Never weaken tests to conceal regressions.

Report actual test counts and failures.

Distinguish automated tests, rendered visual comparisons and physical-device testing.

Separate environmental failures from confirmed application defects.

Do not claim successful implementation without evidence.

## 10. Efficient agent operation

Inspect only relevant files and documentation.

Avoid repeating comprehensive repository audits.

Work incrementally within the assigned phase.

Prefer targeted tests during implementation and full regression at completion.

Avoid unnecessary command retries, dependency updates and APK builds.

Keep final reports concise.

Report:
- Completed tasks and screen IDs
- Changed files
- Actual verification results
- Security or architecture decisions
- Assumptions and blockers
- Remaining manual acceptance requirements

Stop at the assigned phase boundary.