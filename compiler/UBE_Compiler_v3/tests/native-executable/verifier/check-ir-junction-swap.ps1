param([Parameter(Mandatory=$true)][string] $Clang,
      [Parameter(Mandatory=$true)][string] $OutputDirectory,
      [string] $JunctionGuard)
$ErrorActionPreference = 'Stop'
$clang = (Resolve-Path -LiteralPath $Clang).Path
$valid = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot 'valid.ll')).Path
$invalid = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot 'invalid-dominance.ll')).Path
$root = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
$first = Join-Path $root 'first'; $second = Join-Path $root 'second'
[IO.Directory]::CreateDirectory($first) | Out-Null; [IO.Directory]::CreateDirectory($second) | Out-Null
[IO.File]::Copy($valid, (Join-Path $first 'module.ll'))
[IO.File]::Copy($invalid, (Join-Path $second 'module.ll'))
$junction = Join-Path $root 'selected'; $moved = Join-Path $root 'selected-old'
New-Item -ItemType Junction -Path $junction -Target $first | Out-Null
$selected = Join-Path $junction 'module.ll'
function Compile-Module([string] $name) {
    $object = Join-Path $root "$name.o"
    $process = [Diagnostics.Process]::new()
    $process.StartInfo.FileName = $clang
    $process.StartInfo.Arguments = '--target=x86_64-w64-windows-gnu -O2 -Wno-override-module -Xclang -llvm-verify-each -c -x ir "' + $selected + '" -o "' + $object + '"'
    $process.StartInfo.UseShellExecute = $false; $process.StartInfo.CreateNoWindow = $true
    $process.StartInfo.RedirectStandardOutput = $true; $process.StartInfo.RedirectStandardError = $true
    try {
        if (-not $process.Start()) { throw 'Clang did not start' }
        $stdout = $process.StandardOutput.ReadToEndAsync(); $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(10000)) { $process.Kill(); $process.WaitForExit(); throw 'Clang timed out' }
        $null = $stdout.Result
        return @{ Status=$process.ExitCode; Error=$stderr.Result; Object=$object }
    } finally { $process.Dispose() }
}
$guard = $null; $guardProcess = $null; $guardStarted = $false; $ready = $null; $release = $null
try {
    if ($JunctionGuard) {
        $guardPath = (Resolve-Path -LiteralPath $JunctionGuard).Path
        $id = [guid]::NewGuid().ToString('N')
        $readyName = 'Local\UBE-ir-junction-ready-' + $id
        $releaseName = 'Local\UBE-ir-junction-release-' + $id
        $ready = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $readyName)
        $release = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $releaseName)
        $guardProcess = [Diagnostics.Process]::new()
        $guardProcess.StartInfo.FileName = $guardPath
        $guardProcess.StartInfo.Arguments = '"' + $junction + '" ' + $readyName + ' ' + $releaseName
        $guardProcess.StartInfo.UseShellExecute = $false; $guardProcess.StartInfo.CreateNoWindow = $true
        $guardStarted = $guardProcess.Start()
        if (-not $guardStarted -or -not $ready.WaitOne(5000)) { throw 'Junction guard did not become ready' }
    }
    $guard = [IO.File]::Open($selected, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    $initial = Compile-Module 'initial'
    if ($initial.Status -ne 0 -or -not [IO.File]::Exists($initial.Object)) { throw "Initial guarded compile failed: $($initial.Error)" }
    if ($guardProcess) {
        $moveOutput = @(& $guardPath move $junction $moved)
        if ($LASTEXITCODE -ne 5) { throw "Junction move was not blocked: $moveOutput" }
        $stillValid = Compile-Module 'still-valid'
        if ($stillValid.Status -ne 0 -or -not [IO.File]::Exists($stillValid.Object)) { throw 'Guarded junction no longer resolved to valid IR' }
        $release.Set() | Out-Null
        if (-not $guardProcess.WaitForExit(5000) -or $guardProcess.ExitCode -ne 0) { throw 'Junction guard did not exit cleanly' }
    }
    [IO.Directory]::Move($junction, $moved)
    New-Item -ItemType Junction -Path $junction -Target $second | Out-Null
    $substituted = Compile-Module 'substituted'
    if ($substituted.Status -eq 0 -or $substituted.Error -notmatch 'Instruction does not dominate all uses' -or [IO.File]::Exists($substituted.Object)) { throw 'Substituted invalid IR was not observed' }
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $held = ([BitConverter]::ToString($sha.ComputeHash($guard))).Replace('-','') } finally { $sha.Dispose() }
    if ($held -ne (Get-FileHash -LiteralPath $valid).Hash -or (Get-FileHash -LiteralPath $selected).Hash -ne (Get-FileHash -LiteralPath $invalid).Hash) { throw 'Held and selected file identities did not separate as expected' }
    if ($guardProcess) { Write-Output 'Junction guard blocked swap and valid IR compiled; after release the swap redirected Clang to invalid IR.' }
    else { Write-Output 'Held valid IR remained unchanged while a parent junction swap redirected Clang to invalid IR.' }
} finally {
    if ($guard) { $guard.Dispose() }
    if ($release) { $release.Set() | Out-Null }
    if ($guardProcess) { if ($guardStarted -and -not $guardProcess.HasExited -and -not $guardProcess.WaitForExit(5000)) { $guardProcess.Kill(); $guardProcess.WaitForExit() }; $guardProcess.Dispose() }
    if ($ready) { $ready.Dispose() }; if ($release) { $release.Dispose() }
}
