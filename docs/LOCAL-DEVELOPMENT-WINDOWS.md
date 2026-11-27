# Windows local development

Use PowerShell 5.1 from the repository root. The scripts honor the machine's execution policies. If a trusted script is blocked because Windows marked it as downloaded, review it and use `Unblock-File -LiteralPath .\script-name.ps1` on that file. Leave the current execution policy in place.

## One-time setup

- Keep JDK 17 available through `JAVA_HOME` for Spring Boot and Maven. Android builds prefer Android Studio's bundled JDK and accept `-Jdk` for a compatible alternative.
- Put Flutter's `bin`, Maven's `bin` and the Android SDK's `platform-tools` on the Windows user PATH once. Set `ANDROID_HOME` to the installed SDK. Restart Antigravity after environment changes.
- Copy the existing DPAPI-encrypted `device.local.clixml` into the ignored `.local-dev\` directory. It can be decrypted by the Windows account and computer that created it. Use `-Credentials` for an alternative file. Keep its target on loopback and use the pre-provisioned synthetic-only `etf_loans_device` database.
- Enable USB debugging on the phone and approve this computer. If several physical devices are online, pass `-DeviceSerial`.
- Check that the existing PostgreSQL Windows service is running. If this installation's `postgresql-x64-18` service is stopped, run `Start-Service postgresql-x64-18` from an elevated PowerShell.

## Daily commands

From the repository root in the first PowerShell terminal, start the isolated backend.

```powershell
.\start-local-dev.ps1 -SkipPhone
```

In a second terminal, run the normal Flutter app in Chrome.

```powershell
Set-Location 'D:\projects\ETF - login\etf-loans-flutter'
cmd /d /c 'D:\tools\flutter\flutter\bin\flutter.bat --no-version-check run -d chrome --no-pub --web-hostname=127.0.0.1 --web-port=7357 --dart-define=API_BASE_URL=http://127.0.0.1:8080'
```

If the Flutter batch launcher fails, use the cached Flutter tool from the same directory. When it reports that the app is being served, open `http://127.0.0.1:7357` in Chrome.

```powershell
$flutter = 'D:\tools\flutter\flutter'
$env:FLUTTER_ROOT = $flutter
& "$flutter\bin\cache\dart-sdk\bin\dart.exe" `
  "--packages=$flutter\packages\flutter_tools\.dart_tool\package_config.json" `
  "$flutter\packages\flutter_tools\bin\flutter_tools.dart" `
  --no-version-check run -d web-server --no-pub --no-web-resources-cdn `
  --web-hostname=127.0.0.1 --web-port=7357 --dart-define=API_BASE_URL=http://127.0.0.1:8080
```

The backend launcher supplies mock OTP, synthetic PAN and the `financial-fixture` eligibility scenario on each fresh start. These work in a new terminal using the existing encrypted configuration. A matching healthy process is reused. A tracked Java process started by the old launcher or with a different fixture is restarted. Pass `-EligibilityScenario` with `eligible`, `ineligible` or `failure` to switch fixtures. Keep the displayed mock OTP in your local terminal.

For device work and backend shutdown, run from the repository root.

```powershell
.\start-local-dev.ps1
.\build-install.ps1
.\stop-local-dev.ps1
```

Start waits for health on port 8080, generates a synthetic OTP for that backend session and restores ADB reverse when the phone is online. The default cooldown is 10 seconds, startup Flyway is disabled, and Hibernate validates the installed schema.
If PostgreSQL enters recovery during startup and Java exits, the launcher waits for PostgreSQL and retries within the startup timeout. After a backend restart, request a new OTP challenge and use the code from that launch.

Use `.\build-install.ps1 -InstallOnly` for a previously built APK or `.\build-install.ps1 -SkipInstall` to build without attaching the phone. The build uses CMD, one Gradle worker and an ARM64 target for this invocation. Install preserves existing app data.

If a direct Flutter command fails while Gradle starts `flutter.bat`, use `build-install.ps1`. It selects the SDK explicitly, uses a single-use Gradle process and retries a launch failure once. The first failed attempt is preserved in `.local-dev\apk-build-first-attempt.log`. If Windows still reports `0xC0000005`, run the script from a normal Windows Terminal PowerShell session outside the IDE. Use `-Verbose` to capture the Gradle stacktrace.

The launcher packages the backend from the local Maven cache when main sources or the POM change, then starts the executable JAR directly with Java. Packaging diagnostics are in `.local-dev\backend-build.log`. For startup failures, inspect `.local-dev\backend.out.log` and `.local-dev\backend.err.log`. The Android build log is `.local-dev\apk-build.log`.

Stop checks the recorded workspace, executable, process ID and creation time. Stale records are cleared. If a different process owns port 8080, identify it independently.

The workspace also supplies VS Code-format tasks under `.vscode/tasks.json`. Use them if Antigravity exposes **Tasks: Run Task**. The PowerShell commands work independently of the IDE.

## Borrower profile and PAN

Use the isolated development database provisioned through V4. Its Flyway history records V1 and V2 as a V2 baseline, followed by V3 and V4. Keep the existing provisioned database across daily starts.

For an existing `etf_loans_device` database provisioned without Flyway history, first verify that it is on loopback and that its authentication schema matches V1 and V2. As the migration owner, run Flyway `baseline` with `baselineVersion=2`, then run `migrate` and `validate` with both locations. This records the existing schema without rerunning the authentication migrations.

The isolated runtime role needs `SELECT`, `INSERT`, and `UPDATE` on `public.borrower_profiles`. Have the migration owner apply those table-level grants after approval.

To test the profile flow, use **Synthetic Borrower**, **13/02/1990**, **`ZZZZZ0000Z`**, and check PAN consent. The synthetic adapter accepts that PAN only. A successful save leads to a separate credit assessment consent screen.

## Eligibility in Chrome

For new isolated databases, run the PostgreSQL verification suite before provisioning V4 with both Flyway locations as migration owner. The runtime role needs SELECT and INSERT on `eligibility_assessments` and UPDATE on its mutable lifecycle and result columns. Existing profile grants cover the revision column.

The `eligible` scenario always returns the same sample values. A financial change still creates an assessment with a new offer reference. The development-only `financial-fixture` scenario accepts any valid nonnegative income and EMI with up to two decimal places. Use a fresh synthetic profile when switching scenarios because a result for an unchanged revision is reusable until expiry.

The fixture calculates gross monthly capacity as one third of income above ₹12,000, rounded down to paise, with a minimum of zero. It subtracts existing EMI. A positive remainder is the sample affordable EMI, and the sample limit is ten times that remainder plus ₹10,000. A zero or negative remainder is ineligible. These amounts are synthetic and have no production lending use.

| Monthly income | Other monthly EMIs | Expected result |
| --- | --- | --- |
| ₹42,000 | ₹1,000 | ₹1,00,000 limit and ₹9,000 affordable monthly EMI |
| ₹48,000 | ₹1,000 | ₹1,20,000 limit and ₹11,000 affordable monthly EMI |
| ₹48,000 | ₹5,000 | ₹80,000 limit and ₹7,000 affordable monthly EMI |
| ₹48,000 | ₹12,000 | Ineligible |
| ₹60,000 | ₹10,000 | ₹70,000 limit and ₹6,000 affordable monthly EMI |

Invalid profile inputs return HTTP 400. New assessment failures distinguish provider errors (502), service unavailability (503), and provider timeout (504). Stale or expired assessments still return 410. The `ineligible` and `failure` scenarios remain available for standalone checks.

1. Restart Flutter with the Chrome command above so both tabs load the current app. Assess the first input pair in tab A. Confirm **Check eligibility** stays disabled until you give separate credit assessment consent.
2. In tab B for the same borrower, update income to ₹48,000, save, and consent again. Confirm the second offer amounts. In tab A, select **Choose loan amount** on the previous result. Expect a fresh GET returning HTTP 410, the reassessment prompt and ETF-023 to stay closed.
3. Give fresh consent in tab A and open ETF-023 from the current offer. Loan options remain unavailable. In tab B change only EMIs to ₹5,000, save, and consent. Confirm the third offer amounts. Return to tab A and expect it to close ETF-023 after another HTTP 410, with the reassessment prompt ready.

For the BE-03C regression, start with the standard launcher, then save income **60000** and EMI **10000** in ETF-014. Give fresh credit consent and confirm the ₹70,000 sample limit and ₹6,000 affordable EMI. Recheck without changing finances to confirm reuse. Change those finances in a second tab to confirm the first tab's previous offer is stale.

BE-03C verification passed nine input pairs against the device PostgreSQL backend after a cold restart. Normal Chrome at port 7357 confirmed the ₹60,000/₹10,000 result, same-revision reuse, and HTTP 410 on both stale offer click and tab resume. Flyway history remained at V4.

## QA-02 functional inventory

The normal app and the debug preview have separate entry points. To open the debug preview, use the Chrome launch command with `--web-port=7358 -t tool/borrower_preview.dart`. The preview uses in-memory fixtures and does not connect to the backend.

| Screens | Normal app | Debug preview |
| --- | --- | --- |
| ETF-010, ETF-014 | Integrated borrower profile creation, retrieval and financial updates in PostgreSQL. | Synthetic form flows with simulated saves. |
| ETF-011–013 | Integrated PAN and eligibility APIs with synthetic local providers. Separate consent, polling and reassessment are connected. | Synthetic PAN, simulated assessment states and sample results. The sample result has no server-issued offer. |
| ETF-015–018 | UI for face instructions, capture/result states and checklist. Camera adapter, face provider and offer-scoped verification backend remain unimplemented. | Synthetic face session and checklist. No real camera capture. |
| ETF-019–022 | UI for Aadhaar, address/work and bank verification. DigiLocker handoff, persisted submissions and bank verification remain unimplemented. | Synthetic Aadhaar results and submit states for the forms. |
| ETF-023 | Integrated handoff with server offer revalidation. Loan options remain unavailable pending BE-04. | Synthetic amount and term options. |
| ETF-024–026 | UI for quote review, schedule, agreement and Key Facts Statement. Authoritative data, final acceptance and document downloads remain unimplemented. | Synthetic quote, schedule and disclosures. |

The broken daily startup was traced to PAN and eligibility provider settings that lived only in the prior terminal. After the fix, authenticated API smoke checks passed for registration, login, recovery, session revocation and login with the new password, profile creation/retrieval/update, PAN, eligibility reassessment and stale-offer HTTP 410. Normal Chrome on 7357 loaded and saved a profile through backend port 8080, checked eligibility and opened ETF-023. Chrome opened all 18 preview entries, including both ETF-026 viewers, without borrower API requests. The device database retained its V2 baseline, V3/V4 history, scoped runtime privileges and prior assessment rows.

## QA-03 integrated Chrome acceptance

- Restart Flutter to pick up source changes, use the normal entry point, and keep the same loopback origin when refreshing. Browser secure storage is scoped to its origin.
- Use a fresh, unused ten-digit synthetic mobile number starting with 6–9 and a password of at least 12 characters and at most 72 UTF-8 bytes. Use the current development OTP. After registration or password recovery saves the password, sign in explicitly. These flows do not issue a bearer session.
- For a new borrower use **Synthetic Borrower**, **13/02/1990**, **Salaried**, income **42000**, EMI **1000**, PAN **`ZZZZZ0000Z`**, and give PAN consent. Give separate credit assessment consent after the profile save. The BE-03C formula above extends the original fixture pairs.
- Use a separate verified borrower for ETF-014. The full date of birth is read-only. **Save and recheck eligibility** saves finances and opens credit assessment consent. For the two-tab stale-offer checks, change the pair to **48000/1000** and then **48000/5000**. ETF-023 opens for a current offer. Loan options remain unavailable.

The original Chrome build kept sign-in visible when refreshing `/#/login` even though token validation returned HTTP 200. The corrected route restores the verified session. Normal Chrome passed registration, mouse-focused OTP entry, password setup, sign-in, refresh, recovery, PAN and credit consent, and ETF-023 handoff on a fresh account. A separate verified account passed ETF-014 reassessment and returned HTTP 410 for stale offers on both click and tab resume. Validate the launcher's recovery retry, retry ceiling and fail-fast behavior with `.\verify-local-startup.ps1`.

PostgreSQL confirmed revisions 0, 1 and 2 with assessment and offer prefixes `6891b6db/ac5356ce`, `14b6054d/699ec1e3` and `7afe9e60/6353d7d8`. A standard cold start and a new authenticated assessment passed with the default providers. Dart analysis and the three launcher regressions passed. The Flutter widget runner was blocked by Windows access to Android Studio's Java executable before tests started.

## Verification status

DEV-01 and DEV-01A backend automation passed live verification. Two start/stop cycles reached HTTP health, a repeated start reused the tracked Java process, and both scripts refused an unrelated port listener. Hibernate validated the schema with startup Flyway disabled.

DEV-01B's CMD quoting fix passed the Flutter compile task on the diagnostic run. Fresh Android APK build and installation are deferred to the next testing cycle because Windows reported an access violation (`0xC0000005`) in the Flutter subprocess. No fresh APK was installed.
