# Shared helpers for the Windows development scripts.
$script:DevRoot = $PSScriptRoot
$script:DevData = Join-Path $DevRoot '.local-dev'
$script:DevState = Join-Path $DevData 'backend.json'
$script:DevHealth = 'http://127.0.0.1:8080/api/health'
$script:DevPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'

function Enter-DevLock {
    New-Item -ItemType Directory -Path $DevData -Force | Out-Null
    try {
        [IO.File]::Open((Join-Path $DevData 'backend.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
    } catch {
        throw 'Another workspace backend start or stop is in progress. Retry when it finishes.'
    }
}

function Resolve-DevTool([string]$Path, [string]$Command, [string[]]$Fallbacks) {
    if ($Path) {
        if (Test-Path -LiteralPath $Path -PathType Leaf) { return (Resolve-Path -LiteralPath $Path).Path }
        throw "Invalid path for $Command. Check the script parameter."
    }
    foreach ($candidate in $Fallbacks) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) { return $candidate }
    }
    $tool = Get-Command $Command -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($tool) { return $tool.Source }
    throw "Cannot find $Command. Add it to PATH or supply its script parameter."
}

function Get-DevAdb([string]$Path) {
    $sdk = $env:ANDROID_HOME
    if (!$sdk) { $sdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
    Resolve-DevTool $Path 'adb.exe' @((Join-Path $sdk 'platform-tools\adb.exe'))
}

function Get-DevDevice([string]$AdbPath, [string]$Serial) {
    $lines = @(& $AdbPath devices)
    if ($LASTEXITCODE -ne 0) { throw 'ADB device listing failed. Check the Android SDK and USB connection.' }
    $online = @($lines | ForEach-Object {
        if ($_ -match '^(?!emulator-)(\S+)\s+device(?:\s|$)') { $Matches[1] }
    })
    if ($Serial -and $online -contains $Serial) { return $Serial }
    if (!$Serial -and $online.Count -eq 1) { return $online[0] }
    throw 'Connect and unlock one physical Android device, accept USB debugging, or specify its online serial with -DeviceSerial.'
}

function Set-DevReverse([string]$AdbPath, [string]$Serial) {
    & $AdbPath -s $Serial reverse tcp:8080 tcp:8080
    if ($LASTEXITCODE -ne 0) { throw 'ADB reverse failed. Check USB debugging and reconnect the device.' }
}

function Get-DevBackend {
    if (!(Test-Path -LiteralPath $DevState)) { return }
    $state = Get-Content -LiteralPath $DevState -Raw | ConvertFrom-Json
    if ($state.workspace -cne $DevRoot) { throw 'Backend state belongs to another workspace.' }
    $process = Get-Process -Id ([int]$state.pid) -ErrorAction SilentlyContinue
    # Old launcher records have no executable field and refer to its PowerShell supervisor.
    $expected = if ($state.executable) { $state.executable } else { $DevPowerShell }
    if (!$process -or $process.StartTime.ToUniversalTime().Ticks.ToString() -cne $state.started) {
        Remove-Item -LiteralPath $DevState
        return
    }
    if (!$process.Path -or $process.Path -ine $expected -or
        ($state.executable -and [IO.Path]::GetFileName($expected) -ine 'java.exe')) {
        throw 'The recorded live process could not be verified. No process was started or stopped.'
    }
    $process
}

function Get-DevBackendJar([string]$BackendDirectory, [string]$Maven) {
    $pomPath = Join-Path $BackendDirectory 'pom.xml'
    [xml]$pom = Get-Content -LiteralPath $pomPath -Raw
    $jarPath = Join-Path $BackendDirectory "target\$($pom.project.artifactId)-$($pom.project.version).jar"
    $stampPath = Join-Path $DevData 'backend-build.json'
    $sources = @(Get-Item -LiteralPath $pomPath) + @(Get-ChildItem -LiteralPath (Join-Path $BackendDirectory 'src\main') -File -Recurse)
    $fingerprint = ($sources | Sort-Object FullName | ForEach-Object {
        "$($_.FullName) $((Get-FileHash -LiteralPath $_.FullName).Hash)"
    }) -join "`n"
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $sourceHash = [Convert]::ToBase64String($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($fingerprint))) }
    finally { $sha.Dispose() }
    if ((Test-Path -LiteralPath $stampPath) -and (Test-Path -LiteralPath $jarPath)) {
        $stamp = Get-Content -LiteralPath $stampPath -Raw | ConvertFrom-Json
        if ($stamp.source -ceq $sourceHash -and $stamp.jar -ceq (Get-FileHash -LiteralPath $jarPath).Hash) {
            return $jarPath
        }
    }

    $log = Join-Path $DevData 'backend-build.log'
    Write-Host 'Packaging the current backend sources with Maven.'
    Push-Location -LiteralPath $BackendDirectory
    $savedPath = $env:PATH
    try {
        if ([IO.Path]::GetFileName($Maven) -ine 'mvn.cmd') {
            throw 'The Maven path must point to the installed mvn.cmd.'
        }
        $env:PATH = "$(Split-Path -Parent $Maven);$savedPath"
        for ($attempt = 1; $attempt -le 2; $attempt++) {
            & $env:ComSpec /d /c ('mvn.cmd -o -B -Dmaven.test.skip=true package > "' + $log + '" 2>&1')
            $exit = $LASTEXITCODE
            if ($exit -eq 0) { break }
            if ($attempt -eq 2 -or ((Test-Path -LiteralPath $log) -and
                (Select-String -LiteralPath $log -Pattern 'BUILD FAILURE' -Quiet))) {
                throw "Backend packaging failed (exit $exit). Check $log and the installed Maven cache."
            }
            Write-Warning 'The Maven subprocess failed to start. Retrying once.'
        }
    } finally {
        $env:PATH = $savedPath
        Pop-Location
    }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($jarPath)
    try {
        if (!$archive.GetEntry('BOOT-INF/classes/com/etfloans/backend/EtfLoansBackendApplication.class') -or
            !$archive.GetEntry('org/springframework/boot/loader/launch/JarLauncher.class')) {
            throw 'Maven output is not an executable ETF Loans Spring Boot JAR.'
        }
    } finally { $archive.Dispose() }
    @{source=$sourceHash; jar=(Get-FileHash -LiteralPath $jarPath).Hash} |
        ConvertTo-Json | Set-Content -LiteralPath $stampPath
    $jarPath
}

function Test-DevHealth {
    try { (Invoke-RestMethod $DevHealth -TimeoutSec 2).status -eq 'up' } catch { $false }
}

function Test-DevPort {
    $client = [Net.Sockets.TcpClient]::new()
    try {
        $connection = $client.BeginConnect('127.0.0.1', 8080, $null, $null)
        if (!$connection.AsyncWaitHandle.WaitOne(500)) { return $false }
        $client.EndConnect($connection)
        $true
    } catch { $false } finally { $client.Dispose() }
}
