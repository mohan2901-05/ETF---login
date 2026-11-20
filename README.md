# ETF Loans — Mobile Login Application

## Project Overview

This project develops a Flutter mobile login application matching the ETF Loans website branding,
authenticating borrowers using their mobile number and OTP.

### Architecture

```
Flutter Android Application → Spring Boot REST API → PostgreSQL Database
Flutter must NEVER connect directly to PostgreSQL
```

### Current Status

**Phase 1-6 completed:** Project structure, Spring Boot backend, Flutter application foundation,
API contract, and database design documented.

**Phase 7-8 in progress:** Testing, final documentation, and implementation report.

---

## Quick Start

### Prerequisites

- JDK 17
- Maven 3.9.6
- Flutter 3.47.7
- PostgreSQL 18.7 (service startup may require attention)

### Backend (Spring Boot)

```powershell
# 1. Set environment variables (PowerShell, current session only)
$env:DB_URL = "jdbc:postgresql://localhost:5432/ETF-login%28sap%29"
$env:DB_USERNAME = "etf_loans_app"
$env:DB_PASSWORD = "your_secure_password"

# 2. Navigate and run
cd D:\projects\ETF - login\etf-loans-backend
mvn spring-boot:run
```

**Note:** The application is configured to work even without a running PostgreSQL database.
Set `spring.flyway.enabled=false` and `spring.jpa.hibernate.ddl-auto=validate` (already configured).

### Flutter Application

```powershell
# 1. Get dependencies
cd D:\projects\ETF - login\etf-loans-flutter
flutter pub get

# 2. Run analysis
flutter analyze

# 3. Run on device
flutter run
```

### API Health Check

Once the backend is running:

```powershell
curl http://localhost:8080/api/health
# Returns: {"status":"up","service":"etf-loans-backend","version":"1.0.0"}
```

---

## Project Structure

```
ETF - login/
├── etf-loans-backend/     # Spring Boot Java backend
├── etf-loans-flutter/     # Flutter mobile application
├── docs/
│   ├── API-CONTRACT.md
│   ├── DATABASE-DESIGN.md
│   ├── DEVELOPMENT-SETUP.md
│   └── IMPLEMENTATION-STATUS.md
└── README.md
```

---

## Security

- Flutter must NEVER connect directly to PostgreSQL
- Never expose database credentials in Flutter
- Never hardcode production secrets
- Never store passwords in plain text
- Never implement fake production authentication
- Use secure session storage when authentication is implemented
- Never commit secrets to git

---

## Learn More

- [Backend: etf-loans-backend/README.md (if created)]
- [Flutter: flutter.dev documentation]
- [PostgreSQL: postgresqldocs.com]
- [ETF Loans website: etf-loans.vercel.app]