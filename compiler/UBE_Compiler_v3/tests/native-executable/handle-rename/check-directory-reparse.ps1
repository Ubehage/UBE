param([Parameter(Mandatory=$true)][string] $Guard, [Parameter(Mandatory=$true)][string] $Actor, [Parameter(Mandatory=$true)][string] $OutputDirectory, [switch] $ReadOnly, [switch] $RequireReadOnlyObservations)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$guardPath=(Resolve-Path -LiteralPath $Guard).Path; $actorPath=(Resolve-Path -LiteralPath $Actor).Path
$root=Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
$target=Join-Path $root 'target'; [IO.Directory]::CreateDirectory($target) | Out-Null
[IO.File]::WriteAllText((Join-Path $target 'marker.txt'),'target-marker')
foreach ($case in @(@('empty-control',$false,$false),@('empty-guard',$true,$false),@('nonempty-control',$false,$true),@('nonempty-guard',$true,$true))) {
    $directory=Join-Path $root $case[0]; [IO.Directory]::CreateDirectory($directory) | Out-Null
    if ($case[2]) { [IO.File]::WriteAllText((Join-Path $directory 'existing.txt'),'existing') }
    $id=[guid]::NewGuid().ToString('N'); $readyName='Local\UBE-directory-reparse-ready-' + $id; $releaseName='Local\UBE-directory-reparse-release-' + $id
    $ready=[Threading.EventWaitHandle]::new($false,[Threading.EventResetMode]::ManualReset,$readyName)
    $release=[Threading.EventWaitHandle]::new($false,[Threading.EventResetMode]::ManualReset,$releaseName)
    $guardProcess=$null
    try {
        if ($case[1]) {
            $guardProcess=[Diagnostics.Process]::new(); $guardProcess.StartInfo.FileName=$guardPath
            $guardProcess.StartInfo.Arguments='"' + $directory + '" ' + $readyName + ' ' + $releaseName
            if ($ReadOnly) { $guardProcess.StartInfo.Arguments+=' read-only' }
            $guardProcess.StartInfo.UseShellExecute=$false; $guardProcess.StartInfo.CreateNoWindow=$true
            if (-not $guardProcess.Start() -or -not $ready.WaitOne(5000)) { throw 'Directory guard not established' }
        }
        $actorProcess=[Diagnostics.Process]::new(); $actorProcess.StartInfo.FileName=$actorPath
        $actorProcess.StartInfo.Arguments='"' + $directory + '" "' + $target + '"'
        $actorProcess.StartInfo.UseShellExecute=$false; $actorProcess.StartInfo.CreateNoWindow=$true; $actorProcess.StartInfo.RedirectStandardOutput=$true; $actorProcess.StartInfo.RedirectStandardError=$true
        if (-not $actorProcess.Start()) { throw 'Actor did not start' }
        try {
            if (-not $actorProcess.WaitForExit(5000)) { $actorProcess.Kill(); $actorProcess.WaitForExit(); throw 'Actor timed out' }
            $output=$actorProcess.StandardOutput.ReadToEnd().Trim(); $stderr=$actorProcess.StandardError.ReadToEnd().Trim()
            if ($actorProcess.ExitCode -eq 0) {
                if ($output -ne 'set error=0' -or [IO.File]::ReadAllText((Join-Path $directory 'marker.txt')) -ne 'target-marker') { throw 'Successful reparse change did not redirect to target' }
            } elseif ($actorProcess.ExitCode -notin @(3,4) -or $output -notmatch '^(open|set) error=[1-9][0-9]*$') { throw "Unexpected actor failure: $output $stderr" }
            if ($RequireReadOnlyObservations) {
                if (-not $ReadOnly) { throw 'RequireReadOnlyObservations needs ReadOnly' }
                if ($case[1] -and ($actorProcess.ExitCode -ne 3 -or $output -ne 'open error=32')) { throw "Read-only guard did not block actor: $output" }
                if ($case[0] -eq 'empty-control' -and ($actorProcess.ExitCode -ne 0 -or $output -ne 'set error=0')) { throw 'Empty control did not redirect' }
                if ($case[0] -eq 'nonempty-control' -and ($actorProcess.ExitCode -ne 4 -or $output -ne 'set error=145')) { throw 'Nonempty control differed' }
            }
            Write-Output "$($case[0]): status=$($actorProcess.ExitCode) $output"
        } finally { $actorProcess.Dispose() }
    } finally {
        $release.Set() | Out-Null
        if ($guardProcess) { if (-not $guardProcess.WaitForExit(10000)) { $guardProcess.Kill(); $guardProcess.WaitForExit() }; if ($guardProcess.ExitCode -ne 0) { throw 'Guard failed' }; $guardProcess.Dispose() }
        $ready.Dispose(); $release.Dispose()
    }
}
Write-Output "Test-owned artifacts: $root"
