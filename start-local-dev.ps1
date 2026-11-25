# Start the isolated synthetic Windows backend and connect a physical phone.
[CmdletBinding()]
param(
    [string]$DeviceSerial,
    [string]$MockOtpCode,
    [string]$Maven,
    [string]$Adb,
    [string]$PgIsReady,
    [string]$Credentials,
    [ValidateRange(1, 3600)][int]$CooldownSeconds = 10,
    [ValidateRange(5, 300)][int]$StartupTimeoutSeconds = 75,
    [switch]$SkipPhone,
    [switch]$HideOtp,
    [switch]$SyntheticAccountsOnly
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\local-dev-tools.ps1"

$lock = Enter-DevLock
try {
    $process = Get-DevBackend
    if ($process) {
        if ($process.ProcessName -ine 'java') { throw 'Stop the tracked legacy backend, then run start again.' }
        if (!(Test-DevHealth)) {
            throw "The workspace backend is running but unhealthy. Check $DevData\backend.err.log and backend.out.log before stopping it."
        }
        Write-Host 'Reusing the healthy workspace backend.'
        if (!$HideOtp) {
            $state = Get-Content -LiteralPath $DevState -Raw | ConvertFrom-Json
            if ($state.mockOtp) {
                $otp = ConvertTo-SecureString -String $state.mockOtp
                Write-Host "Synthetic development OTP for this session: $([Net.NetworkCredential]::new('', $otp).Password)"
            }
        }
    } else {
        if (Test-DevPort) { throw 'Port 8080 is occupied by a process outside this launcher. Identify it before retrying.' }
        if (!$Credentials) { $Credentials = Join-Path $DevData 'device.local.clixml' }
        if (!(Test-Path -LiteralPath $Credentials -PathType Leaf)) {
            throw 'Encrypted device credentials are missing. Copy the existing device.local.clixml into .local-dev under this Windows account.'
        }
        try {
            $device = Import-Clixml -LiteralPath $Credentials
            if ($device.password -isnot [Security.SecureString] -or $device.key -isnot [Security.SecureString]) {
                throw 'Expected DPAPI-protected credentials.'
            }
            $password = [Net.NetworkCredential]::new('', $device.password).Password
            $key = [Net.NetworkCredential]::new('', $device.key).Password
        } catch {
            throw 'Could not decrypt device credentials. Use the same Windows account and computer that exported the file.'
        }
        if ($device.url -notmatch '^jdbc:postgresql://127\.0\.0\.1:([0-9]{1,5})/etf_loans_device$') {
            throw 'The encrypted configuration must target etf_loans_device on IPv4 loopback.'
        }
        $dbPort = [int]$Matches[1]
        if ($dbPort -lt 1 -or $dbPort -gt 65535 -or !$device.username -or !$password -or
            $key.Length -lt 32 -or $key -ceq $env:ETF_OTP_KEY) {
            throw 'The isolated database credentials or separate development key are invalid.'
        }
        $pg = Resolve-DevTool $PgIsReady 'pg_isready.exe' @((Join-Path $env:ProgramFiles 'PostgreSQL\18\bin\pg_isready.exe'))
        & $pg -q -h 127.0.0.1 -p $dbPort -t 2
        if ($LASTEXITCODE -ne 0) { throw "Isolated PostgreSQL is unavailable on loopback port $dbPort. Check that the installed PostgreSQL Windows service is running." }
        $mavenHome = if ($env:MAVEN_HOME) { Join-Path $env:MAVEN_HOME 'bin\mvn.cmd' }
        $mvn = Resolve-DevTool $Maven 'mvn.cmd' @($mavenHome, (Join-Path $env:LOCALAPPDATA 'Programs\apache-maven-3.9.6\bin\mvn.cmd'))
        if (!$MockOtpCode) { $MockOtpCode = [string](Get-Random -Minimum 100000 -Maximum 1000000) }
        if ($MockOtpCode -cnotmatch '^[0-9]{6}$') { throw 'The local development OTP must contain six digits.' }
        $javaHome = if ($env:JAVA_HOME) { Join-Path $env:JAVA_HOME 'bin\java.exe' }
        $java = Resolve-DevTool $javaHome 'java.exe' @()
        $backend = Join-Path $DevRoot 'etf-loans-backend'
        $jar = Get-DevBackendJar $backend $mvn

        $childEnv = @{
            ETF_DEVICE_DB_URL = $device.url; ETF_DEVICE_DB_USERNAME = $device.username
            ETF_DEVICE_DB_PASSWORD = $password; ETF_DEV_OTP_KEY = $key
            ETF_OTP_MOCK_CODE = $MockOtpCode; ETF_LOCAL_OTP_COOLDOWN_SECONDS = [string]$CooldownSeconds
            CORS_ALLOWED_ORIGINS = 'http://127.0.0.1:8080'
            SPRING_DATASOURCE_URL = $null; SPRING_DATASOURCE_USERNAME = $null; SPRING_DATASOURCE_PASSWORD = $null
        }
        $previous = @{}
        $arguments = @('-jar', ('"' + $jar + '"'), '--spring.profiles.active=local',
            '--server.address=127.0.0.1', '--server.port=8080',
            '--spring.flyway.enabled=false', '--spring.jpa.hibernate.ddl-auto=validate',
            '--etf.otp.mock-enabled=true', '--etf.demo.enabled=false')
        try {
            foreach ($name in $childEnv.Keys) {
                $previous[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
                [Environment]::SetEnvironmentVariable($name, $childEnv[$name], 'Process')
            }
            if (Test-DevPort) { throw 'Port 8080 was occupied during packaging. No backend was launched.' }
            for ($attempt = 1; $attempt -le 2; $attempt++) {
                try {
                    $process = Start-Process -WindowStyle Hidden -PassThru -FilePath $java `
                        -ArgumentList $arguments -WorkingDirectory $backend `
                        -RedirectStandardOutput (Join-Path $DevData 'backend.out.log') `
                        -RedirectStandardError (Join-Path $DevData 'backend.err.log')
                    break
                } catch {
                    if ($attempt -eq 2 -or (Test-DevPort)) { throw }
                    Write-Warning 'Windows could not start the Java process. Retrying once.'
                }
            }
        } finally {
            foreach ($name in $previous.Keys) {
                [Environment]::SetEnvironmentVariable($name, $previous[$name], 'Process')
            }
        }
        if ($process.HasExited) { throw "Backend exited during launch. Check $DevData\backend.err.log and backend.out.log." }
        $protectedOtp = ConvertFrom-SecureString (ConvertTo-SecureString $MockOtpCode -AsPlainText -Force)
        @{workspace=$DevRoot; pid=$process.Id; executable=$java; started=$process.StartTime.ToUniversalTime().Ticks.ToString(); mockOtp=$protectedOtp} |
            ConvertTo-Json | Set-Content -LiteralPath $DevState
        $deadline = [DateTime]::UtcNow.AddSeconds($StartupTimeoutSeconds)
        $healthy = $false
        do {
            if ($process.HasExited) { break }
            if (Test-DevHealth) { $healthy = $true; break }
            Start-Sleep -Seconds 1
        } while ([DateTime]::UtcNow -lt $deadline)
        if (!$healthy) {
            if ($process.HasExited) {
                $process.WaitForExit()
                Remove-Item -LiteralPath $DevState
                $startupLog = Join-Path $DevData 'backend.out.log'
                if (Select-String -LiteralPath $startupLog -Pattern 'the database system is in recovery mode' -Quiet) {
                    throw "PostgreSQL entered recovery during backend startup. Wait until it accepts connections and retry. See $startupLog."
                }
                $reason = 'exited before health was available'
                if ($null -ne $process.ExitCode) { $reason += " (exit $($process.ExitCode))" }
            } else { $reason = 'did not become healthy before the timeout' }
            throw "Workspace backend $reason. Inspect $DevData\backend.err.log and backend.out.log. Use stop-local-dev.ps1 before retrying a running process."
        }
        Write-Host "Workspace backend is healthy. Local OTP cooldown: $CooldownSeconds seconds."
        if (!$HideOtp) { Write-Host "Synthetic development OTP for this session: $MockOtpCode" }
    }
    if (!$SkipPhone) {
        try {
            $adbPath = Get-DevAdb $Adb
            $serial = Get-DevDevice $adbPath $DeviceSerial
            Set-DevReverse $adbPath $serial
            Write-Host "ADB reverse is ready for $serial."
        } catch { Write-Warning $_.Exception.Message }
    }
} finally { $lock.Dispose() }
