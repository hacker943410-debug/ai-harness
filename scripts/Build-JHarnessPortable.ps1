#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Destination,
    [string]$NodeBinary,
    [string]$NodeLicense
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:OS -ne 'Windows_NT' -or -not [Environment]::Is64BitOperatingSystem -or $env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { throw 'WINDOWS_X64_REQUIRED' }
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$output = [IO.Path]::GetFullPath($Destination)
if (Test-Path -LiteralPath $output) { throw 'NEW_DESTINATION_REQUIRED_EXISTING_DESTINATION_PRESERVED' }
function Assert-PlainPath([string]$Target) {
    $cursor = [IO.Path]::GetFullPath($Target)
    while ($cursor) {
        if (Test-Path -LiteralPath $cursor) {
            if (((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "LINK_PATH_REFUSED: $cursor" }
        }
        $parent = [IO.Path]::GetDirectoryName($cursor)
        if ($parent -eq $cursor) { break }; $cursor = $parent
    }
}
Assert-PlainPath $output
$version = [IO.File]::ReadAllText((Join-Path $repo 'J_HARNESS_VERSION')).Trim()
if ($version -notmatch '^8\.\d+\.\d+(-[0-9A-Za-z.-]+)?$') { throw 'EXPECTED_V8_PORTABLE_DISTRIBUTION' }
$portableSource = Join-Path (Join-Path $repo 'core') 'portable'
$launcherSource = Join-Path $portableSource 'launchers'
$installer = Join-Path $portableSource 'install-project.ps1'
if (-not (Test-Path -LiteralPath $installer -PathType Leaf)) { throw 'PROJECT_INSTALLER_SOURCE_REQUIRED' }
New-Item -ItemType Directory -Path $output | Out-Null
# Failed preparations remain inside the new destination for diagnosis. Never delete user paths.
$downloads = Join-Path $output 'trusted-node'
New-Item -ItemType Directory -Path $downloads | Out-Null
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
if (-not $NodeBinary) {
    $NodeBinary = Join-Path $downloads 'node.exe'
    Invoke-WebRequest -UseBasicParsing -Uri 'https://nodejs.org/dist/v22.23.5/win-x64/node.exe' -OutFile $NodeBinary
}
if (-not $NodeLicense) {
    $NodeLicense = Join-Path $downloads 'LICENSE'
    Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/nodejs/node/v22.23.5/LICENSE' -OutFile $NodeLicense
}
$NodeBinary = [IO.Path]::GetFullPath($NodeBinary)
$NodeLicense = [IO.Path]::GetFullPath($NodeLicense)
Assert-PlainPath $NodeBinary; Assert-PlainPath $NodeLicense
if ((Get-FileHash -LiteralPath $NodeBinary -Algorithm SHA256).Hash.ToLowerInvariant() -ne '247e9693d316da9857e44990e5e11709f596f18112251b8026ec6eed80bdf38a') { throw 'NODE_SHA256_MISMATCH' }
if ((Get-FileHash -LiteralPath $NodeLicense -Algorithm SHA256).Hash.ToLowerInvariant() -ne 'c738ae413cf561f174e34f6961f8ca458aae2369a73640dda6234c629b98bcc4') { throw 'NODE_LICENSE_SHA256_MISMATCH' }
$actualVersion = & $NodeBinary --version
if ($LASTEXITCODE -ne 0 -or $actualVersion -ne 'v22.23.5') { throw 'NODE_VERSION_MISMATCH' }
$package = Join-Path $output 'package'
New-Item -ItemType Directory -Path $package | Out-Null
$runtime = Join-Path (Join-Path $package '.agents') 'j-harness'
& $NodeBinary (Join-Path $portableSource 'build-runtime.mjs') $runtime $NodeBinary $NodeLicense
if ($LASTEXITCODE -ne 0) { throw 'MATERIALIZE_RUNTIME_FAILED' }
foreach ($name in @('JHarness.cmd','JHarness.ps1','Install-JHarness.cmd','README.md')) {
    Copy-Item -LiteralPath (Join-Path $launcherSource $name) -Destination (Join-Path $package $name)
}
$installerTemplate = [IO.File]::ReadAllText($installer)
if (-not $installerTemplate.Contains("'JH_PRODUCT_VERSION'")) { throw 'LOCAL_INSTALLER_VERSION_MARKER_MISSING' }
$pinnedInstaller = $installerTemplate.Replace("'JH_PRODUCT_VERSION'", ("'"+$version+"'"))
[IO.File]::WriteAllText((Join-Path $package 'Install-JHarnessLocal.ps1'), $pinnedInstaller, [Text.UTF8Encoding]::new($false))
Copy-Item -LiteralPath (Join-Path $launcherSource 'README.md') -Destination (Join-Path $package 'JHarness-README.md')
$zip = Join-Path $output ('J_Harness_v' + $version + '_Windows_x64.zip')
Add-Type -AssemblyName System.IO.Compression
$stream = [IO.File]::Open($zip,[IO.FileMode]::CreateNew)
try {
    $archive = New-Object IO.Compression.ZipArchive($stream,[IO.Compression.ZipArchiveMode]::Create,$true)
    try {
        # Enumerate hidden .agents explicitly. Sort normalized entry paths deterministically.
        $entries = @{}
        foreach ($file in Get-ChildItem -LiteralPath $package -Force -Recurse -File) {
            Assert-PlainPath $file.FullName
            $relative = $file.FullName.Substring($package.Length + 1).Replace('\','/')
            $entries.Add($relative,$file.FullName)
        }
        $names = [string[]]@($entries.Keys)
        [Array]::Sort($names,[StringComparer]::Ordinal)
        foreach ($name in $names) {
            $entry = $archive.CreateEntry($name,[IO.Compression.CompressionLevel]::Optimal)
            $entry.LastWriteTime = [DateTimeOffset]::new(2020,1,1,0,0,0,[TimeSpan]::Zero)
            $inputStream = [IO.File]::OpenRead($entries[$name]); $entryStream = $entry.Open()
            try { $inputStream.CopyTo($entryStream) } finally { $entryStream.Dispose(); $inputStream.Dispose() }
        }
    } finally { $archive.Dispose() }
} finally { $stream.Dispose() }
$sum = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText((Join-Path $output 'SHA256SUMS.txt'),($sum + '  ' + [IO.Path]::GetFileName($zip) + "`n"),(New-Object Text.UTF8Encoding($false)))
Write-Output ('BUILT ' + $zip)
Write-Output ('SHA256 ' + $sum)
