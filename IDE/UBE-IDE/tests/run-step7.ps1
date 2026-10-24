[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$applicationRoot = Split-Path -Parent $PSScriptRoot
$repositoryRoot = (Resolve-Path (Join-Path $applicationRoot '..\..')).Path
$outputRoot = Join-Path $applicationRoot 'out'
$workRoot = Join-Path $outputRoot 'step7-work'
$compilerPath = Join-Path $repositoryRoot 'compiler\release-previews\ube-v3-rp8-windows-x86_64-x86_64-w64-windows-gnu.exe'
$testProject = Join-Path $applicationRoot 'UBE-IDE-Step7-Tests.UBE'
$runtimeObject = Join-Path $repositoryRoot 'bootstrap\out\bootstrap_runtime.o'
$unicodeRuntimeObject = Join-Path $repositoryRoot 'bootstrap\out\bootstrap_unicode_runtime.o'
$testProgram = Join-Path $outputRoot 'ube-ide-step7-tests.exe'
$testLlvm = Join-Path $outputRoot 'ube-ide-step7-tests.ll'
$deterministicOne = Join-Path $outputRoot 'ube-ide-step7-deterministic-1.ll'
$deterministicTwo = Join-Path $outputRoot 'ube-ide-step7-deterministic-2.ll'
$themeRoot = Join-Path $applicationRoot 'resources\themes'
$lightPath = Join-Path $themeRoot 'light.ube-theme'
$darkPath = Join-Path $themeRoot 'dark.ube-theme'
$highContrastPath = Join-Path $themeRoot 'high-contrast.ube-theme'
$iconSourcePath = Join-Path $applicationRoot 'resources\icons\icon-source.json'
$generatorPath = Join-Path $applicationRoot 'tools\generate-visual-assets.ps1'
$visualSystemPath = Join-Path $applicationRoot 'VISUAL-SYSTEM.md'

$clangCommand = Get-Command clang -ErrorAction SilentlyContinue
$clangPath = if ($null -ne $clangCommand) { $clangCommand.Source } else { 'C:\Program Files\LLVM\bin\clang.exe' }
foreach ($requiredPath in @($compilerPath, $testProject, $runtimeObject, $unicodeRuntimeObject, $lightPath, $darkPath, $highContrastPath, $iconSourcePath, $generatorPath, $visualSystemPath, $clangPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) { throw "Required Step 7 input is missing: $requiredPath" }
}

$clangVersion = @(& $clangPath '--version')[0].ToString()
if ($LASTEXITCODE -ne 0 -or $clangVersion -notmatch '^clang version 23(?:\.|$)') {
    throw "UBE IDE Step 7 requires the verified Clang 23 toolchain; found: $clangVersion"
}
New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
New-Item -ItemType Directory -Path $workRoot -Force | Out-Null

function Read-Theme([string]$Path) {
    $values = [ordered]@{}
    $lines = [IO.File]::ReadAllLines($Path)
    if ($lines.Count -lt 2 -or $lines[0] -ne 'UBE-IDE-Theme 1') { throw "Invalid theme header: $Path" }
    foreach ($line in $lines | Select-Object -Skip 1) {
        if ($line -notmatch '^([A-Za-z][A-Za-z0-9.]*) = "([^"]*)"$') { throw "Malformed theme line in ${Path}: $line" }
        if ($values.Contains($Matches[1])) { throw "Duplicate theme key '$($Matches[1])' in $Path" }
        $values[$Matches[1]] = $Matches[2]
    }
    return $values
}

function Get-LinearComponent([int]$Byte) {
    $value = $Byte / 255.0
    if ($value -le 0.04045) { return $value / 12.92 }
    return [Math]::Pow(($value + 0.055) / 1.055, 2.4)
}

function Get-Luminance([string]$Color) {
    if ($Color -notmatch '^#[0-9A-F]{6}$') { throw "Invalid canonical RGB color: $Color" }
    $r = Get-LinearComponent ([Convert]::ToInt32($Color.Substring(1, 2), 16))
    $g = Get-LinearComponent ([Convert]::ToInt32($Color.Substring(3, 2), 16))
    $b = Get-LinearComponent ([Convert]::ToInt32($Color.Substring(5, 2), 16))
    return 0.2126 * $r + 0.7152 * $g + 0.0722 * $b
}

function Get-Contrast([string]$Foreground, [string]$Background) {
    $first = Get-Luminance $Foreground
    $second = Get-Luminance $Background
    $light = [Math]::Max($first, $second)
    $dark = [Math]::Min($first, $second)
    return ($light + 0.05) / ($dark + 0.05)
}

$themes = @{}
foreach ($path in @($lightPath, $darkPath, $highContrastPath)) {
    $theme = Read-Theme $path
    $themes[$theme.Identity] = $theme
}
if ($themes.Count -ne 3) { throw 'Light, dark, and high-contrast identities must all be unique.' }
$requiredColorKeys = @('Color.Canvas','Color.Panel','Color.Editor','Color.Text','Color.MutedText','Color.Border','Color.Selection','Color.SelectionText','Color.Focus','Color.Diagnostic','Color.Success','Color.Warning','Color.Error','Color.DebugCurrent','Color.DebugChanged','Syntax.Keyword','Syntax.Type','Syntax.String','Syntax.Number','Syntax.Comment','Syntax.Procedure','Syntax.Constant','Syntax.Operator','Syntax.Identifier')
$syntaxKeys = @($requiredColorKeys | Where-Object { $_ -like 'Syntax.*' })
foreach ($entry in $themes.GetEnumerator()) {
    $theme = $entry.Value
    foreach ($key in $requiredColorKeys) {
        if (-not $theme.Contains($key)) { throw "Theme '$($entry.Key)' lacks $key." }
    }
    $textPairs = @(
        @('Color.Text','Color.Editor'), @('Color.MutedText','Color.Editor'),
        @('Color.SelectionText','Color.Selection')
    )
    foreach ($pair in $textPairs) {
        $ratio = Get-Contrast $theme[$pair[0]] $theme[$pair[1]]
        if ($ratio -lt 4.5) { throw "Theme '$($entry.Key)' contrast $($pair[0])/$($pair[1]) is $ratio; expected 4.5." }
    }
    foreach ($key in $syntaxKeys) {
        $ratio = Get-Contrast $theme[$key] $theme['Color.Editor']
        if ($ratio -lt 4.5) { throw "Theme '$($entry.Key)' syntax contrast $key is $ratio; expected 4.5." }
    }
    foreach ($key in @('Color.Border','Color.Focus','Color.Diagnostic','Color.Success','Color.Warning','Color.Error','Color.DebugCurrent','Color.DebugChanged')) {
        $ratio = Get-Contrast $theme[$key] $theme['Color.Panel']
        if ($ratio -lt 3.0) { throw "Theme '$($entry.Key)' state contrast $key is $ratio; expected 3.0." }
    }
}
Write-Output 'All semantic, syntax, selection, focus, and state contrast gates passed.'

& $compilerPath '--build-native' $testProject 'x86_64-w64-windows-gnu' $clangPath $runtimeObject $unicodeRuntimeObject $testProgram $testLlvm
if ($LASTEXITCODE -ne 0) { throw "Compiler v3 RP8 failed to build the Step 7 visual-system tests (exit $LASTEXITCODE)." }
& $compilerPath '--emit-llvm' $testProject 'x86_64-w64-windows-gnu' $deterministicOne
if ($LASTEXITCODE -ne 0) { throw 'The first deterministic Step 7 emission failed.' }
& $compilerPath '--emit-llvm' $testProject 'x86_64-w64-windows-gnu' $deterministicTwo
if ($LASTEXITCODE -ne 0) { throw 'The second deterministic Step 7 emission failed.' }
$firstHash = (Get-FileHash -LiteralPath $deterministicOne -Algorithm SHA256).Hash
$secondHash = (Get-FileHash -LiteralPath $deterministicTwo -Algorithm SHA256).Hash
if ($firstHash -ne $secondHash) { throw 'Repeated Step 7 LLVM emission was not byte-identical.' }
Write-Output "Step 7 deterministic LLVM SHA-256: $firstHash"
$modelOutput = @(& $testProgram $lightPath $darkPath $highContrastPath)
$modelStatus = $LASTEXITCODE
$modelOutput | ForEach-Object { Write-Output $_ }
if ($modelStatus -ne 0 -or $modelOutput.Count -eq 0 -or $modelOutput[-1] -notmatch '^STEP7 PASS [0-9]+$') {
    throw "UBE Step 7 visual-system verification failed (exit $modelStatus)."
}

$generatedOne = Join-Path $workRoot 'assets-one'
$generatedTwo = Join-Path $workRoot 'assets-two'
& $generatorPath -OutputRoot $generatedOne
& $generatorPath -OutputRoot $generatedTwo
$manifestOne = Get-Content -Raw -LiteralPath (Join-Path $generatedOne 'icon-manifest.sha256')
$manifestTwo = Get-Content -Raw -LiteralPath (Join-Path $generatedTwo 'icon-manifest.sha256')
if ($manifestOne -cne $manifestTwo) { throw 'Repeated icon generation was not byte-identical.' }
$generatedIcons = @(Get-ChildItem -LiteralPath (Join-Path $generatedOne 'icons') -Filter '*.svg' -Recurse)
if ($generatedIcons.Count -ne 100) { throw "Expected 100 generated icon assets; found $($generatedIcons.Count)." }
foreach ($icon in $generatedIcons) {
    try { [xml](Get-Content -Raw -LiteralPath $icon.FullName) | Out-Null } catch { throw "Generated icon is not valid SVG XML: $($icon.FullName)" }
}
Write-Output 'Core icon family generated byte-identically at 16, 20, 24, and 32 px.'

$references = @(Get-ChildItem -LiteralPath (Join-Path $applicationRoot 'resources\visual') -Filter '*.svg')
if ($references.Count -ne 3) { throw "Expected Code, Design, and Debug reference screens; found $($references.Count)." }
$presentations = @()
$referenceThemes = @()
foreach ($reference in $references) {
    [xml]$svg = Get-Content -Raw -LiteralPath $reference.FullName
    $root = $svg.DocumentElement
    if ($root.width -ne '1200' -or $root.height -ne '760' -or -not $root.GetAttribute('role')) { throw "Reference screen is incomplete: $($reference.Name)" }
    $presentations += $root.GetAttribute('data-presentation')
    $referenceThemes += $root.GetAttribute('data-theme')
}
if (@($presentations | Sort-Object -Unique) -join ',' -ne 'Code,Debug,Design') { throw 'Reference screens do not cover Code, Design, and Debug.' }
if (@($referenceThemes | Sort-Object -Unique) -join ',' -ne 'dark,high-contrast,light') { throw 'Reference screens do not cover all three palettes.' }
$referenceText = $references | ForEach-Object { Get-Content -Raw -LiteralPath $_.FullName }
if (($referenceText -join "`n") -notmatch 'direction="rtl"' -or ($referenceText -join "`n") -notmatch 'Project-local customization') {
    throw 'Reference screens lack long-label or bidirectional typography fixtures.'
}
Write-Output 'Code, Design, and Debug reference screens passed structure and typography coverage.'
Write-Output 'UBE IDE Step 7 visual system verification passed.'
