# Exercises the launcher's retry loop with local process and readiness fixtures.
$ErrorActionPreference = 'Stop'
$tokens=$null; $errors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'start-local-dev.ps1'),[ref]$tokens,[ref]$errors)
if ($errors) { throw $errors[0] }
$loop=$ast.Find({param($node) $node -is [System.Management.Automation.Language.ForStatementAst] -and $node.Initializer.Extent.Text -eq '$startup = 1'},$true)
if (!$loop) { throw 'Startup loop missing' }
$loop=[ScriptBlock]::Create($loop.Extent.Text)
$DevData=(New-Item -ItemType Directory -Force (Join-Path $PSScriptRoot ('.local-dev/qa03-startup-logic-' + [guid]::NewGuid().ToString('N')))).FullName
$DevRoot=$DevData; $DevState=Join-Path $DevData 'fixture-state.json'
$startupLog=Join-Path $DevData 'fixture-startup.log'
$childEnv=@{}; $previous=@{}
$protectedOtp='fixture'; $EligibilityScenario='financial-fixture'; $java='fixture'
$backend=$DevData; $pg='Get-FixtureDbReady'; $dbPort=5432
function Get-FixtureDbReady { $global:LASTEXITCODE=0 }
function Test-DevPort { $false }
function Test-DevHealth { !$process.HasExited }
function Start-Process {
  param($WindowStyle,[switch]$PassThru,$FilePath,$ArgumentList,$WorkingDirectory,$RedirectStandardOutput,$RedirectStandardError)
  $script:starts++
  $failed=$script:starts -le $script:failures
  Set-Content -LiteralPath $startupLog -Value $script:logLine
  $p=[pscustomobject]@{HasExited=$failed; ExitCode=1; Id=$script:starts; StartTime=[DateTime]::UtcNow}
  $p | Add-Member -MemberType ScriptMethod -Name WaitForExit -Value {} -PassThru
}
foreach ($case in @(
  @{log='the database system is in recovery mode'; failures=1; starts=2; success=$true},
  @{log='the database system is in recovery mode'; failures=3; starts=3; success=$false},
  @{log='authentication failed for runtime role'; failures=1; starts=1; success=$false}
)) {
  $script:starts=0; $script:failures=$case.failures; $script:logLine=$case.log
  if (Test-Path -LiteralPath $DevState) { Remove-Item -LiteralPath $DevState }
  $deadline=[DateTime]::UtcNow.AddSeconds(10)
  $ok=$false; $failure=$null
  try { . $loop; $ok=$true } catch { $failure=$_.Exception.Message }
  if ($ok -ne $case.success -or $script:starts -ne $case.starts) {
    throw "Unexpected outcome starts=$script:starts success=$ok failure=$failure"
  }
  if ($ok -ne (Test-Path -LiteralPath $DevState)) { throw 'Unexpected process-state persistence' }
}
Write-Output 'PASS startup recovery retry, three-attempt ceiling, and fail-fast nonrecovery cases.'
