# Shared path and integrity checks for native project Skills (PowerShell 5.1+).
function Get-HarnessProjectPath {
    param([string]$ProjectRoot, [string]$RelativePath)
    if (-not $RelativePath -or [IO.Path]::IsPathRooted($RelativePath) -or $RelativePath -match '(^|[\\/])\.\.([\\/]|$)') {
        throw 'Expected a safe project-relative path.'
    }
    $root = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $ProjectRoot).Path).TrimEnd([char[]]'\/')
    $rootItem = Get-Item -LiteralPath $root -Force
    if (-not $rootItem.PSIsContainer -or ($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Project root must be an ordinary directory.' }
    $path = [IO.Path]::GetFullPath((Join-HarnessPath $root $RelativePath))
    $comparison = if ($script:HarnessIsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    if (-not $path.StartsWith($root + [IO.Path]::DirectorySeparatorChar, $comparison)) { throw 'Path escapes the project root.' }
    $cursor = $path
    while (-not $cursor.Equals($root, $comparison)) {
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -LiteralPath $cursor -Force
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Skill paths must not traverse links or junctions.' }
        }
        $cursor = Split-Path -Parent $cursor
        if (-not $cursor) { throw 'Cannot validate project path.' }
    }
    return $path
}

function Get-HarnessSkillManifest {
    param([string]$Root)
    $rootPath = (Resolve-Path -LiteralPath $Root).Path.TrimEnd([char[]]'\/')
    $rootItem = Get-Item -LiteralPath $rootPath -Force
    if (-not $rootItem.PSIsContainer -or ($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Skill root must be an ordinary directory.' }
    $entries = [System.Collections.Generic.SortedDictionary[string,string]]::new([StringComparer]::Ordinal)
    $pending = [System.Collections.Generic.Stack[string]]::new()
    $pending.Push($rootPath)
    while ($pending.Count -gt 0) {
        foreach ($item in @(Get-ChildItem -LiteralPath $pending.Pop() -Force)) {
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Skill bundles must not contain links or junctions.' }
            if ($item.PSIsContainer) { $pending.Push($item.FullName); continue }
            $relative = $item.FullName.Substring($rootPath.Length + 1).Replace('\', '/')
            if ($relative -match '[\t\r\n]') { throw 'Skill file names must not contain tabs or line breaks.' }
            $entries.Add($relative, (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash.ToLowerInvariant())
        }
    }
    if (-not $entries.ContainsKey('SKILL.md')) { throw 'Skill bundle is missing SKILL.md.' }
    $canonical = [Text.StringBuilder]::new()
    $files = @()
    foreach ($entry in $entries.GetEnumerator()) {
        [void]$canonical.Append($entry.Key).Append([char]9).Append($entry.Value).Append([char]10)
        $files += [pscustomobject]@{ path = $entry.Key; sha256 = $entry.Value }
    }
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $digest = $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($canonical.ToString())) } finally { $sha.Dispose() }
    [pscustomobject]@{ Files = $files; Hash = ([BitConverter]::ToString($digest).Replace('-', '').ToLowerInvariant()); SkillHash = $entries['SKILL.md'] }
}

function Remove-HarnessSkillWorkPath {
    param([string]$ProjectRoot, [string]$RelativePath)
    $path = Get-HarnessProjectPath $ProjectRoot $RelativePath
    if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Recurse -Force }
}
