<#
Copies the addon into the WoW Forever AddOns folder, for testing. Run it yourself; nothing runs it
for you.

  .\deploy.ps1                         copy to the default install
  .\deploy.ps1 -WowPath "D:\Games\World of Warcraft"

The target folder is replaced completely, so files deleted here disappear there too.
In the game, /reload is enough after a change to .lua files; a change to the .toc or
Bindings.xml needs a restart.
#>
param(
    [string]$WowPath = 'C:\Program Files (x86)\World of Warcraft'
)

$ErrorActionPreference = 'Stop'

$addonName = 'MaldoesScribe'
$source = $PSScriptRoot
$addOns = Join-Path $WowPath '_forever_\Interface\AddOns'
$target = Join-Path $addOns $addonName

if (-not (Test-Path $addOns)) {
    Write-Error "WoW Forever AddOns folder not found: $addOns"
}

# Only what the game needs: no notes, no scripts, no git data.
$files = @("$addonName.toc", 'Bindings.xml', 'README.md') + (Get-ChildItem $source -Filter '*.lua' -File).Name
$folders = @('Media')

try {
    if (Test-Path $target) { Remove-Item $target -Recurse -Force }
    New-Item -ItemType Directory -Path $target | Out-Null

    foreach ($file in $files) {
        Copy-Item (Join-Path $source $file) -Destination $target
    }
    foreach ($folder in $folders) {
        Copy-Item (Join-Path $source $folder) -Destination $target -Recurse
    }

    # The toc carries @project-version@ (filled by the release packager); a test copy shows when it was made.
    $toc = Join-Path $target "$addonName.toc"
    $stamp = 'dev-' + (Get-Date -Format 'yyyyMMdd-HHmm')
    $text = [IO.File]::ReadAllText($toc, [Text.Encoding]::UTF8).Replace('@project-version@', $stamp)
    [IO.File]::WriteAllText($toc, $text, (New-Object System.Text.UTF8Encoding $false))
}
catch [System.UnauthorizedAccessException] {
    Write-Error "No write access to $addOns. Start the terminal as administrator and run the script again."
}

$count = (Get-ChildItem $target -Recurse -File).Count
Write-Host "Copied $count files to $target (version $stamp)" -ForegroundColor Green
