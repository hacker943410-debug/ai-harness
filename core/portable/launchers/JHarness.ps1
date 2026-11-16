$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
$runtime = Join-Path $PSScriptRoot '.agents\j-harness'
$node = Join-Path $runtime 'vendor\win-x64\node.exe'
if (-not (Test-Path -LiteralPath $node -PathType Leaf)) { throw 'BUNDLED_NODE_REQUIRED_NO_GLOBAL_FALLBACK' }
$stream=[IO.File]::OpenRead($node);$hasher=[Security.Cryptography.SHA256]::Create()
try { $nodeSha=[BitConverter]::ToString($hasher.ComputeHash($stream)).Replace('-','').ToLowerInvariant() }
finally { $hasher.Dispose();$stream.Dispose() }
if ($nodeSha -ne 'ae1a50511be58e987483fdbc12125407443926d2d394669ade2352776e920dd3') { throw 'BUNDLED_NODE_HASH_MISMATCH_NO_FALLBACK' }
if ($args.Count -gt 0 -and $args[0] -eq 'setup') {
    if ($args.Count -ne 1) { throw 'SETUP_TAKES_NO_ADDITIONAL_ARGUMENTS' }
    $entry=Join-Path $runtime 'setup.mjs';$arguments=@('--project',$PSScriptRoot)
} else {
    $entry=Join-Path $runtime 'portable.mjs';$arguments=@('--project',$PSScriptRoot)+$args
}
# Preserve quotes and trailing backslashes when forwarding test argv from native PS5.1.
$quoted=foreach($argument in @($entry)+$arguments){
    '"'+[regex]::Replace([regex]::Replace($argument,'(\\*)"','$1$1\"'),'(\\+)$','$1$1')+'"'
}
$info=New-Object Diagnostics.ProcessStartInfo
$info.FileName=$node;$info.Arguments=($quoted -join ' ')
$info.UseShellExecute=$false;$info.CreateNoWindow=$true
$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
$info.StandardOutputEncoding=[Text.UTF8Encoding]::new($false)
$info.StandardErrorEncoding=[Text.UTF8Encoding]::new($false)
$process=New-Object Diagnostics.Process;$process.StartInfo=$info
try {
    if(-not $process.Start()){throw 'BUNDLED_NODE_START_FAILED'}
    $stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    [Console]::Out.Write($stdout.GetAwaiter().GetResult())
    [Console]::Error.Write($stderr.GetAwaiter().GetResult())
    $exitCode=$process.ExitCode
} finally { $process.Dispose() }
exit $exitCode
