param(
    [Parameter(Mandatory=$true)][string] $Objdump,
    [Parameter(Mandatory=$true)][string] $Executable,
    [Parameter(Mandatory=$true)][string] $ObjectFile,
    [Parameter(Mandatory=$true)][string] $OutputDirectory
)
$ErrorActionPreference = 'Stop'
$tool = (Resolve-Path -LiteralPath $Objdump).Path
$executable = (Resolve-Path -LiteralPath $Executable).Path
$objectFile = (Resolve-Path -LiteralPath $ObjectFile).Path
$directory = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($directory) | Out-Null
$candidate = Join-Path $directory 'candidate.exe'
$original = Join-Path $directory 'original.exe'
[IO.File]::Copy($executable, $candidate)
$guard = [IO.File]::Open($candidate, [IO.FileMode]::Open, [IO.FileAccess]::Read, ([IO.FileShare]::Read -bor [IO.FileShare]::Delete))
function Invoke-Inspection([IO.Stream] $inputStream) {
    $process = [Diagnostics.Process]::new()
    $process.StartInfo.FileName = $tool
    $process.StartInfo.Arguments = '-f -'
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.CreateNoWindow = $true
    $process.StartInfo.RedirectStandardInput = $true
    $process.StartInfo.RedirectStandardOutput = $true
    $process.StartInfo.RedirectStandardError = $true
    if (-not $process.Start()) { throw 'Inspector did not start' }
    try {
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        $copy = $inputStream.CopyToAsync($process.StandardInput.BaseStream)
        if (-not $copy.Wait(10000)) { $process.Kill(); $process.WaitForExit(); throw 'Inspector input copy timed out' }
        $process.StandardInput.Close()
        if (-not $process.WaitForExit(10000)) { $process.Kill(); $process.WaitForExit(); throw 'Inspector timed out' }
        return @{ status = $process.ExitCode; stdout = $stdout.Result; stderr = $stderr.Result }
    } finally {
        if (-not $process.HasExited) { $process.Kill(); $process.WaitForExit() }
        $process.Dispose()
    }
}
try {
    [IO.File]::Move($candidate, $original)
    [IO.File]::WriteAllText($candidate, 'not an executable')
    $blocked = $false
    try {
        $writer = [IO.File]::Open($original, [IO.FileMode]::Open, [IO.FileAccess]::Write, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
        $writer.Dispose()
    } catch [IO.IOException] { $blocked = $true }
    if (-not $blocked) { throw 'Guard did not prevent a new write to the original' }
    $good = Invoke-Inspection $guard
    if ($good.status -ne 0 -or $good.stdout -notmatch 'file format coff-x86-64' -or $good.stdout -notmatch 'architecture: x86_64') { throw "Guarded executable was not recognized: $($good.stderr)" }
    $substitute = [IO.File]::OpenRead($candidate)
    try { $bad = Invoke-Inspection $substitute } finally { $substitute.Dispose() }
    if ($bad.status -eq 0) { throw 'Invalid substituted input was accepted' }
    $object = [IO.File]::OpenRead($objectFile)
    try { $notExecutable = Invoke-Inspection $object } finally { $object.Dispose() }
    if ($notExecutable.status -ne 0 -or $notExecutable.stdout -notmatch 'file format coff-x86-64' -or $notExecutable.stdout -notmatch 'architecture: x86_64') { throw 'Object-file control did not demonstrate format-check ambiguity' }
    Write-Output 'Inspector recognized the guarded executable and rejected invalid bytes; its format check also accepted an object file.'
} finally { $guard.Dispose() }
