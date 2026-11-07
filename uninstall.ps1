# Stop and remove only the scheduled task installed by this project.
# Preserve configuration and log files to avoid deleting user data.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$taskName = 'PSLink AutoAudioSwitcher'
$installDir = Join-Path $env:LOCALAPPDATA 'PSLink-AutoAudioSwitcher'
$vbsPath = Join-Path $installDir 'Start-Hidden.vbs'
$wscript = Join-Path $env:WINDIR 'System32\wscript.exe'
try {
    $task = Get-ScheduledTask -TaskName $taskName -TaskPath '\' -ErrorAction SilentlyContinue
    if ($task) {
        $expected = '//B //Nologo "' + $vbsPath + '"'
        if (@($task.Actions).Count -ne 1 -or
            $task.Actions[0].Execute -ne $wscript -or
            $task.Actions[0].Arguments -ne $expected) {
            throw 'Scheduled task does not match this project. Refusing to remove it.'
        }
        Stop-ScheduledTask -TaskName $taskName -TaskPath '\' -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $taskName -TaskPath '\' -Confirm:$false
        Write-Host 'Scheduled task removed.' -ForegroundColor Green
    } else {
        Write-Host 'No project scheduled task found.'
    }
    if (Test-Path -LiteralPath $installDir) {
        Write-Host "Local files and logs preserved at $installDir"
    }
} catch {
    Write-Error $_.Exception.Message
    exit 1
}
