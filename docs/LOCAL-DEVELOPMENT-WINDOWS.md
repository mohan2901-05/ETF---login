# Windows development on a physical Android device

Use PowerShell 5.1 from the repository root. The scripts honor the machine's execution policies. If a trusted script is blocked because Windows marked it as downloaded, review it and use `Unblock-File -LiteralPath .\script-name.ps1` on that file. Leave the current execution policy in place.

## One-time setup

- Keep JDK 17 available through `JAVA_HOME` for Spring Boot and Maven. Android builds prefer Android Studio's bundled JDK and accept `-Jdk` for a compatible alternative.
- Put Flutter's `bin`, Maven's `bin` and the Android SDK's `platform-tools` on the Windows user PATH once. Set `ANDROID_HOME` to the installed SDK. Restart Antigravity after environment changes.
- Copy the existing DPAPI-encrypted `device.local.clixml` into the ignored `.local-dev\` directory. It can be decrypted by the Windows account and computer that created it. Use `-Credentials` for an alternative file. Keep its target on loopback and use the pre-provisioned synthetic-only `etf_loans_device` database.
- Enable USB debugging on the phone and approve this computer. If several physical devices are online, pass `-DeviceSerial`.
- Check that the existing PostgreSQL Windows service is running. If this installation's `postgresql-x64-18` service is stopped, run `Start-Service postgresql-x64-18` from an elevated PowerShell.

## Daily commands

```powershell
.\start-local-dev.ps1
.\build-install.ps1
.\stop-local-dev.ps1
```

Start waits for health on port 8080, generates a synthetic OTP for that backend session and restores ADB reverse when the phone is online. Running start again reuses a healthy tracked backend and restores USB reverse after reconnecting. Use `-SkipPhone` for backend-only work. The default cooldown is 10 seconds, startup Flyway is disabled, and Hibernate validates the installed schema. Keep the displayed mock OTP in your local terminal.

Use `.\build-install.ps1 -InstallOnly` for a previously built APK or `.\build-install.ps1 -SkipInstall` to build without attaching the phone. The build uses CMD, one Gradle worker and an ARM64 target for this invocation. Install preserves existing app data.

If a direct Flutter command fails while Gradle starts `flutter.bat`, use `build-install.ps1`. It selects the SDK explicitly, uses a single-use Gradle process and retries a launch failure once. The first failed attempt is preserved in `.local-dev\apk-build-first-attempt.log`. If Windows still reports `0xC0000005`, run the script from a normal Windows Terminal PowerShell session outside the IDE. Use `-Verbose` to capture the Gradle stacktrace.

The launcher packages the backend from the local Maven cache when main sources or the POM change, then starts the executable JAR directly with Java. Packaging diagnostics are in `.local-dev\backend-build.log`. For startup failures, inspect `.local-dev\backend.out.log` and `.local-dev\backend.err.log`. The Android build log is `.local-dev\apk-build.log`.

Stop checks the recorded workspace, executable, process ID and creation time. Stale records are cleared. If a different process owns port 8080, identify it independently.

The workspace also supplies VS Code-format tasks under `.vscode/tasks.json`. Use them if Antigravity exposes **Tasks: Run Task**. The PowerShell commands work independently of the IDE.

## Verification status

DEV-01 and DEV-01A backend automation passed live verification. Two start/stop cycles reached HTTP health, a repeated start reused the tracked Java process, and both scripts refused an unrelated port listener. Hibernate validated the schema with startup Flyway disabled.

DEV-01B's CMD quoting fix passed the Flutter compile task on the diagnostic run. Fresh Android APK build and installation are deferred to the next testing cycle because Windows reported an access violation (`0xC0000005`) in the Flutter subprocess. No fresh APK was installed.
