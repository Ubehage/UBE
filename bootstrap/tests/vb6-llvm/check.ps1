param(
    [string]$VB6 = 'C:\Program Files (x86)\Microsoft Visual Studio\VB98\VB6.EXE',
    [string]$Clang = 'C:\Program Files\LLVM\bin\clang.exe'
)
$ErrorActionPreference = 'Stop'
# Runs a child with a bounded wait so a tool failure cannot hang the gate.
function Invoke-ProbeProcess([string]$File, [string]$Arguments) {
    $start = @{ FilePath = $File; PassThru = $true; WindowStyle = 'Hidden' }
    if ($Arguments) { $start.ArgumentList = $Arguments }
    $process = Start-Process @start
    if (-not $process.WaitForExit(30000)) {
        $process.Kill()
        throw "Timed out: $File"
    }
    $process.Refresh()
    return $process.ExitCode
}
$output = Join-Path ([IO.Path]::GetTempPath()) ('ube-vb6-probe-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $output | Out-Null
$project = Join-Path $PSScriptRoot 'Emitter.vbp'
$log = Join-Path $output 'build.log'
$hostExe = Join-Path $output 'BootstrapProbe.exe'
$ir = Join-Path $output 'result.ll'
$targetExe = Join-Path $output 'result.exe'
Write-Output "Artifacts: $output"
Write-Output "VB6 version: $((Get-Item -LiteralPath $VB6).VersionInfo.FileVersion)"
& $Clang --version
$code = Invoke-ProbeProcess $VB6 "/make `"$project`" /out `"$log`" /outdir `"$output`""
if (Test-Path -LiteralPath $log) { Get-Content -LiteralPath $log }
if (-not (Test-Path -LiteralPath $hostExe)) { throw "VB6 produced no executable (exit $code)." }
$code = Invoke-ProbeProcess $hostExe $ir
if ($code -ne 0 -or -not (Test-Path -LiteralPath $ir)) { throw "IR emission failed: $code" }
$code = Invoke-ProbeProcess $hostExe (Join-Path $output 'absent/result.ll')
if ($code -ne 3) { throw "Invalid path must return 3, received $code" }
& $Clang --target=x86_64-pc-windows-msvc -fuse-ld=lld -nostdlib $ir -o $targetExe '-Wl,/entry:main,/subsystem:console'
if ($LASTEXITCODE -ne 0) { throw 'LLVM build failed.' }
$bytes = [IO.File]::ReadAllBytes($targetExe)
$peOffset = [BitConverter]::ToInt32($bytes, 0x3c)
if ([BitConverter]::ToUInt32($bytes, $peOffset) -ne 0x4550 -or
    [BitConverter]::ToUInt16($bytes, $peOffset + 4) -ne 0x8664) { throw 'Expected x64 PE executable.' }
$code = Invoke-ProbeProcess $targetExe ''
if ($code -ne 42) { throw "Native program must return 42, received $code" }
Write-Output 'PASS: VB6 emission, controlled invalid-path failure, x64 PE machine, native exit 42.'
