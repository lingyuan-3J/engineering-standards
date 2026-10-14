Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-StandardsGit {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& git @Arguments 2>&1 | ForEach-Object { "$_" })
        $result = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    if ($result -ne 0) { throw "Git failed ($result): $($output -join [Environment]::NewLine)" }
    return $output
}

function Get-StandardsHome {
    param([string]$RequestedHome)
    if ($RequestedHome) { return [IO.Path]::GetFullPath($RequestedHome) }
    if ($env:CODEX_HOME) { return [IO.Path]::GetFullPath($env:CODEX_HOME) }
    return Join-Path ([Environment]::GetFolderPath('UserProfile')) '.codex'
}

function Get-RemoteIdentity {
    param([string]$Remote)
    $value = $Remote.Trim().TrimEnd('/').Replace('\', '/') -replace '\.git$', ''
    if ($value -match '^(?:https://github\.com/|git@github\.com:)(.+)$') {
        return 'github.com/' + $Matches[1].ToLowerInvariant()
    }
    return $value
}

function Assert-StandardsRepository {
    param([string]$Directory, [string]$RepositoryUrl)
    if (-not (Test-Path -LiteralPath (Join-Path $Directory '.git'))) {
        throw "Not an independent standards checkout: $Directory"
    }
    $actualRoot = [string](Invoke-StandardsGit -Arguments @('-C', $Directory, 'rev-parse', '--show-toplevel'))
    if ([IO.Path]::GetFullPath($actualRoot) -ne [IO.Path]::GetFullPath($Directory)) {
        throw 'Standards directory is not the repository root.'
    }
    $remote = [string](Invoke-StandardsGit -Arguments @('-C', $Directory, 'remote', 'get-url', 'origin'))
    if ((Get-RemoteIdentity $remote) -ne (Get-RemoteIdentity $RepositoryUrl)) {
        throw "Unexpected standards origin: $remote"
    }
    if (-not (Test-Path -LiteralPath (Join-Path $Directory '00-规范目录.md'))) {
        throw 'Standards index is missing; installation was not changed.'
    }
}

function Update-StandardsEntry {
    param([string]$CodexDirectory)
    $override = Join-Path $CodexDirectory 'AGENTS.override.md'
    if ((Test-Path -LiteralPath $override) -and [IO.File]::ReadAllText($override).Trim()) {
        throw 'A non-empty AGENTS.override.md takes precedence. Resolve that entry before installing shared standards.'
    }
    $entry = Join-Path $CodexDirectory 'AGENTS.md'
    $old = if (Test-Path -LiteralPath $entry) { [IO.File]::ReadAllText($entry) } else { '' }
    $begin = '<!-- BEGIN engineering-standards -->'
    $end = '<!-- END engineering-standards -->'
    $beginCount = [regex]::Matches($old, [regex]::Escape($begin)).Count
    $endCount = [regex]::Matches($old, [regex]::Escape($end)).Count
    if ($beginCount -ne $endCount -or $beginCount -gt 1) { throw 'Malformed shared standards entry; file left unchanged.' }
    $block = @'
<!-- BEGIN engineering-standards -->
## 共享工程规范

中央规范位于当前 Codex 主目录的 standards/。Codex 主目录优先取 CODEX_HOME，未设置时取用户主目录下 .codex；不要相对于项目工作目录解析。

开始编码或修改技术文档前，必须显式读取 standards/00-规范目录.md 和本次任务适用的正文；Markdown 链接不会自动展开。编码阅读通用规范，再按当前技术栈及任务从目录选读对应规范；Python 项目同时读取 Python 规范，框架、数据库和 AI 接入按实际使用选读。编写文档阅读技术文档编写规范。随后阅读当前项目及子目录 AGENTS.md 和对应领域方案，遵循明确的项目补充及例外。

要求记录或更新规范时：跨项目规则修改 standards/ 的唯一正文；项目特有规则修改项目文档；业务实现修改领域方案。不要在项目复制维护通用规则。修改本仓库前阅读规范维护规范，提交和推送须处于用户授权范围。

同步使用 standards/scripts/sync.ps1（PowerShell）或 sync.sh（Bash），不得自动 reset、stash 或覆盖本地修改。同步后对正在进行的会话显式重新读取规范，不能假设历史上下文已经更新。
<!-- END engineering-standards -->
'@
    if ($beginCount -eq 1) {
        $pattern = '(?s)' + [regex]::Escape($begin) + '.*?' + [regex]::Escape($end)
        if (-not [regex]::IsMatch($old, $pattern)) { throw 'Shared entry markers are reversed; file left unchanged.' }
        $new = [regex]::Replace($old, $pattern, [Text.RegularExpressions.MatchEvaluator]{ param($match) $block })
    } else {
        $new = $old + $(if ($old -and -not $old.EndsWith("`n")) { "`n" } else { '' }) + $(if ($old) { "`n" } else { '' }) + $block + "`n"
    }
    if ($new -eq $old) { return }
    if (Test-Path -LiteralPath $entry) {
        $backupDirectory = Join-Path $CodexDirectory 'standards-backups'
        New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null
        $backupName = 'AGENTS-' + (Get-Date -Format 'yyyyMMdd-HHmmssfff') + '-' + [guid]::NewGuid().ToString('N') + '.md'
        Copy-Item -LiteralPath $entry -Destination (Join-Path $backupDirectory $backupName)
    }
    $temporary = Join-Path $CodexDirectory ('AGENTS.' + [guid]::NewGuid().ToString('N') + '.tmp')
    [IO.File]::WriteAllText($temporary, $new, (New-Object Text.UTF8Encoding($false)))
    Move-Item -LiteralPath $temporary -Destination $entry -Force
}
