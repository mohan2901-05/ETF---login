# ETF Loans — Complete Flutter Development Master Plan
**Version 1.3 | QA-04 physical Android checkpoint**

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
| ETF-005 | Auth | OTP verification | Internal Android acceptance recorded in QA-04. AUTH-12 mouse focus accepted on Chrome. |
| ETF-006 | Auth | Create account | Internally accepted on POCO F4 |
| ETF-007 | Auth | Set password | Internally accepted on POCO F4 |
| ETF-008 | Auth | Forgot password | Internally accepted on POCO F4 |
| ETF-009 | Auth | Set new password | Internally accepted on POCO F4 |
| ETF-010 | Onboarding | Personal details | Implemented profile flow accepted on Chrome and Android. Full reference comparison pending. |
| ETF-011 | Onboarding | PAN verification | Synthetic verification and consent accepted on Chrome and Android. Approved PAN provider and full reference comparison pending. |
| ETF-012 | Eligibility | Checking eligibility | Implemented consent, authenticated polling and retry accepted in the local flow. |
| ETF-013 | Eligibility | Credit score and eligibility result | Implemented synthetic result and offer handoff accepted. Approved production provider and reference screenshot pending. |
| ETF-014 | Profile | Update income and details | Implemented financial persistence, consent and reassessment accepted in the local flow. |
| ETF-015 | Verification | Face verification instructions | Flutter instructions and consent UI implemented. Approved consent and provider integration pending. |
| ETF-016 | Verification | Live face check | Preview, permission, capture and processing UI implemented. Camera adapter pending. |
| ETF-017 | Verification | Face verification result | Flutter result UI implemented. Authoritative provider responses pending. |
| ETF-018 | Verification | Loan verification checklist | Flutter checklist and Phase 06B navigation implemented. Offer-scoped backend status pending. |
| ETF-019 | Verification | Aadhaar verification | Consent and hosted-handoff UI implemented. DigiLocker adapter pending. |
| ETF-020 | Verification | Aadhaar verification result | Provider-state and masked result UI implemented. Backend integration pending. |
| ETF-021 | Verification | Address and work | Flutter form and in-memory draft implemented. Backend submission pending. |
| ETF-022 | Verification | Bank account verification | Flutter form and validation implemented. Account verification adapter pending. |
| ETF-023 | Loan | Choose amount and EMI plan | Authenticated options with local synthetic pricing accepted in QA-04. |
| ETF-024 | Loan | Review and accept | Implemented quotation review accepted in QA-04. Verification and final acceptance pending. |
| ETF-025 | Loan | Expanded repayment schedule | Implemented server-calculated schedule accepted in QA-04. |
| ETF-026 | Loan | Agreement and Key Facts Statement | Versioned text viewer implemented. Approved documents and download integration pending. |
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
| Profile | Local bearer-authenticated create, read and finance update via `/api/borrower/profile`. Additive Flyway V3 persists profile and masked PAN evidence. |
| Eligibility | Credit assessments, consent, score, affordable EMI and limits |
| Verification | Check status, provider references, retry limits, masked bank data |
| Quotes | Amount, tenure, fees, APR, schedule, expiry |
| Loans | Accepted offers, lifecycle, remaining credit, disbursement |
| Repayment | Installments, dates, amounts and status |
| Payments | Orders, provider transaction references, reconciliation |
| Notifications | User-specific events and read state |
| Account | Preferences, session revocation and closure |
| Documents | KFS/agreement versions, acceptance evidence, receipts |

The borrower profile schema is approved for isolated local development. Remaining domains are proposals. Inspect existing schema, entities, repositories, migrations and intern backend first. No schema changes without explicit approval. Never store plaintext passwords or production secrets, log sensitive values, or expose API keys in Flutter. Use secure sessions, server authorization, data minimization, approved retention and provider validation.

## 9. Phase-wise roadmap
| Phase | Scope | Screen IDs | Deliverable |
|---|---|---|---|
| 00 | Read-only repository and architecture investigation | All | Baseline investigation completed |
| 01 | Flutter foundation, Welcome, legal screens, shared calculator and navigation | 001–003 | Implemented and accepted for internal development |
| 02 | Authentication | 004–009, AUTH-10 | Internally accepted on POCO F4 |
| 03 | Borrower onboarding, PAN, consent and profile | 010–011, 014 | Local Chrome and QA-04 Android acceptance complete. Approved live PAN provider pending. |
| 04 | Eligibility | 012–014 | Local assessment and reassessment accepted on Chrome and Android. Production provider and two widget failures pending. |
| 05 | Loan selection, review, KFS and agreement | 023–026 | Authenticated synthetic quotations for ETF-023–025 accepted in QA-04. Approved ETF-026 disclosures and final acceptance remain gated. |
| 06A | Face verification and checklist | 015–018 | Flutter UI implemented. Camera and KYC integration pending. |
| 06B | Aadhaar, address and bank verification | 019–022 | Flutter UI and checklist navigation implemented. Provider and backend integration pending. |
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

## 14. Phase 03 and Phase 04 implementation status

BE-01, BE-02, BE-01A and BE-01B are complete for isolated local Chrome development. The user reported all nine final manual Chrome checks passed, including profile persistence, finance updates, employment selection, logout and AUTH-12 OTP mouse focus. BOR-01 corrected the selected employment display. Testing confirmed BOR-02 returns `422` for a nonfixture PAN and accepts the supported synthetic fixture.

- Flyway recorded the existing isolated `etf_loans_device` schema at V2 and applied V3. Snapshots of all four authentication tables matched before and after provisioning. Local startup keeps Flyway disabled and Hibernate schema validation enabled. The Chrome launcher and synthetic fixture are documented in [Windows local development](LOCAL-DEVELOPMENT-WINDOWS.md).
- Six profile API tests passed on isolated PostgreSQL, and the focused V2-to-V3 preservation test passed. The H2 run recorded 53 passed and seven skipped. Live smoke tests verified synthetic PAN acceptance, profile creation and retrieval, financial updates, duplicate handling, ownership isolation and rejection of identity changes. The synthetic PAN provider is opt-in for isolated local/test profiles. An approved live PAN provider is pending.
- ETF-012 presents progress, unavailable and retryable failure states. Authenticated Home starts an initial check only after confirmed PAN verification and profile persistence. A recheck starts only after ETF-014 confirms a save. An expired session takes the borrower to sign-in.
- ETF-013 presents the service’s decision and any supplied score, credit band, date, source, factors, approved limit and affordable monthly EMI. ETF-014 is accessible from the result. The Phase 05 handoff opens loan selection only for an eligible result with a server-issued offer reference.
- BE-03 connects the eligibility and offer states to the authenticated backend. The result displays a synthetic label when using a local fixture.
- Targeted Dart analysis found zero errors or warnings for the onboarding adapter and corrections. At the Chrome checkpoint, the widget harness stalled during Flutter bootstrap and the desktop runner exited during native asset setup. The run left the AUTH-12 regression, seven onboarding tests and six eligibility tests incomplete. QA-04 subsequently recorded manual Android acceptance.

## 15. Phase 05 implementation status

- ETF-023 through ETF-026 implement authorized amount and term selection, quote review, an expanded installment schedule, and versioned agreement and Key Facts Statement views. Selection stays in memory when returning from review. The public EMI calculator remains illustrative.
- BE-04 subsequently integrated local loan options, quotes and schedules. Acknowledgment is local to the reviewed quote. Approved document contracts, verification and final acceptance integration remain pending.
- The site map and existing brand references informed the initial UI. Screen-specific screenshots were unavailable for comparison. Targeted Dart analysis passed with zero issues. See BE-04A and QA-04 for later rendered and device acceptance.

## 16. Phase 06A implementation status

- Authenticated loan quote review links to the offer-scoped checklist. Face preview opens after explicit consent. The camera session boundary provides a preview texture and provider result without passing biometric payloads to Flutter. Returning to the checklist refreshes status from the service.
- The configured service reports unavailable. Camera and approved KYC adapters and backend checklist integration remain pending. Final acceptance remains disabled. Screen-specific screenshots were unavailable for rendered comparison.
- Targeted Dart analysis passed before the final provider-action gating change. The cached analyzer crashed on the final checks. Three new widget tests and the updated quote-review navigation test await Flutter execution.

## 17. Phase 06B implementation status

- ETF-019 and ETF-020 implement Aadhaar consent, hosted handoff states, and provider-driven results. The interface accepts only the final four digits for display after provider-confirmed completion.
- ETF-021 keeps an offer-scoped address and employment draft in memory until submission or checklist exit. ETF-022 validates account confirmation and IFSC. Bank inputs are disabled until an account verification service is configured. The checklist reloads authoritative status when borrowers return from a check.
- DigiLocker, address and bank submission adapters and offer-scoped checklist data remain integration blockers. The reference routes were inaccessible and screen-specific screenshots were unavailable locally. Targeted Dart analysis passed with zero issues. Four focused widget tests await execution.

## 18. QA-01 borrower preview

- `etf-loans-flutter/tool/borrower_preview.dart` is a debug-only entry point for ETF-010 through ETF-026. It injects synthetic scenarios and does not connect to the backend. Manual Chrome acceptance used the normal application with the isolated backend.

## 19. BE-03 eligibility backend and Flutter integration

- V4 adds `financial_revision` and `eligibility_assessments`. Financial changes advance the revision. Assessment and offer lookups reject expired records, stale revisions and foreign owners. Reused assessments retain each submission’s key and consent independently.
- Bearer-authenticated POST and GET at `/api/borrower/eligibility/assessments` and `/api/borrower/eligibility/assessments/{id}` return 202 with Location, 200 for a current result, 404 for missing or foreign assessments, 410 for stale or expired assessments, 409 for prerequisite or key conflicts, and 503 for provider unavailability.
- A profile lock guards reservation and publication. Provider work runs outside database transactions with a five-second timeout, a twenty-second reservation deadline and a 24-hour result lifetime. These are operational defaults. The explicitly enabled eligible, ineligible and failure fixtures run against isolated local or test data. An approved production credit provider is pending.
- Isolated PostgreSQL passed 68 tests, including V1–V4 preservation, ownership, consent, concurrency, expiry and offers. H2 passed 60 tests with eight PostgreSQL-only skips. Flyway applied V4 to `etf_loans_device` and preserved the existing profile and authentication rows. The runtime grant allows SELECT, INSERT and updates to mutable lifecycle and result columns.
- Live HTTP checks passed on `etf_loans_device` for health, the eligible, ineligible and failure fixtures, and the disabled provider. The eligible check covered replay, foreign ownership and expiry after a financial change.
- ETF-012/013 and ETF-014 use the real eligibility APIs. ETF-023 opens after a server revalidation of the offer. BE-04 added quote integration. See [Windows local development](LOCAL-DEVELOPMENT-WINDOWS.md#eligibility-in-chrome) for manual acceptance.
- Targeted Dart analysis completed with zero errors and warnings and six SDK deprecation notices. Three adapter scenarios passed on the Dart VM. The Dart client also verified consent, polling, offer validation and a financial recheck against the running device backend. The Flutter desktop runner failed in a native-asset hook, and the Chrome test iframe stalled during startup. Widget execution and rendered comparison with the screen references remain pending.

### BE-03B reassessment and stale offers

- PostgreSQL showed that the fixed synthetic provider returned identical amounts on distinct financial revisions and offer references. The optional `financial-fixture` uses exact income and EMI test tuples and stays behind the existing isolated provider guard.
- The original Chrome build returned HTTP 410 when selecting a stale offer from the result screen. An already-open ETF-023 stayed visible on tab return without another server check. The corrected build requests a fresh response before opening ETF-023 and when an open selection returns to the foreground. A stale result clears the offer and requires fresh consent, a new idempotency key and a recheck.
- Nine focused backend tests passed. Live Dart and PostgreSQL checks verified revisions 0, 1 and 2, distinct assessment and offer IDs, distinct amounts, and HTTP 410 for both superseded assessments. [Two-tab Chrome retest](LOCAL-DEVELOPMENT-WINDOWS.md#eligibility-in-chrome)
- Two actual Chrome tabs passed against `etf_loans_device`. Clicking a stale result hit a live GET 410 and kept ETF-023 closed. Resuming an already-open ETF-023 after an EMI update also hit a live GET 410, closed the screen and requested fresh consent. A current offer opened ETF-023 after a GET 200. The database showed assessment and offer prefixes `e657f249/e425ab43` (revision 0), `6c0759ed/52b7eb66` (revision 1) and `98b426e5/ceb6b4c2` (revision 2).

### BE-03C and QA-02/03 acceptance

- The reported QA-03 manual run recorded 18 passes across authentication, onboarding and the four original financial fixtures. Subsequent attempts with ₹48,000 income and ₹6,000 EMI failed within 31–71 ms because the synthetic provider used an exact-pair lookup. This was separate from the earlier reported 15 pass, 22 fail and one pending run.
- BE-03C replaced the lookup with a development-only paise calculation that preserves the four fixture results. The focused backend run passed 16 tests. Nine live device PostgreSQL cases passed, including ₹60,000 income and ₹10,000 EMI, decimal and boundary inputs, and repeat requests. Normal Chrome verified stale-offer HTTP 410 on click and tab resume. V4 remained unchanged.
- QA-02 verified persisted launcher defaults, authenticated API smoke, the normal Chrome app on port 7357 and all 18 debug-preview entries. QA-03 verified normal Chrome with fresh and existing synthetic borrowers, fixed sign-in route session restoration and the DOB year, and added bounded startup retry for PostgreSQL recovery. Three launcher regressions passed. The Flutter widget runner was blocked by Windows access to Android Studio's Java executable.

## 20. BE-04 loan quotations

- Approved V5 adds only `loan_quotations` in the borrower-local Flyway location. It ties each quote to its current V4 assessment and borrower financial revision and stores an immutable pricing snapshot, the pricing version, an expiry and a borrower-scoped idempotency key.
- The authenticated contract uses `GET /api/borrower/loans/offers/{offer}/options`, `POST /api/borrower/loans/offers/{offer}/quotes` and `GET /api/borrower/loans/quotes/{id}`. POST requires an `Idempotency-Key` and takes only integer `amountPaise` and `months`. An expired or stale offer or quote returns HTTP 410. Cross-borrower IDs return HTTP 404. The same key and request replay the same current quote. A changed request using that key returns HTTP 409.
- The opt-in `synthetic-flat-v1` pricing uses ₹10,000 steps through the lower of ₹500,000 and the approved limit, including an off-grid cap. Monthly flat interest is 2% for 3 or 6 months and 3% for 9, 12, 18 or 24 months. Fees are zero. Interest rounds half up to paise, regular EMI rounds down to whole rupees, and the final EMI closes the balance. Affordability uses the larger installment. Due dates follow the issue date in Asia/Kolkata. Quotes expire at the earlier of 15 minutes or offer expiry.
- Normal Flutter routes consume server options, quote terms and schedule. Reopening the selection preserves the chosen amount and tenure while returning from review. Quote review and schedule revalidate on resume. Approved APR, disclosures and final acceptance remain gated. Production pricing returns HTTP 503 without an approved implementation.
- Fifteen focused PostgreSQL tests and five focused Flutter quotation tests passed. Focused Dart analysis reported no errors or warnings and five Flutter Material deprecation notices. Two eligibility widget failures in the wider run reproduced on unmodified HEAD. On `etf_loans_device`, Flyway applied V5 only, validated history and verified preservation of existing authentication, borrower and eligibility records. The existing runtime role was granted quote-table SELECT and INSERT.
- Normal Chrome against `etf_loans_device` verified authenticated ETF-023 options, the ETF-024 ₹10,000 six-month quote, and the ETF-025 persisted schedule. After an income update in a second tab, resuming the open schedule returned HTTP 410 and showed the stale notice. Final acceptance was gated in review.

See [BE-04 local verification](LOCAL-DEVELOPMENT-WINDOWS.md#loan-quotations-in-chrome).

### BE-04A visual verification

- The running debug server on port 7357 returned empty HTTP 404 responses for the Flutter asset manifests, logo and font. A fresh web release contained the generated manifests and original assets. The documented loopback workflow now serves the validated release bundle on port 7360 with caching disabled for local verification.
- ETF-023 uses the existing brand tokens for the amount, slider and responsive tenure grid. ETF-024 and ETF-025 use matching dividers. Quotation calculations, requests, navigation and stale handling were preserved.
- Normal Chrome captured the public, sign-in, onboarding, PAN, eligibility, loan selection, review, schedule and verification screens. The corrected three-column tenure grid was inspected at 390 px. Both manifests, the logo, SVG, all three custom fonts and Material Icons returned nonempty HTTP 200 responses.
- ETF-018 has an offer-scoped checklist interface and unavailable-provider states. An approved backend adapter remains pending. ETF-026 has a versioned viewer and verified unavailable state. Approved agreement and KFS content and download integration remain pending. Final acceptance stayed gated.
- The BE-04A Windows build reached `:app:compileFlutterBuildDebug`, where Windows denied a Flutter child-process launch. QA-04C later produced the APK in GitHub Actions.
- Finalization added a fail-closed proxy check for local synthetic mode. The recorded Chrome acceptance predates this guard. No application rebuild was run during finalization.
- An approved production pricing provider remains pending.

## 21. QA-04 physical Android acceptance

QA-04 is closed. BE-01 through BE-04A are accepted for the implemented local scope, covering borrower onboarding and profile persistence, synthetic PAN and eligibility, offer handoff, loan options, quotation review and schedule, and BE-04A visual updates. The user reported successful installation and **15 of 15** manual acceptance checks on POCO F4 serial `2786684b`.

GitHub Actions run `45992861254` built the fresh ARM64 debug APK from commit `f3a7eba`. The APK signature, ARM64 libraries and debug loopback configuration were verified. The downloaded APK's SHA-256 matched the device copy at `/sdcard/Download/ETF-Loans-BE04.apk`. ADB reverse mapped device port `8080` to the local backend. [Actions run](https://github.com/mohan2901-05/ETF---login/actions/runs/45992861254) · [APK artifact](https://github.com/mohan2901-05/ETF---login/actions/runs/45992861254/artifacts/15194567486)

Use the Ubuntu GitHub Actions workflow for new APKs. Windows attempts encountered Flutter launcher and JNI/CMake/Ninja process failures. CI and local debug keystores can sign the same app ID with different certificates and block in-place updates. [Build and device setup](LOCAL-DEVELOPMENT-WINDOWS.md#android-apk-build-and-device-setup)

Pending work

- Establish consistent development signing for CI and local APK upgrades.
- Resolve the two pre-existing eligibility widget failures reproduced on the earlier unmodified baseline.
- Integrate approved production PAN and eligibility providers, camera and face verification, the offer-scoped KYC checklist, Aadhaar/DigiLocker, address/work submission and bank verification.
- Integrate approved pricing and APR, versioned KFS and agreement content and downloads, and final loan acceptance with backend verification and consent evidence.

## 22. Working references
- ETF Loans website: https://etf-loans.vercel.app/
- ETF Loans Site Map.html (14 November 2026)
- User-provided screenshot batches: IMG_2681 through IMG_2724 (including welcome, sign-in, result, offer, review, checklist, Home, Loans, Profile, account/recovery, update, Aadhaar, face, address/work, deletion, notifications and legal pages).
- Existing local project and login repair/test reports. Exact current repository and backend access remain to be confirmed in Phase 00.
