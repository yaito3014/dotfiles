# Run dotfiles-sync now, whenever the self-hosted runner writes the trigger
# file, and at least every 5 minutes. The dotfiles-sync scheduled task that
# install.ps1 registers starts this at logon.
param(
    [Parameter(Mandatory)] [string] $Bash
)
# Keep looping through failures; each one is in the log.
$ErrorActionPreference = 'Continue'

$TriggerDir = Join-Path $env:ProgramData 'dotfiles-sync'
$Sync = (Join-Path $HOME '.local\bin\dotfiles-sync') -replace '\\', '/'
$Log = Join-Path $HOME '.local\state\dotfiles\sync.log'
New-Item -ItemType Directory -Force (Split-Path $Log) | Out-Null

# Without the runner there is no trigger directory, only the 5-minute poll.
$Watcher = $null
if (Test-Path $TriggerDir) {
    $Watcher = New-Object IO.FileSystemWatcher $TriggerDir, 'trigger'
}

while ($true) {
    if ((Test-Path $Log) -and (Get-Item $Log).Length -gt 1MB) {
        Move-Item -Force $Log "$Log.old"
    }
    # Each run is a new process, so an update to dotfiles-sync takes effect on
    # the next run; an update to this script takes effect at the next logon.
    $Output = & $Bash $Sync 2>&1 | ForEach-Object { "$_" }
    Add-Content -Encoding UTF8 -Path $Log -Value (
        @("$(Get-Date -Format o) exit $LASTEXITCODE") + @($Output))
    if ($Watcher) {
        $null = $Watcher.WaitForChanged([IO.WatcherChangeTypes]::All, 300000)
    } else {
        Start-Sleep -Seconds 300
    }
}
