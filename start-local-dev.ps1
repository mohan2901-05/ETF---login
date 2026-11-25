# ETF Loans - Local development startup (Windows PowerShell 5.1+)
# The script does not install dependencies, modify the database, or store secrets.
[CmdletBinding()]
param(
    [string]$DeviceSerial,
    [string]$MockOtpCode = $env:ETF_OTP_MOCK_CODE,
    [string]$Maven = (Join-Path $env:LOCALAPPDATA 'Programs\apache-maven-3.9.6\bin\mvn.cmd'),
    [string]$Adb = (Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'),
    [string]$PgIsReady = (Join-Path $env:ProgramFiles 'PostgreSQL\18\bin\pg_isready.exe'),
    [switch]$SkipPhone,
    [switch]$SyntheticAccountsOnly
)

$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$backendDir = Join-Path $projectRoot 'etf-loans-backend'
$mavenCmd = $Maven
$adbExe = $Adb
$pgReady = $PgIsReady
$healthUrl = 'http://127.0.0.1:8080/api/health'

function Show-Step([string]$message) {
    Write-Host "`n== $message ==" -ForegroundColor Cyan
}

function Test-BackendHealth {
    try {
        $result = Invoke-RestMethod -Uri $healthUrl -TimeoutSec 3
        return ($result.status -eq 'up')
    } catch {
        return $false
    }
}

function Import-RequiredEnvironment([string]$name) {
    $value = [Environment]::GetEnvironmentVariable($name, 'Process')
    if ([string]::IsNullOrWhiteSpace($value)) {
        $value = [Environment]::GetEnvironmentVariable($name, 'User')
    }
    if ([string]::IsNullOrWhiteSpace($value)) {
        $value = [Environment]::GetEnvironmentVariable($name, 'Machine')
    }
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "Missing $name. Configure it in your Windows user environment or current PowerShell session. No credentials were changed."
    }
    [Environment]::SetEnvironmentVariable($name, $value, 'Process')
    Write-Host "  $name : configured"
}

if (-not (Test-Path -LiteralPath $backendDir -PathType Container)) {
    throw "Backend directory not found: $backendDir. Place this script in your ETF Loans project root."
}
if (-not (Test-Path -LiteralPath $mavenCmd -PathType Leaf)) {
    throw "Maven not found: $mavenCmd"
}
if ($MockOtpCode -notmatch '^\d{6}$') {
    throw 'Supply a six-digit local mock OTP via -MockOtpCode or ETF_OTP_MOCK_CODE.'
}

if (-not $SyntheticAccountsOnly) {
    throw 'Confirm the isolated device database contains only synthetic data with -SyntheticAccountsOnly.'
}
foreach ($name in @('ETF_DEVICE_DB_URL', 'ETF_DEVICE_DB_USERNAME', 'ETF_DEVICE_DB_PASSWORD', 'ETF_DEV_OTP_KEY')) {
    Import-RequiredEnvironment $name
}
if ($env:ETF_DEVICE_DB_URL -notmatch '^jdbc:postgresql://127\.0\.0\.1:([0-9]{1,5})/etf_loans_device$') {
    throw 'ETF_DEVICE_DB_URL must target etf_loans_device on IPv4 loopback.'
}
$dbPort = [int]$Matches[1]
if ($dbPort -lt 1 -or $dbPort -gt 65535) { throw 'Invalid device database port.' }
if ($env:ETF_DEV_OTP_KEY.Length -lt 32 -or $env:ETF_DEV_OTP_KEY -ceq $env:ETF_OTP_KEY) {
    throw 'Configure a separate strong device-testing OTP key.'
}

Show-Step 'Check isolated PostgreSQL'
if (-not (Test-Path -LiteralPath $pgReady -PathType Leaf)) {
    throw "PostgreSQL utility not found: $pgReady"
}
$ready = $false
for ($i = 0; $i -lt 12; $i++) {
    & $pgReady -h 127.0.0.1 -p $dbPort | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $ready = $true
        break
    }
    Start-Sleep -Seconds 2
}
if (-not $ready) {
    throw 'The isolated PostgreSQL instance is not accepting connections on its configured port.'
}
Write-Host '  PostgreSQL is accepting loopback connections on the device database port.' -ForegroundColor Green

Show-Step 'Configure local Spring Boot authentication'
$env:SPRING_FLYWAY_ENABLED = 'false'
$env:ETF_OTP_MOCK_CODE = $MockOtpCode
$env:ETF_OTP_MOCK_ENABLED = 'true'
$env:ETF_DEMO_ENABLED = 'false'
$env:CORS_ALLOWED_ORIGINS = 'http://127.0.0.1:8080'
Write-Host '  Local mock OTP configured; demo mode disabled.'
Write-Host '  No database password, HMAC key, or session token is written to this script.'

Show-Step 'Check Spring Boot'
if (Test-BackendHealth) {
    throw 'Port 8080 already has a backend. Stop it before launching the isolated device backend.'
} else {
    $portInUse = $false
    try {
        $tcp = [System.Net.Sockets.TcpClient]::new()
        try {
            $attempt = $tcp.BeginConnect('127.0.0.1', 8080, $null, $null)
            if ($attempt.AsyncWaitHandle.WaitOne(800)) {
                $tcp.EndConnect($attempt)
                $portInUse = $true
            }
        } finally {
            $tcp.Close()
        }
    } catch { }
    if ($portInUse) {
        throw 'Port 8080 is in use, but /api/health is not healthy. Check the existing process rather than starting a duplicate backend.'
    }

    # Start backend in a separate PowerShell window, inheriting this process's
    # environment variables (including any existing DB secrets). No credentials
    # or commands containing credentials are embedded in the command line.
    $launchCommand = @'
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath '__BACKEND_DIR__'
$maven = '__MAVEN_CMD__'
Write-Host 'ETF Loans backend: local profile (leave this window open)' -ForegroundColor Cyan
& $maven spring-boot:run '-Dspring-boot.run.profiles=local' '-Dspring-boot.run.arguments=--spring.flyway.enabled=false'
Write-Host 'Spring Boot exited. Review the messages above.' -ForegroundColor Yellow
'@
    $launchCommand = $launchCommand.Replace('__BACKEND_DIR__', $backendDir.Replace("'", "''"))
    $launchCommand = $launchCommand.Replace('__MAVEN_CMD__', $mavenCmd.Replace("'", "''"))
    $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($launchCommand))
    Start-Process -WindowStyle Hidden -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-EncodedCommand', $encodedCommand) -WorkingDirectory $backendDir | Out-Null
    Write-Host '  Started the isolated local Spring Boot process.'
    Write-Host "  Health check once startup completes: $healthUrl"
}

if (-not $SkipPhone) {
    Show-Step 'Connect an Android device via ADB reverse'
    if (-not (Test-Path -LiteralPath $adbExe -PathType Leaf)) {
        Write-Warning "ADB not found at $adbExe. Connect the phone and run ADB reverse manually."
    } else {
        $devices = @(& $adbExe devices)
        if (-not $DeviceSerial) {
            $online = @($devices | Where-Object { $_ -match '^\S+\s+device(?:\s|$)' })
            if ($online.Count -eq 1) { $DeviceSerial = ($online[0] -split '\s+')[0] }
        }
        $deviceReady = ($devices | Where-Object { $_ -match ('^' + [regex]::Escape($DeviceSerial) + '\s+device(?:\s|$)') }).Count -gt 0
        if (-not $deviceReady) {
            Write-Warning 'Select an online device with -DeviceSerial, or connect one device with USB debugging enabled.'
        } else {
            & $adbExe -s $DeviceSerial reverse tcp:8080 tcp:8080
            if ($LASTEXITCODE -eq 0) {
                Write-Host '  USB reverse: phone localhost:8080 -> laptop localhost:8080' -ForegroundColor Green
                & $adbExe -s $DeviceSerial reverse --list
            } else {
                Write-Warning 'ADB reverse failed. Check the USB connection.'
            }
        }
    }
}

Show-Step 'Ready for local testing'
Write-Host '  1. Confirm Spring Boot health on the laptop.'
Write-Host "  2. Open $healthUrl in Chrome on the phone."
Write-Host '  3. Open the already-installed ETF Loans app; send a NEW OTP challenge.'
Write-Host '  4. Use the local development OTP you supplied. Verify HomeScreen and logout.'
Write-Host '  Note: USB reverse must be restored after reconnection or ADB restart.'
