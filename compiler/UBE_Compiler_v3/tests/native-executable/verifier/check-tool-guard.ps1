param([Parameter(Mandatory=$true)][string] $Executable,
      [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
$source = (Resolve-Path -LiteralPath $Executable).Path
$directory = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($directory) | Out-Null
$tool = Join-Path $directory 'tool.exe'
$moved = Join-Path $directory 'moved.exe'
[IO.File]::Copy($source, $tool)
$writer = [IO.File]::Open($tool, [IO.FileMode]::Open, [IO.FileAccess]::Write, [IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete)
try {
    $denied = $false
    try {
        $unexpected = [IO.File]::Open($tool, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
        $unexpected.Dispose()
    } catch [IO.IOException] { $denied = $true }
    if (-not $denied) { throw 'Guard was acquired while a writer was open' }
} finally { $writer.Dispose() }
$guard = [IO.File]::Open($tool, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
try {
    $blocked = $false
    try { [IO.File]::Move($tool, $moved) } catch [IO.IOException] { $blocked = $true }
    if (-not $blocked -or -not [IO.File]::Exists($tool)) { throw 'Guard did not block moving the tool name' }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo.FileName = $tool
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.CreateNoWindow = $true
    $process.StartInfo.RedirectStandardOutput = $true
    if (-not $process.Start()) { throw 'Guarded tool could not start' }
    try {
        $output = $process.StandardOutput.ReadToEndAsync()
        if (-not $process.WaitForExit(10000)) { $process.Kill(); $process.WaitForExit(); throw 'Guarded tool timed out' }
        if ($process.ExitCode -ne 0 -or $output.Result.Trim() -ne '36') { throw 'Guarded tool produced an unexpected result' }
    } finally { $process.Dispose() }
} finally { $guard.Dispose() }
[IO.File]::Move($tool, $moved)
if (-not [IO.File]::Exists($moved)) { throw 'Tool move failed after guard release' }
Write-Output 'Pre-existing writer blocked guard; guarded tool launched; move blocked until guard release.'
