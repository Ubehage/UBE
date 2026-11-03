param([Parameter(Mandatory=$true)][string] $Clang,
      [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot 'guard-size-probe.c'
[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
$sizes = @{}
foreach ($guarded in @($false,$true)) {
    $stem = Join-Path $OutputDirectory ("guard-size-$guarded")
    $flags = @(if ($guarded) { '-DINCLUDE_GUARD' })
    & $Clang --target=x86_64-w64-windows-gnu -std=c17 -O2 @flags -S -emit-llvm $source -o "$stem.ll"
    if ($LASTEXITCODE -ne 0) { throw 'IR generation failed' }
    & $Clang --target=x86_64-w64-windows-gnu -O2 -fstack-usage -c -x ir "$stem.ll" -o "$stem.o"
    if ($LASTEXITCODE -ne 0) { throw 'IR compilation failed' }
    $report = [IO.File]::ReadAllText("$stem.su")
    $entry = [regex]::Match($report, '(?m):target\s+(\d+)\s+static\s*$')
    if (-not $entry.Success) { throw 'Static target report missing' }
    $sizes[$guarded] = [long]$entry.Groups[1].Value
}
function Increased($baseline, $guarded) { return $guarded -gt $baseline }
if (-not (Increased $sizes[$false] $sizes[$true])) { throw 'Guard did not increase the measured test frame' }
if (Increased $sizes[$false] $sizes[$false]) { throw 'Equal-size control was not rejected' }
Write-Output "Unguarded=$($sizes[$false]); guarded=$($sizes[$true]); equal-size control rejected."
