# Development Setup
# ==============

This document describes how to set up and run the ETF Loans project
locally.

---

## Prerequisites

### Software Required

| Software | Version | Notes |
|----------|---------|-------|
| **Java** | JDK 17 | Oracle JDK or OpenJDK 17 |
| **Maven** | 3.9.6 | Build tool |
| **Flutter** | 3.47.7 | SDK for mobile app |
| **Dart** | 3.13.5 | Dart language |
| **PostgreSQL** | 18.7 | Database server |
| **Android SDK** | 34.0.0 | For Flutter Android development |
| **Git** | 2.56.0 | Version control |

### Environment Variables

The following environment variables must be set for the Spring Boot backend:

```
DB_URL=jdbc:postgresql://localhost:5432/ETF-login%28sap%29
DB_USERNAME=etf_loans_app
DB_PASSWORD=<your_password_here>
```

**Important:** The DB_PASSWORD must not be committed to source control.
Use a `.env` file or secure vault for local development.

---

## Project Structure

```
ETF - login/
├── etf-loans-backend/     # Spring Boot Java backend
│   ├── pom.xml
│   ├── src/main/java/com/etfloans/backend/
│   │   ├── EtfLoansBackendApplication.java
│   │   ├── config/
│   │   ├── controller/
│   │   ├── service/
│   │   ├── repository/
│   │   ├── model/
│   │   ├── dto/
│   │   ├── security/
│   │   └── exception/
│   ├── src/main/resources/application.properties
│   └── src/test/java/com/etfloans/backend/
│       └── EtfLoansBackendApplicationTests.java
├── etf-loans-flutter/     # Flutter mobile application
│   ├── pubspec.yaml
│   ├── src/main/dart/lib/main.dart
│   ├── src/main/dart/lib/app/
│   │   ├── app.dart
│   │   ├── theme/
│   │   │   └── theme_config.dart
│   ├── src/main/dart/lib/core/
│   │   ├── config/
│   │   ├── constants/api_constants.dart
│   │   ├── network/network_service.dart
│   │   └── errors/app_errors.dart
│   ├── src/main/dart/lib/features/authentication/
│   │   ├── models/auth_models.dart
│   │   ├── services/authentication_service.dart
│   │   ├── screens/login_screen.dart
│   │   └── screens/otp_verification_screen.dart
│   └── shared/widgets/
├── docs/
│   ├── API-CONTRACT.md
│   ├── DATABASE-DESIGN.md
│   ├── DEVELOPMENT-SETUP.md
│   └── IMPLEMENTATION-STATUS.md
└── README.md
```

---

## Running PostgreSQL

### On Windows

1. **Start the PostgreSQL service:**
   ```powershell
   Start-Service postgresql-x64-18
   ```

2. **Verify it's running:**
   ```powershell
   sc query postgresql-x64-18
   ```

3. **If the service fails to start:**
   - Check the log: `C:\Program Files\PostgreSQL\18\log\postgresql-18.log`
   - Ensure no other PostgreSQL instance is using port 5432
   - Verify the data directory is intact: `C:\Program Files\PostgreSQL\18\data`

4. **To start PostgreSQL automatically on boot:**
   ```powershell
   sc config postgresql-x64-18 start= auto
   ```

### Database and User (already created)

The following database and user are assumed to exist (per project setup):

```sql
-- Database
CREATE DATABASE "ETF-login(sap)";

-- User (with password set by administrator)
CREATE USER etf_loans_app WITH PASSWORD '<strong_password>';

-- Grant permissions
GRANT CONNECT ON DATABASE "ETF-login(sap)" TO etf_loans_app;
GRANT USAGE ON SCHEMA public TO etf_loans_app;
GRANT CREATE ON SCHEMA public TO etf_loans_app;
```

---

## Configuring Local Environment Variables

### Option 1: PowerShell Session (Temporary)

```powershell
# Set environment variables for current session only
$env:DB_URL = "jdbc:postgresql://localhost:5432/ETF-login%28sap%29"
$env:DB_USERNAME = "etf_loans_app"
$env:DB_PASSWORD = "your_secure_password_here"
```

**Note:** These variables are only set for the current PowerShell session
and will not be committed to git or persist across sessions.

### Option 2: Windows Environment Variables (Permanent)

1. Search "Edit the system environment variables" in Windows Start
2. Click "Environment Variables"
3. Under "User variables", click "New"
4. Add:
   - Variable name: `DB_URL`
   - Variable value: `jdbc:postgresql://localhost:5432/ETF-login%28sap%29`
   - Variable name: `DB_USERNAME`
   - Variable value: `etf_loans_app`
   - Variable name: `DB_PASSWORD`
   - Variable value: `<your_password>`
5. Click OK on all dialogs

**Security Warning:** Storing passwords in Windows environment variables
may be visible to other users on shared machines. Use Option 1 for
temporary development work.

### Option 3: .env File (Recommended for this project)

1. Create a `.env` file in the `etf-loans-backend` directory:
   ```
   DB_URL=jdbc:postgresql://localhost:5432/ETF-login%28sap%29
   DB_USERNAME=etf_loans_app
   DB_PASSWORD=your_secure_password
   ```

2. **Important:** Add `.env` to `.gitignore` to prevent committing secrets.

3. The application.properties already includes placeholders:
   ```properties
   spring.datasource.url = ${DB_URL:jdbc:postgresql://localhost:5432/ETF-login%28sap%29}
   spring.datasource.username = ${DB_USERNAME:etf_loans_app}
   spring.datasource.password = ${DB_PASSWORD:}
   ```

   - If env vars are set, those values are used
   - If not, the defaults are used (for testing without a database)

---

## Starting Spring Boot Backend

### From Command Line

```powershell
# Navigate to backend directory
cd D:\projects\ETF - login\etf-loans-backend

# Set environment variables (if not already set)
$env:DB_URL = "jdbc:postgresql://localhost:5432/ETF-login%28sap%29"
$env:DB_USERNAME = "etf_loans_app"
$env:DB_PASSWORD = "your_secure_password"

# Run with Maven
mvn spring-boot:run
```

### Using Maven Profile

```powershell
mvn spring-boot:run -Dspring-boot.run.jvmArgs="-Ddb.url=jdbc:postgresql://localhost:5432/ETF-login%28sap%29 -Ddb.username=etf_loans_app -Ddb.password=your_password"
```

### Default Configuration (no database)

The application is configured to work even without a running PostgreSQL
database:

- `spring.flyway.enabled=false` - Flyway migrations disabled
- `spring.jpa.hibernate.ddl-auto=validate` - Hibernate validates but
  doesn't create tables
- Default datasource uses environment variable fallbacks

**Tested:** `mvn test` passes without PostgreSQL running.

---

## Running the Flutter Application

### Prerequisites

- Physical Redmi Android phone or Android emulator
- USB debugging enabled on the device
- `adb` in PATH

### Commands

```powershell
# 1. Get dependencies
cd D:\projects\ETF - login\etf-loans-flutter
flutter pub get

# 2. Run static analysis
flutter analyze

# 3. Format code
flutter format .

# 4. Run on connected device
flutter run

# 5. Build APK for physical device
flutter build apk --release
```

### Device Connection

#### For Android Emulator:
```powershell
# Emulator not intended for this project
# Skip this section
```

#### For Physical Redmi Phone:
```powershell
# 1. Enable USB debugging on the phone:
#   Settings → About phone → Tap "Build number" 7 times → Developer options
#   Settings → Additional settings → Developer options → USB debugging

# 2. Connect phone via USB
# 3. Verify connection
adb devices

# 4. Set IP-based connection (if USB not available)
#    Find phone IP: adb shell ip addr show wlan0
#    Update Constants.baseUrl in lib/core/constants/api_constants.dart
#    Example: http://192.168.1.100:8080
```

### Offline Development (No Phone)

If no Android device is available:

1. `flutter analyze` - Verify Dart code correctness
2. `flutter format .` - Format code
3. `mvn test` - Run backend tests
4. Manual review of UI designs

---

## Testing

### Backend Tests

```powershell
# Run all tests
mvn test

# Run with specific profile
mvn test -Dspring.profiles.active=default
```

**Note:** Tests use `spring.flyway.enabled=false` and pass without
PostgreSQL running. The health endpoint can be verified:

```powershell
curl http://localhost:8080/api/health
# Expected: {"status":"up","service":"etf-loans-backend","version":"1.0.0"}
```

### Flutter Tests

```powershell
# Run Flutter unit tests (if any)
flutter test

# Analyze for issues
flutter analyze
```

---

## Connecting Physical Android Device for Testing

### Network Configuration

1. **Find development machine IP:**
   ```powershell
   ipconfig
   # Note the IPv4 Address (e.g., 192.168.1.100)
   ```

2. **Update API base URL:**
   Edit `etf-loans-flutter/src/main/dart/lib/core/constants/api_constants.dart`:
   ```dart
   static const String baseUrl = 'http://192.168.1.100:8080';
   ```

3. **Ensure firewall allows port 8080:**
   - Windows Defender Firewall → Allow an app or feature → Change settings
   - Check "Private" and "Public" for Java or Maven

4. **Test connectivity:**
   ```powershell
   # From PowerShell on the dev machine
   curl http://192.168.1.100:8080/api/health
   ```

5. **Run Flutter app:**
   ```powershell
   flutter run
   ```

### QR Code Debugging

Flutter can also use QR code debugging:

1. Run `flutter run -d chrome` to start web mode
2. Scan the QR code with the Flutter app on the phone
3. The app will hot-reload changes

---

## Memory Constraints (8 GB RAM Laptop)

### Recommended Practices

- Do not run emulator and backend simultaneously
- Close unnecessary applications during builds
- Monitor free memory: `wmic OS get FreePhysicalMemory`
- Avoid `flutter build` and `mvn test` concurrently
- If memory is critically low (~200 MB free), stop current operation

### Observed Behavior

- `mvn compile` uses ~400-600 MB RAM
- `flutter pub get` uses ~300-500 MB RAM
- Simultaneous builds may cause OOM (Out of Memory)
- Recommended: Work sequentially, not in parallel

---

## Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| `Connection refused` on port 5432 | PostgreSQL not running | `Start-Service postgresql-x64-18` |
| `Flyway connection failed` | Database not accessible | Set `spring.flyway.enabled=false` or start DB |
| `Could not find or load main class` | Maven classpath issue | `mvn clean spring-boot:run` |
| `Flutter command not found` | Flutter not in PATH | Add `C:\Users\mohan\develop\flutter\bin` to PATH |
| `ADB not found` | Android SDK not configured | Set `ANDROID_HOME` to `C:\Users\mohan\AppData\Local\Android\sdk` |
| `Validation error on mobile number` | Format incorrect | Must be 10-15 digits, starts with 6-9 |
| `Unicode escape in application.properties` | Special chars in DB name | Use `%28` for `(` and `%29` for `)` in JDBC URL |

### PostgreSQL Service Issues

If `Start-Service postgresql-x64-18` fails:

1. Check logs: `Get-Content "C:\Program Files\PostgreSQL\18\log\postgresql-18.log" -Tail 20`
2. Verify data integrity
3. Try manual startup via `pg_ctl`
4. If unrecoverable, use `spring.flyway.enabled=false` and
   `spring.jpa.hibernate.ddl-auto=validate` (current setup)