param([Parameter(Mandatory=$true)][string] $Clang, [Parameter(Mandatory=$true)][string] $Readobj,
      [Parameter(Mandatory=$true)][string] $Executable, [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$clangPath=(Resolve-Path -LiteralPath $Clang).Path
$root=Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($root) | Out-Null
$source=Join-Path $PSScriptRoot 'pe-structure.c'; $comparator=Join-Path $PSScriptRoot 'check-pe-structure.ps1'
foreach ($mode in @('correct','omit-bounds','omit-directory')) {
    $probe=Join-Path $root "$mode.exe"
    $flags=@(if ($mode -eq 'omit-bounds') { '-DOMIT_RAW_BOUNDS' } elseif ($mode -eq 'omit-directory') { '-DOMIT_DIRECTORY_BOUNDS' })
    & $clangPath --target=x86_64-w64-windows-gnu -std=c17 -Wall -Wextra -Werror -municode @flags $source -o $probe
    if ($LASTEXITCODE -ne 0) { throw "Probe compilation failed: $mode" }
    $process=[Diagnostics.Process]::new(); $process.StartInfo.FileName=(Get-Process -Id $PID).Path
    $process.StartInfo.Arguments='-NoProfile -File "' + $comparator + '" -Readobj "' + (Resolve-Path -LiteralPath $Readobj).Path + '" -Executable "' + (Resolve-Path -LiteralPath $Executable).Path + '" -OutputDirectory "' + $root + '" -StructuralProbe "' + $probe + '"'
    $process.StartInfo.UseShellExecute=$false; $process.StartInfo.CreateNoWindow=$true; $process.StartInfo.RedirectStandardOutput=$true; $process.StartInfo.RedirectStandardError=$true
    if (-not $process.Start()) { throw 'Comparator did not start' }
    try {
        $out=$process.StandardOutput.ReadToEndAsync(); $err=$process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(20000)) { $process.Kill(); $process.WaitForExit(); throw 'Comparator timed out' }
        if ($mode -eq 'correct' -and $process.ExitCode -ne 0) { throw "Correct probe failed: $($err.Result)" }
        if ($mode -eq 'omit-bounds' -and ($process.ExitCode -eq 0 -or $err.Result -notmatch 'Structural probe differed for outside-section')) { throw "Missing-bounds mutation was not caught: $($out.Result) $($err.Result)" }
        if ($mode -eq 'omit-directory' -and ($process.ExitCode -eq 0 -or $err.Result -notmatch 'Structural probe differed for directory-count-overflow')) { throw "Missing-directory mutation was not caught: $($out.Result) $($err.Result)" }
        $null=$out.Result
        Write-Output "${mode}: comparator exit=$($process.ExitCode)"
    } finally { $process.Dispose() }
}
Write-Output "Test-owned artifacts: $root"
