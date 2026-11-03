param([Parameter(Mandatory=$true)][string] $Original,
      [Parameter(Mandatory=$true)][string] $Replacement,
      [Parameter(Mandatory=$true)][string] $OutputDirectory,
      [string] $JunctionGuard)
$ErrorActionPreference = 'Stop'
$root = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
$first = Join-Path $root 'first'; $second = Join-Path $root 'second'
[IO.Directory]::CreateDirectory($first) | Out-Null
[IO.Directory]::CreateDirectory($second) | Out-Null
[IO.File]::Copy((Resolve-Path -LiteralPath $Original).Path, (Join-Path $first 'tool.exe'))
[IO.File]::Copy((Resolve-Path -LiteralPath $Replacement).Path, (Join-Path $second 'tool.exe'))
$junction = Join-Path $root 'selected'; $old = Join-Path $root 'selected-old'
New-Item -ItemType Junction -Path $junction -Target $first | Out-Null
$selected = Join-Path $junction 'tool.exe'
$guardProcess = $null; $ready = $null; $release = $null
if ($JunctionGuard) {
    $guardPath = (Resolve-Path -LiteralPath $JunctionGuard).Path
    $id = [guid]::NewGuid().ToString('N')
    $readyName = 'Local\UBE-tool-junction-ready-' + $id
    $releaseName = 'Local\UBE-tool-junction-release-' + $id
    $ready = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $readyName)
    $release = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $releaseName)
    $guardProcess = [Diagnostics.Process]::new()
    $guardProcess.StartInfo.FileName = $guardPath
    $guardProcess.StartInfo.Arguments = '"' + $junction + '" ' + $readyName + ' ' + $releaseName
    $guardProcess.StartInfo.UseShellExecute = $false; $guardProcess.StartInfo.CreateNoWindow = $true
    if (-not $guardProcess.Start() -or -not $ready.WaitOne(5000)) { throw 'Junction guard did not become ready' }
}
$guard = [IO.File]::Open($selected, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
try {
    $before = @(& $selected)
    if ($LASTEXITCODE -ne 0 -or $before.Count -ne 1 -or $before[0] -ne '36') { throw 'Original tool control failed' }
    if ($guardProcess) {
        $moveOutput = @(& $guardPath move $junction $old)
        if ($LASTEXITCODE -ne 5) { throw "Guard failed to block junction move: $moveOutput" }
        $guarded = @(& $selected)
        if ($LASTEXITCODE -ne 0 -or $guarded.Count -ne 1 -or $guarded[0] -ne '36') { throw 'Guarded launch changed' }
        $release.Set() | Out-Null
        if (-not $guardProcess.WaitForExit(5000) -or $guardProcess.ExitCode -ne 0) { throw 'Guard did not exit' }
    }
    [IO.Directory]::Move($junction, $old)
    New-Item -ItemType Junction -Path $junction -Target $second | Out-Null
    $after = @(& $selected)
    if ($LASTEXITCODE -ne 1 -or $after.Count -ne 1 -or $after[0] -ne '33') { throw 'Substituted tool was not observed' }
    if ((Get-FileHash -LiteralPath (Join-Path $first 'tool.exe') -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $Original -Algorithm SHA256).Hash) { throw 'Original executable changed' }
    if ($JunctionGuard) { Write-Output 'Junction guard blocked swap and original launched; swap succeeded after release.' }
    else { Write-Output 'A junction swap redirected launch despite the original tool-file guard.' }
} finally {
    $guard.Dispose()
    if ($release) { $release.Set() | Out-Null }
    if ($guardProcess) { if (-not $guardProcess.WaitForExit(5000)) { $guardProcess.Kill(); $guardProcess.WaitForExit() }; $guardProcess.Dispose() }
    if ($ready) { $ready.Dispose() }; if ($release) { $release.Dispose() }
}
