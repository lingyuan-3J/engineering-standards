Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repository = Split-Path -Parent $PSScriptRoot
. (Join-Path $repository 'scripts/lib.ps1')
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('engineering-standards-test-' + [guid]::NewGuid().ToString('N'))
$shell = (Get-Process -Id $PID).Path
$utf8 = New-Object Text.UTF8Encoding($false)
function Assert-Test {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}
function Run-Script {
    param([string]$Name, [string]$ExpectedOrigin, [string]$ProfileDirectory, [bool]$Success = $true)
    $previous = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& $shell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repository "scripts/$Name.ps1") -RepositoryUrl $ExpectedOrigin -CodexHome $ProfileDirectory 2>&1 | ForEach-Object { "$_" })
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previous }
    if (($Success -and $code -ne 0) -or (-not $Success -and $code -eq 0)) { throw "Unexpected $Name result ($code): $($output -join ' ')" }
}
try {
    New-Item -ItemType Directory -Path $testRoot | Out-Null
    $origin = Join-Path $testRoot 'origin.git'
    $source = Join-Path $testRoot 'source'
    $profileDirectory = Join-Path $testRoot 'Codex Home'
    Invoke-StandardsGit -Arguments @('init', '--bare', '--initial-branch=main', $origin) | Out-Null
    Invoke-StandardsGit -Arguments @('clone', $origin, $source) | Out-Null
    Invoke-StandardsGit -Arguments @('-C', $source, 'config', 'user.name', 'Standards Test') | Out-Null
    Invoke-StandardsGit -Arguments @('-C', $source, 'config', 'user.email', 'standards-test@example.invalid') | Out-Null
    [IO.File]::WriteAllText((Join-Path $source '00-规范目录.md'), "# Test standards`n", $utf8)
    Invoke-StandardsGit -Arguments @('-C', $source, 'add', '.') | Out-Null
    Invoke-StandardsGit -Arguments @('-C', $source, 'commit', '-m', 'initial fixture') | Out-Null
    Invoke-StandardsGit -Arguments @('-C', $source, 'push', '-u', 'origin', 'main') | Out-Null
    New-Item -ItemType Directory -Path $profileDirectory | Out-Null
    $entry = Join-Path $profileDirectory 'AGENTS.md'
    $personal = "# Personal instructions`nKeep these unchanged.`n"
    [IO.File]::WriteAllText($entry, $personal, $utf8)
    Run-Script 'install' $origin $profileDirectory
    $installed = [IO.File]::ReadAllText($entry)
    Assert-Test ($installed.StartsWith($personal)) 'Personal instructions were lost.'
    Assert-Test ([regex]::Matches($installed, '<!-- BEGIN engineering-standards -->').Count -eq 1) 'Managed entry duplicated.'
    Assert-Test (@(Get-ChildItem -LiteralPath (Join-Path $profileDirectory 'standards-backups')).Count -eq 1) 'Original entry was not backed up.'
    Run-Script 'install' $origin $profileDirectory
    Assert-Test ([IO.File]::ReadAllText($entry) -ceq $installed) 'Repeated installation was not idempotent.'
    Assert-Test (@(Get-ChildItem -LiteralPath (Join-Path $profileDirectory 'standards-backups')).Count -eq 1) 'Idempotent install made unnecessary backups.'
    [IO.File]::WriteAllText((Join-Path $source 'new-rule.md'), "# Added remotely`n", $utf8)
    Invoke-StandardsGit -Arguments @('-C', $source, 'add', '.') | Out-Null
    Invoke-StandardsGit -Arguments @('-C', $source, 'commit', '-m', 'remote update') | Out-Null
    Invoke-StandardsGit -Arguments @('-C', $source, 'push') | Out-Null
    Run-Script 'sync' $origin $profileDirectory
    $checkout = Join-Path $profileDirectory 'standards'
    Assert-Test (Test-Path -LiteralPath (Join-Path $checkout 'new-rule.md')) 'Fast-forward failed.'
    [IO.File]::WriteAllText((Join-Path $checkout 'local-draft.md'), 'preserve draft', $utf8)
    Run-Script 'sync' $origin $profileDirectory $false
    Assert-Test ([IO.File]::ReadAllText((Join-Path $checkout 'local-draft.md')) -eq 'preserve draft') 'Local draft was changed.'
    Remove-Item -LiteralPath (Join-Path $checkout 'local-draft.md')
    Run-Script 'install' (Join-Path $testRoot 'wrong-origin.git') $profileDirectory $false
    Assert-Test ([IO.File]::ReadAllText($entry) -ceq $installed) 'Wrong origin changed global entry.'
    [IO.File]::WriteAllText((Join-Path $profileDirectory 'AGENTS.override.md'), '# Active override', $utf8)
    Run-Script 'install' $origin $profileDirectory $false
    Assert-Test ([IO.File]::ReadAllText($entry) -ceq $installed) 'Override failure changed global entry.'
    Remove-Item -LiteralPath (Join-Path $profileDirectory 'AGENTS.override.md')
    [IO.File]::WriteAllText($entry, "$installed`n<!-- BEGIN engineering-standards -->", $utf8)
    $malformed = [IO.File]::ReadAllText($entry)
    Run-Script 'install' $origin $profileDirectory $false
    Assert-Test ([IO.File]::ReadAllText($entry) -ceq $malformed) 'Malformed entry was changed.'
    [IO.File]::WriteAllText($entry, $installed, $utf8)
    Invoke-StandardsGit -Arguments @('-C', $checkout, 'config', 'user.name', 'Standards Test') | Out-Null
    Invoke-StandardsGit -Arguments @('-C', $checkout, 'config', 'user.email', 'standards-test@example.invalid') | Out-Null
    [IO.File]::WriteAllText((Join-Path $checkout 'local-rule.md'), 'local commit', $utf8)
    Invoke-StandardsGit -Arguments @('-C', $checkout, 'add', '.') | Out-Null
    Invoke-StandardsGit -Arguments @('-C', $checkout, 'commit', '-m', 'local branch') | Out-Null
    $localHead = [string](Invoke-StandardsGit -Arguments @('-C', $checkout, 'rev-parse', 'HEAD'))
    Run-Script 'sync' $origin $profileDirectory $false
    [IO.File]::WriteAllText((Join-Path $source 'remote-rule.md'), 'remote commit', $utf8)
    Invoke-StandardsGit -Arguments @('-C', $source, 'add', '.') | Out-Null
    Invoke-StandardsGit -Arguments @('-C', $source, 'commit', '-m', 'diverge remote') | Out-Null
    Invoke-StandardsGit -Arguments @('-C', $source, 'push') | Out-Null
    Run-Script 'sync' $origin $profileDirectory $false
    Assert-Test ([string](Invoke-StandardsGit -Arguments @('-C', $checkout, 'rev-parse', 'HEAD')) -eq $localHead) 'Divergence changed local branch.'
    Invoke-StandardsGit -Arguments @('-C', $checkout, 'checkout', '--detach') | Out-Null
    Run-Script 'sync' $origin $profileDirectory $false
    Write-Output 'Passed: install, idempotence, backup, fast-forward, dirty checkout, wrong origin, override, malformed entry, ahead, divergence and detached HEAD.'
} finally {
    $resolved = [IO.Path]::GetFullPath($testRoot)
    $temporaryParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if (-not $resolved.StartsWith($temporaryParent) -or -not ([IO.Path]::GetFileName($resolved)).StartsWith('engineering-standards-test-')) { throw 'Unsafe test cleanup target.' }
    if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
