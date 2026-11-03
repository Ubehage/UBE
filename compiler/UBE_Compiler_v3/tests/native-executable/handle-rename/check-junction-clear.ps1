param([Parameter(Mandatory=$true)][string] $Guard, [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
$guardPath = (Resolve-Path -LiteralPath $Guard).Path
$root = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
$target = Join-Path $root 'target'
$junction = Join-Path $root 'active'
[IO.Directory]::CreateDirectory($target) | Out-Null
[IO.File]::WriteAllText((Join-Path $target 'protected.txt'), 'protected')
New-Item -ItemType Junction -Path $junction -Target $target | Out-Null
$id = [guid]::NewGuid().ToString('N')
$readyName = 'Local\UBE-clear-ready-' + $id
$releaseName = 'Local\UBE-clear-release-' + $id
$ready = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $readyName)
$release = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $releaseName)
$process = [Diagnostics.Process]::new()
try {
    $process.StartInfo.FileName = $guardPath
    $process.StartInfo.Arguments = '"' + $junction + '" ' + $readyName + ' ' + $releaseName
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.CreateNoWindow = $true
    if (-not $process.Start() -or -not $ready.WaitOne(5000)) { throw 'Guard was not ready' }
    $output = @(& $guardPath clear $junction 2>&1)
    $status = $LASTEXITCODE
    if ($status -ne 0 -and $status -ne 5) { throw "Unexpected clear status $status : $output" }
    if ([IO.File]::ReadAllText((Join-Path $target 'protected.txt')) -ne 'protected') { throw 'Target changed' }
    if ($status -eq 0) {
        if ([IO.File]::Exists((Join-Path $junction 'protected.txt'))) { throw 'Clear reported success but junction still resolves' }
        Write-Output "Reparse data cleared while guard held: $output"
    } else {
        if (-not [IO.File]::Exists((Join-Path $junction 'protected.txt'))) { throw 'Failed clear changed junction' }
        $release.Set() | Out-Null
        if (-not $process.WaitForExit(5000) -or $process.ExitCode -ne 0) { throw 'Guard did not close cleanly' }
        $after = @(& $guardPath clear $junction 2>&1)
        if ($LASTEXITCODE -ne 0 -or [IO.File]::Exists((Join-Path $junction 'protected.txt'))) { throw "Clear after release failed: $after" }
        Write-Output "Reparse clear denied while guard held ($output) and succeeded after release"
    }
} finally {
    $release.Set() | Out-Null
    if (-not $process.WaitForExit(10000)) { $process.Kill(); $process.WaitForExit() }
    $process.Dispose(); $ready.Dispose(); $release.Dispose()
}
