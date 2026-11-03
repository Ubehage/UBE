param([Parameter(Mandatory=$true)][string] $Probe, [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$probePath = (Resolve-Path -LiteralPath $Probe).Path
$root = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
foreach ($case in @('open-uncontended','open-alias','closed-uncontended','closed-alias','preexisting-alias')) {
    $aliasCase = $case -like '*-alias'; $closedCase = $case -like 'closed-*'
    $directory = Join-Path $root $case; [IO.Directory]::CreateDirectory($directory) | Out-Null
    $candidate = Join-Path $directory 'candidate.bin'; $destination = Join-Path $directory 'destination.bin'
    $protected = Join-Path $directory 'protected.bin'; $moved = Join-Path $directory 'actor-old.bin'
    [IO.File]::WriteAllText($candidate,'candidate'); [IO.File]::WriteAllText($destination,'old'); [IO.File]::WriteAllText($protected,'protected')
    if ($case -eq 'preexisting-alias') { [IO.File]::Delete($destination); New-Item -ItemType HardLink -Path $destination -Target $protected | Out-Null }
    if ($aliasCase) {
        [IO.File]::Move($destination,$moved); [IO.File]::Move($moved,$destination)
        $control = Join-Path $directory 'link-control.bin'
        New-Item -ItemType HardLink -Path $control -Target $protected | Out-Null
        if ([IO.File]::ReadAllText($control) -ne 'protected') { throw 'Hardlink control failed' }
        [IO.File]::Delete($control)
    }
    $id = [guid]::NewGuid().ToString('N'); $readyName = 'Local\UBE-tx-ready-' + $id; $releaseName = 'Local\UBE-tx-release-' + $id
    $ready = [Threading.EventWaitHandle]::new($false,[Threading.EventResetMode]::ManualReset,$readyName)
    $release = [Threading.EventWaitHandle]::new($false,[Threading.EventResetMode]::ManualReset,$releaseName)
    $closedReadyName = 'Local\UBE-tx-closed-ready-' + $id; $closedReleaseName = 'Local\UBE-tx-closed-release-' + $id
    $closedReady = [Threading.EventWaitHandle]::new($false,[Threading.EventResetMode]::ManualReset,$closedReadyName)
    $closedRelease = [Threading.EventWaitHandle]::new($false,[Threading.EventResetMode]::ManualReset,$closedReleaseName)
    $process = [Diagnostics.Process]::new()
    try {
        $process.StartInfo.FileName = $probePath; $process.StartInfo.Arguments = '"' + $directory + '" ' + $readyName + ' ' + $releaseName
        if ($closedCase) { $process.StartInfo.Arguments += ' ' + $closedReadyName + ' ' + $closedReleaseName }
        $process.StartInfo.UseShellExecute = $false; $process.StartInfo.CreateNoWindow = $true
        $process.StartInfo.RedirectStandardError = $true; $process.StartInfo.RedirectStandardOutput = $true
        if (-not $process.Start()) { throw 'Probe did not start' }
        if (-not $ready.WaitOne(5000)) {
            if (-not $process.WaitForExit(5000)) { throw 'Probe did not signal or exit' }
            if ($case -eq 'preexisting-alias') {
                if ($process.ExitCode -ne 8 -or $process.StandardError.ReadToEnd() -notmatch 'protected identity rejected' -or [IO.File]::ReadAllText($destination) -ne 'protected' -or [IO.File]::ReadAllText($candidate) -ne 'candidate') { throw 'Pre-existing protected alias was not rejected' }
                Write-Output 'Pre-existing protected alias rejected before transaction commit.'
                continue
            }
            Write-Output "${case}: transaction guard unavailable (exit $($process.ExitCode)): $($process.StandardError.ReadToEnd().Trim())"
            continue
        }
        if ($closedCase) {
            $release.Set() | Out-Null
            if (-not $closedReady.WaitOne(5000)) { throw 'Probe did not reach closed-handle barrier' }
        }
        $actorMoved = $false; $actorError = ''
        if ($aliasCase) {
            try { [IO.File]::Move($destination,$moved); $actorMoved = $true } catch [IO.IOException] { $actorError = '0x{0:X8}' -f ([uint32]([int64]$_.Exception.HResult -band 0xFFFFFFFFL)) }
            if ($actorMoved) { New-Item -ItemType HardLink -Path $destination -Target $protected | Out-Null }
            elseif (-not [IO.File]::Exists($destination) -or [IO.File]::Exists($moved)) { throw 'Blocked actor changed the destination entries' }
        }
        if ($closedCase) { $closedRelease.Set() | Out-Null } else { $release.Set() | Out-Null }
        if (-not $process.WaitForExit(10000)) { throw 'Transaction probe timed out' }
        $stderr = $process.StandardError.ReadToEnd().Trim(); $stdout = $process.StandardOutput.ReadToEnd().Trim()
        if ([IO.File]::ReadAllText($protected) -ne 'protected') { throw 'Protected peer bytes changed' }
        $destinationBytes = if ([IO.File]::Exists($destination)) { [IO.File]::ReadAllText($destination) } else { '<absent>' }
        $candidateBytes = if ([IO.File]::Exists($candidate)) { [IO.File]::ReadAllText($candidate) } else { '<absent>' }
        if ($process.ExitCode -eq 0 -and ($destinationBytes -ne 'candidate' -or $candidateBytes -ne '<absent>')) { throw 'Commit outcome differs from reported success' }
        if ($process.ExitCode -ne 0 -and -not $actorMoved -and ($destinationBytes -ne 'old' -or $candidateBytes -ne 'candidate')) { throw 'Failed transaction did not preserve files' }
        Write-Output "${case}: actor-moved=$actorMoved actor-error=$actorError status=$($process.ExitCode) destination=$destinationBytes candidate=$candidateBytes stdout=$stdout stderr=$stderr"
    } finally {
        $release.Set() | Out-Null
        $closedRelease.Set() | Out-Null
        if (-not $process.HasExited) { if (-not $process.WaitForExit(10000)) { $process.Kill(); $process.WaitForExit() } }
        $process.Dispose(); $ready.Dispose(); $release.Dispose(); $closedReady.Dispose(); $closedRelease.Dispose()
    }
}
Write-Output "Test-owned artifacts: $root"
