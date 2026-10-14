Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repository = Split-Path -Parent $PSScriptRoot
$files = @(Get-ChildItem -LiteralPath $repository -Recurse -File -Filter '*.md' | Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' })
$failures = New-Object 'System.Collections.Generic.List[string]'
function Get-Headings {
    param([string]$Content)
    $fenced = $false
    foreach ($line in ($Content -split '\r?\n')) {
        if ($line -match '^\s*(```|~~~)') { $fenced = -not $fenced; continue }
        if (-not $fenced -and $line -match '^(#{1,6})\s+(.+)$') {
            [pscustomobject]@{ Level = $Matches[1].Length; Text = $Matches[2].Trim() }
        }
    }
}
function Get-Anchor {
    param([string]$Text)
    return (($Text.ToLowerInvariant() -replace '[^\p{L}\p{N}_\s-]', '') -replace '\s', '-')
}
foreach ($file in $files) {
    $content = [IO.File]::ReadAllText($file.FullName)
    $headings = @(Get-Headings $content)
    $counters = @(0, 0, 0, 0, 0, 0, 0)
    foreach ($heading in $headings) {
        if ($heading.Level -eq 1) {
            if ($heading.Text -match '^\d+(\.|\s)') { $failures.Add("Numbered title: $($file.Name)") }
            continue
        }
        $level = $heading.Level
        $counters[$level] += 1
        for ($index = $level + 1; $index -lt $counters.Count; $index++) { $counters[$index] = 0 }
        $expected = ($counters[2..$level] -join '.')
        if ($level -eq 2) { $expected = [string]$counters[2] }
        if ($heading.Text -notmatch ('^' + [regex]::Escape($expected) + '\s+')) {
            $failures.Add("Heading sequence: $($file.Name): $($heading.Text); expected $expected")
        }
    }
    foreach ($match in [regex]::Matches($content, '(?<!!)\[[^\]]+\]\(([^)]+)\)')) {
        $link = $match.Groups[1].Value.Trim('<', '>')
        if ($link -match '^[a-zA-Z][a-zA-Z0-9+.-]*:') { continue }
        $parts = $link -split '#', 2
        $target = if ($parts[0]) { Join-Path $file.DirectoryName ([Uri]::UnescapeDataString($parts[0])) } else { $file.FullName }
        if (-not (Test-Path -LiteralPath $target)) { $failures.Add("Missing link: $($file.Name): $link"); continue }
        if ($parts.Count -eq 2 -and $parts[1] -and [IO.Path]::GetExtension($target) -eq '.md') {
            $anchors = @(Get-Headings ([IO.File]::ReadAllText($target)) | ForEach-Object { Get-Anchor $_.Text })
            if ([Uri]::UnescapeDataString($parts[1]) -notin $anchors) { $failures.Add("Missing anchor: $($file.Name): $link") }
        }
    }
}
if ($failures.Count) { $failures | ForEach-Object { Write-Output $_ }; exit 1 }
Write-Output "Checked $($files.Count) Markdown documents: heading sequences and local links passed."
