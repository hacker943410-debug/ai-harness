#Requires -Version 5.1
# sha256-tree-v1: ordinal relative paths + NUL + lowercase file SHA256 + LF.
function ConvertTo-HarnessSkillPath {
    param([string]$Path)
    $value = $Path.Replace('\', '/')
    if ([string]::IsNullOrWhiteSpace($value) -or $value -match '^(?:/|[A-Za-z]:)' -or
        $value -match '(^|/)\.\.(/|$)' -or $value.Contains(';')) {
        throw "Unsafe project-relative Skill path: $Path"
    }
    $parts = @($value.Split('/') | Where-Object { $_ -and $_ -ne '.' })
    if ($parts.Count -eq 0) { throw 'Skill path must not be the project root.' }
    return ($parts -join '/')
}

function Get-HarnessSkillContentHash {
    param([Parameter(Mandatory = $true)][string]$Root)
    $resolved = Get-Item -Force -LiteralPath $Root
    if (-not $resolved.PSIsContainer) { throw "Skill root is not a directory: $Root" }
    $rootPath = $resolved.FullName.TrimEnd([char[]]@('/', '\'))
    # Walk explicitly so links are rejected before recursion follows them.
    $pending = [System.Collections.Generic.Stack[string]]::new()
    $pending.Push($rootPath)
    $files = [System.Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
    while ($pending.Count -gt 0) {
        $dir = Get-Item -Force -LiteralPath $pending.Pop()
        if ($dir.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Skill links are unsupported: $($dir.FullName)" }
        foreach ($item in Get-ChildItem -Force -LiteralPath $dir.FullName) {
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Skill links are unsupported: $($item.FullName)" }
            if ($item.PSIsContainer) { $pending.Push($item.FullName) } else {
                $rel = $item.FullName.Substring($rootPath.Length + 1).Replace('\', '/')
                $files[$rel] = $item.FullName
            }
        }
    }
    [string[]]$paths = @($files.Keys)
    [Array]::Sort($paths, [StringComparer]::Ordinal)
    $manifest = [Text.StringBuilder]::new()
    foreach ($rel in $paths) {
        $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $files[$rel]).Hash.ToLowerInvariant()
        [void]$manifest.Append($rel).Append([char]0).Append($hash).Append("`n")
    }
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.UTF8Encoding]::new($false).GetBytes($manifest.ToString())
        return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    } finally { $sha.Dispose() }
}
