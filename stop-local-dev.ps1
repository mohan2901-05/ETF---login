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
    Stop-DevBackend $process
    Write-Host 'Workspace backend stopped.'
} finally { $lock.Dispose() }
