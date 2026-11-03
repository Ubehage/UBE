param([Parameter(Mandatory=$true)][string] $Clang,
      [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
$probe = Join-Path $PSScriptRoot 'stack-metadata-probe.c'
$driver = Join-Path $PSScriptRoot 'stack-metadata-driver.c'
[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
foreach ($optimization in @('0','2')) {
    $stem = Join-Path $OutputDirectory ("metadata-$optimization")
    & $Clang --target=x86_64-w64-windows-gnu -std=c17 "-O$optimization" -Wall -Wextra -Werror -S -emit-llvm $probe -o "$stem.ll"
    if ($LASTEXITCODE -ne 0) { throw 'IR generation failed' }
    & $Clang --target=x86_64-w64-windows-gnu "-O$optimization" -fno-lto -fstack-usage -c -x ir "$stem.ll" -o "$stem.o"
    if ($LASTEXITCODE -ne 0) { throw 'Object generation failed' }
    $report = [IO.File]::ReadAllText("$stem.su")
    $entry = [regex]::Match($report, '(?m):measured_callee\s+(\d+)\s+static\s*$')
    if (-not $entry.Success) { throw 'Static callee size missing' }
    $frame = [long]$entry.Groups[1].Value
    if ($frame -lt 8192) { throw 'Measured frame is unexpectedly small' }
    $originalHash = (Get-FileHash -LiteralPath "$stem.o" -Algorithm SHA256).Hash
    foreach ($wrong in @($false,$true)) {
        $value = if ($wrong) { $frame + 1 } else { $frame }
        $table = "$stem-table-$wrong.c"; $exe = "$stem-$wrong.exe"
        Set-Content -LiteralPath $table -Encoding Ascii -Value "const unsigned long long required_frame = ${value}ULL;"
        & $Clang --target=x86_64-w64-windows-gnu -std=c17 "-O$optimization" -fno-lto "-DEXPECTED_FRAME=$frame" "$stem.o" $table $driver -o $exe
        if ($LASTEXITCODE -ne 0) { throw 'Test link failed' }
        & (Resolve-Path -LiteralPath $exe).Path
        $expected = if ($wrong) { 1 } else { 0 }
        if ($LASTEXITCODE -ne $expected) { throw 'Unexpected metadata control result' }
        if ((Get-FileHash -LiteralPath "$stem.o" -Algorithm SHA256).Hash -ne $originalHash) { throw 'Measured object changed after link' }
    }
    Write-Output "O$optimization : measured frame $frame; linked value accepted; wrong value rejected; object unchanged."
}
