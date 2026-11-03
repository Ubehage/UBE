param([Parameter(Mandatory=$true)][string] $Guard, [Parameter(Mandatory=$true)][string] $OutputDirectory, [switch] $Prewrite)
$ErrorActionPreference = 'Stop'
$guardPath = (Resolve-Path -LiteralPath $Guard).Path
$root = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
$target = Join-Path $root 'target'
$junction = Join-Path $root 'active'
[IO.Directory]::CreateDirectory($target) | Out-Null
New-Item -ItemType Junction -Path $junction -Target $target | Out-Null
$id = [guid]::NewGuid().ToString('N')
$names = @('pre-ready', 'pre-release', 'guard-ready', 'guard-release') | ForEach-Object { 'Local\UBE-' + $_ + '-' + $id }
$events = @($names | ForEach-Object { [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $_) })
function New-Probe([string] $arguments) {
    $process = [Diagnostics.Process]::new()
    $process.StartInfo.FileName = $guardPath
    $process.StartInfo.Arguments = $arguments
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.CreateNoWindow = $true
    $process.StartInfo.RedirectStandardError = $true
    return $process
}
$actorMode = if ($Prewrite) { 'prewrite' } else { 'preopen' }
$actor = New-Probe ($actorMode + ' "' + $junction + '" ' + $names[0] + ' ' + $names[1])
$first = New-Probe ('"' + $junction + '" ' + $names[2] + ' ' + $names[3])
$second = New-Probe ('"' + $junction + '" ' + $names[2] + ' ' + $names[3])
$started = @()
try {
    if (-not $actor.Start()) { throw 'Actor did not start' }; $started += $actor
    if (-not $events[0].WaitOne(5000)) { throw 'Actor did not acquire its handle' }
    if (-not $first.Start()) { throw 'First guard did not start' }; $started += $first
    if (-not $first.WaitForExit(5000)) { throw 'First guard did not fail promptly' }
    $firstError = $first.StandardError.ReadToEnd()
    if ($first.ExitCode -ne 1 -or $firstError -notmatch 'open junction failed: 32' -or $events[2].WaitOne(0)) {
        throw "Unexpected first guard result: $($first.ExitCode) $firstError"
    }
    $events[1].Set() | Out-Null
    if (-not $actor.WaitForExit(5000) -or $actor.ExitCode -ne 0) { throw 'Actor did not release its handle' }
    if (-not $second.Start()) { throw 'Second guard did not start' }; $started += $second
    if (-not $events[2].WaitOne(5000)) { throw 'Guard failed to acquire after actor release' }
    $events[3].Set() | Out-Null
    if (-not $second.WaitForExit(5000) -or $second.ExitCode -ne 0) { throw 'Second guard failed' }
    Write-Output "Pre-existing $actorMode handle blocked guard acquisition; guard succeeded after release: $root"
} finally {
    $events[1].Set() | Out-Null; $events[3].Set() | Out-Null
    foreach ($process in $started) { if (-not $process.WaitForExit(10000)) { $process.Kill(); $process.WaitForExit() } }
    $actor.Dispose(); $first.Dispose(); $second.Dispose()
    foreach ($event in $events) { $event.Dispose() }
}
