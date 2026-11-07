# Per-user scheduled-task entry point with mutex and local logs.
$ErrorActionPreference = 'Stop'
$mutex = New-Object System.Threading.Mutex($false, 'Local\PSLinkAutoAudioSwitcher_054C_0ECC')
$ownsMutex = $false
try {
    try {
        $ownsMutex = $mutex.WaitOne(0)
    } catch [System.Threading.AbandonedMutexException] {
        $ownsMutex = $true
    }
    if (-not $ownsMutex) { return }
    Start-Sleep -Seconds 12
    $monitor = Join-Path $PSScriptRoot 'PSLink-AutoAudioSwitcher.ps1'
    $configFile = Join-Path $PSScriptRoot 'config.json'
    $log = Join-Path $PSScriptRoot 'last-run.log'
    $previousLog = Join-Path $PSScriptRoot 'previous-run.log'
    if (Test-Path -LiteralPath $log -PathType Leaf) {
        Move-Item -LiteralPath $log -Destination $previousLog -Force
    }
    if (-not (Test-Path -LiteralPath $configFile -PathType Leaf)) {
        throw 'Missing local config.json. Run the installer again.'
    }
    $config = Get-Content -LiteralPath $configFile -Raw -Encoding UTF8 | ConvertFrom-Json
    if ([string]::IsNullOrWhiteSpace([string]$config.HeadsetNameContains) -or
        [string]::IsNullOrWhiteSpace([string]$config.SpeakerNameContains)) {
        throw 'Incomplete device-name configuration.'
    }
    $arguments = @{
        Apply               = $true
        HeadsetNameContains = [string]$config.HeadsetNameContains
        SpeakerNameContains = [string]$config.SpeakerNameContains
    }
    & $monitor @arguments *> $log
} catch {
    Add-Content -LiteralPath (Join-Path $PSScriptRoot 'last-run.log') -Value ('Launch failed: ' + $_.Exception.Message) -Encoding UTF8
    exit 1
} finally {
    if ($ownsMutex) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
}
