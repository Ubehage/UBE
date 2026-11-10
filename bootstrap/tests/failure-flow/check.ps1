param([string]$Clang = 'C:\Program Files\LLVM\bin\clang.exe')
$ErrorActionPreference = 'Stop'
# Runs one child with bounded execution, file-backed diagnostics and a hidden window.
function Invoke-Bounded([string]$File, [string]$Arguments, [string]$Prefix) {
    $start = @{ FilePath=$File; PassThru=$true; WindowStyle='Hidden'; RedirectStandardOutput=($Prefix + '.out'); RedirectStandardError=($Prefix + '.err') }
    if ($Arguments) { $start.ArgumentList = $Arguments }
    $process = Start-Process @start
    try {
        # Retain a process handle so fast-exiting children still expose ExitCode.
        $process.Handle | Out-Null
        if (-not $process.WaitForExit(30000)) { $process.Kill(); throw "Timed out: $File" }
        $process.WaitForExit()
        return $process.ExitCode
    } finally { $process.Dispose() }
}
# Builds target test IR and verifies its PE signature and x64 machine type.
function Build-Probe([string]$Source, [string]$Destination, [string]$Optimization) {
    $arguments = "--target=x86_64-pc-windows-msvc -fuse-ld=lld -nostdlib $Optimization `"$Source`" -o `"$Destination`" -Wl,/entry:main,/subsystem:console"
    $code = Invoke-Bounded $Clang $arguments ($Destination + '.build')
    if ($code -ne 0) { throw "LLVM build failed ($code): $(Get-Content ($Destination + '.build.err') -Raw)" }
    $bytes = [IO.File]::ReadAllBytes($Destination)
    if ($bytes.Length -lt 64) { throw 'Truncated PE header.' }
    $offset = [BitConverter]::ToInt32($bytes, 0x3c)
    if ($offset -lt 0 -or $offset -gt $bytes.Length - 6) { throw 'Invalid PE header offset.' }
    if ([BitConverter]::ToUInt32($bytes, $offset) -ne 0x4550 -or [BitConverter]::ToUInt16($bytes, $offset + 4) -ne 0x8664) { throw 'Expected PE x64 executable.' }
}
$output = Join-Path ([IO.Path]::GetTempPath()) ('ube-failure-flow-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $output | Out-Null
Write-Output "Artifacts: $output"
$versionCode = Invoke-Bounded $Clang '--version' (Join-Path $output 'clang-version')
if ($versionCode -ne 0) { throw 'Cannot identify LLVM toolchain.' }
$version = Get-Content (Join-Path $output 'clang-version.out') -Raw
Write-Output $version
if ($version -notmatch '^clang version 23\.1\.3\b') { throw 'This experiment is qualified for Clang 23.1.3; review another version before updating the gate.' }
$source = Join-Path $PSScriptRoot 'probe.ll'
foreach ($level in @('O0','O2')) {
    $exe = Join-Path $output ($level + '.exe')
    Build-Probe $source $exe ('-' + $level)
    $code = Invoke-Bounded $exe '' ($exe + '.run')
    if ($code -ne 0) { throw "$level failed; assertion bit mask: $code (see README.md)." }
    Write-Output "PASS $level`: x64 PE and all eight behavioral assertions (exit 0)."
}
# Negative controls demonstrate that the oracle rejects a false success and a bad failure edge.
$original = Get-Content -LiteralPath $source -Raw
$mutations = @(
    @{ Name='false-success'; Before='ret i1 false ; RAISE_RETURN'; After='ret i1 true ; RAISE_RETURN'; Expected=158 },
    @{ Name='failed-assignment'; Before='br i1 %ok, label %commit, label %next_statement ; DEFAULT_BRANCH'; After='br i1 %ok, label %commit, label %commit ; DEFAULT_BRANCH'; Expected=4 }
)
foreach ($mutation in $mutations) {
    if (-not $original.Contains($mutation.Before)) { throw "Missing negative-control site: $($mutation.Name)" }
    $mutated = Join-Path $output ($mutation.Name + '.ll')
    $original.Replace($mutation.Before, $mutation.After) | Set-Content -LiteralPath $mutated -Encoding ASCII
    $exe = Join-Path $output ($mutation.Name + '.exe')
    Build-Probe $mutated $exe '-O2'
    $code = Invoke-Bounded $exe '' ($exe + '.run')
    if ($code -ne $mutation.Expected) { throw "Negative control $($mutation.Name) expected mask $($mutation.Expected), received $code." }
    Write-Output "PASS negative control $($mutation.Name): rejected with exact mask $code."
}
Write-Output 'PASS: target failure-flow feasibility only; not UBE compiler conformance.'
