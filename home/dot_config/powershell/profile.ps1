# Loaded from $PROFILE by a line install.ps1 adds, so it works wherever
# Documents is and for both Windows PowerShell and PowerShell 7.
if (Get-Command mise -ErrorAction SilentlyContinue) {
    mise activate pwsh | Out-String | Invoke-Expression
}
oh-my-posh init pwsh --config "$HOME/.oh-my-posh/config.toml" | Invoke-Expression
$LocalProfile = Join-Path $HOME '.config\powershell\profile.local.ps1'
if (Test-Path $LocalProfile) { . $LocalProfile }
