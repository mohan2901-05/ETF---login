# Build the ARM64 debug APK or install an existing device build.
[CmdletBinding()]
param(
    [switch]$InstallOnly,
    [switch]$SkipInstall,
    [string]$DeviceSerial,
    [string]$ApkPath,
    [string]$Flutter,
    [string]$Adb,
    [string]$Jdk
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\local-dev-tools.ps1"
$project = Join-Path $DevRoot 'etf-loans-flutter'
if ($ApkPath -and !$InstallOnly) { throw 'Use -ApkPath together with -InstallOnly.' }
if (!$ApkPath) { $ApkPath = Join-Path $project 'build\app\outputs\flutter-apk\app-debug.apk' }
if (!$InstallOnly) {
    $flutterCmd = Resolve-DevTool $Flutter 'flutter.bat' @()
    if ((Split-Path -Leaf $flutterCmd) -ine 'flutter.bat') {
        throw 'Supply the installed SDK bin\flutter.bat with -Flutter.'
    }
    if (!$Jdk) {
        $studioJdk = Join-Path $env:ProgramFiles 'Android\Android Studio\jbr'
        $Jdk = if (Test-Path -LiteralPath (Join-Path $studioJdk 'bin\java.exe')) { $studioJdk } else { $env:JAVA_HOME }
    }
    if (!$Jdk -or !(Test-Path -LiteralPath (Join-Path $Jdk 'bin\java.exe'))) {
        throw 'Supply a compatible JDK with -Jdk or set JAVA_HOME.'
    }
    New-Item -ItemType Directory -Path $DevData -Force | Out-Null
    $log = Join-Path $DevData 'apk-build.log'
    $settings = @{
        JAVA_HOME = $Jdk
        GRADLE_OPTS = ('-Dorg.gradle.daemon=false -Dorg.gradle.workers.max=1 -Dorg.gradle.jvmargs=-Xmx3072m "-Dorg.gradle.java.home={0}"' -f $Jdk)
        'ORG_GRADLE_PROJECT_android.injected.build.abi' = 'arm64-v8a'
    }
    $cachedEngine = Join-Path (Split-Path -Parent $flutterCmd) 'cache\engine-dart-sdk.stamp'
    if (Test-Path -LiteralPath $cachedEngine) {
        $settings.FLUTTER_PREBUILT_ENGINE_VERSION = (Get-Content -LiteralPath $cachedEngine -Raw).Trim()
    }
    $settings.PATH = (@((Split-Path -Parent $flutterCmd), "$env:SystemRoot\System32", "$env:SystemRoot\System32\WindowsPowerShell\v1.0",
        (Join-Path $env:ProgramFiles 'Git\ucrt64\bin'), (Join-Path $Jdk 'bin'), $env:PATH) -join ';')
    $previous = @{}
    Push-Location -LiteralPath $project
    try {
        foreach ($name in $settings.Keys) {
            $previous[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
            [Environment]::SetEnvironmentVariable($name, $settings[$name], 'Process')
        }
        # Start the selected SDK by name through PATH. CMD only needs quotes around the log path.
        $verbosity = if ($PSBoundParameters['Verbose']) { '--verbose ' } else { '' }
        $command = 'flutter.bat --no-version-check {0}build apk --debug --no-pub --target-platform=android-arm64 --dart-define=API_BASE_URL=http://127.0.0.1:8080 > "{1}" 2>&1' -f $verbosity, $log
        for ($attempt = 1; $attempt -le 2; $attempt++) {
            & $env:ComSpec /d /c $command
            $buildExit = $LASTEXITCODE
            if ($buildExit -eq 0) { break }
            $launcherFailed = (Test-Path -LiteralPath $log) -and
                (Select-String -LiteralPath $log -Pattern 'Unable to determine engine version|PowerShell executable not found|A problem occurred starting process .*flutter\.bat|flutter\.bat.*(-1073741819|0xC0000005)' -Quiet)
            if (!$launcherFailed -or $attempt -eq 2) { throw "ARM64 build failed (exit $buildExit). See $log." }
            Copy-Item -LiteralPath $log -Destination (Join-Path $DevData 'apk-build-first-attempt.log') -Force
            Write-Warning 'A Flutter launch failed. Retrying once with a fresh Gradle process.'
        }
    } finally {
        Pop-Location
        foreach ($name in $previous.Keys) { [Environment]::SetEnvironmentVariable($name, $previous[$name], 'Process') }
    }
}
if (!(Test-Path -LiteralPath $ApkPath -PathType Leaf)) { throw "APK not found: $ApkPath" }
$ApkPath = (Resolve-Path -LiteralPath $ApkPath).Path
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($ApkPath)
try {
    if (!$archive.GetEntry('lib/arm64-v8a/libflutter.so')) { throw 'The selected APK has no ARM64 Flutter engine.' }
} finally { $archive.Dispose() }
Write-Host "ARM64 APK: $ApkPath"
if (!$SkipInstall) {
    $adbPath = Get-DevAdb $Adb
    $serial = Get-DevDevice $adbPath $DeviceSerial
    Set-DevReverse $adbPath $serial
    & $adbPath -s $serial install -r $ApkPath
    if ($LASTEXITCODE -ne 0) { throw 'ADB install failed. Check the device prompt and keep the existing app data intact.' }
}
