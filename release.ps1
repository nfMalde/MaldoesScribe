<#
Builds a release package by hand: MaldoesScribe-<version>.zip with one folder, MaldoesScribe, that
holds only what the game needs (toc, Bindings.xml, Lua, Media, README, CHANGELOG). Nothing else may
be in a release: no tools, no scripts, no notes. The script checks the finished zip for that.

The real releases are made by the GitHub workflow (.github/workflows/release.yml), started by hand
and approved before publishing; this script is for a local look at the package.

  .\release.ps1                       zip next to this script, version from git (or "dev")
  .\release.ps1 -Version 1.2.0        explicit version
  .\release.ps1 -OutDir D:\Releases   zip somewhere else
#>
param(
    [string]$Version = '',
    [string]$OutDir = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'

$addonName = 'MaldoesScribe'
$source = $PSScriptRoot

if (-not $Version) {
    $Version = 'dev'
    if (Get-Command git -ErrorAction SilentlyContinue) {
        try {
            $described = (git -C $source describe --tags --always 2>$null)
            if ($LASTEXITCODE -eq 0 -and $described) { $Version = $described.Trim() }
        }
        catch {}
        # Outside a git checkout git fails; that is fine and must not become the script's exit code.
        $global:LASTEXITCODE = 0
    }
}

# The same list as deploy.ps1: only top-level files, never a folder other than Media.
$files = @("$addonName.toc", 'Bindings.xml', 'README.md', 'CHANGELOG.md') + (Get-ChildItem $source -Filter '*.lua' -File).Name
if (Test-Path (Join-Path $source 'LICENSE')) { $files += 'LICENSE' }

$staging = Join-Path ([IO.Path]::GetTempPath()) ("maldoes-scribe-release-" + [guid]::NewGuid().ToString('N'))
$folder = Join-Path $staging $addonName
New-Item -ItemType Directory -Path $folder | Out-Null
try {
    foreach ($file in $files) {
        Copy-Item (Join-Path $source $file) -Destination $folder
    }
    Copy-Item (Join-Path $source 'Media') -Destination $folder -Recurse

    # The toc carries @project-version@, which the packager fills from the git tag; do the same here.
    $toc = Join-Path $folder "$addonName.toc"
    $text = [IO.File]::ReadAllText($toc, [Text.Encoding]::UTF8).Replace('@project-version@', $Version)
    [IO.File]::WriteAllText($toc, $text, (New-Object System.Text.UTF8Encoding $false))

    if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }
    $zip = Join-Path $OutDir "$addonName-$Version.zip"
    if (Test-Path $zip) { Remove-Item $zip -Force }
    Compress-Archive -Path $folder -DestinationPath $zip
}
finally {
    Remove-Item $staging -Recurse -Force
}

# Check the package: every entry sits in the addon folder, and none of the forbidden names is in it.
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($zip)
try {
    $entries = $archive.Entries | ForEach-Object { $_.FullName.Replace('\', '/') }
}
finally {
    $archive.Dispose()
}
$forbidden = @('tools/', 'docs/', 'node_modules/', '.github/', 'deploy.ps1', 'release.ps1', '.gitignore', '.gitattributes', '.pkgmeta', '.git/')
$bad = $entries | Where-Object {
    $entry = $_
    (-not $entry.StartsWith("$addonName/")) -or ($forbidden | Where-Object { $entry -like "*$_*" })
}
if ($bad) {
    Remove-Item $zip -Force
    throw "The package held files that do not belong in a release: $($bad -join ', ')"
}

Write-Host "Built $zip with $($entries.Count) entries:" -ForegroundColor Green
$entries | ForEach-Object { Write-Host "  $_" }
