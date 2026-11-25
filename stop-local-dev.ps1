# Stop only the backend process tree started by this workspace.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\local-dev-tools.ps1"

$lock = Enter-DevLock
try {
    $process = Get-DevBackend
    if (!$process) {
        if (Test-DevPort) { throw 'Port 8080 has a listener outside this launcher. No process was stopped.' }
        Write-Host 'No workspace backend is running.'
        return
    }
    if ($process.ProcessName -ieq 'java') {
        $process.Kill()
        if (!$process.WaitForExit(5000)) { throw 'The recorded backend Java process did not exit.' }
    } else {
        & "$env:SystemRoot\System32\taskkill.exe" /PID $process.Id /T /F | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Could not stop the recorded legacy workspace process tree.' }
    }
    for ($i = 0; $i -lt 10 -and (Test-DevPort); $i++) { Start-Sleep -Milliseconds 300 }
    if (Test-DevPort) { throw 'Port 8080 still has a listener. Inspect it before restarting.' }
    Remove-Item -LiteralPath $DevState
    Write-Host 'Workspace backend stopped.'
} finally { $lock.Dispose() }
