# Per-user installer. No elevation, drivers, services or network calls.
[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()][string]$HeadsetNameContains = 'PlayStation Link Adapter',
    [ValidateNotNullOrEmpty()][string]$SpeakerNameContains = 'Realtek'
)
$ErrorActionPreference = 'Stop'
$taskName = 'PSLink AutoAudioSwitcher'
$oldTaskName = 'PSLink Audio Automatik'
$installDir = Join-Path $env:LOCALAPPDATA 'PSLink-AutoAudioSwitcher'
$wscript = Join-Path $env:WINDIR 'System32\wscript.exe'
$srcDir = Join-Path $PSScriptRoot 'src'
$vbsPath = Join-Path $installDir 'Start-Hidden.vbs'

function Assert-NoReparsePoint {
    param([string]$Folder)
    if (Test-Path -LiteralPath $Folder) {
        $item = Get-Item -LiteralPath $Folder -Force
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw 'Installation folder is a symlink or junction. Refusing to overwrite it.'
        }
    }
}
function Find-PlaybackEndpoint {
    param([string]$NameContains)
    if ([string]::IsNullOrWhiteSpace($NameContains)) { throw 'Audio name cannot be blank.' }
    $found = @(Get-PnpDevice -Class AudioEndpoint -PresentOnly -ErrorAction Stop |
        Where-Object {
            $_.InstanceId -match '^SWD\\MMDEVAPI\\\{0\.0\.0\.00000000\}\.\{[A-Fa-f0-9-]+\}$' -and
            $_.FriendlyName.IndexOf($NameContains, [StringComparison]::OrdinalIgnoreCase) -ge 0
        })
    if ($found.Count -ne 1) {
        throw "Expected exactly one playback endpoint containing '$NameContains'; found $($found.Count)."
    }
    return $found[0]
}

try {
    if (-not [Environment]::Is64BitOperatingSystem -or -not [Environment]::Is64BitProcess) {
        throw 'Use 64-bit Windows PowerShell 5.1.'
    }
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Run from a normal non-elevated PowerShell window.'
    }
    if (-not (Test-Path -LiteralPath $wscript -PathType Leaf)) {
        throw 'Windows Script Host (wscript.exe) is unavailable.'
    }
    foreach ($file in @('PSLink-AutoAudioSwitcher.ps1', 'Launch.ps1', 'Start-Hidden.vbs')) {
        if (-not (Test-Path -LiteralPath (Join-Path $srcDir $file) -PathType Leaf)) {
            throw "Missing source file: src/$file. Download the complete repository."
        }
    }
    $legacy = Get-ScheduledTask -TaskName $oldTaskName -TaskPath '\' -ErrorAction SilentlyContinue
    if ($legacy -and $legacy.State -ne 'Disabled') {
        throw "An enabled legacy task '$oldTaskName' exists. Stop and disable it first; this installer will not change it."
    }
    $headset = Find-PlaybackEndpoint -NameContains $HeadsetNameContains
    $speaker = Find-PlaybackEndpoint -NameContains $SpeakerNameContains
    if ($headset.InstanceId -eq $speaker.InstanceId) { throw 'Both names select the same device.' }
    if ($headset.Status -ne 'OK' -or $speaker.Status -ne 'OK') { throw 'Selected playback device is not ready.' }

    Assert-NoReparsePoint -Folder $installDir
    $existing = Get-ScheduledTask -TaskName $taskName -TaskPath '\' -ErrorAction SilentlyContinue
    if ($existing) {
        $expected = '//B //Nologo "' + $vbsPath + '"'
        if (@($existing.Actions).Count -ne 1 -or
            $existing.Actions[0].Execute -ne $wscript -or
            $existing.Actions[0].Arguments -ne $expected) {
            throw 'A different task uses this name. Refusing to replace it.'
        }
        Stop-ScheduledTask -TaskName $taskName -TaskPath '\' -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
    Assert-NoReparsePoint -Folder $installDir
    foreach ($file in @('PSLink-AutoAudioSwitcher.ps1', 'Launch.ps1', 'Start-Hidden.vbs')) {
        Copy-Item -LiteralPath (Join-Path $srcDir $file) -Destination (Join-Path $installDir $file) -Force
    }
    @{
        HeadsetNameContains = $HeadsetNameContains
        SpeakerNameContains = $SpeakerNameContains
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $installDir 'config.json') -Encoding UTF8

    $action = New-ScheduledTaskAction -Execute $wscript -Argument ('//B //Nologo "' + $vbsPath + '"') -WorkingDirectory $installDir
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $identity.Name
    $taskPrincipal = New-ScheduledTaskPrincipal -UserId $identity.Name -LogonType Interactive -RunLevel Limited
    $settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    Register-ScheduledTask -TaskName $taskName -TaskPath '\' -Action $action -Trigger $trigger -Principal $taskPrincipal -Settings $settings -Description 'Automatically select PS Link playback or user-selected speakers.' -Force | Out-Null
    Start-ScheduledTask -TaskName $taskName -TaskPath '\'
    Write-Host 'PSLink AutoAudioSwitcher installed. Test again after a reboot.' -ForegroundColor Green
    Write-Host "Headset: $($headset.FriendlyName)"
    Write-Host "Speakers: $($speaker.FriendlyName)"
    Write-Host "Task: $taskName"
    Write-Host "Local log: $(Join-Path $installDir 'last-run.log')"
} catch {
    Write-Error $_.Exception.Message
    exit 1
}
