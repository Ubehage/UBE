param([Parameter(Mandatory=$true)][string] $Probe, [Parameter(Mandatory=$true)][string] $Writer, [Parameter(Mandatory=$true)][string] $OutputDirectory,
      [ValidateSet('native-sourceguard', 'native-reopen')][string] $Mode = 'native-sourceguard')
$ErrorActionPreference = 'Stop'
$probePath = (Resolve-Path -LiteralPath $Probe).Path
$writerPath = (Resolve-Path -LiteralPath $Writer).Path
$directory = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($directory) | Out-Null
$candidate = Join-Path $directory 'candidate.bin'; $destination = Join-Path $directory 'destination.bin'
[IO.File]::WriteAllText($candidate, 'candidate'); [IO.File]::WriteAllText($destination, 'old')
$id = [guid]::NewGuid().ToString('N')
$names = @('writer-ready', 'writer-release', 'guard-ready', 'guard-release') | ForEach-Object { 'Local\UBE-native-map-' + $_ + '-' + $id }
$events = @($names | ForEach-Object { [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $_) })
function New-Probe([string] $path, [string] $arguments) {
    $process = [Diagnostics.Process]::new()
    $process.StartInfo.FileName = $path; $process.StartInfo.Arguments = $arguments
    $process.StartInfo.UseShellExecute = $false; $process.StartInfo.CreateNoWindow = $true
    return $process
}
$writerProcess = New-Probe $writerPath ('"' + $candidate + '" ' + $names[0] + ' ' + $names[1])
$guard = New-Probe $probePath ('"' + $directory + '" ' + $Mode + ' ' + $names[2] + ' ' + $names[3])
$guard.StartInfo.RedirectStandardError = $true
$started = @()
try {
    if (-not $writerProcess.Start()) { throw 'Writer did not start' }; $started += $writerProcess
    if (-not $events[0].WaitOne(5000)) { throw 'Writable view not ready' }
    if (-not $guard.Start()) { throw 'Guard did not start' }; $started += $guard
    $acquired = $events[2].WaitOne(2000)
    if (-not $acquired -and (-not $guard.WaitForExit(5000) -or $guard.ExitCode -ne 5)) { throw 'Unexpected guard failure' }
    $guardError = if (-not $acquired) { $guard.StandardError.ReadToEnd().Trim() } else { '' }
    $events[1].Set() | Out-Null
    if (-not $writerProcess.WaitForExit(5000) -or $writerProcess.ExitCode -ne 0) { throw 'Mapped write failed' }
    if ($acquired) {
        $events[3].Set() | Out-Null
        if (-not $guard.WaitForExit(5000)) { throw 'Guard did not finish' }
        if ($guard.ExitCode -eq 0) {
            if ([IO.File]::ReadAllText($destination) -ne 'TAMPERED!') { throw 'Wrong published bytes' }
            Write-Output 'Writable view changed candidate after guard; changed bytes were renamed.'
        } else {
            if ([IO.File]::ReadAllText($destination) -ne 'old') { throw 'Failed rename changed destination' }
            Write-Output "Guard acquired but rename failed after mapped write: $($guard.ExitCode)"
        }
    } else {
        if ([IO.File]::ReadAllText($candidate) -ne 'TAMPERED!' -or [IO.File]::ReadAllText($destination) -ne 'old') { throw 'Unexpected bytes after rejected guard' }
        [IO.File]::WriteAllText($candidate, 'candidate')
        $control = @(& $probePath $directory $Mode 2>&1)
        if ($LASTEXITCODE -ne 0 -or [IO.File]::ReadAllText($destination) -ne 'candidate') { throw "Post-mapping control failed: $control" }
        Write-Output "Guard open failed ($guardError) while writable view existed; succeeded after view closed."
    }
} finally {
    $events[1].Set() | Out-Null; $events[3].Set() | Out-Null
    foreach ($process in $started) { if (-not $process.WaitForExit(10000)) { $process.Kill(); $process.WaitForExit() } }
    $writerProcess.Dispose(); $guard.Dispose(); foreach ($event in $events) { $event.Dispose() }
}
