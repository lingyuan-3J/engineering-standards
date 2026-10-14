param(
    [string]$RepositoryUrl = 'https://github.com/lingyuan-3J/engineering-standards.git',
    [string]$CodexHome = ''
)
. (Join-Path $PSScriptRoot 'lib.ps1')
try {
    Get-Command git -ErrorAction Stop | Out-Null
    $codexDirectory = Get-StandardsHome $CodexHome
    $directory = Join-Path $codexDirectory 'standards'
    Assert-StandardsRepository $directory $RepositoryUrl
    $status = @(Invoke-StandardsGit -Arguments @('-C', $directory, 'status', '--porcelain'))
    if ($status.Count) { throw 'Uncommitted standards changes found. Commit or resolve them before syncing; nothing was overwritten.' }
    $branch = [string](Invoke-StandardsGit -Arguments @('-C', $directory, 'symbolic-ref', '--quiet', '--short', 'HEAD'))
    $upstream = [string](Invoke-StandardsGit -Arguments @('-C', $directory, 'rev-parse', '--abbrev-ref', '@{upstream}'))
    if ($upstream -ne "origin/$branch") { throw "Unexpected upstream: $upstream. Expected origin/$branch." }
    Invoke-StandardsGit -Arguments @('-C', $directory, 'fetch', 'origin') | Out-Host
    $ahead = [int][string](Invoke-StandardsGit -Arguments @('-C', $directory, 'rev-list', '--count', "$upstream..HEAD"))
    if ($ahead -ne 0) { throw 'Local commits are ahead of or diverged from origin. Push or resolve them before syncing.' }
    Invoke-StandardsGit -Arguments @('-C', $directory, 'merge', '--ff-only', $upstream) | Out-Host
    Update-StandardsEntry $codexDirectory
    $revision = [string](Invoke-StandardsGit -Arguments @('-C', $directory, 'rev-parse', '--short', 'HEAD'))
    Write-Output "Synced shared standards: $revision. Explicitly reread them in active chats."
} catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
}
