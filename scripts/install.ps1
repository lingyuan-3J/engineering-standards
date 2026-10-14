param(
    [string]$RepositoryUrl = 'https://github.com/lingyuan-3J/engineering-standards.git',
    [string]$CodexHome = ''
)
. (Join-Path $PSScriptRoot 'lib.ps1')
try {
    Get-Command git -ErrorAction Stop | Out-Null
    $codexDirectory = Get-StandardsHome $CodexHome
    New-Item -ItemType Directory -Path $codexDirectory -Force | Out-Null
    $directory = Join-Path $codexDirectory 'standards'
    if (-not (Test-Path -LiteralPath $directory)) {
        Invoke-StandardsGit -Arguments @('clone', $RepositoryUrl, $directory) | Out-Host
    }
    Assert-StandardsRepository $directory $RepositoryUrl
    Update-StandardsEntry $codexDirectory
    $revision = [string](Invoke-StandardsGit -Arguments @('-C', $directory, 'rev-parse', '--short', 'HEAD'))
    Write-Output "Installed shared standards at $directory ($revision). Existing personal instructions preserved."
    Write-Output 'Read the standards explicitly in active chats; new sessions will use the global entry.'
} catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
}
