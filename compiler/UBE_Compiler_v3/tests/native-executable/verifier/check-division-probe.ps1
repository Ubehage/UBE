param([Parameter(Mandatory=$true)][string] $Clang, [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
$source = Join-Path $PSScriptRoot 'checked-division.ll'
$sourceText = [IO.File]::ReadAllText($source)
$brokenText = $sourceText.Replace('store i32 1, ptr @error_state', 'store i32 0, ptr @error_state')
if ($brokenText -eq $sourceText) { throw 'Error-state mutation did not apply' }
$brokenSource = Join-Path $OutputDirectory 'division-missing-error.ll'
[IO.File]::WriteAllText($brokenSource, $brokenText, (New-Object Text.UTF8Encoding($false)))
$clearedText = $sourceText -replace 'neutral_result:\r?\n  ret i32 0', "neutral_result:`n  store i32 0, ptr @error_state`n  ret i32 0"
if ($clearedText -eq $sourceText) { throw 'Stale-error mutation did not apply' }
$clearedSource = Join-Path $OutputDirectory 'remainder-clears-error.ll'
[IO.File]::WriteAllText($clearedSource, $clearedText, (New-Object Text.UTF8Encoding($false)))
foreach ($level in @('0', '2')) {
    foreach ($case in @(@('normal', $source, 82), @('missing-error', $brokenSource, 99), @('cleared-error', $clearedSource, 99))) {
        $outputPath = Join-Path $OutputDirectory "checked-div-$($case[0])-O$level.exe"
        $output = @(& $Clang --target=x86_64-w64-windows-gnu "-O$level" -Xclang -llvm-verify-each -x ir $case[1] -o $outputPath 2>&1)
        if ($LASTEXITCODE -ne 0) { throw "Clang $($case[0]) O$level failed: $output" }
        & $outputPath
        if ($LASTEXITCODE -ne $case[2]) { throw "$($case[0]) O$level result was $LASTEXITCODE, expected $($case[2])" }
    }
}
Write-Output 'Passed guarded arithmetic and missing/cleared-error controls at O0 and O2.'
