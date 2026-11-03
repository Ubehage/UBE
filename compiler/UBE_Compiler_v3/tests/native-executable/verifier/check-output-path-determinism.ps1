param([Parameter(Mandatory=$true)][string] $Clang,
      [Parameter(Mandatory=$true)][string] $Readobj,
      [Parameter(Mandatory=$true)][string] $Linker,
      [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$clangPath = (Resolve-Path -LiteralPath $Clang).Path
$readobjPath = (Resolve-Path -LiteralPath $Readobj).Path
$linkerPath = (Resolve-Path -LiteralPath $Linker).Path
$source = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot 'link-determinism.c')).Path
$root = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
$first = Join-Path $root 'candidate one'; $second = Join-Path $root 'candidate two'
[IO.Directory]::CreateDirectory($first) | Out-Null
[IO.Directory]::CreateDirectory($second) | Out-Null
function Build-IR([string] $Ir, [string] $Object, [string] $Exe) {
    & $clangPath --target=x86_64-w64-windows-gnu -O2 -mno-incremental-linker-compatible -Xclang -llvm-verify-each -c -x ir $Ir -o $Object
    if ($LASTEXITCODE -ne 0 -or -not [IO.File]::Exists($Object)) { throw 'LLVM object compilation failed' }
    & $clangPath --target=x86_64-w64-windows-gnu "--ld-path=$linkerPath" $Object '-Wl,--no-insert-timestamp' '-Wl,--subsystem,console' -o $Exe
    if ($LASTEXITCODE -ne 0 -or -not [IO.File]::Exists($Exe)) { throw 'Object link failed' }
}
function Assert-Exit([string] $Path, [int] $Expected) {
    $process = [Diagnostics.Process]::new()
    $process.StartInfo.FileName = $Path
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.CreateNoWindow = $true
    try {
        if (-not $process.Start()) { throw 'Test executable did not start' }
        if (-not $process.WaitForExit(10000)) { $process.Kill(); $process.WaitForExit(); throw 'Test executable timed out' }
        if ($process.ExitCode -ne $Expected) { throw "Expected $Expected, observed $($process.ExitCode)" }
    } finally { $process.Dispose() }
}
$report = @()
foreach ($mode in @('Full', 'None')) {
    $irHashes = @(); $exeHashes = @(); $objectHashes = @()
    foreach ($directory in @($first, $second)) {
        $ir = Join-Path $directory "$mode.ll"
        $object = Join-Path $directory "$mode.o"
        $exe = Join-Path $directory "$mode.exe"
        $debugFlags = @(if ($mode -eq 'Full') { '-g'; '-gdwarf-4' } else { '-g0' })
        & $clangPath --target=x86_64-w64-windows-gnu -O2 @debugFlags -S -emit-llvm $source -o $ir
        if ($LASTEXITCODE -ne 0 -or -not [IO.File]::Exists($ir)) { throw 'LLVM generation failed' }
        $llvm = [IO.File]::ReadAllText($ir)
        if ($mode -eq 'Full') {
            if ($llvm -notmatch '!DIFile\(' -or $llvm -notmatch '!DILocation\(' -or $llvm -notmatch 'link-determinism\.c') { throw 'Expected source metadata missing' }
        } elseif ($llvm -match '!DI(?:Location|Subprogram)\(' -or $llvm -notmatch 'emissionKind: NoDebug') { throw 'Unexpected None debug emission' }
        Build-IR $ir $object $exe
        $objectBytes = [IO.File]::ReadAllBytes($object)
        if ($objectBytes.Length -lt 20 -or [BitConverter]::ToUInt16($objectBytes, 0) -ne 0x8664 -or [BitConverter]::ToUInt32($objectBytes, 4) -ne 0) { throw 'Expected x86-64 COFF object with zero timestamp' }
        $sections = (& $readobjPath --sections $exe) -join "`n"
        if ($LASTEXITCODE -ne 0) { throw 'Section reader failed' }
        if ($mode -eq 'Full' -and ($sections -notmatch 'Name: \.debug_info' -or $sections -notmatch 'Name: \.debug_line')) { throw 'Debug sections missing' }
        $bytes = [IO.File]::ReadAllBytes($exe)
        if ($bytes.Length -lt 64) { throw 'Truncated executable control' }
        $offset = [BitConverter]::ToUInt32($bytes, 0x3c)
        if ([long]$offset + 12 -gt $bytes.Length -or [BitConverter]::ToUInt32($bytes, [int]$offset) -ne 0x4550) { throw 'Bad PE header' }
        if ([BitConverter]::ToUInt32($bytes, [int]$offset + 8) -ne 0) { throw 'Nonzero PE timestamp' }
        Assert-Exit $exe 7
        $irHashes += (Get-FileHash -LiteralPath $ir -Algorithm SHA256).Hash
        $objectHashes += (Get-FileHash -LiteralPath $object -Algorithm SHA256).Hash
        $exeHashes += (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash
        if ($directory -eq $first) { Start-Sleep -Milliseconds 1100 }
    }
    if ($irHashes[0] -ne $irHashes[1] -or $objectHashes[0] -ne $objectHashes[1] -or $exeHashes[0] -ne $exeHashes[1]) { throw "$mode output-path repeatability comparison failed" }

    # Changing only the LLVM value proves the link consumes the emitted object,
    # rather than accidentally recompiling the unchanged C source (still 7).
    $originalIr = [IO.File]::ReadAllText((Join-Path $first "$mode.ll"))
    $pattern = '(?m)^(@value\s*=\s*internal\s+global\s+i32\s+)7(?=,)'
    if ([regex]::Matches($originalIr, $pattern).Count -ne 1) { throw 'Unexpected LLVM control initializer' }
    $controlIr = Join-Path $root "$mode-mutated.ll"
    [IO.File]::WriteAllText($controlIr, [regex]::Replace($originalIr, $pattern, '${1}9'), [Text.UTF8Encoding]::new($false))
    $controlExe = Join-Path $root "$mode-mutated.exe"
    Build-IR $controlIr (Join-Path $root "$mode-mutated.o") $controlExe
    Assert-Exit $controlExe 9
    if ((Get-FileHash -LiteralPath $controlIr).Hash -eq $irHashes[0] -or (Get-FileHash -LiteralPath $controlExe).Hash -eq $exeHashes[0]) { throw 'LLVM behavior mutation not distinguished' }
    $report += [pscustomobject]@{ mode=$mode; llvm=$irHashes; objects=$objectHashes; executables=$exeHashes; expectedExit=7; mutationExit=9 }
    Write-Output "$mode : LLVM, object and executable pairs match; zero timestamps; exits 7 and LLVM-only mutation 9."
}
$identities = @($clangPath, $linkerPath, $readobjPath, $source, $PSCommandPath) | ForEach-Object {
    [pscustomobject]@{ path=$_; sha256=(Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash }
}
[pscustomobject]@{ identities=$identities; results=$report } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $root 'report.json') -Encoding UTF8
Write-Output "Test-owned artifacts and report: $root"
