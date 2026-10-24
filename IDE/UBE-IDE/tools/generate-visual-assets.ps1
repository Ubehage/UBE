[CmdletBinding()]
param(
    [string]$OutputRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) 'out\visual')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$applicationRoot = Split-Path -Parent $PSScriptRoot
$sourcePath = Join-Path $applicationRoot 'resources\icons\icon-source.json'
$source = Get-Content -Raw -LiteralPath $sourcePath | ConvertFrom-Json
if ($source.format -ne 'ube-ide-icons-1' -or $source.viewBox -ne '0 0 24 24') {
    throw 'Unsupported UBE icon source format.'
}
$icons = @($source.icons)
if ($icons.Count -ne 25) { throw "Expected 25 core icons; found $($icons.Count)." }
if (@($icons.name | Sort-Object -Unique).Count -ne $icons.Count) { throw 'Icon names must be unique.' }

$utf8 = [System.Text.UTF8Encoding]::new($false)
$sizes = @(16, 20, 24, 32)
foreach ($size in $sizes) {
    $sizeRoot = Join-Path $OutputRoot "icons\$size"
    New-Item -ItemType Directory -Path $sizeRoot -Force | Out-Null
    foreach ($icon in $icons) {
        if ($icon.name -notmatch '^[a-z][a-z0-9-]*$' -or [string]::IsNullOrWhiteSpace($icon.label)) {
            throw 'Every icon requires a stable lowercase name and accessible label.'
        }
        if ($icon.body -match '#[0-9A-Fa-f]{6}') { throw "Icon '$($icon.name)' embeds a fixed color." }
        $label = [Security.SecurityElement]::Escape([string]$icon.label)
        $svg = "<svg xmlns=`"http://www.w3.org/2000/svg`" width=`"$size`" height=`"$size`" viewBox=`"$($source.viewBox)`" fill=`"none`" stroke=`"currentColor`" stroke-width=`"$($source.strokeWidth)`" stroke-linecap=`"round`" stroke-linejoin=`"round`" role=`"img`"><title>$label</title>$($icon.body)</svg>`n"
        [IO.File]::WriteAllText((Join-Path $sizeRoot "$($icon.name).svg"), $svg, $utf8)
    }
}

$manifestLines = foreach ($size in $sizes) {
    Get-ChildItem -LiteralPath (Join-Path $OutputRoot "icons\$size") -Filter '*.svg' |
        Sort-Object Name |
        ForEach-Object { "$size/$($_.Name) $((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)" }
}
[IO.File]::WriteAllText((Join-Path $OutputRoot 'icon-manifest.sha256'), ($manifestLines -join "`n") + "`n", $utf8)
Write-Output "Generated $($icons.Count) icons at $($sizes.Count) sizes."
