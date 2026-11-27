# Set up the dotfiles on Windows, or bring an existing setup up to date. Safe
# to re-run.
#
#   irm https://raw.githubusercontent.com/yaito3014/dotfiles/main/install.ps1 | iex
#
# Run it from an elevated PowerShell unless DOTFILES_RUNNER is 0: installing
# the runner service and granting it the trigger directory need administrator
# rights.
#
#   DOTFILES_DIR      clone chezmoi applies from (default: ~\.local\share\dotfiles)
#   DOTFILES_RUNNER   set to 0 to skip the self-hosted runner
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$RepoUrl = 'https://github.com/yaito3014/dotfiles.git'
$Dir = if ($env:DOTFILES_DIR) { $env:DOTFILES_DIR } else { Join-Path $HOME '.local\share\dotfiles' }
$UseRunner = $env:DOTFILES_RUNNER -ne '0'
$RunnerRepo = 'yaito3014/ops'
$RunnerDir = 'C:\actions-runner'
$TriggerDir = Join-Path $env:ProgramData 'dotfiles-sync'
$Bin = Join-Path $HOME '.local\bin'
$TaskName = 'dotfiles-sync'
$PowerShell = (Get-Process -Id $PID).Path

function Write-Step([string] $Message) {
    Write-Host "==> $Message"
}

# Fail on a native command's exit code, which $ErrorActionPreference ignores.
function Invoke-Native([scriptblock] $Command) {
    & $Command
    if ($LASTEXITCODE -ne 0) { throw "failed with exit code ${LASTEXITCODE}: $Command" }
}

# winget changes the persistent PATH only, so reload it into this session.
function Update-SessionPath {
    $env:Path = @(
        $Bin
        [Environment]::GetEnvironmentVariable('Path', 'User')
        [Environment]::GetEnvironmentVariable('Path', 'Machine')
    ) -join ';'
}

function Install-Package([string] $Command, [string] $Id) {
    if (Get-Command $Command -ErrorAction SilentlyContinue) { return }
    Write-Step "installing $Id"
    Invoke-Native {
        winget install --exact --id $Id --source winget --silent `
            --accept-package-agreements --accept-source-agreements --disable-interactivity
    }
    Update-SessionPath
}

# Stage 1, e.g. when piped into iex: make sure the clone exists and is
# current, then continue with the clone's own copy of this script. Returns
# rather than exits, which would close the window under iex.
function Invoke-Bootstrap {
    Install-Package git Git.Git
    if (Test-Path $Dir) {
        Write-Step "updating $Dir"
        Invoke-Native { git -C $Dir pull --quiet --ff-only }
    } else {
        Write-Step "cloning into $Dir"
        Invoke-Native { git clone --quiet $RepoUrl $Dir }
    }
    Invoke-Native { & $PowerShell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Dir 'install.ps1') }
}

# Git Bash, not the bash.exe in System32, which starts WSL.
function Get-GitBash {
    $Git = (Get-Command git).Source
    $Bash = Join-Path (Split-Path (Split-Path $Git)) 'bin\bash.exe'
    if (-not (Test-Path $Bash)) { throw "no Git Bash next to $Git" }
    $Bash
}

function Install-Tools {
    New-Item -ItemType Directory -Force $Bin | Out-Null
    $UserPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (-not $UserPath) {
        [Environment]::SetEnvironmentVariable('Path', $Bin, 'User')
    } elseif (($UserPath -split ';') -notcontains $Bin) {
        Write-Step "adding $Bin to PATH"
        [Environment]::SetEnvironmentVariable('Path', "$Bin;$UserPath", 'User')
    }
    Update-SessionPath
    # jq is for the Claude Code hook, which runs in Git Bash.
    Install-Package git Git.Git
    Install-Package jq jqlang.jq
    Install-Package mise jdx.mise
    Install-Package oh-my-posh JanDeDobbeleer.OhMyPosh
    # Always in $Bin, where dotfiles-sync looks for it.
    if (-not (Test-Path (Join-Path $Bin 'chezmoi.exe'))) {
        Write-Step 'installing chezmoi'
        Invoke-Expression "&{$(Invoke-RestMethod 'https://get.chezmoi.io/ps1')} -b '$Bin'"
    }
}

function Set-ProfileHook {
    # The default policy on Windows clients blocks every profile script.
    if ((Get-ExecutionPolicy) -in 'Restricted', 'AllSigned', 'Undefined') {
        Write-Step 'allowing local scripts for the current user'
        Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force
    }
    $Line = '$DotfilesProfile = Join-Path $HOME ''.config\powershell\profile.ps1''; if (Test-Path $DotfilesProfile) { . $DotfilesProfile }'
    $Documents = [Environment]::GetFolderPath('MyDocuments')
    foreach ($Edition in 'WindowsPowerShell', 'PowerShell') {
        $ProfilePath = Join-Path $Documents "$Edition\profile.ps1"
        if ((Test-Path $ProfilePath) -and (Get-Content $ProfilePath) -contains $Line) { continue }
        Write-Step "loading the dotfiles profile from $ProfilePath"
        New-Item -ItemType Directory -Force (Split-Path $ProfilePath) | Out-Null
        # Add-Content ends what it writes with a newline but does not start
        # with one, so it would join $Line onto an unterminated last line.
        if (Test-Path $ProfilePath) {
            $Existing = Get-Content -Raw $ProfilePath
            if ($Existing -and -not $Existing.EndsWith("`n")) { Add-Content -Path $ProfilePath -Value '' }
        }
        Add-Content -Path $ProfilePath -Value $Line
    }
}

function Test-Administrator {
    $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    ([Security.Principal.WindowsPrincipal] $Identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Initialize-GhAuth {
    Install-Package gh GitHub.cli
    & gh auth status *> $null
    if ($LASTEXITCODE -eq 0) { return }
    Invoke-Native { gh auth login --hostname github.com --git-protocol https }
}

# The runner service runs as NETWORK SERVICE (S-1-5-20) and can only write the
# trigger file that dotfiles-sync-watch.ps1 watches; the sync itself runs as
# the logged-on user.
function Initialize-Trigger {
    New-Item -ItemType Directory -Force $TriggerDir | Out-Null
    $Trigger = Join-Path $TriggerDir 'trigger'
    if (-not (Test-Path $Trigger)) { New-Item -ItemType File $Trigger | Out-Null }
    Invoke-Native { icacls $TriggerDir /grant '*S-1-5-20:(OI)(CI)M' } | Out-Null
}

# The ops workflow targets each machine through a label equal to its runner
# name, so every machine gets its own sync job. The suffix keeps a Windows host
# apart from its WSL instances, which have the same host name.
function Initialize-Runner {
    $Name = "$env:COMPUTERNAME-windows"
    if (Test-Path (Join-Path $RunnerDir '.runner')) { return }
    Initialize-GhAuth

    $Arch = switch ($env:PROCESSOR_ARCHITECTURE) {
        'AMD64' { 'x64' }
        'ARM64' { 'arm64' }
        default { throw "no actions runner build for $env:PROCESSOR_ARCHITECTURE" }
    }
    $Version = (gh api repos/actions/runner/releases/latest --jq .tag_name).TrimStart('v')
    Write-Step "installing actions runner $Version as $Name"
    New-Item -ItemType Directory -Force $RunnerDir | Out-Null
    $Zip = Join-Path $env:TEMP "actions-runner-$Version.zip"
    Invoke-WebRequest -UseBasicParsing -OutFile $Zip `
        "https://github.com/actions/runner/releases/download/v$Version/actions-runner-win-$Arch-$Version.zip"
    Expand-Archive -Force $Zip $RunnerDir
    Remove-Item $Zip
    $Token = gh api -X POST "repos/$RunnerRepo/actions/runners/registration-token" --jq .token
    Push-Location $RunnerDir
    try {
        Invoke-Native {
            .\config.cmd --unattended --replace --url "https://github.com/$RunnerRepo" `
                --token $Token --name $Name --labels $Name --runasservice
        }
    } finally {
        Pop-Location
    }
}

function Register-SyncTask([string] $Bash) {
    $User = "$env:USERDOMAIN\$env:USERNAME"
    $Watch = Join-Path $Bin 'dotfiles-sync-watch.ps1'
    $Action = New-ScheduledTaskAction -Execute $PowerShell -Argument (
        "-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass " +
        "-File `"$Watch`" -Bash `"$Bash`"")
    $Trigger = New-ScheduledTaskTrigger -AtLogOn -User $User
    $Principal = New-ScheduledTaskPrincipal -UserId $User -LogonType Interactive -RunLevel Limited
    $Settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) `
        -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) `
        -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew
    Write-Step "registering the $TaskName scheduled task"
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger `
        -Principal $Principal -Settings $Settings -Force | Out-Null
    # Restart so a re-run picks up a changed watcher.
    Stop-ScheduledTask -TaskName $TaskName
    Start-ScheduledTask -TaskName $TaskName
}

if ($env:OS -ne 'Windows_NT') { throw 'install.ps1 is for Windows; use install.sh elsewhere' }
if ($UseRunner -and -not (Test-Administrator)) {
    throw 'run this from an elevated PowerShell, or set DOTFILES_RUNNER=0 to skip the runner'
}

$Here = if ($PSCommandPath) { Split-Path -Parent $PSCommandPath } else { $null }
$Canonical = Resolve-Path $Dir -ErrorAction SilentlyContinue
if (-not $Here -or -not $Canonical -or (Resolve-Path $Here).Path -ne $Canonical.Path) {
    Invoke-Bootstrap
    return
}

Install-Tools
$Bash = Get-GitBash
Write-Step "applying dotfiles from $Dir"
Invoke-Native { & $Bash "$($Dir -replace '\\', '/')/apply.sh" }
Set-ProfileHook
if ($UseRunner) {
    Initialize-Trigger
    Initialize-Runner
}
Register-SyncTask $Bash
Write-Step 'done; open a new PowerShell to pick up the changes'
