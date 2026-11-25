# ETF Loans — Complete Flutter Development Master Plan
**Version 1.1 | 24 November 2026 | Phase 01 internal checkpoint**

## 1. Reference analysis and scope
Build a complete borrower-facing Flutter replica of the intern team's ETF Loans application (https://etf-loans.vercel.app/), extending the working Flutter login project rather than starting over. Sources: ETF Loans Site Map.html (mapped 14 November 2026), three batches of user-provided website screenshots, and the local login implementation/testing history. The screenshots are the latest visual reference; the site map documents earlier routing and API names. Live source and exact backend contracts remain to be inspected.

The latest references add password login, registration, recovery, a detailed landing calculator, loan disclosures and a multi-check verification flow. Notifications contain eligibility updates and timestamps; Terms and Privacy are dated 13 November 2026. Missing visual references may be designed internally using the same branding, but financial, legal and verification rules need approval.

Open inconsistencies: Terms describe OTP-only login whereas the current sign-in screen includes a password; account deletion mentions deleting history while Terms require repayment before closure; credit bureau results are simulated; selfie instructions refer to PAN while the checklist refers to Aadhaar matching. Resolve these before implementing affected features.

## 2. Current baseline
- Phase 00 baseline investigation completed.
- Existing Flutter project, theme, logo, mobile login, six-digit OTP, local Spring Boot authentication and PostgreSQL integration.
- Physical POCO F4 testing completed for the existing login scope, as reported by the user. Existing minimal authenticated HomeScreen and logout are implemented; not a complete borrower dashboard.
- Earlier issues repaired: OTP layout overflow, nullable Boolean and name parsing, duplicate submission guard and missing bearer header. Preserve regression coverage.
- Local development startup script prepared. Windows, Antigravity, 8 GB RAM, physical phone via USB; avoid emulator and redundant builds.
- Local root: `D:\projects\ETF - login`; projects `etf-loans-flutter`, `etf-loans-backend`. Local backend port 8080, PostgreSQL port 5432, ADB reverse TCP 8080; local development OTP only. Never expose credentials or fixed OTP in production.

## 3. Proposed screen inventory (35 screen-level views)
Some entries may become dialogs or reusable views rather than standalone routes. The earlier site map lists 24 screens in its header but 23 named screens; newer screenshots introduce additional functions. This is a proposed inventory, not a verified route count.

| ID | Module | Screen | Status |
|---|---|---|---|
| ETF-001 | Public | Welcome and landing | Implemented and accepted for internal development |
| ETF-002 | Public | Terms of Service | Implemented and accepted for internal development |
| ETF-003 | Public | Privacy Policy | Implemented and accepted for internal development |
| ETF-004 | Auth | Sign in | Internally accepted on POCO F4, including AUTH-10 |
| ETF-005 | Auth | OTP verification | Internally accepted on POCO F4 |
| ETF-006 | Auth | Create account | Internally accepted on POCO F4 |
| ETF-007 | Auth | Set password | Internally accepted on POCO F4 |
| ETF-008 | Auth | Forgot password | Internally accepted on POCO F4 |
| ETF-009 | Auth | Set new password | Internally accepted on POCO F4 |
| ETF-010 | Onboarding | Personal details | Full reference pending |
| ETF-011 | Onboarding | PAN verification | Full reference pending |
| ETF-012 | Eligibility | Checking eligibility | Site map reference |
| ETF-013 | Eligibility | Credit score and eligibility result | Reference available |
| ETF-014 | Profile | Update income and details | Reference available |
| ETF-015 | Verification | Face verification instructions | Reference available |
| ETF-016 | Verification | Live face check | Reference available |
| ETF-017 | Verification | Face verification result | Design required |
| ETF-018 | Verification | Loan verification checklist | Reference available |
| ETF-019 | Verification | Aadhaar verification | Reference available |
| ETF-020 | Verification | Aadhaar verification result | Site map reference |
| ETF-021 | Verification | Address and work | Reference available |
| ETF-022 | Verification | Bank account verification | Design required |
| ETF-023 | Loan | Choose amount and EMI plan | Reference available |
| ETF-024 | Loan | Review and accept | Reference available |
| ETF-025 | Loan | Expanded repayment schedule | Design required |
| ETF-026 | Loan | Agreement and Key Facts Statement | Partial reference |
| ETF-027 | Loan | Loan confirmation | Design required |
| ETF-028 | Main app | Home dashboard | Basic version exists |
| ETF-029 | Main app | Loans and repayment management | Empty-state reference |
| ETF-030 | Main app | Active loan details and EMI schedule | Design required |
| ETF-031 | Main app | Profile | Reference available |
| ETF-032 | Main app | Notifications | Reference available |
| ETF-033 | Main app | Delete account | Reference available |
| ETF-034 | Payments | EMI payment initiation | Design required |
| ETF-035 | Payments | Payment result | Design required |

External DigiLocker authentication is not a Flutter screen. Defer cross-device QR selfie handoff unless required. Help/support, sounds, preferences, all-device sign-out and PDF downloads belong to their relevant modules.

## 4. Proposed application flow
Welcome → register / sign in / reset password. Registration: mobile → OTP → set password. Sign-in: mobile + password → OTP, if approved. Recovery: mobile → purpose-bound OTP → new password. Recovery must not automatically grant unrestricted authenticated access. Preserve working OTP until replacement is approved and tested.

After authentication, complete applicable face check and inspect borrower status. New borrower → personal details/PAN → eligibility checking → result. Returning borrower → existing profile and loan status → dashboard or eligibility result. Eligible borrower → select amount and tenure → review quote, schedule, KFS and agreement → verification checklist → final acceptance → confirmation → Home/Loans/Profile. Exact order of PAN, selfie and password setup remains to be confirmed. Ineligible users must not be permitted to accept a loan. State-based navigation should be driven by backend data, not hardcoded flags.

## 5. Screen requirements and missing-screen designs
### Public pages
Welcome: green gradient hero, logo, loan highlights (up to INR 5,00,000; interest from 2% monthly; zero processing fee; same-day claim in reference), three-step process, pricing, interactive EMI calculator, eligibility criteria (reference: age 21–60, income INR 15,000 or more, score 650 or above, PAN/Aadhaar/selfie), expandable FAQ, legal footer, demo disclaimer, eligibility and sign-in actions. Treat marketing claims and criteria as reference values pending approval. Terms and Privacy: approved versioned content and back navigation.
### Authentication
Mobile +91 input, password visibility, registration/recovery links, continue to OTP, legal links. Reuse OTP boxes, resend timer, challenge verification, session storage and duplicate guards. Distinguish login, registration and recovery challenges. Testing-only demo/skip features must not bypass production authentication. Password hashing, recovery and migration of existing accounts require approved backend changes.
### Onboarding and eligibility
Collect approved identity, employment, income and existing external EMI fields with consent and PAN verification. Update screen locks name, PAN and date of birth; allows salaried/self-employed selection, take-home income and external EMI updates. Recheck eligibility without changing current loans. Checking screen supports progress and retry. Result: personalized greeting, 300–900 score gauge, credit band, date/source label, approved limit, affordable EMI and score factors (payment history, utilization, credit age, recent enquiries). Demo example: score 699 Fair, INR 1,41,000 limit, INR 16,000 affordable EMI. Never hardcode as real borrower outcomes.
### Verification
Face instructions: good light, blink/smile challenges, look straight, remove glasses/caps. Native camera preview with oval guide, permission and lifecycle handling, cancellation, retake and result; capture is not proof of liveness or identity. Approved provider must verify identity. Checklist: PAN, Aadhaar, selfie, address/work and bank; backend-driven pending/success/failure/attempt-limit states. Applicable checks show three attempts per day in reference; enforce server-side only after rules are verified. Aadhaar selection: existing or new DigiLocker account; provider-hosted authentication, secure handoff and backend-confirmed result; do not clone government login. Address/work: house/street/area, city, state, PIN, owned/rented/family/company housing, employer and optional role; save and continue. Bank screen (proposed): holder name, account number and confirmation, IFSC, why verification is required, verify action, secure provider response, masked details, retry handling. Real INR 1 verification only in authorized environment.
### Loan selection and review
Editable amount and slider bounded by approved limit; six EMI cards with affordability warnings, selected state, principal/interest bar and breakdown. Review includes principal, tenure, flat rate, interest, fees, EMI, adjusted last EMI, first due date, total repayment, expandable schedule, KFS version, net proceeds, APR, charges/cooling-off/complaints, agreement link and PDF download. Verification gate before final acceptance. Agreement/KFS viewer must use approved legal documents, preserve version and consent evidence. No invented binding terms.

Proposed expanded schedule for reference example (illustrative only): INR 50,000, six months, INR 6,000 interest, INR 56,000 repayment; five EMIs of INR 9,333 and final INR 9,335. Example dates: 24 Dec 2026 through 24 May 2027, monthly. Backend supplies actual dates, rounding and terms. Confirmation screen: success icon, amount, tenure, EMI, total and disbursement status, Go to Home. Distinguish acceptance, approval, processing and actual disbursement; never report funds sent without confirmation.
### Main application
Home: welcome name, notification bell, demo notice only for demo accounts, available limit and utilization bar, conditional Aadhaar card, new loan action, repayment schedule, credit score, help/support. Bottom navigation: Home, Loans, Profile, including inbox under Home. Loans: no-loans reference, See my limit, active/overdue/completed loans, next EMI, payment and schedule, loading/error states. Proposed active loan: outstanding repayment, paid EMI progress, next due date/amount, Pay EMI and loan detail card. Profile: name/mobile, masked PAN, DOB, employment, employer/address, income, face/Aadhaar status, sounds toggle, income recheck, legal links, sign out, all-device sign out, delete. Notifications: cards with title, body, icon, timestamp, read state. Deletion: explicit DELETE confirmation, cancellation, session revocation and approved closure/retention policy; no blind financial-record cascade.
### Payments
Proposed screens: review EMI amount → approved provider checkout → pending/success/failure result with receipt, schedule refresh and safe retry. Never collect card/UPI secrets directly. Verify provider status server-side before marking paid; prevent duplicate payments.

## 6. Shared EMI calculator
Observed reference rates: 3/6 months = 2% monthly flat; 9/12/18/24 months = 3%. Public estimate range INR 10,000–5,00,000; actual borrower offer is limited by approved available credit. Exact increments and budget rules require verification.

Illustrative formula: interest = principal × monthly flat rate × months; total = principal + interest; regular EMI = floor(total / months); final EMI = total − regular EMI × (months − 1). Example INR 50,000 for 6 months: interest INR 6,000, regular EMI INR 9,333, final EMI INR 9,335, total INR 56,000. Reference APR 40.05% for this example; do not substitute annualized flat rate for APR. Backend is authoritative for quotes, rounding, APR, fees, due dates and eligibility; use decimal arithmetic and tested rules.

## 7. Architecture and visual system
Flutter → REST JSON APIs → Spring Boot → PostgreSQL; backend also integrates approved SMS, credit bureau, identity and payment providers. Flutter handles UI, forms, state, navigation, preliminary estimates, camera and secure session storage. Spring Boot owns authorization, business rules, financial calculations, verification and transaction status. PostgreSQL persists records. Never connect Flutter directly to PostgreSQL.

Proposed feature folders (inspect before restructuring): app/routing; core/config, constants, network, errors, storage; features/welcome, authentication, onboarding, eligibility, face_verification, kyc, loan_application, dashboard, loans, payments, profile, notifications, legal; shared/widgets; theme. Reuse current code and dependencies.

Brand palette: background #F4F7F4; surface #FFFFFF; primary #0A2E1B; accent #15703B; soft accent #E2F1E7; text #0F1F16; secondary #56675C; border #D6E0D8. Headings Plus Jakarta Sans; body DM Sans; technical labels JetBrains Mono. Use original logo/assets, rounded cards, green gradient summaries, responsive spacing and accessible contrast. Shared widgets: branded header, buttons, forms, amount slider, tenure cards, detail rows, credit gauge, verification status, expandable sections, tabs, loading/error/empty states and confirmation dialogs.

## 8. Backend and database requirements
Current local auth endpoints: POST /api/auth/otp/send, POST /api/auth/otp/verify, GET /api/auth/me, POST /api/auth/logout. Other website endpoints are documented, not verified: /api/config, /api/me, /api/otp/send, /api/otp/verify, /api/otp/skip, /api/demo/login; /api/face, /api/face/submit, /api/face/handoff, /api/face/handoff/open, /api/face/handoff/status; /api/profile, /api/kyc/pan, /api/kyc/aadhaar/start, /api/kyc/aadhaar/status; /api/loan/quote, /api/loan/accept; /api/pay/start, /api/pay/confirm; /api/inbox, /api/inbox/read, /api/push/subscribe; /api/logout, /api/logout/all, /api/account/delete. Do not assume these exist in local Spring Boot.

| Domain | Backend responsibility / proposed persistence |
|---|---|
| Authentication | Existing users, OTP challenges, sessions; approved password and recovery support |
| Profile | Personal/employment/income information |
| Eligibility | Credit assessments, consent, score, affordable EMI and limits |
| Verification | Check status, provider references, retry limits, masked bank data |
| Quotes | Amount, tenure, fees, APR, schedule, expiry |
| Loans | Accepted offers, lifecycle, remaining credit, disbursement |
| Repayment | Installments, dates, amounts and status |
| Payments | Orders, provider transaction references, reconciliation |
| Notifications | User-specific events and read state |
| Account | Preferences, session revocation and closure |
| Documents | KFS/agreement versions, acceptance evidence, receipts |

These are conceptual domains, not approved tables. Inspect existing schema, entities, repositories, migrations and intern backend first. No schema changes without explicit approval. Never store plaintext passwords or production secrets, log sensitive values, or expose API keys in Flutter. Use secure sessions, server authorization, data minimization, approved retention and provider validation.

## 9. Phase-wise roadmap
| Phase | Scope | Screen IDs | Deliverable |
|---|---|---|---|
| 00 | Read-only repository and architecture investigation | All | Baseline investigation completed |
| 01 | Flutter foundation, Welcome, legal screens, shared calculator and navigation | 001–003 | Implemented and accepted for internal development |
| 02 | Authentication | 004–009, AUTH-10 | Internally accepted on POCO F4 |
| 03 | Borrower onboarding, PAN, consent and profile | 010–011, 014 | Profile persistence and retrieval |
| 04 | Eligibility | 012–014 | Backend-driven assessment and recheck |
| 05 | Loan selection, review, KFS and agreement | 023–026 | Authoritative quote and review |
| 06 | Verification workflows | 015–022 | Valid verification checklist and provider states |
| 07 | Acceptance and lifecycle | 027 | Authorized sandbox loan workflow |
| 08 | Borrower dashboard, Loans, Profile | 028–031 | Complete authenticated navigation |
| 09 | Payments, notifications, account management | 032–035 | Borrower self-service |
| 10 | Final integration and testing | All | Verified end-to-end physical-device application |

Use a separate focused coding-agent task per phase. No implementation before Phase 00 findings and approval. External dependencies may require clearly labeled sandbox fixtures; never present simulations as real credit, verification or payments.

## 10. Testing and acceptance

Phase 01 verification for this checkpoint recorded zero Flutter static analysis issues, 38 of 38 Flutter regression tests passed, and a successful Android APK build. Legal content authorization and final physical-device acceptance remain pending.

Every phase: visual comparison with references; responsive layout with keyboard and narrow widths; forward/back and conditional routing; contract tests using actual backend DTOs including null/missing fields; persistence and ownership checks; useful network/validation/session errors; automated test results and manual physical-device validation. Financial tests: decimal rounding, eligibility restrictions, expired quotes, incomplete checks, duplicate acceptance, retry and duplicate payment protection, provider reconciliation. Security tests: missing/invalid/expired/revoked sessions, unauthorized cross-user access, no secret leakage, local mock isolation. Do not mark completed without evidence; distinguish source inspection, agent-reported tests and actual manual tests.

## 11. Coding-agent workflow and skills
Discover actual installed skills before invoking them. Relevant expertise: Flutter/Dart, responsive UI, navigation/state, Java/Spring Boot/Security, REST contract testing, PostgreSQL/JPA/Flyway, decimal financial calculations, camera lifecycle, approved KYC integrations, payment checkout/webhooks/idempotency, widget/integration testing and debugging. Use only skills relevant to each task. Inspect before editing; reuse existing code; avoid duplicate functionality, unrelated changes, destructive Git/database operations, unapproved migrations and commits/pushes. Report changed files, actual commands/test outcomes, blockers and assumptions. Prefer module-by-module implementation over all-UI-first or all-backend-first. Preserve the tested authentication baseline and test each module on POCO F4.

## 12. Decisions pending approval
Continue existing Flutter project and PostgreSQL. Preserve OTP baseline. Decide whether to reuse the intern backend or extend local Spring Boot (separate backend only with team authorization), whether password authentication is required, and whether provider integrations are sandbox-only initially. Match screenshot designs; design missing views internally. Native camera for mobile, defer QR handoff unless required. Defer cloud deployment for now. Admin/financier portals outside borrower scope. Confirm approved legal documents, credit/business rules, consent, retention, provider credentials and actual integration contracts before implementing affected features.

## 13. Phase 02 internal acceptance
ETF-004–009 and AUTH-10 passed physical-device acceptance on the POCO F4. Planned authentication journeys were accepted for internal use.

- Automated PostgreSQL V1-to-V2 verification remains open after connection resets. The independent seeded SQL check verified record preservation.
- Both focused AUTH-10 Flutter tests passed. The broader rerun passed 42 tests and left five incomplete after a runner interruption.
- Deployment requires real SMS, provider timing checks for account enumeration, HTTPS, shared throttling before scaling, and intern backend contract verification. Keep older backends away from the V2 authentication database and isolate local mock credentials and data.

## 14. Working references
- ETF Loans website: https://etf-loans.vercel.app/
- ETF Loans Site Map.html (14 November 2026)
- User-provided screenshot batches: IMG_2681 through IMG_2724 (including welcome, sign-in, result, offer, review, checklist, Home, Loans, Profile, account/recovery, update, Aadhaar, face, address/work, deletion, notifications and legal pages).
- Existing local project and login repair/test reports. Exact current repository and backend access remain to be confirmed in Phase 00.
