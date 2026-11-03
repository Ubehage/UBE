$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$fixtureRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'fixtures'))
$definitionPath = Join-Path $PSScriptRoot 'expected-results.json'
$definition = Get-Content -LiteralPath $definitionPath -Raw | ConvertFrom-Json
if ($definition.schema -cne 'ube-native-result-oracles-1') { throw 'Wrong oracle schema.' }
$ids = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
$paths = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
foreach ($result in $definition.results) {
    if ($result.id -cnotmatch '^[a-z][a-z0-9-]*$' -or -not $ids.Add([string]$result.id)) { throw "Invalid or duplicate ID: $($result.id)" }
    if ($result.project -cnotmatch '^[a-z][a-z0-9-]*/[A-Za-z][A-Za-z0-9]*\.UBE$') { throw "Invalid project path: $($result.project)" }
    $path = [IO.Path]::GetFullPath((Join-Path $fixtureRoot $result.project))
    if (-not $path.StartsWith($fixtureRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or -not [IO.File]::Exists($path) -or -not $paths.Add($path)) { throw "Missing, duplicate or out-of-root project: $path" }
    if ($result.signedExit -isnot [int] -and $result.signedExit -isnot [long]) { throw "Noninteger exit: $($result.id)" }
    if ([long]$result.signedExit -lt [int]::MinValue -or [long]$result.signedExit -gt [int]::MaxValue) { throw "Exit outside Long: $($result.id)" }
}
$actual = @(Get-ChildItem -LiteralPath $fixtureRoot -Filter '*.UBE' -Recurse -File | Where-Object { $_.Name -cne 'UBECore.UBE' })
if ($actual.Count -ne $paths.Count) { throw "Project/expectation count differs: $($actual.Count) versus $($paths.Count)" }
foreach ($file in $actual) { if (-not $paths.Contains($file.FullName)) { throw "Unlisted project: $($file.FullName)" } }
Write-Output "Oracle definition consistency: $($paths.Count) unique projects; no native behavior checked."
