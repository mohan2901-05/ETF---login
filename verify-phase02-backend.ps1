[CmdletBinding()]
param(
    [string]$PostgresBin = (Join-Path $env:ProgramFiles 'PostgreSQL\18\bin'),
    [string]$Maven = "$env:LOCALAPPDATA\Programs\apache-maven-3.9.6\bin\mvn.cmd",
    [string]$EvidenceDirectory
)

$ErrorActionPreference = 'Stop'
if (-not $EvidenceDirectory) { $EvidenceDirectory = Join-Path $PSScriptRoot 'phase02-verification' }
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('etf-phase02-' + [guid]::NewGuid().ToString('N'))
$evidence = (New-Item -ItemType Directory -Path $EvidenceDirectory -Force).FullName
$backend = New-Item -ItemType Directory -Path (Join-Path $scratch 'backend') -Force
$data = Join-Path $scratch 'postgres'
$user = 'etf_phase02'
$password = [guid]::NewGuid().ToString('N')
$started = $false
$variables = @('SPRING_DATASOURCE_URL', 'SPRING_DATASOURCE_USERNAME', 'SPRING_DATASOURCE_PASSWORD',
    'SPRING_DATASOURCE_DRIVER_CLASS_NAME', 'SPRING_JPA_PROPERTIES_HIBERNATE_DIALECT',
    'SPRING_JPA_HIBERNATE_DDL_AUTO', 'SPRING_FLYWAY_ENABLED', 'SPRING_FLYWAY_URL',
    'SPRING_FLYWAY_USER', 'SPRING_FLYWAY_PASSWORD', 'ETF_PHASE02_POSTGRES', 'PGPASSWORD')
$saved = @{}
foreach ($name in $variables) {
    $saved[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
    [Environment]::SetEnvironmentVariable($name, $null, 'Process')
}

function Invoke-Native([string]$program, [string[]]$arguments, [string]$log) {
    $processInfo = [Diagnostics.ProcessStartInfo]::new()
    $processInfo.FileName = $program
    $processInfo.Arguments = ($arguments | ForEach-Object { '"' + $_ + '"' }) -join ' '
    if ($program.EndsWith('.cmd')) {
        $processInfo.FileName = $env:ComSpec
        $processInfo.Arguments = '/d /s /c ""' + $program + '" ' + $processInfo.Arguments + '"'
    }
    $processInfo.WorkingDirectory = (Get-Location).Path
    $processInfo.UseShellExecute = $false
    $processInfo.CreateNoWindow = $true
    $processInfo.RedirectStandardOutput = $true
    $processInfo.RedirectStandardError = $true
    $process = [Diagnostics.Process]::Start($processInfo)
    $output = $process.StandardOutput.ReadToEndAsync()
    $errors = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    [IO.File]::WriteAllText($log, $output.Result + $errors.Result)
    return $process.ExitCode
}

function Require-Native([string]$program, [string[]]$arguments, [string]$log) {
    if ((Invoke-Native $program $arguments $log) -ne 0) {
        throw "Command failed. See $log"
    }
}

function Run-Suite([string]$engine) {
    $reports = (New-Item -ItemType Directory -Path (Join-Path $evidence $engine) -Force).FullName
    Push-Location $backend.FullName
    try {
        $log = Join-Path $reports 'maven.log'
        $exitCode = Invoke-Native $Maven @('-o', '-B', "-Dsurefire.reportsDirectory=$reports", 'test') $log
        if (Test-Path -LiteralPath 'target/surefire-reports') {
            Copy-Item -Path 'target/surefire-reports/*' -Destination $reports -Force
        }
        if ($exitCode -eq 0 -and -not (Select-String -LiteralPath $log -Pattern 'Tests run:' -Quiet)) {
            $exitCode = 1
        }
        Set-Content -LiteralPath (Join-Path $reports 'exit-code.txt') -Value $exitCode
        Write-Host "$engine Maven exit: $exitCode"
        return $exitCode
    } finally {
        Pop-Location
    }
}

try {
    foreach ($path in @('pom.xml', 'src')) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot "etf-loans-backend\$path") -Destination $backend.FullName -Recurse
    }
    $h2 = Run-Suite 'h2'
    $socket = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
    $socket.Start()
    $port = $socket.LocalEndpoint.Port
    $socket.Stop()
    $passwordFile = Join-Path $scratch 'init-password.txt'
    Set-Content -LiteralPath $passwordFile -Value $password -Encoding ASCII
    Require-Native (Join-Path $PostgresBin 'initdb.exe') @('-D', $data, '-U', $user,
        '--auth=scram-sha-256', "--pwfile=$passwordFile", '--locale=C', '--encoding=UTF8') (Join-Path $evidence 'postgres-init.log')
    Remove-Item -LiteralPath $passwordFile
    Require-Native (Join-Path $PostgresBin 'pg_ctl.exe') @('-D', $data, '-l',
        (Join-Path $evidence 'postgres-server.log'), '-o', "-h 127.0.0.1 -p $port", '-w', 'start') (Join-Path $evidence 'postgres-start.log')
    $started = $true
    $env:PGPASSWORD = $password
    $psql = Join-Path $PostgresBin 'psql.exe'
    $connection = @('-X', '-w', '-h', '127.0.0.1', '-p', "$port", '-U', $user, '-v', 'ON_ERROR_STOP=1')
    foreach ($database in @('etf_phase02_suite', 'etf_phase02_migration')) {
        Require-Native $psql ($connection + @('-d', 'postgres', '-c', "create database $database")) (Join-Path $evidence "$database-setup.log")
    }
    Require-Native $psql ($connection + @('-d', 'etf_phase02_suite', '-At', '-c',
        "select current_database(), current_setting('server_version'), inet_server_addr(), inet_server_port()")) (Join-Path $evidence 'postgres-effective-database.txt')
    $env:SPRING_DATASOURCE_URL = "jdbc:postgresql://127.0.0.1:$port/etf_phase02_suite"
    $env:SPRING_DATASOURCE_USERNAME = $user
    $env:SPRING_DATASOURCE_PASSWORD = $password
    $env:SPRING_DATASOURCE_DRIVER_CLASS_NAME = 'org.postgresql.Driver'
    $env:SPRING_JPA_PROPERTIES_HIBERNATE_DIALECT = 'org.hibernate.dialect.PostgreSQLDialect'
    $env:SPRING_JPA_HIBERNATE_DDL_AUTO = 'validate'
    $env:SPRING_FLYWAY_ENABLED = 'true'
    $env:ETF_PHASE02_POSTGRES = 'true'
    $postgres = Run-Suite 'postgresql'
    if ($h2 -ne 0 -or $postgres -ne 0) {
        throw 'At least one backend suite failed. See the saved Maven and Surefire reports.'
    }
} finally {
    if ($started) {
        $stopped = (Invoke-Native (Join-Path $PostgresBin 'pg_ctl.exe') @('-D', $data, '-m', 'fast', '-w', 'stop') (Join-Path $evidence 'postgres-stop.log')) -eq 0
    } else {
        $stopped = $true
    }
    foreach ($name in $variables) {
        [Environment]::SetEnvironmentVariable($name, $saved[$name], 'Process')
    }
    $scratchRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if ($stopped -and (Test-Path -LiteralPath $scratch) -and
        (Resolve-Path -LiteralPath $scratch).Path.StartsWith($scratchRoot + 'etf-phase02-', [StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $scratch -Recurse -Force
    }
}
